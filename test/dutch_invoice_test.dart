import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/model.dart';

void main() {
  const table = '''Nr. Omschrijving Aantal Garantie t/m Eenheid Prijs Btw Bedrag
Ordernr. V12345678
5098760 Example graphics card 16 GB
GDDR6 - PCIe 4.0 x16
1 12 apr 2025 Stuks 699,95 21 699,95
 123456789012 1 Stuks
Betalingscondities 0d''';
  test('Dutch dates and invalid date', () {
    expect(iso(parseDate('12 april 2023')!), '2023-04-12');
    expect(iso(parseDate('12 apr 2025')!), '2025-04-12');
    expect(parseDate('31 februari 2025'), isNull);
  });
  test('PDFium-style Azerty replacement invoice', () {
    final f = extractFields('''$table
Klantnr.
Factuurnr.
Datum
Extern documentnr. MM12345678
F12345678
Uw referentie
MK12345678 12 april 2023
Verkoop - Factuur
Azerty BV
Wij hebben je product vervangen voor een nieuw artikel.''');
    expect(f['product'], 'Example graphics card 16 GB GDDR6 - PCIe 4.0 x16');
    expect(f['expiry'], '2025-04-12');
    expect(f['store'], 'Azerty BV');
    expect(f['receipt'], 'F12345678');
    expect(f['notes'], contains('2023-04-12'));
    expect(f['notes'], contains('V12345678'));
    expect(f['start'], '2023-04-12');
    expect(f['months'], '24');
    expect(f['notes'], contains('confirm actual start'));
    expect(f['serial'], isNull);
  });
  test('PDFium split address plus independent shipping recipient guard', () {
    final f = extractFields('''$table
Klantnr.
Factuurnr.
Datum
F12345678
MK12345678 12 april 2023
Verkoop - Factuur
Nederland
Exampletown, 1234AB
Alex Example
Sample Street 12
Factuuradres Verzendadres
Alex
Example
Sample Street 12
Exampletown, 1234AB
Nederland
Azerty BV''');
    expect(f['customer'], 'Alex Example');
    expect(f['start'], '2023-04-12');
    expect(f['months'], '24');
    expect(f['serial'], isNull);
    final different = extractFields('''Alex Example
Factuuradres Verzendadres
Sam
Other
Sample Street 12
Nederland''');
    expect(different['customer'], isNull);
  });
  test('layout-preserving billing name before shipping column', () {
    final f = extractFields(
      'Factuuradres       Verzendadres\nAlex Example       Sam\nSample Street 12   Other\nExampletown 1234AB',
    );
    expect(f['customer'], 'Alex Example');
  });
  test('generic invoice date plus explicit end suggests dates', () {
    final f = extractFields(
      'Product: Tablet\nInvoice date: 12-04-2023\nExpiry date: 12-04-2025',
    );
    expect(f['start'], '2023-04-12');
    expect(f['months'], '24');
    expect(f['notes'], contains('Suggested warranty start'));
  });
  test('explicit start and end derive whole months; no invented serial', () {
    final f = extractFields(
      'Product: Tablet\nPurchase date: 31-01-2024\nExpiry date: 29-02-2024',
    );
    expect(f['months'], '1');
    expect(f['serial'], isNull);
  });
  test('invoice date alone does not imply a start or expiry', () {
    final f = extractFields('Product: Tablet\nInvoice date: 12-04-2023');
    expect(f['start'], isNull);
    expect(f['expiry'], isNull);
  });
  test('nonmatching duration does not override explicit term or infer start', () {
    final f = extractFields(
      'Product: Tablet\nInvoice date: 12-04-2023\nExpiry date: 12-04-2025\nWarranty period: 12 months',
    );
    expect(f['start'], isNull);
    expect(f['months'], '12');
  });
  test('non-whole-month dates do not invent duration', () {
    final f = extractFields(
      'Product: Tablet\nPurchase date: 12-04-2023\nExpiry date: 13-04-2025',
    );
    expect(f['months'], isNull);
  });
  test('expiry-only warranty round trips', () {
    const w = Warranty(
      id: '12345678-1234-1234-1234-123456789abc',
      product: 'Test',
      start: '',
      expiry: '2025-04-12',
    );
    final restored = Warranty.fromJson(w.toJson());
    expect(restored.start, '');
    expect(restored.remaining(DateTime(2025, 4, 13)), -1);
  });
  test('explicit Dutch expiry label', () {
    expect(
      extractFields('Productnaam: Test\nGarantie t/m: 12 apr 2025')['expiry'],
      '2025-04-12',
    );
  });
}
