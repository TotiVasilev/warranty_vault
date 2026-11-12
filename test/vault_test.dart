import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/model.dart';
import 'package:warranty_vault/vault.dart';

void main() {
  test('save, reload, backup, restore, remove', () async {
    final dir = await Directory.systemTemp.createTemp('warranty_test');
    final other = await Directory.systemTemp.createTemp('warranty_restore');
    try {
      final v = Vault(dir), restored = Vault(other);
      const a = Attachment(
        '11111111-1111-4111-8111-111111111111',
        'example.pdf',
        'pdf',
      );
      const w = Warranty(
        id: '22222222-2222-4222-8222-222222222222',
        product: 'Demo',
        start: '2026-11-12',
        expiry: '2028-11-12',
        docs: [a],
      );
      await v.save(w, [
        PendingDoc(a, Uint8List.fromList([1, 2, 3])),
      ]);
      expect((await v.load()).single.product, 'Demo');
      expect(await v.file(a).readAsBytes(), [1, 2, 3]);
      await v.save(
        Warranty(
          id: w.id,
          product: 'Updated',
          start: w.start,
          expiry: w.expiry,
          docs: w.docs,
        ),
        [],
      );
      final all = await v.load();
      expect(all.single.product, 'Updated');
      expect(await restored.restore(await v.backup(all)), 1);
      final imported = (await restored.load()).single;
      expect(imported.id, isNot(w.id));
      expect(await restored.file(imported.docs.single).readAsBytes(), [
        1,
        2,
        3,
      ]);
      await v.remove(all.single);
      expect(await v.load(), isEmpty);
      expect(await v.file(a).exists(), false);
    } finally {
      await dir.delete(recursive: true);
      await other.delete(recursive: true);
    }
  });
}
