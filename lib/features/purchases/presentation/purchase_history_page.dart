import '../../../app_exports.dart';

import 'package:excel_plus/excel_plus.dart' as xlsx;
import 'package:pdf/widgets.dart' as pw;

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({
    super.key,
    required this.controller,
    required this.language,
    required this.products,
  });
  final InventoryController controller;
  final ProductNameLanguage language;
  final List<Product> products;

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  String query = '';
  String? expandedId;

  bool get _isTamil => widget.language == ProductNameLanguage.tamil;
  String _text(String english, String tamil) => _isTamil ? tamil : english;
  String _productName(Map<String, dynamic> data) {
    final productId = data['productId']?.toString();
    for (final product in widget.products) {
      if (product.id == productId) return product.nameFor(widget.language);
    }
    return '${data['productName'] ?? 'Product'}';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _shortDate(DateTime d) {
    if (_isTamil) return _date(d);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')}_${months[d.month - 1]}';
  }
  DateTime? _when(Map<String, dynamic> d) {
    final value = d['transactionDate'] ?? d['createdAt'];
    return value is Timestamp ? value.toDate() : null;
  }

  String _time(Map<String, dynamic> d) {
    final value = _when(d);
    return value == null
        ? '--:--'
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  int _qty(Map<String, dynamic> d) =>
      ((d['purchaseQuantity'] ?? d['quantity']) as num?)?.toInt() ?? 0;
  double _price(Map<String, dynamic> d) =>
      ((d['buyPrice'] ?? d['unitPrice']) as num?)?.toDouble() ?? 0;
  double _total(Map<String, dynamic> d) => _qty(d) * _price(d);
  bool _isPurchase(Map<String, dynamic> d) =>
      '${d['type'] ?? d['recordType'] ?? ''}'.toLowerCase() == 'purchase';
  bool _isDamage(Map<String, dynamic> d) =>
      '${d['type'] ?? d['recordType'] ?? ''}'.toLowerCase() == 'damage';
  bool _isPurchaseOrDamage(Map<String, dynamic> d) =>
      _isPurchase(d) || _isDamage(d);
  /// Compact movement labels used in the history table: Buy, Sell, and Loss.
  String _movementCode(Map<String, dynamic> d) {
    final type = '${d['type'] ?? d['recordType'] ?? ''}'.toLowerCase();
    return switch (type) {
      'purchase' || 'return' => 'B',
      'sale' => 'S',
      _ => 'L',
    };
  }
  String _movementLabel(Map<String, dynamic> d) => _isDamage(d)
      ? _text('Damage / loss', 'சேதம் / இழப்பு')
      : _text('Purchase', 'கொள்முதல்');
  String _short(String value, int maxLength) =>
      value.length <= maxLength ? value : '${value.substring(0, maxLength - 1)}.';

  Future<void> _pick(bool isFrom) async {
    final value = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    setState(() {
      if (isFrom) {
        from = value.isAfter(to) ? to : value;
      } else {
        to = value.isBefore(from) ? from : value;
      }
    });
  }

  int _change(Map<String, dynamic> data) =>
      (data['change'] as num?)?.toInt() ?? (_isPurchase(data) ? _qty(data) : -_qty(data));

  Future<void> _editMovement(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final quantity = TextEditingController(text: '${_qty(data)}');
    final price = TextEditingController(text: _price(data).toStringAsFixed(2));
    final party = TextEditingController(text: '${data['party'] ?? ''}');
    final city = TextEditingController(text: '${data['city'] ?? ''}');
    final note = TextEditingController(text: '${data['note'] ?? ''}');
    DateTime date = _when(data) ?? DateTime.now();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text('Edit ${_movementLabel(data).toLowerCase()}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_productName(data), style: const TextStyle(fontWeight: FontWeight.w700)),
          TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
          if (_isPurchase(data)) TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Buy price')),
          TextField(controller: party, decoration: const InputDecoration(labelText: 'Supplier / party')),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'City / village')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
          TextButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (picked != null) setDialogState(() => date = picked); }, icon: const Icon(Icons.calendar_today_outlined), label: Text(_date(date))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
      )),
    );
    if (save == true) {
      final newQuantity = int.tryParse(quantity.text) ?? 0;
      final newPrice = _isPurchase(data) ? double.tryParse(price.text) : _price(data);
      if (newQuantity <= 0 || newPrice == null || newPrice < 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity and price.')));
      } else {
        try {
          await widget.controller.updateStockMovement(transactionId: doc.id, productId: '${data['productId']}', oldChange: _change(data), quantity: newQuantity, type: '${data['type']}', unitPrice: newPrice, party: party.text.trim(), city: city.text.trim(), note: note.text.trim(), date: date);
        } on StateError catch (error) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message.toString())));
        }
      }
    }
    for (final controller in [quantity, price, party, city, note]) { controller.dispose(); }
  }

  Future<void> _deleteMovement(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Delete movement?'), content: Text('Delete ${_productName(doc.data())}? Stock will be adjusted.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete'))]));
    if (confirmed != true) return;
    try {
      await widget.controller.deleteStockMovement(transactionId: doc.id, productId: '${doc.data()['productId']}', change: _change(doc.data()));
    } on StateError catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<void> _printOne(Map<String, dynamic> d) async {
    final g = Generator(ThermalReceiptPrinter.paperSize, await CapabilityProfile.load());
    final date = _when(d);
    final bytes = <int>[];
    bytes.addAll(g.text('INVENTORYPRO', styles: ThermalReceiptPrinter.centerBoldStyle));
    bytes.addAll(g.text('${_movementLabel(d)} receipt', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(g.hr());
    bytes.addAll(await ThermalReceiptPrinter.receiptText(
      g,
      'Product: ${_productName(d)}',
      styles: ThermalReceiptPrinter.normalStyle,
    ));
    bytes.addAll(g.text('Date: ${date == null ? '-' : _date(date)}  Time: ${_time(d)}', styles: ThermalReceiptPrinter.normalStyle));
    final supplier = '${d['party'] ?? ''}'.trim();
    final city = '${d['city'] ?? ''}'.trim();
    if (supplier.isNotEmpty || city.isNotEmpty) {
      bytes.addAll(g.text('Supplier: ${supplier.isEmpty ? '-' : supplier}${city.isEmpty ? '' : '  City: $city'}', styles: ThermalReceiptPrinter.normalStyle));
    }
    bytes.addAll(g.hr());
    bytes.addAll(g.row([
      PosColumn(text: 'Qty ${_qty(d)} x Rs ${_price(d).toStringAsFixed(2)}', width: 8, styles: ThermalReceiptPrinter.normalStyle),
      PosColumn(text: 'Rs ${_total(d).toStringAsFixed(2)}', width: 4, styles: ThermalReceiptPrinter.rightStyle),
    ]));
    final note = '${d['note'] ?? ''}'.trim();
    if (note.isNotEmpty) bytes.addAll(g.text('Note: $note', styles: ThermalReceiptPrinter.normalStyle));
    bytes.addAll(g.hr());
    bytes.addAll(g.text('TOTAL: Rs ${_total(d).toStringAsFixed(2)}', styles: ThermalReceiptPrinter.rightBoldStyle));
    bytes.addAll(g.feed(3));
    bytes.addAll([0x1D, 0x56, 0x01]);
    if (mounted) await ThermalReceiptPrinter.print(context, bytes);
  }

  Future<void> _printAll(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final g = Generator(ThermalReceiptPrinter.paperSize, await CapabilityProfile.load());
    final sum = docs.fold<double>(0, (v, doc) => v + _total(doc.data()));
    final bytes = <int>[];
    bytes.addAll(g.text('INVENTORYPRO', styles: ThermalReceiptPrinter.centerBoldStyle));
    bytes.addAll(g.text('Purchase & damage summary', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(g.text('${_date(from)} - ${_date(to)}', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(g.hr());
    final byDate = <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in docs) {
      final value = _when(doc.data()) ?? DateTime.now();
      final day = DateTime(value.year, value.month, value.day);
      byDate.putIfAbsent(day, () => []).add(doc);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final day in dates) {
      final transactions = byDate[day]!;
      bytes.addAll(g.hr());
      bytes.addAll(await ThermalReceiptPrinter.receiptText(
        g,
        _date(day),
        styles: ThermalReceiptPrinter.boldStyle,
      ));
      bytes.addAll(g.row([
        PosColumn(text: 'Product', width: 6, styles: ThermalReceiptPrinter.boldStyle),
        PosColumn(text: 'Qty x Rate = Total', width: 6, styles: ThermalReceiptPrinter.rightBoldStyle),
      ]));
      for (var index = 0; index < transactions.length; index++) {
        final d = transactions[index].data();
        final title = '${index + 1}. ${_short(_productName(d), 18)}';
        final amount = '${_qty(d)} x ${_price(d).toStringAsFixed(2)} = ${_total(d).toStringAsFixed(2)}';
        bytes.addAll(await ThermalReceiptPrinter.receiptItemRow(g, name: title, amount: amount));
      }
      final dailyTotal = transactions.fold<double>(0, (total, doc) => total + _total(doc.data()));
      bytes.addAll(g.text('Date total: Rs ${dailyTotal.toStringAsFixed(2)}', styles: ThermalReceiptPrinter.rightStyle));
    }
    bytes.addAll(g.hr());
    bytes.addAll(g.text('TOTAL PURCHASE: Rs ${sum.toStringAsFixed(2)}', styles: ThermalReceiptPrinter.rightBoldStyle));
    bytes.addAll(g.feed(3));
    bytes.addAll([0x1D, 0x56, 0x01]);
    if (mounted) await ThermalReceiptPrinter.print(context, bytes);
  }

  List<List<dynamic>> _rows(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) => [
    ['Date', 'Time', 'Type', 'Product', 'Quantity', 'Unit cost', 'Total', 'Supplier', 'City/Village', 'Note'],
    ...docs.map((doc) {
      final d = doc.data();
      final when = _when(d);
      return [when == null ? '' : _date(when), _time(d), _movementLabel(d), '${d['productName'] ?? ''}', _qty(d), _price(d), _total(d), '${d['party'] ?? ''}', '${d['city'] ?? ''}', '${d['note'] ?? ''}'];
    }),
  ];

  Future<void> _share(List<int> bytes, String fileName, String mimeType) => SharePlus.instance.share(
    ShareParams(files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType)], fileNameOverrides: [fileName]),
  );

  Future<void> _exportCsv(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      _share(utf8.encode(csv.encode(_rows(docs))), 'purchase_history.csv', 'text/csv');

  Future<void> _exportExcel(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final book = xlsx.Excel.createExcel();
    final sheet = book['Purchase history'];
    for (final row in _rows(docs)) {
      sheet.appendRow(row.map((v) => v is int ? xlsx.IntCellValue(v) : v is double ? xlsx.DoubleCellValue(v) : xlsx.TextCellValue('$v')).toList());
    }
    final bytes = book.encode();
    if (bytes == null) throw StateError('Could not create Excel file');
    await _share(bytes, 'purchase_history.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  Future<void> _exportPdf(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final pdf = pw.Document();
    final rows = _rows(docs);
    pdf.addPage(pw.MultiPage(build: (_) => [
      pw.Text('Purchase history: ${_date(from)} to ${_date(to)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(headers: rows.first.map((e) => '$e').toList(), data: rows.skip(1).toList(), headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800), headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7), cellStyle: const pw.TextStyle(fontSize: 6)),
    ]));
    await _share(await pdf.save(), 'purchase_history.pdf', 'application/pdf');
  }

  void _export(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    showModalBottomSheet<void>(context: context, builder: (sheet) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Export PDF'), onTap: () async { Navigator.pop(sheet); await _exportPdf(docs); }),
      ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Export Excel'), onTap: () async { Navigator.pop(sheet); await _exportExcel(docs); }),
      ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Export CSV'), onTap: () async { Navigator.pop(sheet); await _exportCsv(docs); }),
    ])));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.controller.transactionsForRange(from, to),
    builder: (context, snapshot) {
      final docs = (snapshot.data?.docs ?? []).where((doc) {
        final d = doc.data();
        final search = '${d['productName'] ?? ''} ${d['party'] ?? ''} ${d['note'] ?? ''}'.toLowerCase();
        return _isPurchaseOrDamage(d) && search.contains(query.toLowerCase());
      }).toList()..sort((a, b) => (_when(b.data()) ?? DateTime(0)).compareTo(_when(a.data()) ?? DateTime(0)));
      final sum = docs.fold<double>(0, (v, doc) => v + _total(doc.data()));
      final byDate = <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final doc in docs) {
        final value = _when(doc.data()) ?? DateTime.now();
        final day = DateTime(value.year, value.month, value.day);
        byDate.putIfAbsent(day, () => []).add(doc);
      }
      return ResponsivePage(horizontalPaddingFactor: .015, children: [
        Text(
          _text('Purchase & damage history', 'கொள்முதல் மற்றும் சேத வரலாறு'),
          style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('${_text('From', 'முதல்')} ${_date(from)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('${_text('To', 'வரை')} ${_date(to)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: docs.isEmpty ? null : () => _export(docs),
                icon: const Icon(Icons.file_download_outlined),
                label: Text(_text('Export', 'ஏற்றுமதி')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: docs.isEmpty ? null : () => _printAll(docs),
                icon: const Icon(Icons.print_outlined),
                label: Text(_text('Print', 'அச்சிடு')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: _text('Search product, supplier or note', 'பொருள், வழங்குநர் அல்லது குறிப்பைத் தேடவும்'), border: const OutlineInputBorder())),
        const SizedBox(height: 14),
        Card(child: ListTile(leading: const Icon(Icons.shopping_bag_outlined, color: primary), title: Text(_isTamil ? '${docs.length} பதிவுகள்' : '${docs.length} movement ${docs.length == 1 ? 'entry' : 'entries'}'), trailing: Text('Rs ${sum.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)))),
        const SizedBox(height: 10),
        if (snapshot.hasError) Card(child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_text('Unable to load purchase history.', 'கொள்முதல் வரலாற்றை ஏற்ற முடியவில்லை.')))),
        if (!snapshot.hasData) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (snapshot.hasData && docs.isEmpty) Card(child: ListTile(leading: const Icon(Icons.receipt_long_outlined), title: Text(_text('No purchases or damage in this date range', 'இந்த தேதி வரம்பில் கொள்முதல் அல்லது சேதப் பதிவுகள் இல்லை')), subtitle: Text(_text('Change the dates or record a stock movement from the Purchase tab.', 'தேதிகளை மாற்றவும் அல்லது கொள்முதல் பக்கத்தில் இருப்பு நகர்வைப் பதிவு செய்யவும்.')))),
        ...byDate.entries.map((entry) => Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Align(alignment: Alignment.centerLeft, child: Text(_shortDate(entry.key), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(.42),
                1: FlexColumnWidth(2.15),
                2: FlexColumnWidth(.9),
                3: FlexColumnWidth(1.4),
                4: FlexColumnWidth(1.65),
              },
              border: TableBorder.all(color: Theme.of(context).dividerColor),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  children: [
                    const _PurchaseTableCell('B/S/L', header: true, right: true),
                    _PurchaseTableCell(_text('Product', 'பொருள்'), header: true),
                    _PurchaseTableCell(_text('Qty', 'அளவு'), header: true, right: true),
                    _PurchaseTableCell(_text('Price', 'விலை'), header: true, right: true),
                    _PurchaseTableCell(_text('Amount', 'தொகை'), header: true, right: true),
                  ],
                ),
                ...entry.value.map((doc) {
                  final data = doc.data();
                  return TableRow(children: [
                    _PurchaseTableCell(_movementCode(data), right: true),
                    _PurchaseTableCell(_productName(data)),
                    _PurchaseTableCell('${_qty(data)}', right: true),
                    _PurchaseTableCell(_price(data).toStringAsFixed(2), right: true),
                    _PurchaseTableCell(_total(data).toStringAsFixed(2), right: true),
                  ]);
                }),
              ],
            ),
          ),
          ...entry.value.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _productName(doc.data()),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editMovement(doc),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteMovement(doc),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ),
        ])),
        ...const <QueryDocumentSnapshot<Map<String, dynamic>>>[].map((doc) {
          final d = doc.data(); final expanded = expandedId == doc.id; final note = '${d['note'] ?? ''}'.trim();
          return Card(margin: const EdgeInsets.only(bottom: 10), child: Column(children: [
            ListTile(onTap: () => setState(() => expandedId = expanded ? null : doc.id), leading: const CircleAvatar(backgroundColor: Color(0xFFDCF8E9), child: Icon(Icons.south_west, color: Color(0xFF168B57))), title: Text('${d['productName'] ?? 'Product'}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_date(_when(d) ?? DateTime.now())} • ${_time(d)}'), trailing: Text('Rs ${_total(d).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))),
            if (expanded) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(), Text('Type: ${_movementLabel(d)}'), Text('Quantity: ${_qty(d)}'), Text('${_isDamage(d) ? 'Loss value' : 'Buy price'}: Rs ${_price(d).toStringAsFixed(2)}'), Text('Total: Rs ${_total(d).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if ('${d['party'] ?? ''}'.trim().isNotEmpty) Text('Supplier: ${d['party']}'), if ('${d['city'] ?? ''}'.trim().isNotEmpty) Text('City / Village: ${d['city']}'), if (note.isNotEmpty) Text('Note: $note'), if (d['inventoryAfter'] != null) Text('Stock after ${_isDamage(d) ? 'damage' : 'purchase'}: ${d['inventoryAfter']}'),
              const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _printOne(d), icon: const Icon(Icons.print_outlined), label: Text('Print ${_movementLabel(d).toLowerCase()}'))),
            ])),
          ]));
        }),
      ]);
    },
  );
}

class _PurchaseTableCell extends StatelessWidget {
  const _PurchaseTableCell(
    this.value, {
    this.header = false,
    this.right = false,
  });

  final String value;
  final bool header;
  final bool right;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontSize: header ? 12 : 13, fontWeight: header ? FontWeight.w700 : null),
      ),
  );
}
