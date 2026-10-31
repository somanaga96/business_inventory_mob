import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../services/inventory_service.dart';

class InventoryController {
  InventoryController({InventoryService? service}) : _injectedService = service;
  final InventoryService? _injectedService;
  late final InventoryService _service = _injectedService ?? InventoryService();

  Stream<List<Product>> get products => _service.watchProducts();
  Stream<QuerySnapshot<Map<String, dynamic>>> get transactions =>
      _service.watchTransactions();
  Future<void> addProduct({
    required String name,
    required String category,
    required double cost,
    required int quantity,
    required int threshold,
    String? imageUrl,
  }) => _service.addProduct(
    name: name,
    category: category,
    cost: cost,
    quantity: quantity,
    threshold: threshold,
    imageUrl: imageUrl,
  );
  Future<void> adjustStock(Product product, int delta) =>
      _service.adjustStock(product, delta);
  Future<void> updateProduct({required Product product, required String name, required String category, required double cost, required int threshold, String? imageUrl}) => _service.updateProduct(product: product, name: name, category: category, cost: cost, threshold: threshold, imageUrl: imageUrl);
  Future<void> deleteProduct(Product product) => _service.deleteProduct(product);
  Future<void> recordTransaction({
    required Product product,
    required int quantity,
    required String type,
    required double unitPrice,
    required String party,
    required String note,
    required DateTime date,
  }) => _service.recordTransaction(
    product: product,
    quantity: quantity,
    type: type,
    unitPrice: unitPrice,
    party: party,
    note: note,
    date: date,
  );
}
