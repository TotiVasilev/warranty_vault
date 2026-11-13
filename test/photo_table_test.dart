import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/photo_table.dart';

void main() {
  const card = '''COMPUTERS SERVICE
web: www.cservice-bg.com
ГАРАНЦИОННА КАРТА
ПОЛУЧАТЕЛ: Пример Клиент
Дата 19.03.2026 г.
ОПИСАНИЕ             СЕРИЕН НОМЕР | ГАРАНЦИЯ |
MB: ASROCK B650M PG LIGHTNING/PHANTOM GAMING | DEMO001234       36 месеца     и 8
RAM: 16 GB DDR5 5600 A-DATA       DEMO002345       96 месеца     A q
RAM: 8 GB DDR5 5600 A-DATA        DEMO003456       96 mecena     5 §
Устройствата и компонентите са изпитани.
Гаранцията за батерии е 6 месеца.''';
  test('keeps three OCR product rows separate and calculates each date', () {
    final rows = extractPhotoTable(card);
    expect(rows.length, 3);
    expect(rows[0]['product'], 'MB: ASROCK B650M PG LIGHTNING/PHANTOM GAMING');
    expect(rows.map((r) => r['serial']).toList(), ['DEMO001234','DEMO002345','DEMO003456']);
    expect(rows.map((r) => r['months']).toList(), ['36','96','96']);
    expect(rows.map((r) => r['expiry']).toList(), ['2029-03-19','2034-03-19','2034-03-19']);
    expect(rows.first['customer'], 'Пример Клиент');
    expect(rows.first['store'], 'Computers Service');
  });
  test('missing start date remains missing', () {
    final rows = extractPhotoTable(card.replaceAll('Дата 19.03.2026 г.', ''));
    expect(rows.length, 3);
    expect(rows.first.containsKey('start'), false);
    expect(rows.first.containsKey('expiry'), false);
  });
  test('ordinary warranty does not activate table parser', () {
    expect(extractPhotoTable('Product: Laptop\nSerial number: 123456\nWarranty: 24 months'), isEmpty);
  });
  test('single row table also works', () {
    final lines = card.split('\n');
    final input = lines.where((line) => !line.startsWith('RAM:')).join('\n');
    expect(extractPhotoTable(input).length, 1);
  });
}
