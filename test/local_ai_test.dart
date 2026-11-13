import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/local_ai.dart';

void main() {
  test('AI suggestions calculate duration from invoice and expiry', () {
    final r = normalizeAiFields({
      'product': 'Example GPU',
      'customer': 'Example Buyer',
      'invoice_date': '2023-04-12',
      'expiry': '2025-04-12',
    });
    expect(r['start'], '2023-04-12');
    expect(r['months'], '24');
    expect(r['notes'], contains('Suggested start'));
  });
  test('Missing dates remain missing', () {
    final r = normalizeAiFields({
      'product': 'Tablet',
      'months': '24',
      'start': null,
    });
    expect(r['start'], isNull);
    expect(r['expiry'], isNull);
  });
  test('Invalid dates and duration rejected', () {
    final r = normalizeAiFields({
      'start': '2025-02-30',
      'months': '900',
      'serial': 'unknown',
    });
    expect(r['start'], isNull);
    expect(r['months'], isNull);
    expect(r['serial'], isNull);
  });
  test('Explicit date disagreement flagged', () {
    final r = normalizeAiFields({
      'start': '2023-04-12',
      'expiry': '2025-04-12',
      'months': '12',
      'start_source': 'explicit',
    });
    expect(r['months'], '12');
    expect(r['notes'], contains('differs'));
  });
  const invoice =
      """Nr. Omschrijving Aantal Garantie t/m Eenheid Prijs Btw Bedrag
Ordernr. V12345678
5098760 Example GPU 16 GB
GDDR6 - PCIe 4.0 x16
1 12 apr 2025 Stuks 699,95 21 699,95
123456789012 1 Stuks
Betalingscondities 0d
Betaald met:
Vereffenen via creditnota:F99999999 699,95
Klantnr.
Factuurnr.
Datum
Extern documentnr. MM12345678
F12345678
Uw referentie
MK12345678 12 april 2023
Verkoop - Factuur
Azerty BV
Wij hebben je product vervangen voor een nieuw artikel.""";
  test('incorrect AI cannot overwrite recognized invoice fields', () {
    final r = reconcileAiFields(invoice, {
      'product': '5098760 Example GPU 16 GB GDDR6 - PCIe 4.0 x16',
      'product_evidence': '5098760 Example GPU 16 GB GDDR6 - PCIe 4.0 x16',
      'serial': '123456789012',
      'serial_evidence': '123456789012 1 Stuks',
      'receipt': 'F99999999',
      'receipt_evidence': 'Vereffenen via creditnota:F99999999 699,95',
      'reference': 'F12345678',
      'reference_evidence': 'F12345678 Uw referentie',
      'start': '2025-04-12',
      'start_evidence': '1 12 apr 2025 Stuks',
      'expiry': '2026-04-12',
      'expiry_evidence': '12 apr 2025',
      'months': '12',
      'months_evidence': '12 apr 2025',
      'notes': 'Warranty ends in 2026.',
    });
    expect(r['product'], 'Example GPU 16 GB GDDR6 - PCIe 4.0 x16');
    expect(r['receipt'], 'F12345678');
    expect(r['reference'], isNull);
    expect(r['serial'], isNull);
    expect(r['start'], '2023-04-12');
    expect(r['expiry'], '2025-04-12');
    expect(r['months'], '24');
    expect(r['notes'], contains('Article number: 5098760'));
    expect(r['notes'], isNot(contains('Warranty ends in 2026')));
  });
  test('AI fills unknown labels with source quotes', () {
    final r = reconcileAiFields(
      'Objet acquis — Example Tablet\nCouverture jusque 12 avril 2025\nÉmis le 12 avril 2023',
      {
        'product': 'Example Tablet',
        'product_evidence': 'Objet acquis — Example Tablet',
        'expiry': '2025-04-12',
        'expiry_evidence': 'Couverture jusque 12 avril 2025',
        'invoice_date': '2023-04-12',
        'invoice_date_evidence': 'Émis le 12 avril 2023',
        'serial': 'MADEUP',
        'serial_evidence': 'Serial: MADEUP',
      },
    );
    expect(r['product'], 'Example Tablet');
    expect(r['start'], '2023-04-12');
    expect(r['expiry'], '2025-04-12');
    expect(r['months'], '24');
    expect(r['serial'], isNull);
  });
  test('a date quoted from a document cannot be changed by AI', () {
    final r = reconcileAiFields('Coverage through 12 April 2025', {
      'expiry': '2026-04-12',
      'expiry_evidence': 'Coverage through 12 April 2025',
    });
    expect(r['expiry'], isNull);
  });
  test('AI cannot invent a date based on a bare duration', () {
    final r = reconcileAiFields('Term of cover 24 months', {
      'months': '24',
      'months_evidence': 'Term of cover 24 months',
      'start': '2025-04-12',
      'start_evidence': 'Term of cover 24 months',
    });
    expect(r['months'], '24');
    expect(r['start'], isNull);
    expect(r['expiry'], isNull);
  });
}
