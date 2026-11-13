// Local, extensible vocabulary. Each column maps to a canonical warranty field.
const documentLanguages = <String, String>{
  'eng': 'English',
  'bul': 'Bulgarian',
  'deu': 'German',
  'nld': 'Dutch',
  'fra': 'French',
  'spa': 'Spanish',
  'ita': 'Italian',
  'ron': 'Romanian',
  'pol': 'Polish',
  'por': 'Portuguese',
  'ell': 'Greek',
  'tur': 'Turkish',
  'rus': 'Russian',
  'ukr': 'Ukrainian',
};
const fieldKeys = [
  'product',
  'store',
  'customer',
  'model',
  'serial',
  'reference',
  'receipt',
  'start',
  'expiry',
  'months',
];
// Alternatives are separated by |. Add new dictionaries here.
const vocabularies = <String, List<String>>{
  'eng': [
    'Product|Product name|Item|Article',
    'Store|Seller|Retailer|Merchant',
    'Customer|Customer name|Buyer',
    'Model',
    'Serial number|Serial no.|S/N',
    'Warranty number|Warranty reference|Warranty no.',
    'Invoice number|Receipt number|Order number',
    'Purchase date|Delivery date|Warranty start date|Warranty start',
    'Expiry date|Expiration date|Valid until|Warranty end date',
    'Warranty period|Warranty duration|Warranty',
  ],
  'bul': [
    'Продукт|Стока|Артикул',
    'Магазин|Продавач|Търговец',
    'Клиент|Купувач',
    'Модел',
    'Сериен номер|Сериен №',
    'Гаранционен номер|Гаранционна карта №',
    'Фактура|Фактура №|Касова бележка',
    'Дата на покупка|Дата на доставка|Дата на получаване|Начало на гаранцията',
    'Валидна до|Гаранция до|Край на гаранцията',
    'Гаранционен срок|Гаранция',
  ],
  'deu': [
    'Produkt|Produktname|Artikel|Artikelbezeichnung|Bezeichnung',
    'Händler|Verkäufer|Geschäft|Anbieter',
    'Kunde|Kundenname|Käufer',
    'Modell|Modellnummer',
    'Seriennummer|Serien-Nr.|Serien-Nr|Gerätenummer',
    'Garantienummer|Garantie-Nr.|Garantiescheinnummer',
    'Rechnungsnummer|Rechnungs-Nr.|Belegnummer|Bestellnummer',
    'Kaufdatum|Lieferdatum|Garantiebeginn|Datum des Kaufs',
    'Gültig bis|Garantieende|Ablaufdatum|Garantie bis',
    'Garantiezeit|Garantiedauer|Garantiefrist|Garantie|Gewährleistungsfrist',
  ],
  'nld': [
    'Product|Productnaam|Artikel|Artikelnaam|Omschrijving',
    'Winkel|Verkoper|Leverancier',
    'Klant|Klantnaam|Koper',
    'Model|Modelnummer',
    'Serienummer|Serienummer(s)|Serienr.',
    'Garantienummer|Garantiebewijsnummer',
    'Factuurnummer|Factuurnr.|Bonnummer|Bestelnummer',
    'Aankoopdatum|Leverdatum|Ingangsdatum garantie|Garantiebegindatum',
    'Geldig tot|Garantie tot|Garantie t/m|Vervaldatum|Einddatum garantie',
    'Garantietermijn|Garantieperiode|Garantieduur|Garantie',
  ],
  'fra': [
    'Produit|Nom du produit|Article|Désignation',
    'Vendeur|Magasin|Revendeur',
    'Client|Nom du client|Acheteur',
    'Modèle',
    'Numéro de série|N° de série|Nº de série',
    'Numéro de garantie|N° de garantie',
    'Numéro de facture|N° de facture|Numéro de commande',
    'Date d’achat|Date d\'achat|Date de livraison|Début de garantie',
    'Date d’expiration|Date d\'expiration|Valable jusqu’au|Valable jusqu\'au|Fin de garantie',
    'Durée de garantie|Durée de la garantie|Période de garantie|Garantie',
  ],
  'spa': [
    'Producto|Nombre del producto|Artículo',
    'Tienda|Vendedor|Comercio',
    'Cliente|Nombre del cliente|Comprador',
    'Modelo',
    'Número de serie|N.º de serie|Nº de serie',
    'Número de garantía|N.º de garantía',
    'Número de factura|N.º de factura|Número de pedido',
    'Fecha de compra|Fecha de entrega|Inicio de garantía',
    'Fecha de vencimiento|Fecha de caducidad|Válido hasta|Fin de garantía',
    'Período de garantía|Periodo de garantía|Duración de la garantía|Plazo de garantía|Garantía',
  ],
  'ita': [
    'Prodotto|Nome del prodotto|Articolo',
    'Venditore|Negozio|Rivenditore',
    'Cliente|Nome del cliente|Acquirente',
    'Modello',
    'Numero di serie|N. di serie|Matricola',
    'Numero di garanzia',
    'Numero di fattura|Numero ordine|Numero di scontrino',
    'Data di acquisto|Data d’acquisto|Data di consegna|Inizio garanzia',
    'Data di scadenza|Valido fino al|Scadenza garanzia',
    'Durata della garanzia|Periodo di garanzia|Garanzia',
  ],
  'ron': [
    'Produs|Denumire produs|Articol',
    'Vânzător|Magazin|Comerciant',
    'Client|Nume client|Cumpărător',
    'Model',
    'Număr de serie|Serie produs|Nr. serie',
    'Număr garanție|Nr. garanție|Număr certificat',
    'Număr factură|Nr. factură|Număr comandă',
    'Data achiziției|Data cumpărării|Data livrării|Data începerii garanției',
    'Data expirării|Valabil până la|Expiră la',
    'Perioada de garanție|Durata garanției|Termen de garanție|Garanție',
  ],
  'pol': [
    'Produkt|Nazwa produktu|Towar',
    'Sklep|Sprzedawca',
    'Klient|Nabywca',
    'Model',
    'Numer seryjny|Nr seryjny',
    'Numer gwarancji|Nr gwarancji',
    'Numer faktury|Nr faktury|Numer zamówienia',
    'Data zakupu|Data dostawy|Początek gwarancji',
    'Ważna do|Data wygaśnięcia|Koniec gwarancji',
    'Okres gwarancji|Czas gwarancji|Gwarancja',
  ],
  'por': [
    'Produto|Nome do produto|Artigo',
    'Loja|Vendedor',
    'Cliente|Nome do cliente|Comprador',
    'Modelo',
    'Número de série|N.º de série',
    'Número da garantia|Número de garantia',
    'Número da fatura|Número da nota fiscal|Número do pedido',
    'Data de compra|Data da compra|Data de entrega|Início da garantia',
    'Data de validade|Válido até|Fim da garantia',
    'Prazo de garantia|Período de garantia|Duração da garantia|Garantia',
  ],
  'ell': [
    'Προϊόν|Όνομα προϊόντος|Είδος',
    'Κατάστημα|Πωλητής',
    'Πελάτης|Αγοραστής',
    'Μοντέλο',
    'Σειριακός αριθμός|Αριθμός σειράς',
    'Αριθμός εγγύησης',
    'Αριθμός τιμολογίου|Αριθμός απόδειξης|Αριθμός παραγγελίας',
    'Ημερομηνία αγοράς|Ημερομηνία παράδοσης|Έναρξη εγγύησης',
    'Ημερομηνία λήξης|Ισχύει έως|Λήξη εγγύησης',
    'Διάρκεια εγγύησης|Περίοδος εγγύησης|Εγγύηση',
  ],
  'tur': [
    'Ürün|Ürün adı',
    'Mağaza|Satıcı',
    'Müşteri|Alıcı',
    'Model',
    'Seri numarası|Seri no',
    'Garanti numarası|Garanti belgesi numarası',
    'Fatura numarası|Fatura no|Sipariş numarası',
    'Satın alma tarihi|Teslim tarihi|Garanti başlangıç tarihi',
    'Garanti bitiş tarihi|Son geçerlilik tarihi',
    'Garanti süresi|Garanti',
  ],
  'rus': [
    'Товар|Продукт|Наименование товара',
    'Магазин|Продавец',
    'Покупатель|Клиент',
    'Модель',
    'Серийный номер',
    'Номер гарантии|Номер гарантийного талона',
    'Номер чека|Номер счета|Номер заказа',
    'Дата покупки|Дата доставки|Начало гарантии',
    'Действительно до|Дата окончания гарантии',
    'Гарантийный срок|Срок гарантии|Гарантия',
  ],
  'ukr': [
    'Товар|Продукт|Назва товару',
    'Магазин|Продавець',
    'Покупець|Клієнт',
    'Модель',
    'Серійний номер',
    'Номер гарантії|Номер гарантійного талона',
    'Номер чека|Номер рахунку|Номер замовлення',
    'Дата покупки|Дата придбання|Дата доставки|Початок гарантії',
    'Дійсна до|Дата закінчення гарантії',
    'Гарантійний строк|Термін гарантії|Гарантія',
  ],
};
String labelPattern(int index) {
  final labels =
      vocabularies.values.expand((v) => v[index].split('|')).toSet().toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  return labels.map(RegExp.escape).join('|');
}

