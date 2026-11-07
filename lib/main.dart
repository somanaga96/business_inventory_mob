import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'core/theme/app_theme.dart';
import 'core/services/thermal_receipt_printer.dart';
import 'firebase/firebase_options.dart';
import 'features/alerts/presentation/alerts_page.dart';
import 'features/bills/presentation/bills_history_page.dart';
import 'features/bills/presentation/bills_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/history/presentation/history_page.dart';
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

enum UserRole { admin, sales }

class AppUser {
  const AppUser({required this.username, required this.role});

  final String username;
  final UserRole role;
}

class InventoryProApp extends StatefulWidget {
  const InventoryProApp({super.key});

  @override
  State<InventoryProApp> createState() => _InventoryProAppState();
}

class _InventoryProAppState extends State<InventoryProApp> {
  ThemeMode themeMode = ThemeMode.system;
  AppUser? currentUser;

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
    title: 'Inventory',
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: buildAppTheme(Brightness.light),
    darkTheme: buildAppTheme(Brightness.dark),
    home: currentUser == null
        ? LoginPage(onLogin: (user) => setState(() => currentUser = user))
        : InventoryHome(
            user: currentUser!,
            onToggleTheme: toggleTheme,
            onLogout: () => setState(() => currentUser = null),
          ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final ValueChanged<AppUser> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final user = switch ((username, password)) {
      ('admin', 'admin123') =>
        const AppUser(username: 'admin', role: UserRole.admin),
      ('sales', 'sales567') =>
        const AppUser(username: 'sales', role: UserRole.sales),
      _ => null,
    };
    if (user == null) {
      setState(() => error = 'Invalid username or password.');
      return;
    }
    widget.onLogin(user);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: primary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'InventoryPro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onSubmitted: (_) => login(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: login,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class InventoryHome extends StatefulWidget {
  const InventoryHome({
    super.key,
    required this.user,
    required this.onToggleTheme,
    required this.onLogout,
  });
  final AppUser user;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  @override
  State<InventoryHome> createState() => _InventoryHomeState();
}

class _InventoryHomeState extends State<InventoryHome> {
  int tab = 0;
  ProductNameLanguage productLanguage = ProductNameLanguage.english;
  late final InventoryController controller;
  bool firebaseReady = false;
  bool productNumberMigrationStarted = false;
  final sample = const [
    Product(
      id: 'egg',
      name: 'Egg',
      tamilName: 'முட்டை',
      marathiName: 'अंडे',
      category: 'Other',
      cost: 5,
      quantity: 50,
      minStock: 60,
    ),
    Product(
      id: 'kurkure',
      name: 'Kurkure',
      tamilName: 'குர்குரே',
      marathiName: 'कुरकुरे',
      category: 'Kitchen',
      cost: 4,
      quantity: 50,
    ),
  ];
  @override
  void initState() {
    super.initState();
    productLanguage = widget.user.role == UserRole.sales
        ? ProductNameLanguage.marathi
        : ProductNameLanguage.tamil;
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
      if (firebaseReady &&
          snapshot.hasData &&
          !productNumberMigrationStarted &&
          products.any((product) => product.productNumber == null)) {
        productNumberMigrationStarted = true;
        controller.assignMissingProductNumbers(products).catchError((_) {
          productNumberMigrationStarted = false;
        });
      }
      final isSalesUser = widget.user.role == UserRole.sales;
      if (isSalesUser) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Orders'),
            actions: [
              IconButton(
                tooltip: 'Logout',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primary,
                      child: Icon(Icons.person_outline, color: Colors.white),
                    ),
                    title: Text(
                      'Sales account',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('Orders only'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: const Text('Product name language'),
                    trailing: DropdownButton<ProductNameLanguage>(
                      value: productLanguage,
                      underline: const SizedBox.shrink(),
                      items: ProductNameLanguage.values
                          .map(
                            (language) => DropdownMenuItem(
                              value: language,
                              child: Text(language.label),
                            ),
                          )
                          .toList(),
                      onChanged: (language) {
                        if (language != null) {
                          setState(() => productLanguage = language);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                    title: const Text('Dark theme'),
                    trailing: Switch(
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged: (_) => widget.onToggleTheme(),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: widget.onLogout,
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Bills(
              products: products,
              submit: recordTransaction,
              controller: controller,
              language: productLanguage,
              showLastCompletedOrder: true,
            ),
          ),
        );
      }
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
          language: productLanguage,
        ),
        Stock(products: products, adjust: adjust, language: productLanguage),
        PurchasePage(
          products: products,
          submit: recordTransaction,
          language: productLanguage,
        ),
        PurchaseHistoryPage(controller: controller),
        Bills(
          products: products,
          submit: recordTransaction,
          controller: controller,
          language: productLanguage,
        ),
        BillsHistory(
          controller: controller,
          products: products,
          language: productLanguage,
        ),
        Alerts(products: products, language: productLanguage),
        BusinessSummary(controller: controller),
        HistoryPage(controller: controller),
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
              tooltip: 'Home',
              onPressed: tab == 0 ? null : () => setState(() => tab = 0),
              icon: const Icon(Icons.home_outlined, color: primary),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, color: primary),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
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
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Product name language'),
                  trailing: DropdownButton<ProductNameLanguage>(
                    value: productLanguage,
                    underline: const SizedBox.shrink(),
                    items: ProductNameLanguage.values
                        .map(
                          (language) => DropdownMenuItem(
                            value: language,
                            child: Text(language.label),
                          ),
                        )
                        .toList(),
                    onChanged: (language) {
                      if (language != null) {
                        setState(() => productLanguage = language);
                      }
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                  title: const Text('Dark theme'),
                  trailing: Switch(
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (_) => widget.onToggleTheme(),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bluetooth_searching),
                  title: const Text('Change printer'),
                  subtitle: const Text('Choose a different printer on the next print.'),
                  onTap: () {
                    ThermalReceiptPrinter.resetPrinter();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Printer selection cleared.'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup products'),
                  subtitle: const Text('Export products as JSON'),
                  onTap: exportBackup,
                ),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore products'),
                  subtitle: const Text('Add missing products from JSON'),
                  onTap: restoreProducts,
                ),
                const Divider(),
                ...[
                  'Overview',
                  'Products',
                  'Inventory',
                  'Purchase',
                  'Purchase history',
                  'Orders',
                  'Order history',
                  'Alerts',
                  'Business summary',
                  'History',
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
                        Icons.history_outlined,
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
        floatingActionButton: tab == 1 || tab == 3 || tab == 5 || tab == 8 || tab == 9
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

  Future<void> exportBackup() async {
    try {
      final backup = await controller.createBackup();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(backup))),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: ['inventorypro_backup_$stamp.json'],
        ),
      );
    } catch (_) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the backup. Check your Firestore access.')),
        );
      }
    }
  }

  Future<void> restoreProducts() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final bytes = picked.isEmpty ? null : await picked.first.readAsBytes();
      if (bytes == null) return;
      final decoded = jsonDecode(utf8.decode(bytes));
      final collections = decoded is Map ? decoded['collections'] : null;
      final inventory = collections is Map ? collections['inventory'] : null;
      if (inventory is! List) throw const FormatException('Not an InventoryPro product backup.');
      final products = inventory
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore products?'),
          content: Text(
            '${products.length} product records found. Existing products will be skipped and never overwritten.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restore')),
          ],
        ),
      );
      if (confirm != true) return;
      final restored = await controller.restoreMissingProducts(products);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$restored new product${restored == 1 ? '' : 's'} restored. Existing products were skipped.')),
        );
      }
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not restore products. Check the JSON file and Firestore access.')),
        );
      }
    }
  }

  Future<void> addProduct() async {
    final name = TextEditingController(),
        tamilName = TextEditingController(),
        marathiName = TextEditingController(),
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
                field(name, 'Product name (English)'),
                field(tamilName, 'Product name (Tamil)'),
                field(marathiName, 'Product name (Marathi)'),
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
        tamilName: tamilName.text,
        marathiName: marathiName.text,
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
    final tamilName = TextEditingController(text: p.tamilName ?? '');
    final marathiName = TextEditingController(text: p.marathiName ?? '');
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
              field(name, 'Product name (English)'),
              field(tamilName, 'Product name (Tamil)'),
              field(marathiName, 'Product name (Marathi)'),
              field(category, 'Category'),
              field(image, 'Image URL'),
              field(cost, 'Price', true),
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
        tamilName: tamilName.text,
        marathiName: marathiName.text,
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
