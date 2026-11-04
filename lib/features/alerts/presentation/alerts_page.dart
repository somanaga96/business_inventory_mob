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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final alertSurface = isDark
        ? const Color(0xFF1A1F2A)
        : const Color(0xFFFFF8E7);
    final imageSurface = isDark
        ? const Color(0xFF252B38)
        : const Color(0xFFFFE6A7);
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
            color: alertSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFFE59A00).withValues(alpha: .35)
                    : const Color(0xFFE59A00).withValues(alpha: .28),
              ),
            ),
            child: ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: imageSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: p.imageUrl == null || p.imageUrl!.isEmpty
                        ? Icon(
                            Icons.inventory_2_outlined,
                          color: isDark
                              ? const Color(0xFFFFD56A)
                              : const Color(0xFF6B4A00),
                          )
                        : Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.inventory_2_outlined,
                            color: isDark
                                ? const Color(0xFFFFD56A)
                                : const Color(0xFF6B4A00),
                            ),
                          ),
                  ),
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: isDark
                          ? const Color(0xFF1A1F2A)
                          : alertSurface,
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
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${p.quantity} left · reorder level ${p.minStock}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
