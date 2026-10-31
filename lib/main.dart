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
        Products(products: products, add: addProduct, edit: editProduct, remove: deleteProduct),
        Stock(products: products, adjust: adjust),
        NewTransaction(products: products, submit: recordTransaction),
        TransactionHistory(controller: controller),
        Bills(products: products, submit: recordTransaction),
        BillsHistory(controller: controller),
        Alerts(products: products, update: editProduct),
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
                  'Bills',
                  'Bills history',
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
                        Icons.receipt_long_outlined,
                        Icons.receipt_long,
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
    String city,
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
      city: city,
      note: note,
      date: date,
    );
  }

  Future<void> editProduct(Product p) async {
    final name = TextEditingController(text: p.name);
    final category = TextEditingController(text: p.category);
    final cost = TextEditingController(text: p.cost.toString());
    final threshold = TextEditingController(text: p.minStock.toString());
    final image = TextEditingController(text: p.imageUrl ?? '');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Edit product'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        field(name, 'Product name'), field(category, 'Category'), field(image, 'Image URL'),
        field(cost, 'Cost', true), field(threshold, 'Low stock level', true),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
    ));
    if (ok == true) await controller.updateProduct(product: p, name: name.text.trim(), category: category.text.trim(), cost: double.tryParse(cost.text) ?? p.cost, threshold: int.tryParse(threshold.text) ?? p.minStock, imageUrl: image.text.trim());
  }

  Future<void> deleteProduct(Product p) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete product?'), content: Text('Remove ${p.name}?'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
    if (ok == true) await controller.deleteProduct(p);
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
  const Products({super.key, required this.products, required this.add, required this.edit, required this.remove});
  final List<Product> products;
  final VoidCallback add;
  final Future<void> Function(Product) edit;
  final Future<void> Function(Product) remove;
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
      ...products.map((p) => ProductTile(product: p, actions: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () => edit(p), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => remove(p), icon: const Icon(Icons.delete_outline, color: Colors.red))]))),
    ],
  );
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.actions});
  final Product product;
  final Widget? actions;
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
      trailing: actions ?? Column(
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
                Container(
                  width: 46,
                  height: 46,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: p.imageUrl == null || p.imageUrl!.isEmpty
                      ? const Icon(Icons.inventory_2_outlined, color: primary)
                      : Image.network(p.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: primary)),
                ),
                const SizedBox(width: 12),
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
    String,
    DateTime,
  )
  submit;
  @override
  State<NewTransaction> createState() => _NewTransactionState();
}

