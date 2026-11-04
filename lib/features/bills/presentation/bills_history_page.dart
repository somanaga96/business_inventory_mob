import '../../../app_exports.dart';

import 'package:excel_plus/excel_plus.dart' as xlsx;
import 'package:pdf/widgets.dart' as pw;

class BillsHistory extends StatefulWidget {
  const BillsHistory({
    super.key,
    required this.controller,
    required this.products,
    required this.language,
  });
  final InventoryController controller;
  final List<Product> products;
  final ProductNameLanguage language;
  @override
  State<BillsHistory> createState() => _BillsHistoryState();
}

class _BillsHistoryState extends State<BillsHistory> {
  DateTime selectedDate = DateTime.now();
  String productName(Map<String, dynamic> data) {
    final productId = data['productId']?.toString();
    for (final product in widget.products) {
      if (product.id == productId) return product.nameFor(widget.language);
    }
    return '${data['productName'] ?? 'Product'}';
  }
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  void changeSelectedDate(int days) {
    setState(() => selectedDate = selectedDate.add(Duration(days: days)));
  }

  List<List<dynamic>> exportRows(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) {
    final rows = <List<dynamic>>[
      [
        'Bill number',
        'Date',
        'Time',
        'Customer',
        'City/Village',
        'Product',
        'Quantity',
        'MRP',
        'Unit price',
        'Item total',
      ],
    ];
    for (final entry in grouped.entries) {
      final docs = entry.value;
      final firstData = docs.first.data();
      final customer = '${firstData['party'] ?? ''}'.trim();
      final city = '${firstData['city'] ?? ''}'.trim();
      final rawDate = firstData['transactionDate'] ?? firstData['createdAt'];
      final orderDate = rawDate is Timestamp ? rawDate.toDate() : null;
      for (final doc in docs) {
        final data = doc.data();
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
        final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
        final mrp = (data['mrp'] as num?)?.toDouble() ?? price;
        rows.add([
          entry.key,
          orderDate == null ? '' : dateLabel(orderDate),
          orderDate == null ? '' : _timeLabel(orderDate),
          customer.isEmpty ? 'Not specified' : customer,
          city.isEmpty ? 'Not specified' : city,
          productName(data),
          quantity.toInt(),
          mrp,
          price,
          quantity * price,
        ]);
      }
    }
    return rows;
  }

  List<List<dynamic>> billTotalRows(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) {
    final rows = <List<dynamic>>[
      [
        'Bill number',
        'Date',
        'Time',
        'Customer',
        'City/Village',
        'Items',
        'Quantity',
        'Bill total',
      ],
    ];
    for (final entry in grouped.entries) {
      final docs = entry.value;
      final firstData = docs.first.data();
      final customer = '${firstData['party'] ?? ''}'.trim();
      final city = '${firstData['city'] ?? ''}'.trim();
      final rawDate = firstData['transactionDate'] ?? firstData['createdAt'];
      final orderDate = rawDate is Timestamp ? rawDate.toDate() : null;
      var quantity = 0;
      var total = 0.0;
      for (final doc in docs) {
        final data = doc.data();
        final itemQuantity = (data['quantity'] as num?)?.toDouble() ?? 0;
        final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
        quantity += itemQuantity.toInt();
        total += itemQuantity * price;
      }
      rows.add([
        entry.key,
        orderDate == null ? '' : dateLabel(orderDate),
        orderDate == null ? '' : _timeLabel(orderDate),
        customer.isEmpty ? 'Not specified' : customer,
        city.isEmpty ? 'Not specified' : city,
        docs.length,
        quantity,
        total,
      ]);
    }
    return rows;
  }

