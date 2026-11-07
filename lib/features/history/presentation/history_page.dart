import '../../../app_exports.dart';

/// One place to review every stock and sales movement.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.controller});

  final InventoryController controller;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  String filter = 'All';

  DateTime? _when(Map<String, dynamic> data) {
    final value = data['transactionDate'] ?? data['createdAt'];
    return value is Timestamp ? value.toDate() : null;
  }

  String _type(Map<String, dynamic> data) =>
      '${data['type'] ?? data['recordType'] ?? ''}'.trim().toLowerCase();

  String _label(Map<String, dynamic> data) {
    switch (_type(data)) {
      case 'purchase':
        return 'Purchase';
      case 'sale':
        return 'Order';
      case 'damage':
        return 'Damage';
      case 'stolen':
        return 'Stolen';
      case 'adjustment':
        return 'Adjustment';
      default:
        return 'Stock movement';
    }
  }

  bool _matches(Map<String, dynamic> data) => switch (filter) {
    'Purchases' => _type(data) == 'purchase',
    'Orders' => _type(data) == 'sale',
    'Damage' => _type(data) == 'damage',
    'Stolen' => _type(data) == 'stolen',
    'Adjustments' => _type(data) == 'adjustment',
    _ => true,
  };

  IconData _icon(Map<String, dynamic> data) => switch (_type(data)) {
    'purchase' => Icons.add_shopping_cart_outlined,
    'sale' => Icons.receipt_long_outlined,
    'damage' => Icons.broken_image_outlined,
    'stolen' => Icons.lock_outline,
    'adjustment' => Icons.tune_outlined,
    _ => Icons.swap_horiz,
  };

  Color _color(Map<String, dynamic> data) => switch (_type(data)) {
    'purchase' => const Color(0xFF168B57),
    'sale' => primary,
    'damage' => const Color(0xFFD34C4C),
    'stolen' => const Color(0xFF8B5A2B),
    'adjustment' => Colors.blueGrey,
    _ => Colors.blueGrey,
  };

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  String _shortDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')}_${months[date.month - 1]}';
  }

  String _movementSymbol(Map<String, dynamic> data) => switch (_type(data)) {
    'purchase' || 'adjustment' => '+',
    _ => '−',
  };

  Future<void> _pickDate(bool isFrom) async {
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

  double _price(Map<String, dynamic> data) =>
      ((data['unitPrice'] ?? data['buyPrice']) as num?)?.toDouble() ?? 0;

  int _quantity(Map<String, dynamic> data) =>
      (data['quantity'] as num?)?.toInt() ?? 0;

  Future<void> _export(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
  ) async {
    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Product', 'Quantity', 'Unit value', 'Total', 'Party', 'City/Village', 'Note'],
      ...entries.map((doc) {
        final data = doc.data();
        final quantity = _quantity(data);
        final price = _price(data);
        final date = _when(data);
        return [
          date == null ? '' : _date(date),
          _label(data),
          '${data['productName'] ?? ''}',
          quantity,
          price,
          quantity * price,
          '${data['party'] ?? ''}',
          '${data['city'] ?? ''}',
          '${data['note'] ?? ''}',
        ];
      }),
    ];
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(Uint8List.fromList(utf8.encode(csv.encode(rows))), mimeType: 'text/csv')],
        fileNameOverrides: ['inventory_history.csv'],
      ),
    );
  }

  Future<void> _print(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
  ) async {
    final generator = Generator(
      ThermalReceiptPrinter.paperSize,
      await CapabilityProfile.load(),
    );
    final bytes = <int>[];
    var purchaseTotal = 0.0;
    var orderTotal = 0.0;
    var lossTotal = 0.0;
    bytes.addAll(generator.text('INVENTORYPRO', styles: ThermalReceiptPrinter.centerBoldStyle));
    bytes.addAll(generator.text('HISTORY REPORT', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(generator.row([
      PosColumn(
        text: 'FROM ${_date(from)}',
        width: 6,
        styles: ThermalReceiptPrinter.normalStyle,
      ),
      PosColumn(
        text: 'TO ${_date(to)}',
        width: 6,
        styles: ThermalReceiptPrinter.rightStyle,
      ),
    ]));
    bytes.addAll(generator.text('CATEGORY: $filter', styles: ThermalReceiptPrinter.centerStyle));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: '+/- | PRODUCT', width: 6, styles: ThermalReceiptPrinter.boldStyle),
      PosColumn(text: 'QTY x PRICE = AMOUNT', width: 6, styles: ThermalReceiptPrinter.rightStyle),
    ]));
    bytes.addAll(generator.hr());
    for (final doc in entries) {
      final data = doc.data();
      final quantity = _quantity(data);
      final price = _price(data);
      final total = quantity * price;
      switch (_type(data)) {
        case 'purchase':
          purchaseTotal += total;
          break;
        case 'sale':
          orderTotal += total;
          break;
        case 'damage':
        case 'stolen':
          lossTotal += total;
          break;
      }
      bytes.addAll(await ThermalReceiptPrinter.receiptItemRow(
        generator,
        name: '${_movementSymbol(data)} | ${data['productName'] ?? 'Product'}',
        amount: '$quantity × ${price.toStringAsFixed(2)} = ${total.toStringAsFixed(2)}',
      ));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(
        text: 'ENTRIES: ${entries.length}',
        width: 5,
        styles: ThermalReceiptPrinter.boldStyle,
      ),
      PosColumn(
        text: purchaseTotal > 0 ? '+ ${purchaseTotal.toStringAsFixed(2)}' : '',
        width: 7,
        styles: ThermalReceiptPrinter.rightStyle,
      ),
    ]));
    final stockOutTotal = orderTotal + lossTotal;
    if (stockOutTotal > 0) {
      bytes.addAll(generator.text('- ${stockOutTotal.toStringAsFixed(2)}', styles: ThermalReceiptPrinter.rightStyle));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.feed(3));
    bytes.addAll([0x1D, 0x56, 0x01]);
    if (mounted) await ThermalReceiptPrinter.print(context, bytes);
  }

  Future<void> _printWithFeedback(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
  ) async {
    try {
      await _print(entries);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare the history print: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.controller.transactionsForRange(from, to),
    builder: (context, snapshot) {
      final entries = (snapshot.data?.docs ?? [])
          .where((doc) => _matches(doc.data()))
          .toList()
        ..sort((a, b) => (_when(b.data()) ?? DateTime(0)).compareTo(_when(a.data()) ?? DateTime(0)));
      final byDate = <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final entry in entries) {
        final value = _when(entry.data()) ?? DateTime.now();
        final day = DateTime(value.year, value.month, value.day);
        byDate.putIfAbsent(day, () => []).add(entry);
      }
      return ResponsivePage(
        horizontalPaddingFactor: .015,
        children: [
          const Text('History', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Purchases, orders, damage, and stolen stock in one place.'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.calendar_today_outlined), label: Text('From ${_date(from)}'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.calendar_today_outlined), label: Text('To ${_date(to)}'))),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: const ['All', 'Purchases', 'Orders', 'Damage', 'Stolen', 'Adjustments']
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => setState(() => filter = value ?? 'All'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: entries.isEmpty ? null : () => _export(entries),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: entries.isEmpty ? null : () => _printWithFeedback(entries),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!snapshot.hasData) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          if (snapshot.hasError) const Card(child: ListTile(leading: Icon(Icons.error_outline), title: Text('Unable to load history.'))),
          if (snapshot.hasData && entries.isEmpty) const Card(child: ListTile(leading: Icon(Icons.history_outlined), title: Text('No matching history'), subtitle: Text('Try a different date range or category.'))),
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
                    children: const [
                      _HistoryTableCell('+/-', header: true, right: true),
                      _HistoryTableCell('Product', header: true),
                      _HistoryTableCell('Qty', header: true, right: true),
                      _HistoryTableCell('Price', header: true, right: true),
                      _HistoryTableCell('Amount', header: true, right: true),
                    ],
                  ),
                  ...entry.value.map((doc) {
                    final data = doc.data();
                    final quantity = _quantity(data);
                    final price = _price(data);
                    return TableRow(children: [
                      _HistoryTableCell(_movementSymbol(data), right: true),
                      _HistoryTableCell('${data['productName'] ?? 'Product'}'),
                      _HistoryTableCell('$quantity', right: true),
                      _HistoryTableCell(price.toStringAsFixed(2), right: true),
                      _HistoryTableCell((quantity * price).toStringAsFixed(2), right: true),
                    ]);
                  }),
                ],
              ),
            ),
          ])),
          ...const <QueryDocumentSnapshot<Map<String, dynamic>>>[].map((doc) {
            final data = doc.data();
            final quantity = _quantity(data);
            final price = _price(data);
            final date = _when(data);
            final note = '${data['note'] ?? ''}'.trim();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: _color(data).withValues(alpha: .14), child: Icon(_icon(data), color: _color(data))),
                title: Text('${_label(data)}: ${data['productName'] ?? 'Product'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${date == null ? '-' : _date(date)} · Qty $quantity${note.isEmpty ? '' : ' · $note'}'),
                trailing: Text('Rs ${(quantity * price).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            );
          }),
        ],
      );
    },
  );
}

class _HistoryTableCell extends StatelessWidget {
  const _HistoryTableCell(this.value, {this.header = false, this.right = false});

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
