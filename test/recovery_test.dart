import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/model.dart';
import 'package:warranty_vault/product_ai.dart';

void main() {
  test('recovery: invoice dates and duration remain coherent', () {
    final fields = extractFields(
      'Product: Example GPU\nInvoice date: 12 april 2023\nExpiry date: 12 apr 2025',
    );
    expect(fields['start'], '2023-04-12');
    expect(fields['expiry'], '2025-04-12');
    expect(fields['months'], '24');
  });
  test('recovery: contextual correction leaves serial and expiry intact', () {
    const old = 'ВАМ: 16 СВ DDRS 5600 A-DATA';
    const fixed = 'RAM: 16 GB DDR5 5600 A-DATA';
    final row = applyProductCorrection(
      {'product': old, 'serial': 'ABC123', 'expiry': '2029-03-19'},
      old,
      fixed,
    );
    expect(row['product'], fixed);
    expect(row['serial'], 'ABC123');
    expect(row['expiry'], '2029-03-19');
  });
}
