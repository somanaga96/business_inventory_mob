import '../../../app_exports.dart';

class Products extends StatelessWidget {
  const Products({
    super.key,
    required this.products,
    required this.add,
    required this.edit,
    required this.remove,
  });
  final List<Product> products;
  final VoidCallback add;
  final Future<void> Function(Product) edit;
  final Future<void> Function(Product) remove;
  @override
  Widget build(BuildContext context) => ResponsivePage(
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
      ...products.map(
        (p) => ProductTile(
          product: p,
          actions: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => edit(p),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => remove(p),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
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
