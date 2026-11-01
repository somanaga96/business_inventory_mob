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
          var profit = 0.0;
          var loss = 0.0;
          var itemsSold = 0;
          for (final doc in snapshot.data?.docs ?? []) {
            final data = doc.data();
            final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
            final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
            final cost = (data['mrp'] as num?)?.toDouble() ?? 0;
            final amount = quantity * price;
            switch (data['type']) {
              case 'Sale':
                sales += amount;
                profit += (price - cost) * quantity;
                itemsSold += quantity.toInt();
                break;
              case 'Purchase':
                purchases += amount;
                break;
              case 'Damage':
                loss += cost * quantity;
                break;
            }
          }
          return ResponsivePage(
            children: [
              const Text(
                'Business summary',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sales and stock performance for a selected period.',
                style: TextStyle(color: Color(0xFF8493AD)),
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
                    label: 'Sales',
                    value: 'Rs ${sales.toStringAsFixed(2)}',
                    icon: Icons.sell_outlined,
                    color: const Color(0xFF168B57),
                  ),
                  SummaryMetricCard(
                    label: 'Purchase inflow',
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
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: primary,
                  ),
                  title: Text('$itemsSold items sold'),
                  subtitle: const Text(
                    'Based on completed sale transactions in this period.',
                  ),
                ),
              ),
            ],
          );
        },
      );

  String _fileDate(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';

  String get _exportLabel => '${_fileDate(from)}_to_${_fileDate(to)}';

  List<List<dynamic>> _exportRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) => [
    ['Date', 'Type', 'Product', 'Quantity', 'Unit price', 'MRP', 'Amount', 'Customer', 'City/Village', 'Reference'],
    ...transactions.map((doc) {
      final data = doc.data();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final unitPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0;
      final rawDate = data['transactionDate'] ?? data['createdAt'];
      final date = rawDate is Timestamp ? rawDate.toDate() : null;
      return [
        date == null ? '' : dateLabel(date),
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
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'business_summary_$_exportLabel.pdf',
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
