import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductNameLanguage { english, tamil, marathi }

extension ProductNameLanguageLabel on ProductNameLanguage {
  String get label => switch (this) {
    ProductNameLanguage.english => 'English',
    ProductNameLanguage.tamil => 'Tamil',
    ProductNameLanguage.marathi => 'Marathi',
  };
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.tamilName,
    this.marathiName,
    required this.category,
    required this.cost,
    required this.quantity,
    this.minStock = 10,
    this.imageUrl,
  });

  final String id;
  final String name;
  /// English is stored in [name] for compatibility with existing inventory.
  final String? tamilName;
  final String? marathiName;
  final String category;
  final double cost;
  final int quantity;
  final int minStock;
  final String? imageUrl;

  bool get low => quantity <= minStock;

  /// A compact label for pickers, so staff can identify the same item in all
  /// three supported product-name languages.
  String get displayName => [
    name,
    if (tamilName?.isNotEmpty ?? false) tamilName!,
    if (marathiName?.isNotEmpty ?? false) marathiName!,
  ].join(' / ');

  String nameFor(ProductNameLanguage language) => switch (language) {
    ProductNameLanguage.english => name,
    ProductNameLanguage.tamil => (tamilName?.isNotEmpty ?? false) ? tamilName! : name,
    ProductNameLanguage.marathi => (marathiName?.isNotEmpty ?? false)
        ? marathiName!
        : name,
  };

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    num number(dynamic value) =>
        value is num ? value : num.tryParse('$value') ?? 0;
    return Product(
      id: doc.id,
      name: '${data['name'] ?? 'Untitled product'}',
      tamilName: data['tamilName'] as String?,
      marathiName: data['marathiName'] as String?,
      category: '${data['category'] ?? 'Other'}',
      cost: number(data['price']).toDouble(),
      quantity: number(data['quantity']).toInt(),
      minStock: number(data['minStock'] ?? 10).toInt(),
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
