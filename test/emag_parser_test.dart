import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/model.dart';

void main() {
  const fixture = ''' Емаг Интернешънъл ООД
bul. Example address
Гаранция
Номер: 123456789
Удостоверява се, че следните продукти:
Продукт Гаранция Сериен номер
Example Tablet 11, 128GB, Wi-Fi 24 Месеца DEMO123456
закупени с фактура 987654321 се възползват от условията посочени на следващата страница
Дата на постъпване
Условия за признаване на гаранцията
Гаранционният срок и животът за батериите 6 месеца от датата на покупката.
''';
  void check(String text) {
    final f = extractFields(text);
    expect(f['product'], 'Example Tablet 11, 128GB, Wi-Fi');
    expect(f['months'], '24');
    expect(f['serial'], 'DEMO123456');
    expect(f['reference'], '123456789');
    expect(f['receipt'], '987654321');
    expect(f['store'], 'Емаг Интернешънъл ООД');
    expect(f.containsKey('start'), isFalse);
    expect(f.containsKey('expiry'), isFalse);
  }

  test('eMAG table and contextual identifiers', () => check(fixture));
  test(
    'PDF Windows line endings',
    () => check(fixture.replaceAll('\n', '\r\n')),
  );
  test(
    'table headings and cells on separate lines',
    () => check(
      fixture
          .replaceAll(
            'Продукт Гаранция Сериен номер',
            'Продукт\nГаранция\nСериен номер',
          )
          .replaceAll(
            'Wi-Fi 24 Месеца DEMO123456',
            'Wi-Fi\n24 Месеца\nDEMO123456',
          ),
    ),
  );
  test('ambiguous multiple products not merged', () {
    final f = extractFields(
      fixture.replaceAll(
        'DEMO123456\n',
        'DEMO123456\nSecond Tablet 12 Месеца DEMO999\n',
      ),
    );
    expect(f.containsKey('product'), isFalse);
    expect(f.containsKey('months'), isFalse);
    expect(f.containsKey('serial'), isFalse);
  });
}
