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

  bool get _isTamil => widget.language == ProductNameLanguage.tamil;

  String _text(String english, String tamil) => _isTamil ? tamil : english;

  String get _typeLabel => switch (type) {
    'Damage' => _text('Damage / loss', 'உடைதல்'),
    'Stolen' => _text('Stolen stock', 'திருட்டு'),
    _ => _text('Purchase', 'வாங்குதல்'),
  };
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
            ? _text('Product and quantity are required.', 'பொருள் மற்றும் எண்ணிக்கை அவசியம்.')
            : _text(
                'Product, purchase quantity, and buy price are required.',
                'பொருள், பொருள் எண்ணிக்கை மற்றும் பொருள் விலை அவசியம்.',
              ))),
      );
      return;
    }
    final stockOut = type == 'Sale' || type == 'Damage' || type == 'Stolen';
    if (stockOut && amount > currentProduct.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_text(
            'Cannot remove more than current stock.',
            'தற்போதைய இருப்பை விட அதிகமாகக் குறைக்க முடியாது.',
          )),
        ),
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
        setState(() {
          selected = null;
          quantity.clear();
          price.clear();
          note.clear();
          party.clear();
          city.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(type == 'Damage'
              ? _text('Damage / loss recorded.', 'உடைதல் பதிவு செய்யப்பட்டது.')
              : type == 'Stolen'
              ? _text('Stolen stock recorded.', 'திருட்டு பதிவு செய்யப்பட்டது.')
              : _text('Purchase recorded.', 'வாங்குதல் பதிவு செய்யப்பட்டது.')),
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
                  decoration: InputDecoration(
                    labelText: _text('Stock movement', 'இருப்பு மாற்றம்'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Purchase',
                      child: Text(_text('Purchase / stock in', 'வாங்குதல்')),
                    ),
                    DropdownMenuItem(
                      value: 'Damage',
                      child: Text(_text('Damage / loss', 'உடைதல்')),
                    ),
                    DropdownMenuItem(
                      value: 'Stolen',
                      child: Text(_text('Stolen stock', 'திருட்டு')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => type = value);
                  },
                ),
                const SizedBox(height: 14),
                ProductSearchField(
                  products: widget.products,
                  selected: selectedValue,
                  language: widget.language,
                  labelText: _text('Product', 'பொருள்'),
                  hintText: _text('Search product or number', 'பொருள் அல்லது எண் தேடுக'),
                  subtitle: (product) => _text(
                    '${product.quantity} available',
                    '${product.quantity} இருப்பு',
                  ),
                  onSelected: (product) => setState(() => selected = product),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isTamil
                        ? 'பொருள் எண்ணிக்கை *'
                        : '${type == 'Purchase' ? 'Purchase' : _typeLabel} quantity *',
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
                    labelText: _text('Buy price per unit *', 'பொருள் விலை *'),
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
                  decoration: InputDecoration(
                    labelText: _text(
                      'Supplier / Party (optional)',
                      'பொருள் கொடுப்பவர் பெயர் (விருப்பம்)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: city,
                  decoration: InputDecoration(
                    labelText: _text('City / Village (optional)', 'ஊர் / கிராமம் (விருப்பம்)'),
                    border: const OutlineInputBorder(),
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
                    '${_text('Date', 'தேதி')}: ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _text('Note (optional)', 'குறிப்பு (விருப்பம்)'),
                    hintText: _text('Supplier, sale, adjustment…', 'வழங்குபவர், விற்பனை, மாற்றம்…'),
                    border: const OutlineInputBorder(),
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
            label: Text(saving ? _text('Saving…', 'சேமிக்கிறது…') : _text('Record $_typeLabel', 'பதிவு செய்')),
          ),
        ),
      ],
    );
  }
}
