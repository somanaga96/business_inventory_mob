import '../../../app_exports.dart';

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
                      onPressed: () => _showExportOptions(context),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _showExportOptions(context, printOnly: true),
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

  void _showExportOptions(BuildContext context, {bool printOnly = false}) {
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
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'PDF export will use the selected date range.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export Excel'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Excel export will use the selected date range.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Export CSV'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'CSV export will use the selected date range.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
