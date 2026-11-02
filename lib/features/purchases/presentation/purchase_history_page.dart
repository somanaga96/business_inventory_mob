import '../../../app_exports.dart';

import 'package:excel_plus/excel_plus.dart' as xlsx;
import 'package:pdf/widgets.dart' as pw;

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key, required this.controller});
  final InventoryController controller;

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  String query = '';
  String? expandedId;

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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

  Future<void> _printOne(Map<String, dynamic> d) async {
    final g = Generator(ThermalReceiptPrinter.paperSize, await CapabilityProfile.load());
    final date = _when(d);
    final bytes = <int>[];
    bytes.addAll(g.text('INVENTORYPRO', styles: ThermalReceiptPrinter.centerBoldStyle));
    bytes.addAll(g.text('Purchase receipt', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(g.hr());
    bytes.addAll(g.text('Product: ${d['productName'] ?? 'Product'}', styles: ThermalReceiptPrinter.normalStyle));
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
    bytes.addAll(g.text('Purchase summary', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(g.text('${_date(from)} - ${_date(to)}', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(g.hr());
    bytes.addAll(g.row([
      PosColumn(text: 'No', width: 1, styles: ThermalReceiptPrinter.boldStyle),
      PosColumn(text: 'Item', width: 2, styles: ThermalReceiptPrinter.boldStyle),
      PosColumn(text: 'Date', width: 2, styles: ThermalReceiptPrinter.boldStyle),
      PosColumn(text: 'Qty x rate', width: 4, styles: ThermalReceiptPrinter.rightBoldStyle),
      PosColumn(text: 'Total', width: 3, styles: ThermalReceiptPrinter.rightBoldStyle),
    ]));
    bytes.addAll(g.hr());
    for (var index = 0; index < docs.length; index++) {
      final doc = docs[index];
      final d = doc.data();
      final purchasedAt = _when(d);
      bytes.addAll(g.row([
        PosColumn(
          text: '${index + 1}',
          width: 1,
          styles: ThermalReceiptPrinter.normalStyle,
        ),
        PosColumn(
          text: _short('${d['productName'] ?? 'Product'}', 7),
          width: 2,
          styles: ThermalReceiptPrinter.normalStyle,
        ),
        PosColumn(
          text: purchasedAt == null
              ? '-'
              : '${purchasedAt.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][purchasedAt.month - 1]}',
          width: 2,
          styles: ThermalReceiptPrinter.normalStyle,
        ),
        PosColumn(
          text: '${_qty(d)} x ${_price(d).toStringAsFixed(2)}',
          width: 4,
          styles: ThermalReceiptPrinter.rightStyle,
        ),
        PosColumn(
          text: _total(d).toStringAsFixed(2),
          width: 3,
          styles: ThermalReceiptPrinter.rightStyle,
        ),
      ]));
    }
    bytes.addAll(g.hr());
    bytes.addAll(g.text('TOTAL PURCHASE: Rs ${sum.toStringAsFixed(2)}', styles: ThermalReceiptPrinter.rightBoldStyle));
    bytes.addAll(g.feed(3));
    bytes.addAll([0x1D, 0x56, 0x01]);
    if (mounted) await ThermalReceiptPrinter.print(context, bytes);
  }

  List<List<dynamic>> _rows(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) => [
    ['Date', 'Time', 'Product', 'Quantity', 'Buy price', 'Total', 'Supplier', 'City/Village', 'Note'],
    ...docs.map((doc) {
      final d = doc.data();
      final when = _when(d);
      return [when == null ? '' : _date(when), _time(d), '${d['productName'] ?? ''}', _qty(d), _price(d), _total(d), '${d['party'] ?? ''}', '${d['city'] ?? ''}', '${d['note'] ?? ''}'];
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
        return _isPurchase(d) && search.contains(query.toLowerCase());
      }).toList()..sort((a, b) => (_when(b.data()) ?? DateTime(0)).compareTo(_when(a.data()) ?? DateTime(0)));
      final sum = docs.fold<double>(0, (v, doc) => v + _total(doc.data()));
      return ResponsivePage(children: [
        const Text('Purchase history', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.calendar_today_outlined), label: Text('From ${_date(from)}'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.calendar_today_outlined), label: Text('To ${_date(to)}')))]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: docs.isEmpty ? null : () => _export(docs), icon: const Icon(Icons.file_download_outlined), label: const Text('Export'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: docs.isEmpty ? null : () => _printAll(docs), icon: const Icon(Icons.print_outlined), label: const Text('Print')))]),
        const SizedBox(height: 14),
        TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search product, supplier or note', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        Card(child: ListTile(leading: const Icon(Icons.shopping_bag_outlined, color: primary), title: Text('${docs.length} purchase ${docs.length == 1 ? 'entry' : 'entries'}'), trailing: Text('Rs ${sum.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)))),
        const SizedBox(height: 10),
        if (snapshot.hasError) const Card(child: ListTile(leading: Icon(Icons.error_outline), title: Text('Unable to load purchase history.'))),
        if (!snapshot.hasData) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (snapshot.hasData && docs.isEmpty) const Card(child: ListTile(leading: Icon(Icons.receipt_long_outlined), title: Text('No purchases in this date range'), subtitle: Text('Change the dates or record a purchase from the Purchase tab.'))),
        ...docs.map((doc) {
          final d = doc.data(); final expanded = expandedId == doc.id; final note = '${d['note'] ?? ''}'.trim();
          return Card(margin: const EdgeInsets.only(bottom: 10), child: Column(children: [
            ListTile(onTap: () => setState(() => expandedId = expanded ? null : doc.id), leading: const CircleAvatar(backgroundColor: Color(0xFFDCF8E9), child: Icon(Icons.south_west, color: Color(0xFF168B57))), title: Text('${d['productName'] ?? 'Product'}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_date(_when(d) ?? DateTime.now())} • ${_time(d)}'), trailing: Text('Rs ${_total(d).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800))),
            if (expanded) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(), Text('Quantity: ${_qty(d)}'), Text('Buy price: Rs ${_price(d).toStringAsFixed(2)}'), Text('Total: Rs ${_total(d).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              if ('${d['party'] ?? ''}'.trim().isNotEmpty) Text('Supplier: ${d['party']}'), if ('${d['city'] ?? ''}'.trim().isNotEmpty) Text('City / Village: ${d['city']}'), if (note.isNotEmpty) Text('Note: $note'), if (d['inventoryAfter'] != null) Text('Stock after purchase: ${d['inventoryAfter']}'),
              const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _printOne(d), icon: const Icon(Icons.print_outlined), label: const Text('Print purchase'))),
            ])),
          ]));
        }),
      ]);
    },
  );
}
