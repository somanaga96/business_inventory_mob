import '../../../app_exports.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key, required this.products, required this.submit, required this.language});
  final List<Product> products;
  final ProductNameLanguage language;
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
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  Product? selected;
  String type = 'Purchase';
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
    // Damaged stock is valued at the product's current cost, so recording a
    // loss does not require entering a purchase price.
    final unitPrice = type == 'Damage' || type == 'Stolen'
        ? (selected?.cost ?? 0)
        : double.tryParse(price.text);
    final currentProduct = selected == null
        ? null
        : widget.products.where((p) => p.id == selected!.id).firstOrNull;
    if (currentProduct == null ||
        amount <= 0 ||
        unitPrice == null ||
        unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == 'Damage' || type == 'Stolen'
            ? 'Product and ${type.toLowerCase()} quantity are required.'
            : 'Product, purchase quantity, and buy price are required.')),
      );
      return;
    }
    final stockOut = type == 'Sale' || type == 'Damage' || type == 'Stolen';
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
        unitPrice,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(type == 'Damage'
              ? 'Damage / loss recorded.'
              : type == 'Stolen'
              ? 'Stolen stock recorded.'
              : 'Purchase recorded.'),
        ));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message.toString())),
        );
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
    return Stack(
      children: [
        ResponsivePage(
          children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Stock movement',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Purchase',
                      child: Text('Purchase / stock in'),
                    ),
                    DropdownMenuItem(
                      value: 'Damage',
                      child: Text('Damage / loss'),
                    ),
                    DropdownMenuItem(
                      value: 'Stolen',
                      child: Text('Stolen stock'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => type = value);
                  },
                ),
                const SizedBox(height: 14),
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
                                  '${p.nameFor(widget.language)} (${p.quantity} available)',
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
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == 'Damage' || type == 'Stolen'
                        ? '${type == 'Stolen' ? 'Stolen' : 'Damaged'} quantity *'
                        : 'Purchase quantity *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                if (type != 'Damage' && type != 'Stolen') TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Buy price per unit *',
                    hintText: selected == null
                        ? '0.00'
                        : selected!.cost.toStringAsFixed(2),
                    prefixText: '₹ ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (type != 'Damage' && type != 'Stolen') const SizedBox(height: 14),
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
                    '${type == 'Damage' ? 'Damage' : type == 'Stolen' ? 'Stolen' : 'Purchase'} date: ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
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
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
          ],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 12,
          child: FilledButton.icon(
            onPressed: saving ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              minimumSize: const Size.fromHeight(54),
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
        ),
      ],
    );
  }
}
