import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/product.dart';
import '../../data/datasources/firebase_inventory_data_source.dart';

class InventoryController {
  InventoryController({FirebaseInventoryDataSource? dataSource})
    : _injectedDataSource = dataSource;
  final FirebaseInventoryDataSource? _injectedDataSource;
  late final FirebaseInventoryDataSource _dataSource =
      _injectedDataSource ?? FirebaseInventoryDataSource();

  Stream<List<Product>> get products => _dataSource.watchProducts();
  Stream<QuerySnapshot<Map<String, dynamic>>> get transactions =>
      _dataSource.watchTransactions();
  Stream<QuerySnapshot<Map<String, dynamic>>> get purchases =>
      _dataSource.watchPurchases();
  Stream<QuerySnapshot<Map<String, dynamic>>> transactionsForDate(
    DateTime date,
  ) => _dataSource.watchTransactionsForDate(date);
  Stream<QuerySnapshot<Map<String, dynamic>>> transactionsForRange(
    DateTime from,
    DateTime to,
  ) => _dataSource.watchTransactionsForRange(from, to);
  Future<int> nextBillSequence(DateTime date) =>
      _dataSource.nextBillSequence(date);
  Future<void> addProduct({
    required String name,
    required String category,
    required double cost,
    required int quantity,
    required int threshold,
    String? imageUrl,
  }) => _dataSource.addProduct(
    name: name,
    category: category,
    cost: cost,
    quantity: quantity,
    threshold: threshold,
    imageUrl: imageUrl,
  );
  Future<void> adjustStock(Product product, int delta) =>
      _dataSource.adjustStock(product, delta);
  Future<void> updateProduct({
    required Product product,
    required String name,
    required String category,
    required double cost,
    required int threshold,
    String? imageUrl,
  }) => _dataSource.updateProduct(
    product: product,
    name: name,
    category: category,
    cost: cost,
    threshold: threshold,
    imageUrl: imageUrl,
  );
  Future<void> deleteProduct(Product product) =>
      _dataSource.deleteProduct(product);
  Future<void> recordTransaction({
    required Product product,
    required int quantity,
    required String type,
    required double unitPrice,
    required String party,
    required String city,
    required String note,
    required DateTime date,
  }) => _dataSource.recordTransaction(
    product: product,
    quantity: quantity,
    type: type,
    unitPrice: unitPrice,
    party: party,
    city: city,
    note: note,
    date: date,
  );

  Future<void> recordSale({
    required List<({Product product, int quantity, double unitPrice})> items,
    required String party,
    required String city,
    required String billNumber,
    required DateTime date,
  }) => _dataSource.recordSale(
    items: items,
    party: party,
    city: city,
    billNumber: billNumber,
    date: date,
  );

  Future<void> updateSaleOrder({
    required List<
      ({String transactionId, String productId, int oldQuantity, int quantity, double unitPrice})
    > items,
    required String party,
    required String city,
  }) => _dataSource.updateSaleOrder(items: items, party: party, city: city);
}
