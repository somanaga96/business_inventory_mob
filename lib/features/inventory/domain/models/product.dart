import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.cost,
    required this.quantity,
    this.minStock = 10,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String category;
  final double cost;
  final int quantity;
  final int minStock;
  final String? imageUrl;

  bool get low => quantity <= minStock;

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    num number(dynamic value) =>
        value is num ? value : num.tryParse('$value') ?? 0;
    return Product(
      id: doc.id,
      name: '${data['name'] ?? 'Untitled product'}',
      category: '${data['category'] ?? 'Other'}',
      cost: number(data['price']).toDouble(),
      quantity: number(data['quantity']).toInt(),
      minStock: number(data['minStock'] ?? 10).toInt(),
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
