import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/document_reader.dart';
import 'package:warranty_vault/photo_table.dart';

void main() {
  test('iOS keeps selected language and English product vocabulary', () {
    expect(iosOcrLanguages('bul'), 'bul+eng');
    expect(iosOcrLanguages('nld'), 'nld+eng');
    expect(iosOcrLanguages('ukr'), 'ukr+eng');
    expect(iosOcrLanguages('eng'), 'eng');
    expect(iosOcrLanguages('bul_only'), 'bul');
    expect(iosOcrLanguages('auto'), autoOcrLanguages);
  });
  test('reconstructed invoice rows beat column-major OCR', () {
    const rows =
        'INVOICE\nDescription Quantity Unit price Total\n1 Apple Pencil Pro 1 99.00 99.00\n2 Apple iPad Air 1 499.00 499.00';
    const columns =
        'INVOICE\nDescription\nApple Pencil Pro\nApple iPad Air\nQuantity\n1\n1\nUnit price\n99.00\n499.00';
    expect(extractPhotoTable(rows), hasLength(2));
    expect(chooseOcrText([columns, rows]), rows);
  });
}
