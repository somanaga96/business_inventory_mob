import '../../../app_exports.dart';

class CumulativeHistoryPage extends StatefulWidget {
  const CumulativeHistoryPage({super.key, required this.controller, required this.products});
  final InventoryController controller;
  final List<Product> products;

  String name(String id, Map<String, dynamic> data) {
    for (final product in products) {
      if (product.id == id) return product.name;
    }
    return '${data['productName'] ?? 'Product'}';
  }

  @override
  State<CumulativeHistoryPage> createState() => _CumulativeHistoryPageState();
}

class _CumulativeHistoryPageState extends State<CumulativeHistoryPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.controller.transactions,
    builder: (context, snapshot) {
      final grouped = <String, Map<String, ({int quantity, double value})>>{};
      for (final doc in snapshot.data?.docs ?? []) {
        final data = doc.data();
        final stamp = data['transactionDate'] ?? data['createdAt'];
        if (stamp is! Timestamp) continue;
        final date = stamp.toDate();
        if (date.year != month.year || date.month != month.month) continue;
        if ('${data['type'] ?? ''}'.toLowerCase() != 'sale') continue;
        final key = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
        final product = widget.name('${data['productId']}', data);
        final keyProduct = product;
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
        final old = grouped.putIfAbsent(key, () => {})[keyProduct];
        grouped[key]![keyProduct] = (quantity: (old?.quantity ?? 0) + quantity, value: (old?.value ?? 0) + quantity * price);
      }
      final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      return ResponsivePage(children: [
        const Text('Cumulative history', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Daily totals grouped by product.', style: TextStyle(color: Color(0xFF8493AD))),
        Row(children: [
          IconButton.outlined(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: OutlinedButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: month, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (picked != null) setState(() => month = DateTime(picked.year, picked.month)); }, icon: const Icon(Icons.calendar_month), label: Text('${month.month}/${month.year}'))),
          IconButton.outlined(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 12),
        if (dates.isEmpty) const Card(child: ListTile(title: Text('No transactions found.'))),
        ...dates.map((date) => Card(child: ExpansionTile(title: Text(date, style: const TextStyle(fontWeight: FontWeight.w800)), initiallyExpanded: true, children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Quantity')), DataColumn(label: Text('Amount'))],
            rows: grouped[date]!.entries.map((e) => DataRow(cells: [DataCell(Text(e.key)), DataCell(Text('${e.value.quantity}')), DataCell(Text('Rs ${e.value.value.toStringAsFixed(2)}'))])).toList(),
          )),
        ]))),
      ]);
    },
  );
}