// Date-free durations; use exact whole values, not arbitrary warranty prose.
const monthUnits =
    r'months?|месеца?|мес\.?|monate?n?|maand(?:en)?|mois|mes(?:es)?|mes[ei]|lun[ăia]|luni|miesiąc|miesiące|miesięcy|μήνα|μήνες|μηνών|ay|месяц(?:а|ев)?|міс(?:яць|яці|яців|\.)';
const yearUnits =
    r'years?|година|години|г\.?|jahr(?:e|en)?|jaar|jaren|ans?|années?|años?|anni?|an(?:i)?|rok|lata|lat|anos?|έτη|έτος|χρόνια|yıl|yıllar|год(?:а|ов)?|лет|рік|роки|років';
const allUnits = '(?:$monthUnits|$yearUnits)';
String? durationMonths(String input) {
  final match = RegExp(
    r'^(\d{1,3})\s*(' + allUnits + r')\.?$',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(input.trim());
  if (match == null) return null;
  final n = int.parse(match.group(1)!);
  final years = RegExp(
    '^(?:$yearUnits)\u0024',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(match.group(2)!);
  final m = n * (years ? 12 : 1);
  return m > 0 && m <= 600 ? '$m' : null;
}

// Scores distinctive label matches, not names or brand words. This is a hint,
// not a general-purpose language classifier. Ties are intentionally uncertain.
String documentLanguage(String text) {
  final counts = <String, int>{};
  for (final e in vocabularies.entries) {
    var score = 0;
    for (final labels in e.value) {
      final pattern = labels.split('|').map(RegExp.escape).join('|');
      if (RegExp(
        '(?:^|\\n)[ \\t]*(?:$pattern)[ \\t]*(?=[:：]|\\n|[ \\t]{2,}|\u0024)',
        caseSensitive: false,
        unicode: true,
      ).hasMatch(text))
        score++;
    }
    counts[e.key] = score;
  }
  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ranked.first.value >= 2 && ranked.first.value > ranked[1].value
      ? documentLanguages[ranked.first.key]!
      : 'Uncertain / mixed';
}

Map<String, String> multilingualFields(String text) {
  final result = <String, String>{};
  for (var i = 0; i < fieldKeys.length; i++) {
    final pattern = labelPattern(i);
    final m = RegExp(
      '(?:^|\\n)[ \\t]*(?:$pattern)[ \\t]*[:：][ \\t]*([^\\n]+)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (m != null) result[fieldKeys[i]] = m.group(1)!.trim();
  }
  // Generic three-column warranty tables. Accept one row only. Existing eMAG
  // parser handles its special surrounding prose and split headings separately.
  final header = RegExp(
    '(?:^|\\n)[ \\t]*(?:${labelPattern(0)})\\s+(?:${labelPattern(9)})\\s+(?:${labelPattern(4)})[ \\t]*(?:\\n|\u0024)',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(text);
  if (header != null) {
    final lines = text
        .substring(header.end)
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final row = RegExp(
      r'^(.+?)\s+(\d{1,3}\s*' +
          allUnits +
          r')\s+([A-Za-z0-9][A-Za-z0-9._/-]*)$',
      caseSensitive: false,
      unicode: true,
    );
    final rows = lines.map(row.firstMatch).whereType<RegExpMatch>().toList();
    if (rows.length == 1) {
      final m = rows.single;
      result['product'] = m.group(1)!;
      result['months'] = m.group(2)!;
      result['serial'] = m.group(3)!;
    }
  }
  return result;
}
