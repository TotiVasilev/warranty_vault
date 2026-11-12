import 'dart:convert';

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime? parseDate(String input) {
  final s = input.trim();
  final a = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  final b = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(s);
  if (a == null && b == null) return null;
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
        parseDate(s('start')) == null ||
        parseDate(s('expiry')) == null ||
        parseDate(s('expiry'))!.isBefore(parseDate(s('start'))!)) {
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

// Conservative label-based extraction. Unknown fields stay blank.
Map<String, String> extractFields(String text) {
  final out = <String, String>{};
  String find(String labels) {
    final match = RegExp(
      '(?:^|\\n)\\s*(?:$labels)\\s*[:：]\\s*([^\\r\\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
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
        r'warranty start(?: date)?|purchase date|delivery date|дата на покупка|дата на доставка|начало на гаранцията',
    'expiry':
        r'expir(?:y|ation)(?: date)?|valid until|warranty end(?: date)?|валидна до|гаранция до|край на гаранцията',
    'months': r'warranty period|warranty duration|гаранционен срок|гаранция',
  };
  for (final e in labels.entries) {
    final v = find(e.value);
    if (v.isNotEmpty) out[e.key] = v;
  }
  for (final key in ['start', 'expiry']) {
    final d = parseDate(out[key] ?? '');
    if (d == null) {
      out.remove(key);
    } else {
      out[key] = iso(d);
    }
  }
  final duration = out.remove('months') ?? '';
  final match = RegExp(
    r'^(\d{1,3})\s*(months?|месеца?|мес\.?|years?|години|година|г\.?)$',
    caseSensitive: false,
  ).firstMatch(duration);
  if (match != null) {
    final n = int.parse(match.group(1)!);
    final unit = match.group(2)!.toLowerCase();
    final m = n * ((unit.startsWith('y') || unit.startsWith('г')) ? 12 : 1);
    if (m > 0 && m <= 600) out['months'] = '$m';
  }
  if (!out.containsKey('expiry') &&
      out.containsKey('start') &&
      out.containsKey('months'))
    out['expiry'] = iso(
      addMonths(parseDate(out['start']!)!, int.parse(out['months']!)),
    );
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
