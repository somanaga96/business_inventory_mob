import '../../../app_exports.dart';

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key, required this.controller});
  final InventoryController controller;
  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  String query = '', typeFilter = 'All types';
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.controller.transactions,
    builder: (context, snapshot) {
      final allDocs = snapshot.data?.docs ?? [];
      final docs = allDocs.where((d) {
        final m = d.data();
        final text =
            '${m['productName'] ?? ''} ${m['party'] ?? ''} ${m['note'] ?? ''}'
                .toLowerCase();
        return text.contains(query.toLowerCase()) &&
            (typeFilter == 'All types' || '${m['type']}' == typeFilter);
      }).toList();
      return ResponsivePage(
        children: [
          const Text(
            'Transaction history',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Audit trail of every inventory movement.',
            style: TextStyle(color: Color(0xFF8493AD)),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search product, supplier or note…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Transaction type',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const [
                              'All types',
                              'Purchase',
                              'Sale',
                              'Return',
                              'Damage',
                              'Adjustment',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) =>
                        setState(() => typeFilter = v ?? 'All types'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!snapshot.hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            ),
          if (snapshot.hasData && docs.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('No transactions yet'),
                subtitle: Text(
                  'Record your first stock movement from the Transaction tab.',
                ),
              ),
            ),
          ...docs.map((d) {
            final m = d.data();
            final isIn = [
              'Purchase',
              'Return',
              'Stock in',
            ].contains('${m['type']}');
            final timestamp = m['transactionDate'] ?? m['createdAt'];
            final time = timestamp is Timestamp
                ? '${timestamp.toDate().day.toString().padLeft(2, '0')}/${timestamp.toDate().month.toString().padLeft(2, '0')}/${timestamp.toDate().year}'
                : 'Just now';
            final note = (m['note'] ?? '').toString();
            final color = isIn
                ? const Color(0xFF168B57)
                : const Color(0xFFD34C4C);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isIn
                      ? const Color(0xFFDCF8E9)
                      : const Color(0xFFFFE5E5),
                  child: Icon(
                    isIn ? Icons.south_west : Icons.north_east,
                    color: color,
                  ),
                ),
                title: Text(
                  '${m['productName'] ?? 'Product'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${m['type'] ?? 'Adjustment'} · $time${note.isEmpty ? '' : ' · $note'}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIn ? '+' : '-'}${m['quantity'] ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (m['inventoryAfter'] != null)
                      Text(
                        '${m['inventoryAfter']} after',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8493AD),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}
