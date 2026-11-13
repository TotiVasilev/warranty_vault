import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/document_reader.dart';
import 'package:warranty_vault/photo_table.dart';

void main() {
  // Layout based on actual OCR from a Bulgarian warranty photograph;
  // customer and serials are synthetic to keep personal data out of tests.
  const card = '''COMPUTERS SERVICE
web: www.cservice-bg.com
ГАРАНЦИОННА КАРТА
ПОЛУЧАТЕЛ: Пример Клиент
Дата 19.03.2026 г.
ОПИСАНИЕ                 СЕРИЕН НОМЕР | ГАРАНЦИЯ
MB: ASROCK B650M PG LIGHTNING/PHANTOM GAMING | DEMO123456 | 36 месеца |
RAM: 16 GB DDRS 5600 A-DATA           DEMO234567 | 96 месеца
RAM: 8 GB DDRS 5600 A-DATA            DEMO345678 | 96 месеца
Устройствата и компонентите са изпитани.''';
  test('layout retry prefers a real product table over broken text', () {
    final best = chooseOcrText(['X? q | !', card]);
    expect(best, card);
    final rows = extractPhotoTable(best);
    expect(rows.length, 3);
    expect(rows.map((r) => r['expiry']).toList(), [
      '2029-03-19',
      '2034-03-19',
      '2034-03-19',
    ]);
  });
  test('layout retry prefers more rows rather than the first match', () {
    final single = card
        .split('\n')
        .where((l) => !l.startsWith('RAM:'))
        .join('\n');
    expect(chooseOcrText([single, card]), card);
  });
  test('normal labeled documents and empty results still work', () {
    const normal =
        'Product: Laptop\nWarranty period: 24 months\nSerial number: ABC123456';
    expect(chooseOcrText(['', normal]), normal);
    expect(chooseOcrText(['', '  ']), '');
  });
}
