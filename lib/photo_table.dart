import 'model.dart';

/// Recognizes itemized invoices and description / serial / duration tables.
/// Keeps each row separate; never fixes ambiguous serial characters by guessing.
List<Map<String, String>> extractPhotoTable(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');
  final lines = normalized.split('\n');
  final header = lines.indexWhere((line) => RegExp(
    r'(?:описание|наименование|продукт)\s*[|│]?\s+сериен\s+номер\s*[|│]?\s+гаранция',
    caseSensitive: false, unicode: true).hasMatch(line));
  if (header < 0) return extractInvoiceTable(normalized);
  final before = lines.take(header).join('\n');
  final dateMatch = RegExp(r'(?:^|\n)[ \t]*дата[ \t]*:?[ \t]*(\d{1,2}[./-]\d{1,2}[./-]\d{4})',
      caseSensitive: false, unicode: true).firstMatch(before);
  final start = parseDate(dateMatch?.group(1) ?? '');
  final customer = RegExp(r'(?:^|\n)[ \t]*получател[ \t]*:[ \t]*([^\n|│]+)',
      caseSensitive: false, unicode: true).firstMatch(before)?.group(1)?.trim().split(RegExp(r'[ \t]{2,}')).first.trim();
  // This known header/domain gives a seller hint when stylized logo OCR fails.
  final seller = RegExp(r'computers\s+service|cservice-bg\.com|computers_service@abv\.bg',
      caseSensitive: false).hasMatch(before) ? 'Computers Service' : '';
  final rows = <Map<String, String>>[];
  final rowPattern = RegExp(
    r'^(.+?)\s*(?:[|│]\s*|\s+)([A-Za-zА-Яа-я0-9][A-Za-zА-Яа-я0-9._/-]{5,39})\s*(?:[|│]\s*|\s+)(\d{1,3})\s*(?:[мm][еe][сc][еe][цcn][аa]?|мес\.?|months?)(?=\s|[|│]|$)',
    caseSensitive: false, unicode: true);
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
    final product = m.group(1)!.trim().replaceFirst(RegExp(r'[|│]\s*$'), '').trim();
    final serial = m.group(2)!;
    final months = int.parse(m.group(3)!);
    if (product.length < 3 || !RegExp(r'\d').hasMatch(serial) || months < 1 || months > 600) continue;
    final row = <String, String>{'product': product, 'serial': serial, 'months': '$months',
      'notes': 'Table OCR: verify product, serial and duration against the original. Serial characters may be misread.'};
    if (seller.isNotEmpty) row['store'] = seller;
    if (customer != null && customer.isNotEmpty) row['customer'] = customer;
    if (start != null) {
      final end = addMonths(start, months);
      if (end.year <= 2200) {
        row['start'] = iso(start);
        row['expiry'] = iso(end);
        row['notes'] = '${row['notes']}\nStart suggested from card date; confirm.';
      }
    }
    rows.add(row);
  }
  return rows;
}

