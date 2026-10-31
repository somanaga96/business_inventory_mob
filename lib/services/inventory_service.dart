import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

class InventoryService {
  InventoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<List<Product>> watchProducts() => _firestore
      .collection('inventory')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Product.fromFirestore).toList());

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactions() => _firestore
      .collection('transactions')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Future<void> addProduct({
    required String name,
    required String category,
    required double cost,
    required int quantity,
    required int threshold,
    String? imageUrl,
  }) async {
    final product = _firestore.collection('products').doc();
    final inventory = _firestore.collection('inventory').doc(product.id);
    final batch = _firestore.batch();
    final image = imageUrl?.trim();
    batch.set(product, {
      'name': name,
      'category': category,
      'threshold': threshold,
      if (image?.isNotEmpty ?? false) 'imageUrl': image,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(inventory, {
      'productId': product.id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'threshold': threshold,
      'avgCost': cost,
      'lastBuyPrice': cost,
      'costValue': quantity * cost,
      if (image?.isNotEmpty ?? false) 'imageUrl': image,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> adjustStock(Product product, int delta) async {
    final after = (product.quantity + delta).clamp(0, 1 << 31);
    final batch = _firestore.batch();
    batch.update(_firestore.collection('inventory').doc(product.id), {
      'quantity': after,
      'costValue': after * product.cost,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('transactions').doc(), {
      'productId': product.id,
      'productName': product.name,
      'imageUrl': product.imageUrl,
      'quantity': delta.abs(),
      'change': delta,
      'type': delta >= 0 ? 'Stock in' : 'Stock out',
      'inventoryAfter': after,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateProduct({
    required Product product,
    required String name,
    required String category,
    required double cost,
    required int threshold,
    String? imageUrl,
  }) async {
    final image = imageUrl?.trim();
    final batch = _firestore.batch();
    final productData = {'name': name, 'category': category, 'threshold': threshold, 'imageUrl': image, 'updatedAt': FieldValue.serverTimestamp()};
    final inventoryData = {'name': name, 'category': category, 'threshold': threshold, 'imageUrl': image, 'avgCost': cost, 'lastBuyPrice': cost, 'costValue': product.quantity * cost, 'updatedAt': FieldValue.serverTimestamp()};
    batch.update(_firestore.collection('products').doc(product.id), productData);
    batch.update(_firestore.collection('inventory').doc(product.id), inventoryData);
    await batch.commit();
  }

  Future<void> deleteProduct(Product product) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('products').doc(product.id));
    batch.delete(_firestore.collection('inventory').doc(product.id));
    await batch.commit();
  }

  Future<void> recordTransaction({
    required Product product,
    required int quantity,
    required String type,
    required double unitPrice,
    required String party,
    required String city,
    required String note,
    required DateTime date,
  }) async {
    final stockIn = type == 'Purchase' || type == 'Return';
    final change = stockIn ? quantity : -quantity;
    final after = (product.quantity + change).clamp(0, 1 << 31);
    final batch = _firestore.batch();
    batch.update(_firestore.collection('inventory').doc(product.id), {
      'quantity': after,
      'costValue': after * product.cost,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('transactions').doc(), {
      'productId': product.id,
      'productName': product.name,
      'imageUrl': product.imageUrl,
      'quantity': quantity,
      'change': change,
      'type': type,
      'unitPrice': unitPrice,
      'party': party,
      'city': city,
      'note': note,
      'inventoryAfter': after,
      'transactionDate': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