class _NewTransactionState extends State<NewTransaction> {
  Product? selected;
  String type = 'Sale';
  final quantity = TextEditingController();
  final price = TextEditingController();
  final party = TextEditingController();
  final city = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;
  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    party.dispose();
    city.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = int.tryParse(quantity.text) ?? 0;
    final currentProduct = selected == null
        ? null
        : widget.products.where((p) => p.id == selected!.id).firstOrNull;
    if (currentProduct == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a product and enter a quantity.')),
      );
      return;
    }
    final stockOut = type == 'Sale' || type == 'Damage';
    if (stockOut && amount > currentProduct.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove more than current stock.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.submit(
        currentProduct,
        amount,
        type,
        double.tryParse(price.text) ?? currentProduct.cost,
        party.text.trim(),
        city.text.trim(),
        note.text.trim(),
        date,
      );
      if (mounted) {
        quantity.clear();
        note.clear();
        party.clear();
        city.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction recorded.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedValue = selected == null
        ? null
        : widget.products.where((p) => p.id == selected!.id).firstOrNull;
    return ListView(
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
                initialValue: selectedValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
                items: widget.products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: p.imageUrl == null || p.imageUrl!.isEmpty
                                  ? const Icon(
                                      Icons.inventory_2_outlined,
                                      color: primary,
                                      size: 20,
                                    )
                                  : Image.network(
                                      p.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.inventory_2_outlined,
                                        color: primary,
                                        size: 20,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${p.name} (${p.quantity} available)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
              TextField(
                controller: city,
                decoration: const InputDecoration(
                  labelText: 'City / Village (optional)',
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
}

class Bills extends StatefulWidget {
  const Bills({super.key, required this.products, required this.submit});
  final List<Product> products;
  final Future<void> Function(Product, int, String, double, String, String, String, DateTime) submit;
  @override
  State<Bills> createState() => _BillsState();
}

class _BillsState extends State<Bills> {
  Product? product;
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final customer = TextEditingController();
  final city = TextEditingController();
  final cart = <String, int>{};
  final prices = <String, double>{};
  int billSequence = 1;
  late String billNumber;
  static const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String newBillNumber() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}_${months[now.month - 1]}_${now.year}_${billSequence++}';
  }
  @override
  void initState() {
    super.initState();
    billNumber = newBillNumber();
  }
  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    customer.dispose();
    city.dispose();
    super.dispose();
  }
  Product? find(String id) => widget.products.where((p) => p.id == id).firstOrNull;
  double get total => cart.entries.fold(0, (totalValue, e) => totalValue + (prices[e.key] ?? find(e.key)?.cost ?? 0) * e.value);
  Product? get selectedProduct => product == null ? null : find(product!.id);
  void add() {
    final qty = int.tryParse(quantity.text) ?? 0;
    if (product == null || qty <= 0) return;
    final salePrice = double.tryParse(price.text) ?? product!.cost;
    final existing = cart[product!.id] ?? 0;
    if (existing + qty > product!.quantity) return;
    setState(() {
      cart[product!.id] = existing + qty;
      prices[product!.id] = salePrice;
    });
    quantity.text = '1';
    price.clear();
  }
  Future<void> complete() async {
    if (cart.isEmpty) return;
    for (final entry in cart.entries) {
      final p = find(entry.key);
      if (p != null) await widget.submit(p, entry.value, 'Sale', prices[entry.key] ?? p.cost, customer.text.trim(), city.text.trim(), billNumber, DateTime.now());
    }
    if (mounted) {
      await showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text('Bill generated'),
        content: Text('Order: $billNumber\nItems: ${cart.length}\nTotal: ₹${total.toStringAsFixed(2)}\n\nConnect a Bluetooth thermal printer in the device settings, then use Print bill to print this receipt.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')), FilledButton(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thermal printing requires a Bluetooth printer plugin configured for this device.'))); }, child: const Text('Print bill'))],
      ));
      setState(() { cart.clear(); prices.clear(); customer.clear(); billNumber = newBillNumber(); });
    }
  }
  Future<void> printBill() async => showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Print bill'), content: Text('Order $billNumber\nTotal ₹${total.toStringAsFixed(2)}'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect a Bluetooth thermal printer to print this bill.'))); }, child: const Text('Print'))]));
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), children: [
    const Text('Bills', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Add multiple goods to one sale and generate a cumulative bill.', style: TextStyle(color: Color(0xFF8493AD))),
    const SizedBox(height: 18),
    Row(children: [Expanded(child: TextField(controller: customer, decoration: const InputDecoration(labelText: 'Shop / customer name', border: OutlineInputBorder()))), const SizedBox(width: 10), SizedBox(width: 150, child: InputDecorator(decoration: const InputDecoration(labelText: 'Bill no.', border: OutlineInputBorder()), child: Text(billNumber, overflow: TextOverflow.ellipsis))) ]),
    const SizedBox(height: 14),
    TextField(controller: city, decoration: const InputDecoration(labelText: 'City / Village', border: OutlineInputBorder())),
    const SizedBox(height: 14),
    Row(children: [Expanded(child: DropdownButtonFormField<Product>(initialValue: selectedProduct, isExpanded: true, decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()), items: widget.products.map((p) => DropdownMenuItem(value: p, child: Row(children: [Container(width: 34, height: 34, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)), child: p.imageUrl == null || p.imageUrl!.isEmpty ? const Icon(Icons.inventory_2_outlined, color: primary, size: 19) : Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: primary, size: 19))), const SizedBox(width: 10), Expanded(child: Text('${p.name} (${p.quantity})', overflow: TextOverflow.ellipsis))]))).toList(), onChanged: (v) => setState(() => product = v))), const SizedBox(width: 10), SizedBox(width: 82, child: TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()))) ]),
    const SizedBox(height: 10),
    TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Sale price per unit', hintText: selectedProduct == null ? 'Enter price' : selectedProduct!.cost.toStringAsFixed(2), prefixText: '₹ ', border: const OutlineInputBorder())),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add item')),
    const SizedBox(height: 14),
    ...cart.entries.map((e) { final p = find(e.key)!; final salePrice = prices[e.key] ?? p.cost; return ListTile(title: Text(p.name), subtitle: Text('${e.value} × ₹${salePrice.toStringAsFixed(2)}'), trailing: Text('₹${(e.value * salePrice).toStringAsFixed(2)}')); }),
    const Divider(),
    Align(alignment: Alignment.centerRight, child: Text('Total ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: cart.isEmpty ? null : printBill, icon: const Icon(Icons.print_outlined), label: const Text('Print bill'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: cart.isEmpty ? null : complete, icon: const Icon(Icons.receipt_long), label: const Text('Complete sale')))]),
  ]);
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

