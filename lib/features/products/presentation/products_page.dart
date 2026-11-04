import '../../../app_exports.dart';

class Products extends StatefulWidget {
  final List<Product> products;
  final VoidCallback add;
  final Future<void> Function(Product) edit;
  final Future<void> Function(Product) remove;
  final ProductNameLanguage language;
  const Products({
    super.key,
    required this.products,
    required this.add,
    required this.edit,
    required this.remove,
    required this.language,
  });
  @override
  State<Products> createState() => _ProductsState();
}

class _ProductsState extends State<Products> {
  String query = '';
  String? category;
  @override
  Widget build(BuildContext context) {
    final categories = widget.products.map((p) => p.category).toSet().toList()..sort();
    final visible = widget.products.where((p) {
      final search = '${p.name} ${p.tamilName ?? ''} ${p.marathiName ?? ''} ${p.category}'.toLowerCase();
      return (category == null || p.category == category) && search.contains(query.toLowerCase());
    });
    return ResponsivePage(
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
            onPressed: widget.add,
            icon: const Icon(Icons.add_circle, color: primary),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        onChanged: (value) => setState(() => query = value),
        decoration: const InputDecoration(
          labelText: 'Search products',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String?>(
        initialValue: category,
        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
          ...categories.map((value) => DropdownMenuItem(value: value, child: Text(value))),
        ],
        onChanged: (value) => setState(() => category = value),
      ),
      const SizedBox(height: 12),
      ...visible.map(
        (p) => ProductTile(
          product: p,
          language: widget.language,
          actions: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => widget.edit(p),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => widget.remove(p),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    ],
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.language, this.actions});
  final Product product;
  final ProductNameLanguage language;
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
      title: Text(product.nameFor(language), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${product.category} · ₹${product.cost.toStringAsFixed(2)} avg. cost',
      ),
      trailing:
          actions ??
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
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
