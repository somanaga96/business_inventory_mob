import '../../../app_exports.dart';

import 'package:excel_plus/excel_plus.dart' as xlsx;
import 'package:pdf/widgets.dart' as pw;

class BusinessSummary extends StatefulWidget {
  const BusinessSummary({super.key, required this.controller});
  final InventoryController controller;

  @override
  State<BusinessSummary> createState() => _BusinessSummaryState();
}

class _BusinessSummaryState extends State<BusinessSummary> {
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();

  String dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        from = picked.isAfter(to) ? to : picked;
      } else {
        to = picked.isBefore(from) ? from : picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.controller.transactionsForRange(from, to),
        builder: (context, snapshot) {
          var sales = 0.0;
          var purchases = 0.0;
          var grossProfit = 0.0;
          var stockLoss = 0.0;
          var itemsSold = 0;
          var saleEntries = 0;
          var purchaseEntries = 0;
          for (final doc in snapshot.data?.docs ?? []) {
            final data = doc.data();
            final type = '${data['type'] ?? data['recordType'] ?? ''}'
                .trim()
                .toLowerCase();
            final quantity =
                ((data['quantity'] ?? data['purchaseQuantity']) as num?)
                    ?.toDouble() ??
                0;
            final price = ((data['unitPrice'] ?? data['buyPrice']) as num?)
                    ?.toDouble() ??
                0;
            final cost = (data['mrp'] as num?)?.toDouble() ?? 0;
            final amount = quantity * price;
            switch (type) {
              case 'sale':
                sales += amount;
                grossProfit += (price - cost) * quantity;
                itemsSold += quantity.toInt();
                saleEntries++;
                break;
              case 'purchase':
                purchases += amount;
                purchaseEntries++;
                break;
              case 'damage':
              case 'stolen':
                stockLoss += cost * quantity;
                break;
            }
          }
          final netCashFlow = sales - purchases - stockLoss;
          final profit = grossProfit > 0 ? grossProfit : 0.0;
          final loss = (grossProfit < 0 ? -grossProfit : 0.0) + stockLoss;
          return ResponsivePage(
            children: [
              const Text(
                'Business summary',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickDate(true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('From ${dateLabel(from)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickDate(false),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('To ${dateLabel(to)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showExportOptions(
                        context,
                        snapshot.data?.docs ?? const [],
                      ),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _showExportOptions(
                            context,
                            snapshot.data?.docs ?? const [],
                            printOnly: true,
                          ),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  SummaryMetricCard(
                    label: 'Sales revenue',
                    value: 'Rs ${sales.toStringAsFixed(2)}',
                    icon: Icons.sell_outlined,
                    color: const Color(0xFF168B57),
                  ),
                  SummaryMetricCard(
                    label: 'Purchase spend',
                    value: 'Rs ${purchases.toStringAsFixed(2)}',
                    icon: Icons.shopping_bag_outlined,
                    color: primary,
                  ),
                  SummaryMetricCard(
                    label: 'Profit',
                    value: 'Rs ${profit.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                    color: const Color(0xFF168B57),
                  ),
                  SummaryMetricCard(
                    label: 'Loss',
                    value: 'Rs ${loss.toStringAsFixed(2)}',
                    icon: Icons.trending_down,
                    color: const Color(0xFFD34C4C),
                  ),
                  SummaryMetricCard(
                    label: 'Units sold',
                    value: '$itemsSold',
                    icon: Icons.shopping_cart_outlined,
                    color: const Color(0xFF168B57),
                  ),
                  StreamBuilder<List<Product>>(
                    stream: widget.controller.products,
                    builder: (context, inventorySnapshot) {
                      final inventoryValue = (inventorySnapshot.data ?? [])
                          .fold<double>(
                            0,
                            (totalValue, product) =>
                                totalValue + (product.quantity * product.cost),
                          );
                      return SummaryMetricCard(
                        label: 'Inventory value',
                        value: 'Rs ${inventoryValue.toStringAsFixed(2)}',
                        icon: Icons.inventory_2_outlined,
                        color: primary,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash movement (not profit)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _summaryRow('Selling total', sales, const Color(0xFF168B57)),
                      _summaryRow('Buying total', purchases, primary),
                      _summaryRow('Stock loss', stockLoss, const Color(0xFFD34C4C)),
                      const Divider(height: 22),
                      _summaryRow(
                        'Sales minus purchases',
                        netCashFlow,
                        netCashFlow < 0 ? const Color(0xFFD34C4C) : const Color(0xFF168B57),
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$saleEntries sale ${saleEntries == 1 ? 'entry' : 'entries'} • '
                        '$purchaseEntries purchase ${purchaseEntries == 1 ? 'entry' : 'entries'}',
                        style: const TextStyle(color: Color(0xFF8493AD)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _summaryRow(String label, double amount, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
            Text(
              'Rs ${amount.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
            ),
          ],
        ),
      );

  String _fileDate(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';

  String get _exportLabel => '${_fileDate(from)}_to_${_fileDate(to)}';

  List<List<dynamic>> _exportRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) => [
    ['Date', 'Time', 'Type', 'Product', 'Quantity', 'Unit price', 'MRP', 'Amount', 'Customer', 'City/Village', 'Reference'],
    ...transactions.map((doc) {
      final data = doc.data();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0;
      final rawDate = data['transactionDate'] ?? data['createdAt'];
      final date = rawDate is Timestamp ? rawDate.toDate() : null;
      return [
        date == null ? '' : dateLabel(date),
        date == null
            ? ''
            : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        '${data['type'] ?? ''}',
        '${data['productName'] ?? ''}',
        quantity,
        unitPrice,
        (data['mrp'] as num?)?.toDouble() ?? 0,
        quantity * unitPrice,
        '${data['party'] ?? ''}',
        '${data['city'] ?? ''}',
        '${data['note'] ?? ''}',
      ];
    }),
  ];

  Future<void> _shareExport(
    List<int> bytes, {
    required String filename,
    required String mimeType,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType)],
      fileNameOverrides: [filename],
    ),
  );

  Future<void> _exportCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) => _shareExport(
    utf8.encode(csv.encode(_exportRows(transactions))),
    filename: 'business_summary_$_exportLabel.csv',
    mimeType: 'text/csv',
  );

  Future<void> _exportExcel(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) async {
    final workbook = xlsx.Excel.createExcel();
    final sheet = workbook['Business summary'];
    for (final row in _exportRows(transactions)) {
      sheet.appendRow(row.map((value) {
        if (value is int) return xlsx.IntCellValue(value);
        if (value is double) return xlsx.DoubleCellValue(value);
        return xlsx.TextCellValue('$value');
      }).toList());
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Could not create the Excel file.');
    await _shareExport(
      bytes,
      filename: 'business_summary_$_exportLabel.xlsx',
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> _exportPdf(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) async {
    final document = pw.Document();
    final rows = _exportRows(transactions);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Business summary: ${dateLabel(from)} to ${dateLabel(to)}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: rows.first.map((value) => '$value').toList(),
            data: rows.skip(1).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
            cellStyle: const pw.TextStyle(fontSize: 6),
            cellPadding: const pw.EdgeInsets.all(3),
          ),
        ],
      ),
    );
    await _shareExport(
      await document.save(),
      filename: 'business_summary_$_exportLabel.pdf',
      mimeType: 'application/pdf',
    );
  }

  Future<void> _runExport(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create the export file. Please try again.')),
        );
      }
    }
  }

  void _showExportOptions(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions, {
    bool printOnly = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Bluetooth thermal printer'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Connect a Bluetooth thermal printer to print this report.',
                    ),
                  ),
                );
              },
            ),
            if (!printOnly) ...[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Export PDF'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _runExport(context, () => _exportPdf(transactions));
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export Excel'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _runExport(context, () => _exportExcel(transactions));
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Export CSV'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _runExport(context, () => _exportCsv(transactions));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
