import 'model.dart';

/// Recognizes a description / serial / duration table on a Bulgarian card.
/// Keeps each row separate; never fixes ambiguous serial characters by guessing.
List<Map<String, String>> extractPhotoTable(String text) {
  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ');
  final lines = normalized.split('\n');
  final header = lines.indexWhere(
    (line) => RegExp(
      r'(?:описание|наименование|продукт)\s*[|│]?\s+сериен\s+номер\s*[|│]?\s+гаранция',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(line),
  );
  if (header < 0) return [];
  final before = lines.take(header).join('\n');
  final dateMatch = RegExp(
    r'(?:^|\n)[ \t]*дата[ \t]*:?[ \t]*(\d{1,2}[./-]\d{1,2}[./-]\d{4})',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(before);
  final start = parseDate(dateMatch?.group(1) ?? '');
  final customer =
      RegExp(
            r'(?:^|\n)[ \t]*получател[ \t]*:[ \t]*([^\n|│]+)',
            caseSensitive: false,
            unicode: true,
          )
          .firstMatch(before)
          ?.group(1)
          ?.trim()
          .split(RegExp(r'[ \t]{2,}'))
          .first
          .trim();
  // This known header/domain gives a seller hint when stylized logo OCR fails.
  final seller =
      RegExp(
        r'computers\s+service|cservice-bg\.com|computers_service@abv\.bg',
        caseSensitive: false,
      ).hasMatch(before)
      ? 'Computers Service'
      : '';
  final rows = <Map<String, String>>[];
  final rowPattern = RegExp(
    r'^(.+?)\s*(?:[|│]\s*|\s+)([A-Za-zА-Яа-я0-9][A-Za-zА-Яа-я0-9._/-]{5,39})\s*(?:[|│]\s*|\s+)(\d{1,3})\s*(?:[мm][еe][сc][еe][цcn][аa]?|мес\.?|months?)(?=\s|[|│]|$)',
    caseSensitive: false,
    unicode: true,
  );
  for (final original in lines.skip(header + 1).take(40)) {
    final line = original.trim().replaceFirst(RegExp(r'^[|│]+\s*'), '');
    if (line.isEmpty || RegExp(r'^[-_=|│─+\s]+$').hasMatch(line)) continue;
    final m = rowPattern.firstMatch(line);
    if (m == null) {
      // Stop at the first prose line after the table. Do not pick durations
      // in warranty conditions as additional products.
      if (rows.isNotEmpty) break;
      continue;
    }
    final product = m
        .group(1)!
        .trim()
        .replaceFirst(RegExp(r'[|│]\s*$'), '')
        .trim();
    final serial = m.group(2)!;
    final months = int.parse(m.group(3)!);
    if (product.length < 3 ||
        !RegExp(r'\d').hasMatch(serial) ||
        months < 1 ||
        months > 600)
      continue;
    final row = <String, String>{
      'product': product,
      'serial': serial,
      'months': '$months',
      'notes':
          'Table OCR: verify product, serial and duration against the original. Serial characters may be misread.',
    };
    if (seller.isNotEmpty) row['store'] = seller;
    if (customer != null && customer.isNotEmpty) row['customer'] = customer;
    if (start != null) {
      final end = addMonths(start, months);
      if (end.year <= 2200) {
        row['start'] = iso(start);
        row['expiry'] = iso(end);
        row['notes'] =
            '${row['notes']}\nStart suggested from card date; confirm.';
      }
    }
    rows.add(row);
  }
  return rows;
}
