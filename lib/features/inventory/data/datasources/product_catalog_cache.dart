import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/product.dart';

/// Keeps the last known product catalogue available before Firestore connects.
class ProductCatalogCache {
  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}inventorypro_products.json');
  }

  Future<List<Product>> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((value) {
        final data = Map<String, dynamic>.from(value);
        return Product(
          id: '${data['id'] ?? ''}',
          productNumber: (data['productNumber'] as num?)?.toInt(),
          name: '${data['name'] ?? 'Product'}',
          tamilName: data['tamilName'] as String?,
          marathiName: data['marathiName'] as String?,
          category: '${data['category'] ?? 'Other'}',
          cost: (data['cost'] as num?)?.toDouble() ?? 0,
          quantity: (data['quantity'] as num?)?.toInt() ?? 0,
          minStock: (data['minStock'] as num?)?.toInt() ?? 10,
          imageUrl: data['imageUrl'] as String?,
        );
      }).where((product) => product.id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Product> products) async {
    try {
      final file = await _file();
      final data = products.map((product) => {
        'id': product.id,
        'productNumber': product.productNumber,
        'name': product.name,
        'tamilName': product.tamilName,
        'marathiName': product.marathiName,
        'category': product.category,
        'cost': product.cost,
        'quantity': product.quantity,
        'minStock': product.minStock,
        'imageUrl': product.imageUrl,
      }).toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // The live Firestore stream remains usable if local storage is unavailable.
    }
  }
}
