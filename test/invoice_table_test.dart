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
    expect(
      rows[1]['product'],
      'Apple iPad Air 11, M3, 128GB, Wi-Fi, Space Gray',
    );
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
    final rows = extractPhotoTable(
      invoice
          .replaceFirst('Пример Магазин ООД', 'Друг Доставчик ЕООД')
          .replaceFirst(
            'Стилус Apple Pencil Pro 2024 [mx2d3zm/a] броя 245.83 295.00 1 245.83 295.00',
            'Dell Monitor 27 [U2724D]\nброя 245,83 295,00\n1 245,83 295,00',
          ),
    );
    expect(rows.length, 2);
    expect(rows.first['product'], 'Dell Monitor 27');
    expect(rows.first['store'], 'Друг Доставчик ЕООД');
  });
  test('ordinary warranty and unrelated price lists are not invoices', () {
    expect(
      extractInvoiceTable('Product: Laptop\nWarranty: 24 months'),
      isEmpty,
    );
    expect(
      extractInvoiceTable(invoice.replaceFirst('ФАКТУРА', 'ЦЕНОВА ЛИСТА')),
      isEmpty,
    );
  });
  test('incomplete or skipped row is not returned as a complete invoice', () {
    expect(
      extractInvoiceTable(
        invoice.replaceFirst('1,332.66 1 1,110.55 1,332.66', '1,332.66'),
      ),
      isEmpty,
    );
    expect(
      extractInvoiceTable(invoice.replaceFirst('2 Apple', '3 Apple')),
      isEmpty,
    );
  });
  // Same parser, independent heading vocabulary. Mixed-script product names
  // are intentionally retained verbatim, not translated or normalized.
  const layouts = <String, List<String>>{
    'English': ['Invoice', 'Description', 'Quantity', 'Unit price', 'Total'],
    'Bulgarian': ['Фактура', 'Описание', 'Количество', 'Единична цена', 'Общо'],
    'German': [
      'Rechnung',
      'Beschreibung',
      'Menge',
      'Einzelpreis',
      'Gesamtbetrag',
    ],
    'Dutch': ['Factuur', 'Omschrijving', 'Aantal', 'Stukprijs', 'Totaal'],
    'French': [
      'Facture',
      'Désignation',
      'Quantité',
      'Prix unitaire',
      'Montant',
    ],
    'Spanish': [
      'Factura',
      'Descripción',
      'Cantidad',
      'Precio unitario',
      'Importe',
    ],
    'Italian': [
      'Fattura',
      'Descrizione',
      'Quantità',
      'Prezzo unitario',
      'Importo',
    ],
    'Romanian': ['Factură', 'Denumire', 'Cantitate', 'Preț unitar', 'Valoare'],
    'Polish': ['Faktura', 'Opis', 'Ilość', 'Cena jednostkowa', 'Wartość'],
    'Portuguese': [
      'Fatura',
      'Descrição',
      'Quantidade',
      'Preço unitário',
      'Valor',
    ],
    'Greek': ['Τιμολόγιο', 'Περιγραφή', 'Ποσότητα', 'Τιμή μονάδας', 'Σύνολο'],
    'Turkish': ['Fatura', 'Açıklama', 'Miktar', 'Birim fiyat', 'Tutar'],
    'Russian': ['Счёт-фактура', 'Наименование', 'Кол-во', 'Цена', 'Сумма'],
    'Ukrainian': ['Рахунок', 'Назва товару', 'Кількість', 'Ціна', 'Сума'],
  };
  for (final e in layouts.entries) {
    test('${e.key}: two mixed-language products, no guessed coverage', () {
      final h = e.value;
      final rows = extractPhotoTable(
        '${h[0]}\n${h.skip(1).join(" ")}\n'
        '1 Стилус Apple Pencil Pro [MX2D3ZM/A] 1 245.83 245.83\n'
        '2 Apple iPad Air M3 128GB [MC9W4HC/A] 1 1,110.55 1,110.55',
      );
      expect(rows.length, 2);
      expect(rows.first['product'], 'Стилус Apple Pencil Pro');
      expect(rows.last['model'], 'MC9W4HC/A');
      expect(rows.every((r) => !r.containsKey('expiry')), isTrue);
    });
  }
  test('mixed headings and explicit unnumbered columns', () {
    final rows = extractPhotoTable(
      'Invoice\nОписание | Qty | Unit price | Total\n'
      'Apple Pencil Pro | 1 | 99.00 | 99.00\n'
      'Клавиатура Logitech | 1 | 49.00 | 49.00',
    );
    expect(rows.map((r) => r['product']).toList(), [
      'Apple Pencil Pro',
      'Клавиатура Logitech',
    ]);
  });
  test('quantity after price, total price heading not double-counted', () {
    final rows = extractPhotoTable(
      'Invoice\nDescription Unit price Quantity Total price\n'
      '1 Dell Monitor 27 100.00 2 200.00',
    );
    expect(rows.single['product'], 'Dell Monitor 27');
  });
  test('German warranty table keeps products separate and dates unguessed', () {
    final rows = extractPhotoTable(
      'Garantiekarte\nBeschreibung | Seriennummer | Garantie\n'
      'Apple Pencil | ABC12345 | 24 Monate\n'
      'Клавиатура Logitech | DEF12345 | 12 Monate',
    );
    expect(rows.length, 2);
    expect(rows.first['serial'], 'ABC12345');
    expect(rows.last['months'], '12');
    expect(rows.first.containsKey('expiry'), isFalse);
  });
}
