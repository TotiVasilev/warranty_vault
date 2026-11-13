import 'dart:convert';
import 'languages.dart';

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime? parseDate(String input) {
  final s = input.trim();
  final a = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  final b = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(s);
  if (a == null && b == null) {
    final named = RegExp(
      r'^(\d{1,2})\s+([a-z]+)\.?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(s);
    if (named == null) return null;
    const dutchMonths = [
      'jan januari',
      'feb februari',
      'mrt maart',
      'apr april',
      'mei',
      'jun juni',
      'jul juli',
      'aug augustus',
      'sep sept september',
      'okt oktober',
      'nov november',
      'dec december',
    ];
    final m =
        dutchMonths.indexWhere(
          (names) => names.split(' ').contains(named.group(2)!.toLowerCase()),
        ) +
        1;
    if (m == 0) return null;
    return parseDate('${named.group(1)}-$m-${named.group(3)}');
  }
  final y = int.parse(a?.group(1) ?? b!.group(3)!);
  final m = int.parse(a?.group(2) ?? b!.group(2)!);
  final d = int.parse(a?.group(3) ?? b!.group(1)!);
  if (y < 1900 || y > 2200) return null;
  final dt = DateTime(y, m, d);
  return dt.year == y && dt.month == m && dt.day == d ? dt : null;
}

DateTime addMonths(DateTime d, int months) {
  final first = DateTime(d.year, d.month + months, 1);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day > last ? last : d.day);
}

int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

class Attachment {
  final String id, name, ext;
  const Attachment(this.id, this.name, this.ext);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ext': ext};
  factory Attachment.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String, ext = j['ext'] as String;
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) ||
        !['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
      throw const FormatException('Invalid attachment');
    }
    return Attachment(id, j['name'] as String, ext);
  }
}

class Warranty {
  final String id,
      product,
      store,
      customer,
      model,
      serial,
      reference,
      receipt,
      start,
      expiry,
      notes;
  final int months;
  final List<Attachment> docs;
  const Warranty({
    required this.id,
    required this.product,
    this.store = '',
    this.customer = '',
    this.model = '',
    this.serial = '',
    this.reference = '',
    this.receipt = '',
    required this.start,
    required this.expiry,
    this.months = 0,
    this.notes = '',
    this.docs = const [],
  });
  int remaining([DateTime? now]) =>
      daysBetween(now ?? DateTime.now(), parseDate(expiry)!);
  Map<String, dynamic> toJson() => {
    'id': id,
    'product': product,
    'store': store,
    'customer': customer,
    'model': model,
    'serial': serial,
    'reference': reference,
    'receipt': receipt,
    'start': start,
    'expiry': expiry,
    'months': months,
    'notes': notes,
    'docs': docs.map((d) => d.toJson()).toList(),
  };
  factory Warranty.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(s('id')) ||
        s('product').trim().isEmpty ||
        (s('start').isNotEmpty && parseDate(s('start')) == null) ||
        parseDate(s('expiry')) == null ||
        (parseDate(s('start')) != null &&
            parseDate(s('expiry'))!.isBefore(parseDate(s('start'))!))) {
      throw const FormatException('Invalid warranty record');
    }
    return Warranty(
      id: s('id'),
      product: s('product'),
      store: s('store'),
      customer: s('customer'),
      model: s('model'),
      serial: s('serial'),
      reference: s('reference'),
      receipt: s('receipt'),
      start: s('start'),
      expiry: s('expiry'),
      months: j['months'] as int? ?? 0,
      notes: s('notes'),
      docs: (j['docs'] as List? ?? [])
          .map((d) => Attachment.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
    );
  }
}

// Exact whole calendar months, including end-of-month clamping.
int? exactMonthsBetween(DateTime start, DateTime end) {
  final n = (end.year - start.year) * 12 + end.month - start.month;
  if (n < 1 || n > 600 || iso(addMonths(start, n)) != iso(end)) return null;
  return n;
}

