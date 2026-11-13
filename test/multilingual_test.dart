import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/model.dart';
import 'package:warranty_vault/languages.dart';

void main() {
  final examples = <String, (String, String)>{
    'German': (
      'Produkt: Test Tablet\nHändler: Demo GmbH\nSeriennummer: ABC-123\nKaufdatum: 12.11.2026\nGarantiezeit: 2 Jahre',
      '24',
    ),
    'Dutch': (
      'Productnaam: Test Tablet\nVerkoper: Demo BV\nSerienummer: ABC-123\nAankoopdatum: 12-11-2026\nGarantietermijn: 24 maanden',
      '24',
    ),
    'French': (
      'Produit: Test Tablet\nVendeur: Demo\nNuméro de série: ABC-123\nDate d’achat: 12/11/2026\nDurée de garantie: 2 ans',
      '24',
    ),
    'Spanish': (
      'Producto: Test Tablet\nTienda: Demo\nNúmero de serie: ABC-123\nFecha de compra: 12/11/2026\nPeríodo de garantía: 24 meses',
      '24',
    ),
    'Italian': (
      'Prodotto: Test Tablet\nVenditore: Demo\nNumero di serie: ABC-123\nData di acquisto: 12/11/2026\nDurata della garanzia: 2 anni',
      '24',
    ),
    'Romanian': (
      'Produs: Test Tablet\nMagazin: Demo\nNumăr de serie: ABC-123\nData achiziției: 12.11.2026\nPerioada de garanție: 24 luni',
      '24',
    ),
    'Polish': (
      'Nazwa produktu: Test Tablet\nSklep: Demo\nNumer seryjny: ABC-123\nData zakupu: 12.11.2026\nOkres gwarancji: 2 lata',
      '24',
    ),
    'Portuguese': (
      'Produto: Test Tablet\nLoja: Demo\nNúmero de série: ABC-123\nData de compra: 12/11/2026\nPrazo de garantia: 2 anos',
      '24',
    ),
    'Greek': (
      'Προϊόν: Test Tablet\nΚατάστημα: Demo\nΣειριακός αριθμός: ABC-123\nΗμερομηνία αγοράς: 12/11/2026\nΔιάρκεια εγγύησης: 24 μήνες',
      '24',
    ),
    'Turkish': (
      'Ürün: Test Tablet\nSatıcı: Demo\nSeri numarası: ABC-123\nSatın alma tarihi: 12.11.2026\nGaranti süresi: 2 yıl',
      '24',
    ),
    'Russian': (
      'Наименование товара: Test Tablet\nПродавец: Demo\nСерийный номер: ABC-123\nДата покупки: 12.11.2026\nГарантийный срок: 24 месяца',
      '24',
    ),
    'Ukrainian': (
      'Назва товару: Test Tablet\nПродавець: Demo\nСерійний номер: ABC-123\nДата придбання: 12.11.2026\nГарантійний строк: 2 роки',
      '24',
    ),
  };
  for (final e in examples.entries) {
    test('${e.key} fields and language', () {
      final f = extractFields(e.value.$1);
      expect(f['product'], 'Test Tablet');
      expect(f['serial'], 'ABC-123');
      expect(f['months'], e.value.$2);
      expect(f['start'], '2026-11-12');
      expect(f['expiry'], '2028-11-12');
      expect(documentLanguage(e.value.$1), e.key);
    });
  }
  test('German table, no invented start', () {
    final f = extractFields(
      'Produkt Garantiezeit Seriennummer\nTest Tablet 24 Monate ABC-123',
    );
    expect(f['product'], 'Test Tablet');
    expect(f['months'], '24');
    expect(f['serial'], 'ABC-123');
    expect(f.containsKey('start'), false);
  });
  test('Dutch table with split headings', () {
    final f = extractFields(
      'Productnaam\nGarantietermijn\nSerienummer\nTest Tablet 24 maanden ABC-123',
    );
    expect(f['product'], 'Test Tablet');
    expect(f['months'], '24');
    expect(f['serial'], 'ABC-123');
  });
  test('Unknown language and unrelated prose', () {
    expect(documentLanguage('XYZ 123'), 'Uncertain / mixed');
    expect(extractFields('The battery has a guarantee of 6 months.'), isEmpty);
  });
  test('Ambiguous table does not merge products', () {
    final f = extractFields(
      'Produkt Garantiezeit Seriennummer\nFirst Tablet 24 Monate ABC-123\nSecond Tablet 12 Monate ABC-456',
    );
    expect(f.containsKey('product'), false);
  });
}
