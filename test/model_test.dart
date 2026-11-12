import 'package:flutter_test/flutter_test.dart';
import 'package:warranty_vault/model.dart';

void main() {
  test('strict dates reject rollover', () {
    expect(parseDate('31.02.2026'), isNull);
    expect(iso(parseDate('12.11.2026')!), '2026-11-12');
  });
  test('calendar month and leap year', () {
    expect(iso(addMonths(DateTime(2024, 2, 29), 12)), '2025-02-28');
    expect(iso(addMonths(DateTime(2026, 1, 31), 1)), '2026-02-28');
  });
  test('calendar days, expiry day active, next day expired', () {
    const w = Warranty(
      id: 'test',
      product: 'TV',
      start: '2026-11-12',
      expiry: '2028-11-12',
    );
    expect(w.remaining(DateTime(2026, 11, 12)), 731);
    expect(w.remaining(DateTime(2028, 11, 12, 23)), 0);
    expect(w.remaining(DateTime(2028, 11, 13)), -1);
  });
  test('English labeled extraction', () {
    final f = extractFields(
      'Product: Test TV\nSerial number: ABC123\nPurchase date: 12.11.2026\nWarranty period: 24 months',
    );
    expect(f['product'], 'Test TV');
    expect(f['serial'], 'ABC123');
    expect(f['expiry'], '2028-11-12');
  });
  test('Bulgarian labeled extraction', () {
    final f = extractFields(
      'Артикул: Телевизор\nМагазин: Пример\nСериен номер: AB123\nДата на покупка: 12.11.2026\nГаранционен срок: 2 години',
    );
    expect(f['store'], 'Пример');
    expect(f['expiry'], '2028-11-12');
  });
  test('unknown document does not invent dates', () {
    expect(extractFields('Unknown receipt 24 11 2026'), isEmpty);
  });
  test('calendar event date', () {
    const w = Warranty(
      id: 'test',
      product: 'TV, model A',
      start: '2026-11-12',
      expiry: '2028-11-12',
    );
    final ics = calendarFile(w, 7);
    expect(ics, contains('DTSTART;VALUE=DATE:20281105'));
    expect(ics, contains('TV\\, model A'));
  });
}
