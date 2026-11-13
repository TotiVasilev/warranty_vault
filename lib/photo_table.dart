import 'model.dart';

/// Recognizes itemized invoices and description / serial / duration tables.
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
  if (header < 0) {
    final warranty = _extractMultilingualWarrantyTable(lines);
    return warranty.isNotEmpty ? warranty : extractInvoiceTable(normalized);
  }
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
  return rows.isNotEmpty ? rows : extractInvoiceTable(normalized);
}

/// Header vocabulary is independent of product language. The same row parser
/// handles numbered invoices with quantity/price/total in different orders.
const _invoiceTitle =
    r'invoice|фактура|rechnung|factuur|facture|factura|fattura|factură|faktura|fatura|nota fiscal|τιμολόγιο|fatura|счёт[- ]фактура|счет[- ]фактура|рахунок(?:-фактура)?';
const _description =
    r'description|product(?: name)?|item(?: description)?|описание|наименование|beschreibung|artikelbezeichnung|bezeichnung|omschrijving|désignation|descripción|descrizione|denumire|descriere|opis|nazwa towaru|descrição|περιγραφή|açıklama|ürün adı|опис товару|назва товару';
const _qty =
    r'quantity|qty\.?|количество|кол\.?|menge|anzahl|aantal|quantité|qté\.?|cantidad|cant\.?|quantità|qta\.?|cantitate|cant\.?|ilość|liczba|quantidade|qtd\.?|ποσότητα|miktar|adet|кол-во|кількість';
const _price =
    r'unit price|price per unit|price|единична цена|ед\. цена|einzelpreis|stückpreis|prijs per stuk|stukprijs|eenheidsprijs|prix unitaire|precio unitario|prezzo unitario|preț unitar|pret unitar|cena jednostkowa|preço unitário|τιμή μονάδας|birim fiyat|цена за единицу|цена|ціна за одиницю|ціна';
const _total =
    r'line total|total price|amount|total|общо|сума|gesamtpreis|gesamtbetrag|betrag|totaal|bedrag|montant|importe|importo|totale|valoare|wartość|razem|valor|σύνολο|ποσό|tutar|toplam|сумма|итого|сума|всього';
const _unit =
    r'unit of measure|мерна единица|einheit|eenheid|unité|unidad|unità|unitate de măsură|jednostka|unidade|μονάδα|birim|единица измерения|одиниця виміру';
const _units =
    r'броя|бр\.?|брой|комплект[аи]?|к-т|pcs?\.?|pieces?|units?|stk\.?|stück|stuks?|pièces?|unidades?|uds?\.?|pz\.?|pezzi|buc\.?|szt\.?|un\.?|τεμ\.?|adet|шт\.?';
const _currency =
    r'(?:EUR|USD|GBP|BGN|RON|PLN|TRY|RUB|UAH|CHF|лв\.?|руб\.?|грн\.?|€|\$|£|zł|₺|₽|₴)';
const _number = r'(?:\d{1,3}(?:[,.]\d{3})+|\d+)(?:[.,]\d+)?';
const _money = r'(?:\d{1,3}(?:[,.]\d{3})+|\d+)[.,]\d{2}';

RegExp _wordPattern(String pattern) => RegExp(
  '(?:^|[^\\p{L}\\p{N}])(?:$pattern)(?=\$|[^\\p{L}\\p{N}])',
  caseSensitive: false,
  unicode: true,
);

