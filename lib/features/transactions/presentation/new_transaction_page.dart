import '../../../app_exports.dart';

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
    return ResponsivePage(
      children: [
        const Text(
          'Purchase',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    labelText: 'Buy price per unit',
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
