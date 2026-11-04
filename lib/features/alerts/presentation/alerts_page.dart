import '../../../app_exports.dart';

class Alerts extends StatelessWidget {
  const Alerts({
    super.key,
    required this.products,
    required this.language,
  });
  final List<Product> products;
  final ProductNameLanguage language;
  @override
  Widget build(BuildContext context) {
    final alerts = products.where((p) => p.low).toList();
    return ResponsivePage(
      children: [
        const Text(
          'Stock alerts',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        if (alerts.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.check_circle_outline,
                color: Color(0xFF22B573),
              ),
              title: Text('All stock levels look good'),
            ),
          ),
        ...alerts.map(
          (p) => Card(
            color: const Color(0xFFFFF8E7),
            child: ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE6A7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: p.imageUrl == null || p.imageUrl!.isEmpty
                        ? const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF6B4A00),
                          )
                        : Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF6B4A00),
                            ),
                          ),
                  ),
                  const Positioned(
                    right: -5,
                    bottom: -5,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(0xFFFFF8E7),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFE59A00),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                '${p.nameFor(language)} is running low',
                style: const TextStyle(
                  color: Color(0xFF3D2A00),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${p.quantity} left · reorder level ${p.minStock}',
                style: const TextStyle(color: Color(0xFF684F1B)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