/// Extracts common itemized invoice layouts in the app's 14 OCR languages.
/// No document-wide language choice, no translation of product names, no AI.
/// Unrecognized layouts return no rows rather than inventing warranty fields.
List<Map<String, String>> extractInvoiceTable(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ')
      .split('\n')
      .map((line) => line.trim())
      .toList();
  final title = lines.indexWhere(
    (line) => _wordPattern(_invoiceTitle).hasMatch(line),
  );
  if (title < 0) return [];
  final numbered = RegExp(r'^(\d{1,5})[.)]?\s+(.+)$');
  final footer = RegExp(
    r'^(?:изготвил|съгласно|дата на възникване|дата на плащане|плащане|срок на плащане|банка|обща данъчна основа|данъчна ставка|обща сума|сума за плащане|subtotal|sub total|grand total|total due|amount due|payment|bank|tax|vat|mwst|zwischensumme|gesamtsumme|summe|totaal|subtotaal|btw|sous-total|total ttc|total ht|tva|importe total|totale|totale fattura|total de plată|suma do zapłaty|razem|valor total|σύνολο|genel toplam|итого|всього|powered by)(?=\s|:|$)',
    caseSensitive: false,
    unicode: true,
  );
  // Match headings across lines (PDF extraction often splits each heading).
  int header = -1, first = -1;
  String headings = '';
  for (var h = title; h < lines.length && h < title + 100; h++) {
    if (!_wordPattern(_description).hasMatch(lines[h])) continue;
    for (var j = h + 1; j < lines.length && j <= h + 35; j++) {
      final candidate = lines.sublist(h, j).join(' ');
      if (!_wordPattern(_qty).hasMatch(candidate) ||
          !_wordPattern(_price).hasMatch(candidate) ||
          !_wordPattern(_total).hasMatch(candidate))
        continue;
      if (!numbered.hasMatch(lines[j]) && !lines[j].contains(RegExp(r'[|│\t]')))
        continue;
      header = h;
      first = j;
      headings = candidate;
      break;
    }
    if (first >= 0) break;
  }
  if (first < 0) return [];
  // Each matched price/total heading represents one numeric column. Quantity
  // has its own position. This supports e.g. qty/price/total and the eMAG
  // price-net/price-gross/qty/total-net/total-gross layout.
  final totals = _wordPattern(_total).allMatches(headings).toList();
  final prices = _wordPattern(_price)
      .allMatches(headings)
      .where((p) => !totals.any((t) => p.start < t.end && t.start < p.end))
      .toList();
  final quantities = _wordPattern(_qty).allMatches(headings).toList();
  final priceCount = prices.length;
  final totalCount = totals.length;
  final qtyCount = quantities.length;
  if (qtyCount != 1 ||
      priceCount < 1 ||
      priceCount > 2 ||
      totalCount < 1 ||
      totalCount > 2)
    return [];
  final positions = <MapEntry<int, bool>>[
    for (final m in prices) MapEntry(m.start, false),
    for (final m in totals) MapEntry(m.start, false),
    for (final m in quantities) MapEntry(m.start, true),
  ]..sort((a, b) => a.key.compareTo(b.key));
  // Only parse description-first layouts. Other column orders require layout
  // metadata and must not be mistaken for product descriptions.
  if (positions.first.key <
      _wordPattern(_description).firstMatch(headings)!.start)
    return [];
  final hasUnit = _wordPattern(_unit)
      .allMatches(headings)
      .any((u) => !prices.any((p) => u.start < p.end && p.start < u.end));
  final numericTail = positions
      .map(
        (p) =>
            p.value ? _number : '(?:$_currency\\s*)?$_money(?:\\s*$_currency)?',
      )
      .join(r'\s+');
  final rowPattern = RegExp(
    '^(.+?)\\s+${hasUnit ? '(?:$_units)\\s+' : ''}$numericTail\$',
    caseSensitive: false,
    unicode: true,
  );
  final pre = lines.take(header).join('\n');
  String label(String pattern) =>
      RegExp(
        '(?:^|\\n)[ \\t]*(?:$pattern)[ \\t]*[:：][ \\t]*([^\\n]+)',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(pre)?.group(1)?.trim() ??
      '';
  final seller = label(
    r'фирма\s*/\s*наименование|наименование на доставчика|доставчик|продавач|seller|supplier|vendor|store|verkäufer|lieferant|händler|verkoper|leverancier|vendeur|fournisseur|vendedor|proveedor|venditore|fornitore|furnizor|vânzător|sprzedawca|dostawca|fornecedor|πωλητής|προμηθευτής|satıcı|tedarikçi|продавец|поставщик|продавець|постачальник',
  );
  final customer = label(
    r'име на клиента|клиент|купувач|customer|buyer|kunde|käufer|klant|koper|client|acheteur|cliente|comprador|acquirente|cumpărător|nabywca|klient|πελάτης|αγοραστής|müşteri|alıcı|покупатель|покупець',
  );
  final receipt = label(
    r'номер|фактура\s*(?:номер|№)|invoice\s*(?:number|no\.?|#)|rechnungsnummer|rechnungs-nr\.?|factuurnummer|numéro de facture|número de factura|numero di fattura|număr factură|numer faktury|número da fatura|αριθμός τιμολογίου|fatura no|номер сч[её]та|номер рахунку',
  );
  final invoiceDate = parseDate(
    label(
      r'дата|дата на фактурата|invoice date|date|rechnungsdatum|datum|factuurdatum|date de facture|fecha|data|data fattura|data facturii|data faktury|data da fatura|ημερομηνία|fatura tarihi|дата сч[её]та|дата рахунку',
    ),
  );
  final rows = <Map<String, String>>[];
  var buffer = '';
  int? nextNumber;
  final useNumbers = numbered.hasMatch(lines[first]);
  for (final original in lines.skip(first)) {
    if (original.isEmpty) continue;
    if (footer.hasMatch(original) || RegExp(r'^\d+/\d+$').hasMatch(original))
      break;
    final line = original.replaceAll(RegExp(r'[|│\t]+'), ' ').trim();
    final start = numbered.firstMatch(line);
    if (buffer.isEmpty) {
      if (useNumbers) {
        if (start == null) break;
        final n = int.parse(start.group(1)!);
        if (n != (nextNumber ?? 1)) return [];
        nextNumber = n + 1;
        buffer = start.group(2)!;
      } else {
        if (!original.contains(RegExp(r'[|│\t]'))) break;
        buffer = line;
      }
    } else {
      if (useNumbers &&
          start != null &&
          int.parse(start.group(1)!) == nextNumber &&
          RegExp(r'^\p{L}', unicode: true).hasMatch(start.group(2)!))
        return [];
      buffer = '$buffer $line';
    }
    final m = rowPattern.firstMatch(buffer);
    if (m == null) {
      if (buffer.length > 3000) return [];
      continue;
    }
    final description = m.group(1)!.trim();
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(description)) return [];
    final code = RegExp(
      r'\[([A-Za-z0-9][A-Za-z0-9._/-]{2,39})\]$',
    ).firstMatch(description);
    final product = code == null
        ? description
        : description.substring(0, code.start).trim();
    final row = <String, String>{
      'product': product,
      'notes':
          'Invoice item ${rows.length + 1}. No warranty dates or duration stated in this invoice row. Confirm coverage before saving.',
    };
    if (code != null) row['model'] = code.group(1)!;
    if (seller.isNotEmpty) row['store'] = seller;
    if (customer.isNotEmpty) row['customer'] = customer;
    if (receipt.isNotEmpty) row['receipt'] = receipt;
    if (invoiceDate != null)
      row['notes'] =
          '${row['notes']}\nInvoice date: ${iso(invoiceDate)} (not a confirmed warranty start date).';
    rows.add(row);
    buffer = '';
  }
  return buffer.isEmpty ? rows : [];
}

