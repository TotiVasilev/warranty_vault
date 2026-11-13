import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/product_ai.dart';
import 'package:warranty_vault/local_ai.dart';
import 'package:warranty_vault/photo_table.dart';

void main() {
  test('contextual spelling suggestions work for unrelated products', () {
    expect(isSafeProductCorrection('BAM: 16 GB DDR5', 'RAM: 16 GB DDR5'), isTrue);
    expect(isSafeProductCorrection('Samsunq Galaxy S24', 'Samsung Galaxy S24'), isTrue);
    expect(isSafeProductCorrection('App1e iPad Air', 'Apple iPad Air'), isTrue);
    expect(isSafeProductCorrection('ASR0CK B650M', 'ASRock B650M'), isTrue);
    expect(isSafeProductCorrection('Logltech Maus', 'Logitech Maus'), isTrue);
    expect(isSafeProductCorrection('Телевизор Самсунг', 'Телевизор Самсунг'), isFalse);
  });
  test('mixed-script OCR and technical glyphs can be corrected together', () {
    const original = 'ВАМ: 16 СВ DDRS 5600 A-DATA';
    const corrected = 'RAM: 16 GB DDR5 5600 A-DATA';
    expect(isSafeProductCorrection(original, corrected), isTrue);
    final row = {'product': original, 'serial': '1Q0700638013', 'months': '96', 'expiry': '2034-03-19'};
    final result = applyProductCorrection(row, original, corrected);
    expect(result['product'], corrected);
    expect(result['serial'], row['serial']);
    expect(result['months'], row['months']);
    expect(result['expiry'], row['expiry']);
    expect(result['notes'], contains(original));
    expect(isSafeProductCorrection(original, 'RAM: 32 GB DDR5 5600 A-DATA'), isFalse);
    expect(isSafeProductCorrection(original, 'RAM: 16 GB DDR5 6000 A-DATA'), isFalse);
  });
  test('general visual glyph comparison works outside the RAM example', () {
    expect(isSafeProductCorrection('Ѕamsung TV', 'Samsung TV'), isTrue);
    expect(isSafeProductCorrection('USBЗ adapter', 'USB3 adapter'), isTrue);
    expect(isSafeProductCorrection('Рhilips Monitor', 'Philips Monitor'), isTrue);
    expect(isSafeProductCorrection('RTX 4070', 'RTX 4090'), isFalse);
  });
  test('unsafe suggestions are visible but never overwrite original fields', () {
    final row = {'product': 'RAM 16 GB DDR5', 'serial': 'ABC123', 'expiry': '2028-01-01'};
    final result = applyProductCorrection(row, row['product'], 'RAM 32 GB DDR5');
    expect(result['product'], row['product']);
    expect(result['serial'], row['serial']);
    expect(result['expiry'], row['expiry']);
    expect(result['notes'], contains('not applied'));
    expect(result['notes'], contains('RAM 32 GB DDR5'));
  });
  test('mixed-script correction reaches the batch output', () {
    const original = 'ВАМ: 16 СВ DDRS 5600 A-DATA';
    const corrected = 'RAM: 16 GB DDR5 5600 A-DATA';
    final rows = [{'product': original, 'serial': 'ABC123', 'months': '96'}];
    final result = applyProductBatch(rows, {'products': [
      {'id': 0, 'original': original, 'corrected': corrected},
    ]});
    expect(result.single['product'], corrected);
    expect(result.single['serial'], 'ABC123');
    expect(result.single['months'], '96');
  });
  test('reject changes to quantity, model code, dates, and added or removed words', () {
    for (final bad in ['RAM: 32 GB DDR5', 'RAM: 16 GB DDR4', 'RAM: 16 GB DDR5 Pro', 'RAM: DDR5']) {
      expect(isSafeProductCorrection('BAM: 16 GB DDR5', bad), isFalse, reason: bad);
    }
    expect(isSafeProductCorrection('RTX 4070', 'RTX 4090'), isFalse);
    expect(isSafeProductCorrection('ASRock B650M', 'ASRock B650N'), isFalse);
    expect(isSafeProductCorrection('Tablet 2025', 'Tablet 2026'), isFalse);
    expect(isSafeProductCorrection('Samsung TV', 'Apple iPad'), isFalse);
    expect(isSafeProductCorrection('BAM 16 GB', 'RAM 16 GB\nextra'), isFalse);
  });
  test('multi-product batch preserves row identity and every non-description field', () {
    final rows = [
      {'product':'ASR0CK B650M', 'serial':'SN001', 'months':'36', 'expiry':'2029-03-19', 'notes':'Original note'},
      {'product':'BAM: 16 GB DDR5', 'serial':'1Q0700638013', 'months':'96', 'expiry':'2034-03-19', 'customer':'Example Buyer'},
      {'product':'BAM: 8 GB DDR5', 'serial':'2Q0500094131', 'months':'96', 'expiry':'2034-03-19'},
    ];
    final result = applyProductBatch(rows, {'products': [
      {'id':2, 'original':rows[2]['product'], 'corrected':'RAM: 8 GB DDR5', 'serial':'wrong'},
      {'id':0, 'original':rows[0]['product'], 'corrected':'ASRock B650M'},
      {'id':1, 'original':rows[1]['product'], 'corrected':'RAM: 16 GB DDR5', 'expiry':'2099-01-01'},
    ]});
    expect(result.map((r) => r['product']).toList(), ['ASRock B650M','RAM: 16 GB DDR5','RAM: 8 GB DDR5']);
    for (var i=0; i<rows.length; i++) {
      for (final entry in rows[i].entries.where((e) => e.key != 'product' && e.key != 'notes')) {
        expect(result[i][entry.key], entry.value);
      }
      expect(result[i]['notes'], contains(rows[i]['product']!));
    }
    expect(result[0]['notes'], contains('Original note'));
    expect(rows[1]['product'], 'BAM: 16 GB DDR5');
  });
  test('bad IDs, duplicate IDs, wrong source and missing rows leave OCR intact', () {
    final rows = [{'product':'BAM 16 GB'}, {'product':'BAM 8 GB'}, {'product':'Samsunq TV'}];
    final result = applyProductBatch(rows, {'products': [
      {'id':0,'original':'BAM 16 GB','corrected':'RAM 16 GB'},
      {'id':0,'original':'BAM 16 GB','corrected':'RAM 16 GB'},
      {'id':1,'original':'BAM 16 GB','corrected':'RAM 16 GB'},
      {'id':99,'original':'Samsunq TV','corrected':'Samsung TV'},
    ]});
    expect(result, rows);
    expect(applyProductBatch(rows, null), rows);
  });
  test('single-product AI correction uses standard product and preserves evidence fields', () {
    const doc = 'Product: Samsunq Galaxy S24\nSerial number: ABC123\nPurchase date: 12.04.2023\nWarranty period: 24 months';
    final result = reconcileAiFields(doc, {
      'product_correction_source':'Samsunq Galaxy S24',
      'product_correction':'Samsung Galaxy S24',
      'expiry':'2026-04-12', 'expiry_evidence':'Warranty period: 24 months',
    });
    expect(result['product'], 'Samsung Galaxy S24');
    expect(result['serial'], 'ABC123');
    expect(result['expiry'], '2025-04-12');
    expect(result['months'], '24');
    expect(result['notes'], contains('Samsunq Galaxy S24'));
  });
  test('OCR table rows can be enhanced together without changing coverage', () {
    const doc = '''ГАРАНЦИОННА КАРТА
Дата: 19.03.2026
ОПИСАНИЕ СЕРИЕН НОМЕР ГАРАНЦИЯ
ASR0CK B650M | DEMO001 | 36 месеца
Samsunq SSD 1 TB | DEMO002 | 96 месеца
Logltech Maus | DEMO003 | 24 месеца''';
    final rows = extractPhotoTable(doc);
    expect(rows, hasLength(3));
    final result = applyProductBatch(rows, {'products': [
      {'id':0, 'original':rows[0]['product'], 'corrected':'ASRock B650M'},
      {'id':1, 'original':rows[1]['product'], 'corrected':'Samsung SSD 1 TB'},
      {'id':2, 'original':rows[2]['product'], 'corrected':'Logitech Maus'},
    ]});
    expect(result.map((r) => r['product']).toList(), ['ASRock B650M','Samsung SSD 1 TB','Logitech Maus']);
    expect(result.map((r) => r['expiry']).toList(), ['2029-03-19','2034-03-19','2028-03-19']);
    expect(result.map((r) => r['serial']).toList(), ['DEMO001','DEMO002','DEMO003']);
  });
  test('single-product AI can suggest spelling for source-backed unfamiliar labels', () {
    final result = reconcileAiFields('Objet acquis — Samsunq TV', {
      'product':'Samsunq TV','product_evidence':'Objet acquis — Samsunq TV',
      'product_correction_source':'Samsunq TV','product_correction':'Samsung TV',
    });
    expect(result['product'], 'Samsung TV');
  });
}