/// Reads numbered Bulgarian invoice rows with a description, unit, two unit
/// prices, quantity and two totals. No seller-specific assumptions are needed.
/// Invoice dates are evidence of invoicing, not confirmed warranty start dates.
List<Map<String, String>> extractInvoiceTable(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');
  final lines = normalized.split('\n').map((line) => line.trim()).toList();
  final title = lines.indexWhere((line) => RegExp(
    r'^фактура(?:\s+оригинал)?$', caseSensitive: false,
  ).hasMatch(line));
  if (title < 0) return [];
  final header = lines.indexWhere((line) => RegExp(
    r'^(?:no|№|номер|nо)\s*[/\.]?\s*код\s+описание(?:\s|$)',
    caseSensitive: false,
  ).hasMatch(line), title + 1);
  if (header < 0) return [];
  final rowStart = RegExp(r'^(\d{1,5})[.)]?\s+([A-Za-zА-Яа-я].*)$');
  final first = lines.indexWhere((line) => rowStart.hasMatch(line), header + 1);
  if (first < 0 || first - header > 35) return [];
  final headings = lines.sublist(header, first).join(' ');
  if (!RegExp(r'мерна\s+единица', caseSensitive: false).hasMatch(headings) ||
      !RegExp(r'единична\s+цена', caseSensitive: false).hasMatch(headings) ||
      !RegExp(r'кол\.?\s', caseSensitive: false).hasMatch('$headings ') ||
      !RegExp(r'общо', caseSensitive: false).hasMatch(headings)) return [];
  final pre = lines.take(header).join('\n');
  final invoiceHeader = lines.sublist(title, header).join('\n');
  String label(String input, String pattern) => RegExp(
    '(?:^|\\n)\\s*(?:$pattern)\\s*[:：]\\s*([^\\n]+)',
    caseSensitive: false,
  ).firstMatch(input)?.group(1)?.trim() ?? '';
  final seller = label(pre, r'фирма\s*/\s*наименование|наименование на доставчика|доставчик|продавач');
  final customer = label(pre, r'име на клиента|клиент|купувач');
  final receipt = label(invoiceHeader, r'номер|фактура\s*(?:номер|№)');
  final invoiceDate = parseDate(label(invoiceHeader, r'дата|дата на фактурата'));
  // Require all numeric columns. This keeps prices, quantity, tax and totals
  // out of product descriptions, and avoids interpreting footer text as rows.
  const amount = r'(?:\d{1,3}(?:[ ,.]\d{3})+|\d+)[.,]\d{2}';
  const quantity = r'\d+(?:[.,]\d+)?';
  final rowPattern = RegExp(
    r'^(\d{1,5})[.)]?\s+(.+?)\s+(?:броя|бр\.?|брой|комплект[аи]?|к-т|pcs?\.?|pieces?|units?)\s+' +
    amount + r'\s+' + amount + r'\s+' + quantity + r'\s+' + amount + r'\s+' + amount + r'$',
    caseSensitive: false,
  );
  final footer = RegExp(
    r'^(?:изготвил|съгласно|дата на възникване|дата на плащане|плащане|срок на плащане|банка|обща данъчна основа|данъчна ставка|обща сума|сума за плащане|общо\s*:|powered by)(?=\s|:|$)',
    caseSensitive: false,
  );
  final rows = <Map<String, String>>[];
  var buffer = '';
  for (final line in lines.skip(first)) {
    if (line.isEmpty) continue;
    if (footer.hasMatch(line) || RegExp(r'^\d+/\d+$').hasMatch(line)) break;
    // An incomplete row must not be silently merged with the following one.
    if (buffer.isNotEmpty && rowStart.hasMatch(line)) return [];
    buffer = buffer.isEmpty ? line : '$buffer $line';
    final match = rowPattern.firstMatch(buffer);
    if (match == null) {
      if (buffer.length > 3000) return [];
      continue;
    }
    // This numbered layout must start at 1 and remain contiguous.
    if (int.parse(match.group(1)!) != rows.length + 1) return [];
    final description = match.group(2)!.trim();
    final code = RegExp(r'\[([A-Za-z0-9][A-Za-z0-9._/-]{2,39})\]$').firstMatch(description);
    final product = code == null ? description : description.substring(0, code.start).trim();
    if (product.isEmpty) return [];
    final row = <String, String>{
      'product': product,
      'notes': 'Invoice item ${rows.length + 1}. No warranty dates or duration stated in this invoice row. Confirm coverage before saving.',
    };
    if (code != null) row['model'] = code.group(1)!;
    if (seller.isNotEmpty) row['store'] = seller;
    if (customer.isNotEmpty) row['customer'] = customer;
    if (receipt.isNotEmpty) row['receipt'] = receipt;
    if (invoiceDate != null) {
      row['notes'] = '${row['notes']}\nInvoice date: ${iso(invoiceDate)} (not a confirmed warranty start date).';
    }
    rows.add(row);
    buffer = '';
  }
  // Never report a partially parsed table as complete.
  return buffer.isEmpty ? rows : [];
}
