import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/vision_ai.dart';

void main(){
  test('separates rows and calculates distinct expiration dates', () {
    final rows=parseVisionRows('''{"products":[{"product":"Motherboard","start":"2026-03-19","months":36},{"product":"RAM","start":"2026-03-19","months":96}]}''');
    expect(rows.length,2);expect(rows[0]['expiry'],'2029-03-19');expect(rows[1]['expiry'],'2034-03-19');
  });
  test('keeps explicit expiry and warns on duration conflict', () {
    final row=parseVisionRows('''{"products":[{"product":"GPU","start":"2023-04-12","expiry":"2025-04-12","months":12}]}''').single;
    expect(row['expiry'],'2025-04-12');expect(row['notes'],contains('disagree'));
  });
  test('unknown fields remain empty; invalid date rejected', () {
    final row=parseVisionRows('''{"products":[{"product":"GPU","start":"2025-02-30","serial":null,"expiry":"2025-04-12"}]}''').single;
    expect(row.containsKey('start'),false);expect(row.containsKey('serial'),false);expect(row['expiry'],'2025-04-12');
  });
  test('invalid model output fails instead of filling made-up values', () {
    expect(()=>parseVisionRows('I cannot read it'),throwsFormatException);
  });
}
