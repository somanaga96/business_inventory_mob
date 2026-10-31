import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'controllers/inventory_controller.dart';
import 'firebase/firebase_options.dart';
import 'models/product.dart';

const primary = Color(0xFF6256F6), ink = Color(0xFF17213A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  runApp(const InventoryProApp());
}

class InventoryProApp extends StatelessWidget {
  const InventoryProApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'InventoryPro',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    ),
    home: const InventoryHome(),
  );
}

class InventoryHome extends StatefulWidget {
  const InventoryHome({super.key});
  @override
  State<InventoryHome> createState() => _InventoryHomeState();
}

class _InventoryHomeState extends State<InventoryHome> {
  int tab = 0;
  late final InventoryController controller;
  bool firebaseReady = false;
  final sample = const [
    Product(
      id: 'egg',
      name: 'Egg',
      category: 'Other',
      cost: 5,
      quantity: 50,
      minStock: 60,
    ),
    Product(
      id: 'kurkure',
      name: 'Kurkure',
      category: 'Kitchen',
      cost: 4,
      quantity: 50,
    ),
  ];
  @override
  void initState() {
    super.initState();
    controller = InventoryController();
    try {
      FirebaseFirestore.instance;
      firebaseReady = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
    stream: firebaseReady ? controller.products : null,
    builder: (context, snapshot) {
      final products = snapshot.data ?? sample;
      final views = [
        Dashboard(
          products: products,
          showInventory: () => setState(() => tab = 2),
        ),
        Products(products: products, add: addProduct),
        Stock(products: products, adjust: adjust),
        NewTransaction(products: products, submit: recordTransaction),
        TransactionHistory(controller: controller),
        Alerts(products: products),
      ];
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Text(
                  'IP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'InventoryPro',
                style: TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: addProduct,
              icon: const Icon(Icons.add_circle_outline, color: primary),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                const ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primary,
                    child: Text(
                      'IP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    'InventoryPro',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ),
                const Divider(),
                ...[
                  'Overview',
                  'Products',
                  'Inventory',
                  'Transactions',
                  'Transaction history',
                  'Alerts',
                ].asMap().entries.map(
                  (entry) => ListTile(
                    selected: tab == entry.key,
                    selectedTileColor: primary.withValues(alpha: .10),
                    leading: Icon(
                      [
                        Icons.grid_view_rounded,
                        Icons.inventory_2_outlined,
                        Icons.warehouse_outlined,
                        Icons.swap_horiz,
                        Icons.history,
                        Icons.warning_amber_outlined,
                      ][entry.key],
                      color: tab == entry.key ? primary : null,
                    ),
                    title: Text(entry.value),
                    onTap: () {
                      setState(() => tab = entry.key);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(child: views[tab]),
        floatingActionButton: tab == 1 || tab == 2
            ? FloatingActionButton.extended(
                onPressed: addProduct,
                backgroundColor: primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              )
            : null,
      );
    },
  );
  Future<void> addProduct() async {
    final name = TextEditingController(),
        category = TextEditingController(text: 'Other'),
        cost = TextEditingController(),
        qty = TextEditingController(text: '0'),
        min = TextEditingController(text: '10'),
        imageUrl = TextEditingController();
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(c).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add product',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              field(name, 'Product name'),
              field(category, 'Category'),
              field(imageUrl, 'Image URL'),
              Row(
                children: [
                  Expanded(child: field(cost, 'Cost', true)),
                  const SizedBox(width: 12),
                  Expanded(child: field(qty, 'Opening stock', true)),
                ],
              ),
              field(min, 'Low stock level', true),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Save product'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      await controller.addProduct(
        name: name.text.trim(),
        category: category.text.trim(),
        cost: double.tryParse(cost.text) ?? 0,
        quantity: int.tryParse(qty.text) ?? 0,
        threshold: int.tryParse(min.text) ?? 10,
        imageUrl: imageUrl.text,
      );
    }
  }

  Widget field(TextEditingController c, String label, [bool number = false]) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  Future<void> adjust(Product p, int delta) async {
    await controller.adjustStock(p, delta);
  }

  Future<void> recordTransaction(
    Product product,
    int quantity,
    String type,
    double unitPrice,
    String party,
    String note,
    DateTime date,
  ) async {
    if (quantity <= 0) return;
    await controller.recordTransaction(
      product: product,
      quantity: quantity,
      type: type,
      unitPrice: unitPrice,
      party: party,
      note: note,
      date: date,
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.products,
    required this.showInventory,
  });
  final List<Product> products;
  final VoidCallback showInventory;
  @override
  Widget build(BuildContext context) {
    final value = products.fold(0.0, (a, p) => a + p.cost * p.quantity);
    final low = products.where((p) => p.low).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.23,
          children: [
            Metric(
              'Total products',
              '${products.length}',
              Icons.inventory_2_outlined,
              primary,
            ),
            Metric(
              'Inventory value',
              '₹${value.toStringAsFixed(0)}',
              Icons.account_balance_wallet_outlined,
              const Color(0xFF22B573),
            ),
            Metric(
              'Products in stock',
              '${products.where((p) => p.quantity > 0).length}',
              Icons.check_circle_outline,
              const Color(0xFF22B573),
            ),
            Metric(
              'Stock alerts',
              '$low',
              Icons.warning_amber_rounded,
              const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Current inventory',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            TextButton(onPressed: showInventory, child: const Text('View all')),
          ],
        ),
        ...products.take(4).map((p) => ProductTile(product: p)),
      ],
    );
  }
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, this.icon, this.color, {super.key});
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: color.withValues(alpha: .18)),
    ),
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
  );
}