// Other warranty cards can use the same description / serial / duration
// structure with headings in any supported language. Keep the older Bulgarian
// OCR recovery rules above intact.
List<Map<String, String>> _extractMultilingualWarrantyTable(
  List<String> lines,
) {
  final serialHeader = _wordPattern(
    r'serial number|serial no\.?|s/n|сериен номер|seriennummer|serienummer|numéro de série|número de serie|numero di serie|număr de serie|numer seryjny|número de série|αριθμός σειράς|seri numarası|серийный номер|серійний номер',
  );
  final warrantyHeader = _wordPattern(
    r'warranty(?: duration| period)?|гаранция|garantie(?:dauer|periode)?|garantía|garanzia|garanție|gwarancja|garantia|εγγύηση|garanti|гарантия|гарантія',
  );
  final header = lines.indexWhere((line) {
    final d = _wordPattern(_description).firstMatch(line);
    final sn = serialHeader.firstMatch(line);
    final w = warrantyHeader.firstMatch(line);
    return d != null &&
        sn != null &&
        w != null &&
        d.start < sn.start &&
        sn.start < w.start;
  });
  if (header < 0) return [];
  final pattern = RegExp(
    r'^(.+?)\s*(?:[|│]\s*|\s+)([\p{L}\p{N}][\p{L}\p{N}._/-]{2,39})\s*(?:[|│]\s*|\s+)(\d{1,3})\s*(?:months?|мес\.?|месеца|monat(?:e|en)?|maand(?:en)?|mois|mes(?:es)?|mesi|luni|miesi[aą]c(?:e|y)?|mies\.?|μήνες|μήνας|ay|месяц(?:а|ев)?|місяц(?:і|ів)?)(?=\s|[|│]|$)',
    caseSensitive: false,
    unicode: true,
  );
  final rows = <Map<String, String>>[];
  for (final original in lines.skip(header + 1).take(60)) {
    final line = original.trim().replaceFirst(RegExp(r'^[|│]+\s*'), '');
    if (line.isEmpty || RegExp(r'^[-_=|│─+\s]+$').hasMatch(line)) continue;
    final m = pattern.firstMatch(line);
    if (m == null) {
      if (rows.isNotEmpty) break;
      continue;
    }
    final months = int.parse(m.group(3)!);
    final product = m
        .group(1)!
        .trim()
        .replaceFirst(RegExp(r'[|│]\s*$'), '')
        .trim();
    if (product.isEmpty || months < 1 || months > 600) return [];
    rows.add({
      'product': product,
      'serial': m.group(2)!,
      'months': '$months',
      'notes':
          'Warranty table: verify the original serial and duration; confirm start and expiration dates.',
    });
  }
  return rows;
}
