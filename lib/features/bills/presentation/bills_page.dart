import '../../../app_exports.dart';

class Bills extends StatefulWidget {
  const Bills({
    super.key,
    required this.products,
    required this.submit,
    required this.controller,
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
    return selected?.quantity == 0 ? null : selected;
  }

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
      if (p != null) {
        await widget.submit(
          p,
          entry.value,
          'Sale',
          prices[entry.key] ?? p.cost,
          customer.text.trim(),
          city.text.trim(),
          billNumber,
          DateTime.now(),
        );
      }
    }
    if (mounted) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Bill generated'),
          content: Text(
            'Order: $billNumber\nItems: ${cart.length}\nTotal: ₹${total.toStringAsFixed(2)}\n\nConnect a Bluetooth thermal printer in the device settings, then use Print bill to print this receipt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Thermal printing requires a Bluetooth printer plugin configured for this device.',
                    ),
                  ),
                );
              },
              child: const Text('Print bill'),
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

  Future<void> printBill() async => showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Print bill'),
      content: Text('Order $billNumber\nTotal ₹${total.toStringAsFixed(2)}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Connect a Bluetooth thermal printer to print this bill.',
                ),
              ),
            );
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
    return ResponsivePage(
      children: [
        const Text(
          'Bills',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add multiple goods to one sale and generate a cumulative bill.',
          style: TextStyle(color: Color(0xFF8493AD)),
        ),
        const SizedBox(height: 18),
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
              child: DropdownButtonFormField<Product>(
                initialValue: selectedProduct,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
                items: widget.products
                    .where((p) => p.quantity > 0)
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: p.imageUrl == null || p.imageUrl!.isEmpty
                                  ? const Icon(
                                      Icons.inventory_2_outlined,
                                      color: primary,
                                      size: 19,
                                    )
                                  : Image.network(
                                      p.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.inventory_2_outlined,
                                        color: primary,
                                        size: 19,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${p.name} (${p.quantity})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => product = v),
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
            title: Text(p.name),
            subtitle: Text('${e.value} × ₹${salePrice.toStringAsFixed(2)}'),
            trailing: Text('₹${(e.value * salePrice).toStringAsFixed(2)}'),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cart.isEmpty || !billNumberReady ? null : printBill,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print bill'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: cart.isEmpty || !billNumberReady ? null : complete,
                icon: const Icon(Icons.receipt_long),
                label: const Text('Complete sale'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
