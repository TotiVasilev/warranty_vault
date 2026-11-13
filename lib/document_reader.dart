import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'languages.dart';
import 'model.dart';
import 'photo_table.dart';
import 'vault.dart';

const autoOcrLanguages = 'eng+bul+deu+nld';
const _iosOcr = MethodChannel('warranty_vault/ios_ocr');

// Retain the chosen document language and English technical product names.
String iosOcrLanguages(String language) {
  if (language == 'auto') return autoOcrLanguages;
  if (language == 'bul_only') return 'bul';
  if (!documentLanguages.containsKey(language)) return 'eng';
  return language == 'eng' ? 'eng' : '$language+eng';
}

Future<String> _readIosPhoto(
  String path,
  String language,
  String layout,
) async {
  final candidates = <String>[];
  Object? lastError;
  Future<void> attempt(String langs, {required bool vision}) async {
    try {
      final result = await _iosOcr
          .invokeListMethod<String>('recognize', {
            'path': path,
            'language': langs,
            'vision': vision,
            'layout': layout,
          })
          .timeout(const Duration(seconds: 90));
      if (result != null)
        candidates.addAll(result.where((s) => s.trim().isNotEmpty));
    } catch (error) {
      lastError = error;
    }
  }

  await attempt(iosOcrLanguages(language), vision: true);
  // Auto may mix Cyrillic and Latin. Retry a narrower model only when needed.
  if (language == 'auto' &&
      ocrTextScore(chooseOcrText(candidates)) < 30 &&
      lastError == null) {
    await attempt('bul+eng', vision: false);
  }
  if (candidates.isEmpty && lastError != null) {
    throw StateError('iPhone OCR failed: $lastError');
  }
  return chooseOcrText(candidates);
}

// Prefer a coherent product table over isolated labels, and do not join text
// from separate OCR attempts (that could mix unrelated serials and dates).
int ocrTextScore(String text) {
  if (text.trim().isEmpty) return -1;
  final rows = extractPhotoTable(text);
  if (rows.isNotEmpty) {
    return 1000 +
        rows.length * 100 +
        rows.where((r) => r.containsKey('expiry')).length * 10;
  }
  final fields = extractFields(text);
  var score = 0;
  for (final key in [
    'product',
    'store',
    'customer',
    'model',
    'serial',
    'reference',
    'receipt',
    'start',
    'expiry',
    'months',
  ]) {
    if ((fields[key] ?? '').trim().isNotEmpty) {
      score += key == 'product' || key == 'expiry' ? 15 : 5;
    }
  }
  return score;
}

String chooseOcrText(Iterable<String> candidates) {
  var best = '';
  var bestScore = -1;
  for (final candidate in candidates) {
    final score = ocrTextScore(candidate);
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

Future<String> readDocument(
  PendingDoc d, {
  String language = 'auto',
  String pageMode = '6',
}) async {
  if (d.doc.ext == 'pdf') {
    await pdfrxFlutterInitialize();
    final pdf = await PdfDocument.openData(d.bytes);
    try {
      final result = StringBuffer();
      for (final page in pdf.pages.take(30)) {
        final text = await page.loadText();
        result.writeln(text?.fullText ?? '');
      }
      final text = result.toString();
      if (text.trim().isEmpty) {
        throw StateError(
          'Image-only PDF: import a photo or enter the details manually.',
        );
      }
      return text;
    } finally {
      pdf.dispose();
    }
  }
  final langs = language == 'auto'
      ? autoOcrLanguages
      : language == 'bul_only'
      ? 'bul'
      : language == 'bul'
      ? 'bul+eng'
      : documentLanguages.containsKey(language)
      ? language
      : 'eng';
  final mode = const ['3', '6', '11'].contains(pageMode) ? pageMode : '6';
  final tmp = await getTemporaryDirectory();
  final f = File(p.join(tmp.path, '${d.doc.id}.${d.doc.ext}'));
  await f.writeAsBytes(d.bytes);
  final mobile = Platform.isAndroid;
  final dataDir = Directory(p.join(tmp.path, 'wv_tessdata_v03'));
  final candidates = <String>[];
  final attempts = <String>{};
  Object? lastError;
  try {
    if (Platform.isIOS) return await _readIosPhoto(f.path, language, mode);
    Future<void> attempt(String selected, String layout) async {
      if (!attempts.add('$selected/$layout')) return;
      try {
        if (mobile) {
          candidates.add(
            await FlutterTesseractOcr.extractText(
              f.path,
              language: selected,
              args: {'psm': layout, 'preserve_interword_spaces': '1'},
            ),
          );
        } else {
          await dataDir.create(recursive: true);
          for (final lang in selected.split('+')) {
            final name = '$lang.traineddata';
            final dest = File(p.join(dataDir.path, name));
            if (!await dest.exists() || await dest.length() == 0) {
              final data = await rootBundle.load('assets/tessdata/$name');
              await dest.writeAsBytes(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
                flush: true,
              );
            }
          }
          final result = await Process.run(
            'tesseract',
            [
              f.path,
              'stdout',
              '--tessdata-dir',
              dataDir.path,
              '-l',
              selected,
              '--psm',
              layout,
              '-c',
              'preserve_interword_spaces=1',
            ],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );
          if (result.exitCode != 0)
            throw StateError('Tesseract OCR failed: ${result.stderr}');
          candidates.add(result.stdout as String);
        }
      } catch (error) {
        lastError = error;
      }
    }

    // Try the chosen settings first. Page-layout mode 3 often preserves the
    // columns on warranty cards better than a single text block (mode 6).
    await attempt(langs, mode);
    final first = chooseOcrText(candidates);
    final fields = extractFields(first);
    final hasCompleteRecord =
        (fields['product'] ?? '').isNotEmpty &&
        ((fields['expiry'] ?? '').isNotEmpty ||
            (fields['months'] ?? '').isNotEmpty);
    // Always compare a recognized table with an alternate layout: a first
    // attempt may have found only one of several rows.
    if (!hasCompleteRecord || extractPhotoTable(first).isNotEmpty) {
      await attempt(langs, '3');
      await attempt(langs, '6');
    }
    var best = chooseOcrText(candidates);
    // Auto's four-language model can confuse Cyrillic and Latin characters.
    // A narrower Bulgarian+English pass is a bounded fallback, not a guess
    // that every document is Bulgarian. Keep it only if it parses better.
    if (language == 'auto' && ocrTextScore(best) < 30) {
      await attempt('bul+eng', '3');
      await attempt('bul+eng', '6');
      best = chooseOcrText(candidates);
    }
    if (candidates.isEmpty && lastError != null) {
      throw StateError('All OCR attempts failed: $lastError');
    }
    return best;
  } finally {
    if (await f.exists()) await f.delete();
  }
}
