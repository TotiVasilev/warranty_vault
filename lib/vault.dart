import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'model.dart';

const maxFile = 25 * 1024 * 1024;
const maxBackup = 100 * 1024 * 1024;

class PendingDoc {
  final Attachment doc;
  final Uint8List bytes;
  PendingDoc(this.doc, this.bytes);
}

class Vault {
  final Directory root;
  Vault(this.root);
  static Future<Vault> open() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'warranty_vault'));
    await root.create(recursive: true);
    return Vault(root);
  }

  File record(String id) => File(p.join(root.path, '$id.json'));
  File file(Attachment a) => File(p.join(root.path, '${a.id}.${a.ext}'));
  Future<List<Warranty>> load() async {
    final results = <Warranty>[];
    await for (final f in root.list()) {
      if (f is File && p.extension(f.path) == '.json') {
        final w = Warranty.fromJson(
          Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map),
        );
        if (p.basename(f.path) != '${w.id}.json')
          throw const FormatException('Record filename mismatch');
        results.add(w);
      }
    }
    return results;
  }

  Future<void> save(Warranty w, List<PendingDoc> pending) async {
    final created = <File>[];
    final temp = File('${record(w.id).path}.tmp');
    try {
      for (final d in pending) {
        final f = file(d.doc);
        await f.writeAsBytes(d.bytes, flush: true);
        created.add(f);
      }
      await temp.writeAsString(jsonEncode(w.toJson()), flush: true);
      await temp.rename(record(w.id).path);
    } catch (_) {
      for (final f in created) {
        if (await f.exists()) await f.delete();
      }
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  Future<void> remove(Warranty w) async {
    await record(w.id).delete();
    for (final d in w.docs) {
      final f = file(d);
      if (await f.exists()) await f.delete();
    }
  }

  Future<Uint8List> backup(List<Warranty> records) async {
    final docs = <String, String>{};
    var total = 0;
    for (final w in records) {
      for (final d in w.docs) {
        final f = file(d);
        final size = await f.length();
        total += size;
        if (total > maxBackup * 0.70)
          throw StateError('Backup exceeds 100 MB prototype limit');
        docs[d.id] = base64Encode(await f.readAsBytes());
      }
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'records': records.map((w) => w.toJson()).toList(),
          'documents': docs,
        }),
      ),
    );
    if (bytes.length > maxBackup)
      throw StateError('Backup exceeds 100 MB prototype limit');
    return bytes;
  }

  Future<int> restore(Uint8List bytes) async {
    if (bytes.length > maxBackup)
      throw const FormatException('Backup too large');
    final j = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    if (j['version'] != 1) throw const FormatException('Unsupported backup');
    final docs = Map<String, dynamic>.from(j['documents'] as Map);
    final staged = <(Warranty, List<PendingDoc>)>[];
    for (final row in j['records'] as List) {
      final old = Warranty.fromJson(Map<String, dynamic>.from(row as Map));
      final pending = <PendingDoc>[];
      for (final d in old.docs) {
        final b = base64Decode(docs[d.id] as String);
        if (b.length > maxFile)
          throw const FormatException('Document exceeds 25 MB');
        pending.add(
          PendingDoc(Attachment(const Uuid().v4(), d.name, d.ext), b),
        );
      }
      final w = Warranty.fromJson({
        ...old.toJson(),
        'id': const Uuid().v4(),
        'docs': pending.map((d) => d.doc.toJson()).toList(),
      });
      staged.add((w, pending));
    }
    final saved = <Warranty>[];
    try {
      for (final pair in staged) {
        await save(pair.$1, pair.$2);
        saved.add(pair.$1);
      }
    } catch (_) {
      for (final w in saved) {
        await remove(w);
      }
      rethrow;
    }
    return saved.length;
  }
}