class Products extends StatelessWidget {
  const Products({super.key, required this.products, required this.add});
  final List<Product> products;
  final VoidCallback add;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Products',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: add,
            icon: const Icon(Icons.add_circle, color: primary),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ...products.map((p) => ProductTile(product: p)),
    ],
  );
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: product.low ? const Color(0xFFF4C541) : const Color(0xFFE7EAF2),
      ),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: Container(
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: product.imageUrl == null || product.imageUrl!.isEmpty
            ? const Icon(Icons.inventory_2_outlined, color: primary)
            : Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.inventory_2_outlined, color: primary),
              ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${product.category} · ₹${product.cost.toStringAsFixed(2)} avg. cost',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${product.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(
            product.low ? 'low stock' : 'in stock',
            style: TextStyle(
              fontSize: 12,
              color: product.low
                  ? const Color(0xFFC17700)
                  : const Color(0xFF168B57),
            ),
          ),
        ],
      ),
    ),
  );
}

class Stock extends StatelessWidget {
  const Stock({super.key, required this.products, required this.adjust});
  final List<Product> products;
  final Future<void> Function(Product, int) adjust;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
    children: [
      const Text(
        'Inventory',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'Update quantities as stock moves.',
        style: TextStyle(color: Color(0xFF8493AD)),
      ),
      const SizedBox(height: 18),
      ...products.map(
        (p) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${p.quantity} units available',
                        style: TextStyle(
                          color: p.low
                              ? const Color(0xFFC17700)
                              : const Color(0xFF71809A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => adjust(p, -1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: () => adjust(p, 1),
                  color: primary,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class NewTransaction extends StatefulWidget {
  const NewTransaction({
    super.key,
    required this.products,
    required this.submit,
  });
  final List<Product> products;
  final Future<void> Function(
    Product,
    int,
    String,
    double,
    String,
    String,
    DateTime,
  )
  submit;
  @override
  State<NewTransaction> createState() => _NewTransactionState();
}

class _NewTransactionState extends State<NewTransaction> {
  Product? selected;
  String type = 'Purchase';
  final quantity = TextEditingController();
  final price = TextEditingController();
  final party = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;
  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    party.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = int.tryParse(quantity.text) ?? 0;
    if (selected == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a product and enter a quantity.')),
      );
      return;
    }
    final stockOut = type == 'Sale' || type == 'Damage';
    if (stockOut && amount > selected!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove more than current stock.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.submit(
        selected!,
        amount,
        type,
        double.tryParse(price.text) ?? selected!.cost,
        party.text.trim(),
        note.text.trim(),
        date,
      );
      if (mounted) {
        quantity.clear();
        note.clear();
        party.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction recorded.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
    children: [
      const Text(
        'Transactions',
        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'Every transaction changes inventory automatically.',
        style: TextStyle(color: Color(0xFF8493AD)),
      ),
      const SizedBox(height: 24),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INVENTORY MOVEMENT',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Record transaction',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use Purchase, Sale, Return, Damage or Adjustment.',
                style: TextStyle(color: Color(0xFF8493AD)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Product>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
                items: widget.products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (${p.quantity} available)'),
                      ),
                    )
                    .toList(),
                onChanged: (p) => setState(() => selected = p),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Transaction type',
                  border: OutlineInputBorder(),
                ),
                items:
                    const ['Purchase', 'Sale', 'Return', 'Damage', 'Adjustment']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => type = v ?? 'Purchase'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: type == 'Sale'
                      ? 'Sell price per unit'
                      : 'Buy price per unit',
                  hintText: selected == null
                      ? '0.00'
                      : selected!.cost.toStringAsFixed(2),
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: party,
                decoration: const InputDecoration(
                  labelText: 'Supplier / Party (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (picked != null) setState(() => date = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'Transaction date: ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Supplier, sale, adjustment…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(saving ? 'Saving…' : 'Record $type'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

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
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
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

class Alerts extends StatelessWidget {
  const Alerts({super.key, required this.products});
  final List<Product> products;
  @override
  Widget build(BuildContext context) {
    final alerts = products.where((p) => p.low).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Stock alerts',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        if (alerts.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.check_circle_outline,
                color: Color(0xFF22B573),
              ),
              title: Text('All stock levels look good'),
            ),
          ),
        ...alerts.map(
          (p) => Card(
            color: const Color(0xFFFFF8E7),
            child: ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE59A00),
              ),
              title: Text('${p.name} is running low'),
              subtitle: Text(
                '${p.quantity} left · reorder level ${p.minStock}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
