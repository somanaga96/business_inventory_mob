import '../../../app_exports.dart';

class Bills extends StatefulWidget {
  const Bills({
    super.key,
    required this.products,
    required this.submit,
    required this.controller,
    required this.language,
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
  final InventoryController controller;
  final ProductNameLanguage language;
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
  bool billNumberReady = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? billSubscription;
  static const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String datePrefix(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}_${months[date.month - 1]}_${date.year}';

  String billNumberFor(DateTime date, int sequence) =>
      '${datePrefix(date)}_$sequence';

  @override
  void initState() {
    super.initState();
    billNumber = '${datePrefix(DateTime.now())}_…';
    _loadInitialBillNumber();
    billSubscription = widget.controller.transactions.listen((snapshot) {
      final today = DateTime.now();
      final prefix = datePrefix(today);
      final pattern = RegExp('^${RegExp.escape(prefix)}_(\\d+)\$');
      var highest = 0;
      for (final doc in snapshot.docs) {
        final match = pattern.firstMatch(doc.data()['note']?.toString() ?? '');
        final number = int.tryParse(match?.group(1) ?? '') ?? 0;
        if (number > highest) highest = number;
      }
      final nextSequence = highest + 1;
      final nextBillNumber = billNumberFor(today, nextSequence);
      if (mounted && billNumberReady && nextSequence > billSequence) {
        setState(() {
          billSequence = nextSequence;
          billNumber = nextBillNumber;
        });
      }
    });
  }

  Future<void> _loadInitialBillNumber() async {
    final today = DateTime.now();
    final nextSequence = await widget.controller.nextBillSequence(today);
    if (!mounted) return;
    setState(() {
      billSequence = nextSequence;
      billNumber = billNumberFor(today, nextSequence);
      billNumberReady = true;
    });
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    customer.dispose();
    city.dispose();
    super.dispose();
    billSubscription?.cancel();
  }

  Product? find(String id) =>
      widget.products.where((p) => p.id == id).firstOrNull;
  double get total => cart.entries.fold(
    0,
    (totalValue, e) =>
        totalValue + (prices[e.key] ?? find(e.key)?.cost ?? 0) * e.value,
  );
  Product? get selectedProduct {
    final selected = product == null ? null : find(product!.id);
    return selected == null || availableQuantity(selected) == 0 ? null : selected;
  }

  int availableQuantity(Product item) =>
      item.quantity - (cart[item.id] ?? 0);

  void add() {
    final qty = int.tryParse(quantity.text) ?? 0;
    if (product == null || qty <= 0) return;
    final salePrice = double.tryParse(price.text) ?? product!.cost;
    final existing = cart[product!.id] ?? 0;
    if (existing + qty > product!.quantity) return;
    setState(() {
      cart[product!.id] = existing + qty;
      prices[product!.id] = salePrice;
      product = null;
    });
    quantity.text = '1';
    price.clear();
  }

  Future<void> editCartItem(String productId) async {
    final item = find(productId);
    if (item == null) return;
    final quantityController = TextEditingController(
      text: (cart[productId] ?? 1).toString(),
    );
    final priceController = TextEditingController(
      text: (prices[productId] ?? item.cost).toStringAsFixed(2),
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${item.nameFor(widget.language)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                helperText: '${item.quantity} available',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Sale price per unit'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;

    final newQuantity = int.tryParse(quantityController.text) ?? 0;
    final newPrice = double.tryParse(priceController.text);
    if (newQuantity <= 0 || newQuantity > item.quantity || newPrice == null || newPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a quantity from 1 to ${item.quantity} and a valid price.')),
      );
      return;
    }
    setState(() {
      cart[productId] = newQuantity;
      prices[productId] = newPrice;
    });
  }

  void removeCartItem(String productId) {
    setState(() {
      cart.remove(productId);
      prices.remove(productId);
    });
  }

  Future<void> complete() async {
    if (cart.isEmpty) return;
    final shouldComplete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete sale?'),
        content: Text(
          'Save this bill with ${cart.length} item(s) for '
          'Rs ${total.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Complete sale'),
          ),
        ],
      ),
    );
    if (shouldComplete != true) return;
    await _completeSale();
  }

  Future<void> _completeSale() async {
    if (cart.isEmpty) return;
    // Keep an immutable receipt before the sale dialog can clear this draft.
    // This lets users print immediately after completing an order.
    List<int>? completedReceipt;
    try {
      completedReceipt = await _receiptBytes();
    } catch (_) {
      // The sale can still be recorded; a later print will regenerate it.
    }
    final saleItems = <({Product product, int quantity, double unitPrice})>[];
    for (final entry in cart.entries) {
      final item = find(entry.key);
      if (item == null) continue;
      saleItems.add((
        product: item,
        quantity: entry.value,
        unitPrice: prices[entry.key] ?? item.cost,
      ));
    }
    if (saleItems.length != cart.length) return;
    try {
      await widget.controller.recordSale(
        items: saleItems,
        party: customer.text.trim(),
        city: city.text.trim(),
        billNumber: billNumber,
        date: DateTime.now(),
      );
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message.toString()
            : 'Could not complete the sale. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    if (mounted) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Order generated'),
          content: Text(
            'Order: $billNumber\nItems: ${cart.length}\nTotal: ₹${total.toStringAsFixed(2)}\n\nConnect a Bluetooth thermal printer in the device settings, then use Print order to print this receipt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(c);
                await _printCurrentBill(receiptBytes: completedReceipt);
              },
              child: const Text('Print order'),
            ),
          ],
        ),
      );
      setState(() {
        cart.clear();
        prices.clear();
        customer.clear();
        city.clear();
        quantity.text = '1';
        price.clear();
        product = null;
        billSequence++;
        billNumber = billNumberFor(DateTime.now(), billSequence);
      });
    }
  }

  Future<List<int>> _receiptBytes() async {
    // Capture the bill before awaiting. Completing a sale clears the cart while
    // the Bluetooth printer picker/profile is loading.
    final items = <({String name, int quantity, double unitPrice})>[];
    for (final entry in cart.entries) {
      final item = find(entry.key);
      if (item == null) continue;
      items.add((
        name: item.nameFor(widget.language),
        quantity: entry.value,
        unitPrice: prices[entry.key] ?? item.cost,
      ));
    }
    final receiptBillNumber = billNumber;
    final receiptCustomer = customer.text.trim();
    final receiptCity = city.text.trim();
    final receiptTime = DateTime.now();
    final receiptTotal = items.fold<double>(
      0,
      (value, item) => value + item.quantity * item.unitPrice,
    );
    final generator = Generator(
      ThermalReceiptPrinter.paperSize,
      await CapabilityProfile.load(),
    );
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
          text: 'Order: $receiptBillNumber',
          width: 7,
          styles: ThermalReceiptPrinter.normalStyle,
        ),
        PosColumn(
          text: 'Time: ${receiptTime.hour.toString().padLeft(2, '0')}:${receiptTime.minute.toString().padLeft(2, '0')}',
          width: 5,
          styles: ThermalReceiptPrinter.rightStyle,
        ),
      ]),
    );
    if (receiptCustomer.isNotEmpty || receiptCity.isNotEmpty) {
      bytes.addAll(
        generator.row([
          PosColumn(
            text: receiptCustomer.isEmpty ? '' : 'Customer: $receiptCustomer',
            width: 6,
            styles: ThermalReceiptPrinter.normalStyle,
          ),
          PosColumn(
            text: receiptCity.isEmpty ? '' : 'City: $receiptCity',
            width: 6,
            styles: ThermalReceiptPrinter.rightStyle,
          ),
        ]),
      );
    }
    bytes.addAll(generator.hr());
    for (final item in items) {
      bytes.addAll(await ThermalReceiptPrinter.receiptItemRow(
        generator,
        name: item.name,
        amount: '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} = '
            '${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
      ));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'TOTAL: Rs ${receiptTotal.toStringAsFixed(2)}',
        styles: ThermalReceiptPrinter.rightBoldStyle,
      ),
    );
    bytes.addAll(generator.feed(3));
    // Partial cut without Generator.cut(), which adds five extra blank lines.
    bytes.addAll(const [0x1D, 0x56, 0x01]);
    return bytes;
  }

  Future<void> _printCurrentBill({List<int>? receiptBytes}) async {
    try {
      final bytes = receiptBytes ?? await _receiptBytes();
      if (!mounted) return;
      await ThermalReceiptPrinter.print(context, bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare the receipt: $error')),
        );
      }
    }
  }

  Future<void> printBill() async => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Print order'),
      content: Text('Order $billNumber\nTotal ₹${total.toStringAsFixed(2)}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(c);
            await _printCurrentBill();
          },
          child: const Text('Print'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final billNumberWidth = screenWidth * .28;
    final quantityWidth = screenWidth * .18;
    return Stack(
      children: [
        ResponsivePage(
          children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customer,
                decoration: const InputDecoration(
                  labelText: 'Shop / customer name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: billNumberWidth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Bill no.',
                  border: OutlineInputBorder(),
                ),
                child: Text(billNumber, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: city,
          decoration: const InputDecoration(
            labelText: 'City / Village',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ProductSearchField(
                products: widget.products
                    .where((item) => availableQuantity(item) > 0)
                    .toList(),
                selected: selectedProduct,
                language: widget.language,
                subtitle: (item) => '${availableQuantity(item)} available',
                onSelected: (item) => setState(() => product = item),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: quantityWidth,
              child: TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Sale price per unit',
            hintText: selectedProduct == null
                ? 'Enter price'
                : selectedProduct!.cost.toStringAsFixed(2),
            prefixText: '₹ ',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: add,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
        const SizedBox(height: 14),
        ...cart.entries.map((e) {
          final p = find(e.key)!;
          final salePrice = prices[e.key] ?? p.cost;
          return ListTile(
            title: Text(p.nameFor(widget.language)),
            subtitle: Text('${e.value} × ₹${salePrice.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${(e.value * salePrice).toStringAsFixed(2)}'),
                IconButton(
                  tooltip: 'Edit item',
                  onPressed: () => editCartItem(e.key),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: () => removeCartItem(e.key),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        const Divider(),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total ₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 88),
          ],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 12,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cart.isEmpty || !billNumberReady ? null : printBill,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print order'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: cart.isEmpty || !billNumberReady ? null : complete,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Complete sale'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
