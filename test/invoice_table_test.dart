import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/photo_table.dart';

// Real invoice layout, with synthetic customer and invoice identifiers.
const invoice = '''Име на клиента: Пример Клиент
Фирма/ Наименование: Пример Магазин ООД
ФАКТУРА
ОРИГИНАЛ
Номер: 1234567890
Дата: 21-06-2025
Място: България
No/код Описание Мерна
единица
Единична цена
без ДДС
BGN
Единична цена
с ДДС
BGN
Кол.
Общо
без ДДС
BGN
Общо
с ДДС
BGN
1 Стилус Apple Pencil Pro 2024 [mx2d3zm/a] броя 245.83 295.00 1 245.83 295.00
2 Apple iPad Air 11, M3, 128GB, Wi-Fi, Space Gray [MC9W4HC/A] броя 1,110.55 1,332.66 1 1,110.55 1,332.66
Изготвил: 1499
Обща сума: 1,627.66 лв''';

void main() {
  test('shared table path recognizes both invoice products without AI', () {
    final rows = extractPhotoTable(invoice);
    expect(rows.length, 2);
    expect(rows[0]['product'], 'Стилус Apple Pencil Pro 2024');
    expect(rows[0]['model'], 'mx2d3zm/a');
    expect(rows[1]['product'], 'Apple iPad Air 11, M3, 128GB, Wi-Fi, Space Gray');
    expect(rows[1]['model'], 'MC9W4HC/A');
    for (final row in rows) {
      expect(row['store'], 'Пример Магазин ООД');
      expect(row['customer'], 'Пример Клиент');
      expect(row['receipt'], '1234567890');
      expect(row['notes'], contains('2025-06-21'));
      for (final key in ['serial', 'start', 'expiry', 'months']) {
        expect(row.containsKey(key), isFalse);
      }
    }
  });
  test('another seller and wrapped rows with decimal commas', () {
    final rows = extractPhotoTable(invoice.replaceFirst('Пример Магазин ООД', 'Друг Доставчик ЕООД')
      .replaceFirst('Стилус Apple Pencil Pro 2024 [mx2d3zm/a] броя 245.83 295.00 1 245.83 295.00',
        'Dell Monitor 27 [U2724D]\nброя 245,83 295,00\n1 245,83 295,00'));
    expect(rows.length, 2);
    expect(rows.first['product'], 'Dell Monitor 27');
    expect(rows.first['store'], 'Друг Доставчик ЕООД');
  });
  test('ordinary warranty and unrelated price lists are not invoices', () {
    expect(extractInvoiceTable('Product: Laptop\nWarranty: 24 months'), isEmpty);
    expect(extractInvoiceTable(invoice.replaceFirst('ФАКТУРА', 'ЦЕНОВА ЛИСТА')), isEmpty);
  });
  test('incomplete or skipped row is not returned as a complete invoice', () {
    expect(extractInvoiceTable(invoice.replaceFirst('1,332.66 1 1,110.55 1,332.66', '1,332.66')), isEmpty);
    expect(extractInvoiceTable(invoice.replaceFirst('2 Apple', '3 Apple')), isEmpty);
  });
}