  Future<void> shareExport(
    List<int> bytes, {
    required String filename,
    required String mimeType,
  }) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType)],
      fileNameOverrides: [filename],
    ),
  );

  Future<void> exportCsv(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) async {
    final content = csv.encode(exportRows(grouped));
    await shareExport(
      utf8.encode(content),
      filename: 'orders_${dateLabel(selectedDate)}.csv',
      mimeType: 'text/csv',
    );
  }

  Future<void> exportExcel(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) async {
    final workbook = xlsx.Excel.createExcel();
    final sheet = workbook['Order summary'];
    for (final row in exportRows(grouped)) {
      sheet.appendRow(
        row.map((value) {
          if (value is int) return xlsx.IntCellValue(value);
          if (value is double) return xlsx.DoubleCellValue(value);
          return xlsx.TextCellValue('$value');
        }).toList(),
      );
    }
    final totalsSheet = workbook['Bill totals'];
    for (final row in billTotalRows(grouped)) {
      totalsSheet.appendRow(
        row.map((value) {
          if (value is int) return xlsx.IntCellValue(value);
          if (value is double) return xlsx.DoubleCellValue(value);
          return xlsx.TextCellValue('$value');
        }).toList(),
      );
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Could not create the Excel file.');
    await shareExport(
      bytes,
      filename: 'orders_${dateLabel(selectedDate)}.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportPdf(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) async {
    final document = pw.Document();
    double billTotal(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
        docs.fold(0.0, (total, doc) {
          final data = doc.data();
          final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
          final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
          return total + quantity * price;
        });
    final totalSales = grouped.values.fold(
      0.0,
      (total, docs) => total + billTotal(docs),
    );
    final itemsSold = grouped.values.fold<int>(
      0,
      (total, docs) =>
          total +
          docs.fold<int>(
            0,
            (runningTotal, doc) =>
                runningTotal + ((doc.data()['quantity'] as num?)?.toInt() ?? 0),
          ),
    );
    final averageBill = grouped.isEmpty ? 0.0 : totalSales / grouped.length;
    final itemRows = <List<dynamic>>[];
    for (final entry in grouped.entries) {
      final docs = entry.value;
      final firstData = docs.first.data();
      final customer = '${firstData['party'] ?? ''}'.trim();
      final city = '${firstData['city'] ?? ''}'.trim();
      final rawOrderDate = firstData['transactionDate'] ?? firstData['createdAt'];
      final orderDate = rawOrderDate is Timestamp ? rawOrderDate.toDate() : null;
      final total = billTotal(docs);
      for (var index = 0; index < docs.length; index++) {
        final data = docs[index].data();
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
        final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
        final firstItem = index == 0;
        itemRows.add([
          firstItem ? entry.key : '',
          firstItem && orderDate != null ? dateLabel(orderDate) : '',
          firstItem && orderDate != null ? _timeLabel(orderDate) : '',
          firstItem ? (customer.isEmpty ? 'Not specified' : customer) : '',
          firstItem ? (city.isEmpty ? 'Not specified' : city) : '',
          productName(data),
          quantity.toInt(),
          'Rs ${price.toStringAsFixed(2)}',
          'Rs ${(quantity * price).toStringAsFixed(2)}',
          firstItem ? 'Rs ${total.toStringAsFixed(2)}' : '',
        ]);
      }
    }

    pw.Widget tableCell(
      String value, {
      bool header = false,
      pw.Alignment alignment = pw.Alignment.centerLeft,
    }) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.all(6),
      color: header ? PdfColors.blueGrey800 : null,
      child: pw.Text(
        value,
        style: pw.TextStyle(
          color: header ? PdfColors.white : PdfColors.black,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 8,
        ),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.Text(
            'Order history - ${dateLabel(selectedDate)}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Daily bill summary',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                children: [
                  tableCell('Total sales', header: true),
                  tableCell('Orders', header: true),
                  tableCell('Items sold', header: true),
                  tableCell('Average bill', header: true),
                ],
              ),
              pw.TableRow(
                children: [
                  tableCell('Rs ${totalSales.toStringAsFixed(2)}'),
                  tableCell('${grouped.length}'),
                  tableCell('$itemsSold'),
                  tableCell('Rs ${averageBill.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Bill number',
              'Date',
              'Time',
              'Customer',
              'City/Village',
              'Product',
              'Quantity',
              'Unit price',
              'Item total',
              'Bill total',
            ],
            data: itemRows,
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(3),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(.7),
              3: pw.FlexColumnWidth(1.1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.4),
              6: pw.FlexColumnWidth(.7),
              7: pw.FlexColumnWidth(.9),
              8: pw.FlexColumnWidth(.9),
              9: pw.FlexColumnWidth(.9),
            },
          ),
          if (grouped.isNotEmpty)
            ...grouped.entries.map((entry) {
              final docs = entry.value;
              final firstData = docs.first.data();
              final customer = '${firstData['party'] ?? ''}'.trim();
              final city = '${firstData['city'] ?? ''}'.trim();
              final rawOrderDate =
                  firstData['transactionDate'] ?? firstData['createdAt'];
              final orderDate = rawOrderDate is Timestamp
                  ? rawOrderDate.toDate()
                  : null;
              final total = billTotal(docs);
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      color: PdfColors.blueGrey50,
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              entry.key,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          pw.Text(
                            'Bill total: Rs ${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(
                        'Date: ${orderDate == null ? '-' : dateLabel(orderDate)}  Time: ${orderDate == null ? '-' : _timeLabel(orderDate)}\nCustomer: ${customer.isEmpty ? 'Not specified' : customer}    City/Village: ${city.isEmpty ? 'Not specified' : city}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(3),
                        1: pw.FlexColumnWidth(1),
                        2: pw.FlexColumnWidth(1.2),
                        3: pw.FlexColumnWidth(1.2),
                        4: pw.FlexColumnWidth(1.4),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            tableCell('Product', header: true),
                            tableCell(
                              'Qty',
                              header: true,
                              alignment: pw.Alignment.centerRight,
                            ),
                            tableCell(
                              'MRP',
                              header: true,
                              alignment: pw.Alignment.centerRight,
                            ),
                            tableCell(
                              'Price',
                              header: true,
                              alignment: pw.Alignment.centerRight,
                            ),
                            tableCell(
                              'Amount',
                              header: true,
                              alignment: pw.Alignment.centerRight,
                            ),
                          ],
                        ),
                        ...docs.map((doc) {
                          final data = doc.data();
                          final quantity =
                              (data['quantity'] as num?)?.toDouble() ?? 0;
                          final price =
                              (data['unitPrice'] as num?)?.toDouble() ?? 0;
                          final mrp =
                              (data['mrp'] as num?)?.toDouble() ?? price;
                          return pw.TableRow(
                            children: [
                              tableCell(productName(data)),
                              tableCell(
                                '${quantity.toInt()}',
                                alignment: pw.Alignment.centerRight,
                              ),
                              tableCell(
                                'Rs ${mrp.toStringAsFixed(2)}',
                                alignment: pw.Alignment.centerRight,
                              ),
                              tableCell(
                                'Rs ${price.toStringAsFixed(2)}',
                                alignment: pw.Alignment.centerRight,
                              ),
                              tableCell(
                                'Rs ${(quantity * price).toStringAsFixed(2)}',
                                alignment: pw.Alignment.centerRight,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
    await shareExport(
      await document.save(),
      filename: 'orders_${dateLabel(selectedDate).replaceAll('/', '-')}.pdf',
      mimeType: 'application/pdf',
    );
  }

  Future<List<int>> _receiptBytes(
    String billNumber,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final generator = Generator(
      ThermalReceiptPrinter.paperSize,
      await CapabilityProfile.load(),
    );
    final firstData = docs.first.data();
    final customer = '${firstData['party'] ?? ''}'.trim();
    final city = '${firstData['city'] ?? ''}'.trim();
    final rawOrderDate = firstData['transactionDate'] ?? firstData['createdAt'];
    final orderTime = rawOrderDate is Timestamp
        ? _timeLabel(rawOrderDate.toDate())
        : '-';
    var total = 0.0;
    final bytes = <int>[];
    bytes.addAll(
      generator.text(
        'INVENTORYPRO',
        styles: ThermalReceiptPrinter.centerBoldStyle,
      ),
    );
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'Order: $billNumber',
          width: 7,
          styles: ThermalReceiptPrinter.normalStyle,
        ),
        PosColumn(
          text: 'Time: $orderTime',
          width: 5,
          styles: ThermalReceiptPrinter.rightStyle,
        ),
      ]),
    );
    if (customer.isNotEmpty || city.isNotEmpty) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: customer.isEmpty ? '' : 'Customer: $customer',
            width: 6,
            styles: ThermalReceiptPrinter.normalStyle,
          ),
          PosColumn(
            text: city.isEmpty ? '' : 'City: $city',
            width: 6,
            styles: ThermalReceiptPrinter.rightStyle,
          ),
        ]),
      );
    }
    bytes.addAll(generator.hr());
    for (final doc in docs) {
      final data = doc.data();
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
      final amount = quantity * price;
      total += amount;
      bytes.addAll(await ThermalReceiptPrinter.receiptItemRow(
        generator,
        name: productName(data),
        amount: '${quantity.toInt()} x ${price.toStringAsFixed(2)} = '
            '${amount.toStringAsFixed(2)}',
      ));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'TOTAL: Rs ${total.toStringAsFixed(2)}',
        styles: ThermalReceiptPrinter.rightBoldStyle,
      ),
    );
    bytes.addAll(generator.feed(3));
    // Partial cut without Generator.cut(), which adds five extra blank lines.
    bytes.addAll(const [0x1D, 0x56, 0x01]);
    return bytes;
  }

  Future<void> _printHistoryBill(
    BuildContext context,
    String billNumber,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final bytes = await _receiptBytes(billNumber, docs);
    if (!context.mounted) return;
    await ThermalReceiptPrinter.print(context, bytes);
  }

  Future<void> _editTodayOrder(
    String orderNumber,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (!sameDay(selectedDate, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only today\'s orders can be edited.')),
      );
      return;
    }
    final first = docs.first.data();
    final customer = TextEditingController(text: '${first['party'] ?? ''}');
    final city = TextEditingController(text: '${first['city'] ?? ''}');
    final quantities = docs.map((doc) {
      return TextEditingController(text: '${doc.data()['quantity'] ?? 0}');
    }).toList();
    final prices = docs.map((doc) {
      return TextEditingController(text: '${doc.data()['unitPrice'] ?? 0}');
    }).toList();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit order $orderNumber'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: customer,
                  decoration: const InputDecoration(labelText: 'Customer'),
                ),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'City / Village'),
                ),
                const SizedBox(height: 12),
                ...List.generate(docs.length, (index) {
                  final data = docs[index].data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(productName(data)),
                        ),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: quantities[index],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: prices[index],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(labelText: 'Price'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (save == true) {
      final updates = <
        ({String transactionId, String productId, int oldQuantity, int quantity, double unitPrice})
      >[];
      for (var index = 0; index < docs.length; index++) {
        final data = docs[index].data();
        final quantity = int.tryParse(quantities[index].text) ?? 0;
        final price = double.tryParse(prices[index].text) ?? -1;
        if (quantity <= 0 || price < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a valid quantity and price.')),
            );
          }
          customer.dispose();
          city.dispose();
          for (final controller in [...quantities, ...prices]) {
            controller.dispose();
          }
          return;
        }
        updates.add((
          transactionId: docs[index].id,
          productId: '${data['productId']}',
          oldQuantity: (data['quantity'] as num?)?.toInt() ?? 0,
          quantity: quantity,
          unitPrice: price,
        ));
      }
      try {
        await widget.controller.updateSaleOrder(
          items: updates,
          party: customer.text.trim(),
          city: city.text.trim(),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update this order.')),
          );
        }
      }
    }
    customer.dispose();
    city.dispose();
    for (final controller in [...quantities, ...prices]) {
      controller.dispose();
    }
  }

  Future<void> _printSelectedDate(
    BuildContext context,
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) async {
    if (grouped.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders exist for the selected date.')),
      );
      return;
    }
    final bytes = await _summaryBytes(grouped);
    if (!context.mounted) return;
    await ThermalReceiptPrinter.print(context, bytes);
  }

  Future<List<int>> _summaryBytes(
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) async {
    final generator = Generator(
      ThermalReceiptPrinter.paperSize,
      await CapabilityProfile.load(),
    );
    final bytes = <int>[];
    var dailyTotal = 0.0;
    bytes.addAll(
      generator.text(
        'INVENTORYPRO',
        styles: ThermalReceiptPrinter.centerBoldStyle,
      ),
    );
    bytes.addAll(
      generator.text(
        'Order summary - ${dateLabel(selectedDate)}',
        styles: ThermalReceiptPrinter.centerStyle,
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'No', width: 2, styles: ThermalReceiptPrinter.boldStyle),
        PosColumn(
          text: 'Cust',
          width: 3,
          styles: ThermalReceiptPrinter.boldStyle,
        ),
        PosColumn(
          text: 'City',
          width: 2,
          styles: ThermalReceiptPrinter.boldStyle,
        ),
        PosColumn(
          text: 'Time',
          width: 2,
          styles: ThermalReceiptPrinter.boldStyle,
        ),
        PosColumn(
          text: 'Total',
          width: 3,
          styles: ThermalReceiptPrinter.rightBoldStyle,
        ),
      ]),
    );
    bytes.addAll(generator.hr());
    for (final entry in grouped.entries) {
      final docs = entry.value;
      final first = docs.first.data();
      final customer = '${first['party'] ?? ''}'.trim();
      final city = '${first['city'] ?? ''}'.trim();
      final rawOrderDate = first['transactionDate'] ?? first['createdAt'];
      final orderTime = rawOrderDate is Timestamp
          ? _timeLabel(rawOrderDate.toDate())
          : '-';
      final billTotal = docs.fold<double>(0, (total, doc) {
        final data = doc.data();
        return total +
            ((data['quantity'] as num?)?.toDouble() ?? 0) *
                ((data['unitPrice'] as num?)?.toDouble() ?? 0);
      });
      dailyTotal += billTotal;
      bytes.addAll(
        generator.row([
          PosColumn(
            text: _shortBillNumber(entry.key),
            width: 2,
            styles: ThermalReceiptPrinter.normalStyle,
          ),
          PosColumn(
            text: _shortText(customer.isEmpty ? '-' : customer, 7),
            width: 3,
            styles: ThermalReceiptPrinter.normalStyle,
          ),
          PosColumn(
            text: _shortText(city.isEmpty ? '-' : city, 5),
            width: 2,
            styles: ThermalReceiptPrinter.normalStyle,
          ),
          PosColumn(
            text: orderTime,
            width: 2,
            styles: ThermalReceiptPrinter.normalStyle,
          ),
          PosColumn(
            text: billTotal.toStringAsFixed(0),
            width: 3,
            styles: ThermalReceiptPrinter.rightStyle,
          ),
        ]),
      );
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'DAILY TOTAL: Rs ${dailyTotal.toStringAsFixed(2)}',
        styles: ThermalReceiptPrinter.rightBoldStyle,
      ),
    );
    bytes.addAll(generator.feed(3));
    // Partial cut without Generator.cut(), which adds five extra blank lines.
    bytes.addAll(const [0x1D, 0x56, 0x01]);
    return bytes;
  }

  String _shortBillNumber(String value) => value.split('_').last;

  String _shortText(String value, int length) =>
      value.length <= length ? value : '${value.substring(0, length - 1)}.';

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void showExportOptions(
    BuildContext context,
    Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped,
  ) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Print with Bluetooth thermal printer'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await _printSelectedDate(context, grouped);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export PDF'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await exportPdf(grouped);
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export Excel'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await exportExcel(grouped);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Export CSV'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await exportCsv(grouped);
            },
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.controller.transactions,
    builder: (context, snapshot) {
      final grouped =
          <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final doc in snapshot.data?.docs ?? []) {
        final data = doc.data();
        final rawDate = data['transactionDate'] ?? data['createdAt'];
        final date = rawDate is Timestamp ? rawDate.toDate() : null;
        if (date == null || !sameDay(date, selectedDate)) continue;
        final bill = '${data['note'] ?? ''}'.trim();
        if (bill.isEmpty) continue;
        grouped.putIfAbsent(bill, () => []).add(doc);
      }
      double dailySales = 0;
      for (final docs in grouped.values) {
        for (final doc in docs) {
          final data = doc.data();
          final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
          final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
          dailySales += qty * price;
        }
      }
      return ResponsivePage(
        children: [
          const Text(
            'Order history',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Daily cumulative orders and their item details.',
            style: TextStyle(color: Color(0xFF8493AD)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              IconButton.outlined(
                onPressed: () => changeSelectedDate(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous day',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: selectedDate,
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Showing ${dateLabel(selectedDate)}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () => changeSelectedDate(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next day',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showExportOptions(context, grouped),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export'),
                ),
              ),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _printSelectedDate(context, grouped),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              SummaryMetricCard(
                label: 'Total sales',
                value: '₹${dailySales.toStringAsFixed(2)}',
                icon: Icons.currency_rupee,
                color: const Color(0xFF168B57),
              ),
              SummaryMetricCard(
                label: 'Orders',
                value: '${grouped.length}',
                icon: Icons.receipt_long_outlined,
                color: primary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator()),
          if (snapshot.hasData && grouped.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('No orders for this date'),
                subtitle: Text('Completed orders will appear here.'),
              ),
            ),
          ...grouped.entries.map((entry) {
            final docs = entry.value;
            final firstData = docs.first.data();
            final customerName = '${firstData['party'] ?? ''}'.trim();
            final villageName = '${firstData['city'] ?? ''}'.trim();
            final customerDetails = [
              if (customerName.isNotEmpty) 'Customer: $customerName',
              if (villageName.isNotEmpty) 'City/Village: $villageName',
            ].join('  ·  ');
            double total = 0;
            for (final doc in docs) {
              final data = doc.data();
              final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
              final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
              total += qty * price;
            }
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${customerDetails.isEmpty ? 'Customer not specified' : customerDetails}\n${docs.length} item(s)',
                ),
                trailing: Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  ...docs.map((doc) {
                  final data = doc.data();
                  final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
                  final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
                  final mrp = (data['mrp'] as num?)?.toDouble() ?? price;
                  return ListTile(
                    title: Text(productName(data)),
                    subtitle: Text(
                      'Order ID: ${entry.key}\nQty: ${qty.toInt()}  ·  MRP: ₹${mrp.toStringAsFixed(2)}  ·  Price: ₹${price.toStringAsFixed(2)}',
                    ),
                    isThreeLine: true,
                    trailing: Text('₹${(qty * price).toStringAsFixed(2)}'),
                  );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      children: [
                        if (sameDay(selectedDate, DateTime.now())) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editTodayOrder(entry.key, docs),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit order'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _printHistoryBill(
                              context,
                              entry.key,
                              docs,
                            ),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Print order'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    },
  );
}