// Address headings can be flattened by a PDF reader. Prefer billing over
// shipping; only accept a plausible name at the top of an address block.
String? _dutchCustomer(String text) {
  final heading = RegExp(
    r'^\s*Factuuradres(?:[ \t]+Verzendadres)?[ \t]*$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(text);
  if (heading == null) return null;
  final lines = text
      .substring(heading.end)
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(5)
      .toList();
  if (lines.isEmpty) return null;
  String firstColumn(String line) =>
      line.trim().split(RegExp(r'[ \t]{2,}')).first.trim();
  bool name(String value, {int minWords = 2}) {
    final words = value.split(RegExp(r'\s+'));
    if (words.length < minWords || words.length > 5 || value.length > 100)
      return false;
    if (RegExp(
      r'\b(?:nederland|netherlands|factuuradres|verzendadres|datum|klantnr|factuurnr|straat|postcode|telefoon|azerty|bv|order)\b',
      caseSensitive: false,
    ).hasMatch(value))
      return false;
    return words.every(
      (word) => RegExp(
        r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-ž][A-Za-zÀ-ÖØ-öø-ÿĀ-ž.'’-]*$",
      ).hasMatch(word),
    );
  }

  final first = firstColumn(lines.first);
  if (name(first) &&
      lines.skip(1).take(3).any((l) => RegExp(r'\d').hasMatch(l)))
    return first;
  // PDFium may emit a two-line shipping name directly after both headings.
  if (lines.length >= 3 && name(first, minWords: 1)) {
    final second = firstColumn(lines[1]);
    if (first.split(' ').length == 1 &&
        name(second, minWords: 1) &&
        second.split(' ').length == 1 &&
        RegExp(r'\d').hasMatch(lines[2])) {
      final candidate = '$first $second';
      // Confirm the complete name is also present in the preceding billing
      // block; never silently substitute an unrelated shipping recipient.
      final before = text
          .substring(0, heading.start)
          .split('\n')
          .reversed
          .take(8);
      if (before.any(
        (line) => line.trim().toLowerCase() == candidate.toLowerCase(),
      ))
        return candidate;
    }
  }
  return null;
}

void _appendNote(Map<String, String> out, String note) {
  final previous = out['notes'] ?? '';
  out['notes'] = previous.isEmpty ? note : '$previous\n$note';
}

// Invoice dates are candidates, not verified warranty commencement dates.
// Derive a start only from an explicit end date and a coherent invoice date;
// require an exact whole-month interval and consistency with any stated term.
void _completeDates(Map<String, String> out, DateTime? invoiceDate) {
  final end = parseDate(out['expiry'] ?? '');
  var start = parseDate(out['start'] ?? '');
  final stated = int.tryParse(out['months'] ?? '');
  if (start == null && end != null && invoiceDate != null) {
    final inferred = exactMonthsBetween(invoiceDate, end);
    if (inferred != null && (stated == null || stated == inferred)) {
      start = invoiceDate;
      out['start'] = iso(start);
      _appendNote(
        out,
        'Suggested warranty start: ${iso(start)} (invoice date; confirm actual start).',
      );
    }
  }
  if (start != null && end != null) {
    final calculated = exactMonthsBetween(start, end);
    if (stated == null && calculated != null) {
      out['months'] = '$calculated';
      _appendNote(
        out,
        'Calculated duration: $calculated months from start and expiration; confirm if applicable.',
      );
    } else if (stated != null && iso(addMonths(start, stated)) != iso(end)) {
      _appendNote(
        out,
        'Review dates: the stated duration does not match the start and expiration.',
      );
    }
  }
}

// Conservative extraction: explicit labels, then contextual document layouts.
// No date is invented, and a duration in general warranty terms is not used.
Map<String, String> extractFields(String text) {
  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ');
  final out = multilingualFields(normalized);
  DateTime? invoiceDate;
  String find(String labels) {
    final match = RegExp(
      '(?:^|\\n)[ \\t]*(?:$labels)[ \\t]*[:：][ \\t]*([^\\n]+)',
      caseSensitive: false,
    ).firstMatch(normalized);
    return match?.group(1)?.trim() ?? '';
  }

  final labels = <String, String>{
    'product': r'product(?: name)?|item|article|продукт|стока|артикул',
    'store': r'store|seller|retailer|merchant|магазин|продавач|търговец',
    'customer': r'customer(?: name)?|buyer|клиент|купувач',
    'model': r'model|модел',
    'serial':
        r'serial(?: number| no\.?| #)?|s/n|серий(?:ен номер|ен №)|сериен номер',
    'reference':
        r'warranty (?:no\.?|number|reference)|гаранционна карта(?: №| номер)?|гаранционен номер',
    'receipt':
        r'(?:receipt|invoice|order)(?: no\.?| number| #)|касова бележка(?: №| номер)?|фактура(?: №| номер)?',
    'start':
        r'warranty start(?: date)?|purchase date|delivery date|дата на покупка|дата на доставка|дата на получаване|начало на гаранцията',
    'expiry':
        r'expir(?:y|ation)(?: date)?|valid until|warranty end(?: date)?|валидна до|гаранция до|край на гаранцията',
    'months': r'warranty period|warranty duration|гаранционен срок|гаранция',
  };
  for (final e in labels.entries) {
    final value = find(e.value);
    if (value.isNotEmpty) out[e.key] = value;
  }

  // Keep table fields together. Only accept a single unambiguous product row.
  // Handles headings separated by spaces OR line breaks (PDF extraction varies).
  final header = RegExp(
    r'(?:^|\n)[ \t]*(?:продукт|product(?: name)?)\s+(?:гаранция|warranty(?: period)?)\s+(?:сериен номер|serial number)[ \t]*(?:\n|$)',
    caseSensitive: false,
  ).firstMatch(normalized);
  const units = r'months?|месеца?|мес\.?|years?|години|година|г\.?';
  if (header != null) {
    final tail = normalized.substring(header.end).trimLeft();
    final boundary = RegExp(
      r'(?:^|\n)\s*(?:закупени с фактура|purchased with invoice|дата на\s+постъпване|условия за признаване)',
      caseSensitive: false,
    ).firstMatch(tail);
    final table = (boundary == null ? tail : tail.substring(0, boundary.start))
        .trim();
    final row = RegExp(
      r'^(.+?)\s+(\d{1,3}\s*(?:' +
          units +
          r'))\s+([A-Za-z0-9][A-Za-z0-9._/-]*)$',
      caseSensitive: false,
    );
    // A row can be a single line or three cells on separate lines. A
    // multi-product certificate must be split manually in this version.
    final candidate = table.replaceAll(RegExp(r'\s+'), ' ');
    final match = row.firstMatch(candidate);
    final durationCount = RegExp(
      r'\d{1,3}\s*(?:' + units + r')(?=\s|$)',
      caseSensitive: false,
    ).allMatches(candidate).length;
    if (match != null && durationCount == 1) {
      out['product'] = match.group(1)!.trim();
      out['months'] = match.group(2)!.trim();
      out['serial'] = match.group(3)!;
    }
  }

  // A standalone “Номер:” is a warranty ID only next to the title.
  final reference = RegExp(
    r'(?:^|\n)[ \t]*(?:гаранция|warranty(?: certificate)?)[ \t]*\n\s*(?:номер|number|no\.?)[ \t]*[:：][ \t]*([A-Za-z0-9][A-Za-z0-9._/-]*)[ \t]*(?=\n|$)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (reference != null) out['reference'] = reference.group(1)!;
  final invoice = RegExp(
    r'(?:закупени\s+с\s+фактура|purchased\s+with\s+invoice)\s*(?:№|:)?\s*([A-Za-z0-9][A-Za-z0-9._/-]*)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (invoice != null) out['receipt'] = invoice.group(1)!;
  // Retailer-specific fallback, restricted to the document header.
  final top = normalized.split('\n').take(8).join('\n');
  final seller = RegExp(
    r'(?:^|\n)[ \t]*(Емаг[ \t]+Интернешънъл[ \t]+ООД)[ \t]*(?=\n|$)',
    caseSensitive: false,
  ).firstMatch(top);
  if (seller != null) out.putIfAbsent('store', () => seller.group(1)!);

  // Dutch invoice tables: the explicit end date takes precedence over duration.
  // Restrict this layout to a single product; never infer an unlabeled serial.
  final dutchHeader = RegExp(
    r'(?:^|\n)\s*Nr\.\s+Omschrijving\s+Aantal\s+Garantie\s+t\s*/\s*m\s+Eenheid\s+Prijs\s+Btw\s+Bedrag\s*(?=\n|$)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (dutchHeader != null) {
    final tail = normalized.substring(dutchHeader.end).trimLeft();
    final stop = RegExp(
      r'(?:^|\n)\s*(?:Specificatie btw-bedrag|Betalingscondities|Betaald met:|Totaal)(?=\s|$)',
      caseSensitive: false,
    ).firstMatch(tail);
    final table = (stop == null ? tail : tail.substring(0, stop.start)).trim();
    // PDFium may emit the quantity/date on a separate line from the product.
    final flat = table.replaceAll(RegExp(r'\s+'), ' ');
    final rows = RegExp(
      r'(?:^|\s)(\d{1,2}\s+[a-z]+\.?\s+\d{4})\s+Stuks\b',
      caseSensitive: false,
    ).allMatches(flat).toList();
    final item = RegExp(
      r'^(?:Ordernr\.\s+[A-Za-z0-9-]+\s+)?(\d{4,12})\s+(.+?)\s+(\d+)\s+(\d{1,2}\s+[a-z]+\.?\s+\d{4})\s+Stuks\b',
      caseSensitive: false,
    ).firstMatch(flat);
    if (item != null && rows.length == 1) {
      final end = parseDate(item.group(4)!);
      if (end != null) {
        var product = item.group(2)!.trim();
        // In layout-preserving text, the description continuation may follow
        // the price columns. Keep that line, but not bare unlabeled numbers.
        final continuation = RegExp(
          r'^\s*(GDDR\d[^\n]*)$',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(table);
        if (continuation != null &&
            !product.contains(continuation.group(1)!.trim())) {
          product += ' ${continuation.group(1)!.trim()}';
        }
        out['product'] = product;
        out['expiry'] = iso(end);
        final notes = <String>['Article number: ${item.group(1)}'];
        final order = RegExp(
          r'\bOrdernr\.\s+([A-Za-z0-9-]+)',
          caseSensitive: false,
        ).firstMatch(table);
        if (order != null) notes.add('Order number: ${order.group(1)}');
        final azerty = RegExp(
          r'(?:^|\n)\s*Azerty\s+BV\s*(?=\n|$)',
          caseSensitive: false,
        ).firstMatch(normalized);
        if (azerty != null) {
          out['store'] = 'Azerty BV';
          final invoice =
              RegExp(
                r'\bFactuurnr\.\s*:?\s*(F\d+)\b',
                caseSensitive: false,
              ).firstMatch(normalized) ??
              RegExp(
                r'\bFactuurnr\.[\s\S]{0,180}?(?:^|\n)\s*(F\d+)\s*(?=\n|$)',
                caseSensitive: false,
              ).firstMatch(normalized);
          if (invoice != null) out['receipt'] = invoice.group(1)!;
          final invoiceDateMatch = RegExp(
            r'\bDatum\b[\s\S]{0,220}?(\d{1,2}\s+[a-z]+\.?\s+\d{4})',
            caseSensitive: false,
          ).firstMatch(normalized);
          invoiceDate = parseDate(invoiceDateMatch?.group(1) ?? '');
          if (invoiceDate != null)
            notes.add('Invoice date: ${iso(invoiceDate)}');
          if (RegExp(
            r'product vervangen voor een nieuw artikel',
            caseSensitive: false,
          ).hasMatch(normalized))
            notes.add(
              'Replacement invoice: verify the actual warranty start and duration.',
            );
        }
        out['notes'] = notes.join('\n');
      }
    }
  }

  // Also support clearly labeled invoice dates outside the Azerty layout.
  // Never interpret an arbitrary date in warranty terms as an invoice date.
  final invoiceLabel = RegExp(
    r'^[ \t]*(?:invoice date|factuurdatum|rechnungsdatum|дата на фактура(?:та)?|date de facturation|fecha de factura|data fattura)[ \t]*(?:[:：][ \t]*|[ \t]{2,})([^\n]+)$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(normalized);
  invoiceDate ??= parseDate(invoiceLabel?.group(1) ?? '');
  final customer = _dutchCustomer(normalized);
  if (customer != null) out.putIfAbsent('customer', () => customer);

  for (final key in ['start', 'expiry']) {
    final d = parseDate(out[key] ?? '');
    if (d == null) {
      out.remove(key);
    } else {
      out[key] = iso(d);
    }
  }
  final duration = durationMonths(out.remove('months') ?? '');
  if (duration != null) out['months'] = duration;
  _completeDates(out, invoiceDate);
  if (!out.containsKey('expiry') &&
      out.containsKey('start') &&
      out.containsKey('months')) {
    out['expiry'] = iso(
      addMonths(parseDate(out['start']!)!, int.parse(out['months']!)),
    );
  }
  return out;
}

String _icsEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');
String calendarFile(Warranty w, int lead) {
  final expiry = parseDate(w.expiry)!;
  final day = DateTime(expiry.year, expiry.month, expiry.day - lead);
  String compact(DateTime d) => iso(d).replaceAll('-', '');
  final stamp =
      DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .split('.')
          .first +
      'Z';
  final rows = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Warranty Vault//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:${w.id}-$lead@warranty-vault.local',
    'DTSTAMP:$stamp',
    'DTSTART;VALUE=DATE:${compact(day)}',
    'DTEND;VALUE=DATE:${compact(DateTime(day.year, day.month, day.day + 1))}',
    'SUMMARY:${_icsEscape('Warranty reminder: ${w.product}')}',
    'DESCRIPTION:${_icsEscape('Warranty expires ${w.expiry}. Seller: ${w.store}. Check original documents and coverage.')}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  // RFC 5545: fold at 75 UTF-8 octets, never split a character.
  return rows
          .map((line) {
            final buf = StringBuffer();
            var len = 0;
            for (final r in line.runes) {
              final c = String.fromCharCode(r);
              final n = utf8.encode(c).length;
              if (len + n > 75) {
                buf.write('\r\n ');
                len = 1;
              }
              buf.write(c);
              len += n;
            }
            return buf.toString();
          })
          .join('\r\n') +
      '\r\n';
}