class BillsHistory extends StatefulWidget {
  const BillsHistory({super.key, required this.controller});
  final InventoryController controller;
  @override
  State<BillsHistory> createState() => _BillsHistoryState();
}

class _BillsHistoryState extends State<BillsHistory> {
  DateTime selectedDate = DateTime.now();
  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String dateLabel(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.controller.transactions,
    builder: (context, snapshot) {
      final grouped = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
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
      var itemCount = 0;
      for (final docs in grouped.values) {
        for (final doc in docs) {
          final data = doc.data();
          final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
          final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
          itemCount += qty.toInt();
          dailySales += qty * price;
        }
      }
      final averageBill = grouped.isEmpty ? 0 : dailySales / grouped.length;
      return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), children: [
        const Text('Bills history', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Daily cumulative bills and their item details.', style: TextStyle(color: Color(0xFF8493AD))),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: selectedDate); if (picked != null) setState(() => selectedDate = picked); }, icon: const Icon(Icons.calendar_today_outlined), label: Text('Showing ${dateLabel(selectedDate)}'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _BillSummaryCard(label: 'Total sales', value: '₹${dailySales.toStringAsFixed(2)}', icon: Icons.currency_rupee, color: const Color(0xFF168B57)),
            _BillSummaryCard(label: 'Bills', value: '${grouped.length}', icon: Icons.receipt_long_outlined, color: primary),
            _BillSummaryCard(label: 'Items sold', value: '$itemCount', icon: Icons.inventory_2_outlined, color: const Color(0xFFF59E0B)),
            _BillSummaryCard(label: 'Average bill', value: '₹${averageBill.toStringAsFixed(2)}', icon: Icons.analytics_outlined, color: const Color(0xFF7C55C7)),
          ],
        ),
        const SizedBox(height: 18),
        if (!snapshot.hasData) const Center(child: CircularProgressIndicator()),
        if (snapshot.hasData && grouped.isEmpty) const Card(child: ListTile(leading: Icon(Icons.receipt_long_outlined), title: Text('No bills for this date'), subtitle: Text('Completed bills will appear here.'))),
        ...grouped.entries.map((entry) {
          final docs = entry.value;
          double total = 0;
          for (final doc in docs) { final data = doc.data(); final qty = (data['quantity'] as num?)?.toDouble() ?? 0; final price = (data['unitPrice'] as num?)?.toDouble() ?? 0; total += qty * price; }
          return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), child: ExpansionTile(title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${docs.length} item(s)'), trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)), children: docs.map((doc) { final data = doc.data(); final qty = (data['quantity'] as num?)?.toDouble() ?? 0; final price = (data['unitPrice'] as num?)?.toDouble() ?? 0; return ListTile(title: Text('${data['productName'] ?? 'Product'}'), subtitle: Text('${qty.toInt()} × ₹${price.toStringAsFixed(2)}'), trailing: Text('₹${(qty * price).toStringAsFixed(2)}')); }).toList()));
        }),
      ]);
    },
  );
}

class _BillSummaryCard extends StatelessWidget {
  const _BillSummaryCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: .20))),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: color, size: 21),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        Text(label, style: const TextStyle(color: Color(0xFF8493AD), fontSize: 12)),
      ]),
    ),
  );
}

class Alerts extends StatelessWidget {
  const Alerts({super.key, required this.products, required this.update});
  final List<Product> products;
  final Future<void> Function(Product) update;
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
              trailing: IconButton(onPressed: () => update(p), icon: const Icon(Icons.edit_outlined)),
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
