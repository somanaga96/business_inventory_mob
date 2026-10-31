import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'firebase/firebase_options.dart';
import 'features/alerts/presentation/alerts_page.dart';
import 'features/bills/presentation/bills_history_page.dart';
import 'features/bills/presentation/bills_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/inventory/application/controllers/inventory_controller.dart';
import 'features/inventory/domain/models/product.dart';
import 'features/inventory/presentation/stock_page.dart';
import 'features/products/presentation/products_page.dart';
import 'features/reports/presentation/business_summary_page.dart';
import 'features/purchases/presentation/purchase_history_page.dart';
import 'features/purchases/presentation/purchase_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  runApp(const InventoryProApp());
}

class InventoryProApp extends StatefulWidget {
  const InventoryProApp({super.key});

  @override
  State<InventoryProApp> createState() => _InventoryProAppState();
}

class _InventoryProAppState extends State<InventoryProApp> {
  ThemeMode themeMode = ThemeMode.system;

  void toggleTheme() {
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && systemBrightness == Brightness.dark);
    setState(() => themeMode = isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'InventoryPro',
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: buildAppTheme(Brightness.light),
    darkTheme: buildAppTheme(Brightness.dark),
    home: InventoryHome(onToggleTheme: toggleTheme),
  );
}

class InventoryHome extends StatefulWidget {
  const InventoryHome({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
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
      final screenWidth = MediaQuery.sizeOf(context).width;
      final screenHeight = MediaQuery.sizeOf(context).height;
      final billButtonWidth = screenWidth * .90;
      final billButtonHeight = screenHeight * .07;
      final views = [
        Dashboard(
          products: products,
          controller: controller,
          openTab: (index) => setState(() => tab = index),
        ),
        Products(
          products: products,
          add: addProduct,
          edit: editProduct,
          remove: deleteProduct,
        ),
        Stock(products: products, adjust: adjust),
        PurchasePage(products: products, submit: recordTransaction),
        PurchaseHistoryPage(controller: controller),
        Bills(
          products: products,
          submit: recordTransaction,
          controller: controller,
        ),
        BillsHistory(controller: controller),
        Alerts(products: products, update: editProduct, remove: deleteProduct),
        BusinessSummary(controller: controller),
      ];
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surface,
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
              Text(
                'InventoryPro',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: Theme.of(context).brightness == Brightness.dark
                  ? 'Use light theme'
                  : 'Use dark theme',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: primary,
              ),
            ),
            IconButton(
              tooltip: 'Home',
              onPressed: tab == 0 ? null : () => setState(() => tab = 0),
              icon: const Icon(Icons.home_outlined, color: primary),
            ),
            if (tab != 5)
              IconButton(
                tooltip: 'Add bill',
                onPressed: openNewBill,
                icon: const Icon(Icons.receipt_long_outlined, color: primary),
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
                  'Purchase',
                  'Purchase history',
                  'Bills',
                  'Bills history',
                  'Alerts',
                  'Business summary',
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
                        Icons.insights_outlined,
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
        floatingActionButton: tab == 5
            ? null
            : SizedBox(
                width: billButtonWidth,
                height: billButtonHeight,
                child: FloatingActionButton.extended(
                  tooltip: 'Add bill',
                  onPressed: openNewBill,
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Add bill'),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    },
  );

  void openNewBill() => setState(() => tab = 5);

  Future<void> addProduct() async {
    final name = TextEditingController(),
        category = TextEditingController(text: 'Other'),
        min = TextEditingController(text: '10'),
        imageUrl = TextEditingController();
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final screenWidth = MediaQuery.sizeOf(c).width;
        final screenHeight = MediaQuery.sizeOf(c).height;
        final horizontalInset = screenWidth * .05;
        final verticalInset = screenHeight * .03;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            verticalInset,
            horizontalInset,
            MediaQuery.viewInsetsOf(c).bottom + verticalInset,
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
        );
      },
    );
    if (save == true && name.text.trim().isNotEmpty) {
      await controller.addProduct(
        name: name.text.trim(),
        category: category.text.trim(),
        cost: 0,
        quantity: 0,
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(name, 'Product name'),
              field(category, 'Category'),
              field(image, 'Image URL'),
              field(cost, 'Cost', true),
              field(threshold, 'Low stock level', true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.updateProduct(
        product: p,
        name: name.text.trim(),
        category: category.text.trim(),
        cost: double.tryParse(cost.text) ?? p.cost,
        threshold: int.tryParse(threshold.text) ?? p.minStock,
        imageUrl: image.text.trim(),
      );
    }
  }

  Future<void> deleteProduct(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove ${p.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteProduct(p);
  }
}
