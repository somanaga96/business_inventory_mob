import '../../../app_exports.dart';

class Dashboard extends StatelessWidget {
  /*
  const Dashboard({
    super.key,
    required this.products,
    required this.openTab,
  });
  final List<Product> products;
  final ValueChanged<int> openTab;
  @override
  Widget build(BuildContext context) {
    final value = products.fold(0.0, (a, p) => a + p.cost * p.quantity);
    final low = products.where((p) => p.low).length;
    return ResponsivePage(
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        Text(
          '${products.length} products · ${products.length} inventory records',
          style: const TextStyle(color: Color(0xFF8493AD), fontSize: 16),
        ),
        const SizedBox(height: 24),
        DashboardCard(
          title: 'Inventory',
          subtitle: 'View and manage your stock',
          icon: Icons.inventory_2_outlined,
          color: primary,
          onTap: () => openTab(2),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DashboardPill(label: '${products.length} products'),
              DashboardPill(label: '₹${value.toStringAsFixed(0)} value'),
              DashboardPill(label: '${products.where((p) => p.quantity > 0).length} in stock'),
              DashboardPill(label: '$low alerts', color: low == 0 ? const Color(0xFF168B57) : const Color(0xFFC17700)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DashboardCard(
          title: 'Bills',
          subtitle: 'Create a sale or review completed bills',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFF22B573),
          onTap: () => openTab(5),
          child: Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => openTab(5), icon: const Icon(Icons.add), label: const Text('New bill'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => openTab(6), icon: const Icon(Icons.history), label: const Text('History'))),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => openTab(3), icon: const Icon(Icons.swap_horiz), label: const Text('Stock movement'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => openTab(4), icon: const Icon(Icons.history), label: const Text('Purchase history'))),
        ]),

      ],
    );
  }
}

  */
  const Dashboard({
    super.key,
    required this.products,
    required this.controller,
    required this.openTab,
  });

  final List<Product> products;
  final InventoryController controller;
  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final value = products.fold(
      0.0,
      (total, product) => total + product.cost * product.quantity,
    );
    final inStock = products.where((product) => product.quantity > 0).length;
    final lowStock = products.where((product) => product.low).length;
    return ResponsivePage(
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        Text(
          '${products.length} products',
          style: const TextStyle(color: Color(0xFF8493AD), fontSize: 16),
        ),
        const SizedBox(height: 24),
        BillsOverviewCard(controller: controller, openBills: () => openTab(6)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            Metric(
              'Total products',
              '${products.length}',
              Icons.inventory_2_outlined,
              primary,
              onTap: () => openTab(1),
            ),
            InventorySummaryMetric(value: value, onTap: () => openTab(2)),
            Metric(
              'Products in stock',
              '$inStock',
              Icons.check_circle_outline,
              const Color(0xFF22B573),
              onTap: () => openTab(2),
            ),
            Metric(
              'Stock alerts',
              '$lowStock',
              Icons.warning_amber_rounded,
              const Color(0xFFF59E0B),
              onTap: () => openTab(7),
            ),
          ],
        ),
      ],
    );
  }
}

class BillsOverviewCard extends StatefulWidget {
  const BillsOverviewCard({
    super.key,
    required this.controller,
    required this.openBills,
  });

  final InventoryController controller;
  final VoidCallback openBills;

  @override
  State<BillsOverviewCard> createState() => _BillsOverviewCardState();
}

class _BillsOverviewCardState extends State<BillsOverviewCard> {
  DateTime selectedDate = DateTime.now();

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.controller.transactionsForDate(selectedDate),
        builder: (context, snapshot) {
          final billPattern = RegExp(r'^\d{2}_[A-Z][a-z]{2}_\d{4}_\d+$');
          final bills = <String>{};
          var totalValue = 0.0;
          for (final doc in snapshot.data?.docs ?? []) {
            final data = doc.data();
            final billNumber = data['note']?.toString() ?? '';
            if (!billPattern.hasMatch(billNumber)) continue;
            bills.add(billNumber);
            final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
            final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
            totalValue += quantity * price;
          }
          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: primary.withValues(alpha: .22)),
            ),
            child: InkWell(
              onTap: widget.openBills,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bills summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => selectedDate = date);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_dateLabel(selectedDate)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _BillMetric(
                            label: 'Bills',
                            value: '${bills.length}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BillMetric(
                            label: 'Total value',
                            value: 'Rs ${totalValue.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _BillMetric extends StatelessWidget {
  const _BillMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: primary.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7C8AA3)),
        ),
      ],
    ),
  );
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: color.withValues(alpha: .22)),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF7C8AA3)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

class DashboardPill extends StatelessWidget {
  const DashboardPill({super.key, required this.label, this.color = primary});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class InventorySummaryMetric extends StatelessWidget {
  const InventorySummaryMetric({
    super.key,
    required this.value,
    required this.onTap,
  });

  final double value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    color: primary.withValues(alpha: .035),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: primary.withValues(alpha: .18)),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: primary),
            const Spacer(),
            Text(
              'Rs ${value.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const Text(
              'Inventory',
              style: TextStyle(fontSize: 12, color: Color(0xFF7C8AA3)),
            ),
          ],
        ),
      ),
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(
    this.label,
    this.value,
    this.icon,
    this.color, {
    super.key,
    this.onTap,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    color: color.withValues(alpha: .035),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: color.withValues(alpha: .18)),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C8AA3)),
            ),
          ],
        ),
      ),
    ),
  );
}
