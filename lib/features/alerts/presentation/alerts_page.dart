import '../../../app_exports.dart';

class Alerts extends StatelessWidget {
  const Alerts({
    super.key,
    required this.products,
    required this.update,
    required this.remove,
  });
  final List<Product> products;
  final Future<void> Function(Product) update;
  final Future<void> Function(Product) remove;
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
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE59A00),
              ),
              title: Text('${p.name} is running low'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit product',
                    onPressed: () => update(p),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete product',
                    onPressed: () => remove(p),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
              subtitle: Text(
                '${p.quantity} left · reorder level ${p.minStock}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
