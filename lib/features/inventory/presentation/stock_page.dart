import '../../../app_exports.dart';

class Stock extends StatelessWidget {
  const Stock({super.key, required this.products, required this.adjust});
  final List<Product> products;
  final Future<void> Function(Product, int) adjust;
  @override
  Widget build(BuildContext context) {
    final inStockProducts = products
        .where((product) => product.quantity > 0)
        .toList();
    return ResponsivePage(
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
      if (inStockProducts.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('No products in inventory'),
            subtitle: Text('Products with zero stock are hidden here.'),
          ),
        ),
      ...inStockProducts.map(
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
                      : Image.network(
                          p.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.inventory_2_outlined,
                            color: primary,
                          ),
                        ),
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
                        'Price: Rs ${p.cost.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF71809A)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${p.quantity}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'units available',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.low
                            ? const Color(0xFFC17700)
                            : const Color(0xFF71809A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ],
    );
  }
}
