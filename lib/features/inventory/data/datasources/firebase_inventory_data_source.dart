import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/product.dart';

class FirebaseInventoryDataSource {
  FirebaseInventoryDataSource({FirebaseFirestore? firestore})
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPurchases() => _firestore
      .collection('transactions')
      .where('type', isEqualTo: 'Purchase')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactionsForDate(
    DateTime date,
  ) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _firestore
        .collection('transactions')
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('transactionDate', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactionsForRange(
    DateTime from,
    DateTime to,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    return _firestore
        .collection('transactions')
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('transactionDate', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  Future<int> nextBillSequence(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _firestore
        .collection('transactions')
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('transactionDate', isLessThan: Timestamp.fromDate(end))
        .get();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final prefix =
        '${date.day.toString().padLeft(2, '0')}_${months[date.month - 1]}_${date.year}';
    final pattern = RegExp('^${RegExp.escape(prefix)}_(\\d+)\$');
    var highest = 0;
    for (final doc in snapshot.docs) {
      final match = pattern.firstMatch(doc.data()['note']?.toString() ?? '');
      final sequence = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (sequence > highest) highest = sequence;
    }
    return highest + 1;
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required double cost,
    required int quantity,
    required int threshold,
    String? imageUrl,
    String? tamilName,
    String? marathiName,
  }) async {
    final inventory = _firestore.collection('inventory').doc();
    final batch = _firestore.batch();
    final image = imageUrl?.trim();
    batch.set(inventory, {
      'name': name,
      if (tamilName?.trim().isNotEmpty ?? false) 'tamilName': tamilName!.trim(),
      if (marathiName?.trim().isNotEmpty ?? false) 'marathiName': marathiName!.trim(),
      'category': category,
      'quantity': quantity,
      'minStock': threshold,
      'price': cost,
      if (image?.isNotEmpty ?? false) 'imageUrl': image,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // The initial quantity is stock bought for the business, so retain it in
    // the same audit trail as purchases.  Without this record, newly added
    // stock appears in inventory but cannot appear in purchase history or
    // purchase totals.
    if (quantity > 0) {
      batch.set(_firestore.collection('transactions').doc(), {
        'productId': inventory.id,
        'productName': name,
        'imageUrl': image,
        'quantity': quantity,
        'purchaseQuantity': quantity,
        'change': quantity,
        'type': 'Purchase',
        'recordType': 'purchase',
        'unitPrice': cost,
        'buyPrice': cost,
        'mrp': cost,
        'party': '',
        'city': '',
        'note': 'Opening stock',
        'inventoryAfter': quantity,
        'transactionDate': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> adjustStock(Product product, int delta) async {
    final after = (product.quantity + delta).clamp(0, 1 << 31);
    final batch = _firestore.batch();
    batch.update(_firestore.collection('inventory').doc(product.id), {
      'quantity': after,
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
    String? tamilName,
    String? marathiName,
  }) async {
    final image = imageUrl?.trim();
    final productData = {
      'name': name,
      'tamilName': tamilName?.trim() ?? '',
      'marathiName': marathiName?.trim() ?? '',
      'category': category,
      'minStock': threshold,
      'imageUrl': image,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final inventoryData = {
      ...productData,
      'price': cost,
    };
    await _firestore.collection('inventory').doc(product.id).update(inventoryData);
  }

  Future<void> deleteProduct(Product product) async {
    await _firestore.collection('inventory').doc(product.id).delete();
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
    final isPurchase = type == 'Purchase';
    final nextCost = isPurchase
        ? ((product.quantity * product.cost) + (quantity * unitPrice)) / after
        : product.cost;
    final batch = _firestore.batch();
    batch.update(_firestore.collection('inventory').doc(product.id), {
      'quantity': after,
      'price': nextCost,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('transactions').doc(), {
      'productId': product.id,
      'productName': product.name,
      'imageUrl': product.imageUrl,
      'quantity': quantity,
      'change': change,
      'type': type,
      'recordType': type == 'Purchase' ? 'purchase' : 'inventory_transaction',
      'unitPrice': unitPrice,
      if (type == 'Purchase') 'purchaseQuantity': quantity,
      if (type == 'Purchase') 'buyPrice': unitPrice,
      'mrp': nextCost,
      'party': party,
      'city': city,
      'note': note,
      'inventoryAfter': after,
      'transactionDate': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Saves every line of one bill in a single Firestore batch.
  Future<void> recordSale({
    required List<({Product product, int quantity, double unitPrice})> items,
    required String party,
    required String city,
    required String billNumber,
    required DateTime date,
  }) async {
    final batch = _firestore.batch();
    for (final item in items) {
      final after = (item.product.quantity - item.quantity).clamp(0, 1 << 31);
      batch.update(_firestore.collection('inventory').doc(item.product.id), {
        'quantity': after,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('transactions').doc(), {
        'productId': item.product.id,
        'productName': item.product.name,
        'imageUrl': item.product.imageUrl,
        'quantity': item.quantity,
        'change': -item.quantity,
        'type': 'Sale',
        'recordType': 'inventory_transaction',
        'unitPrice': item.unitPrice,
        'mrp': item.product.cost,
        'party': party,
        'city': city,
        'note': billNumber,
        'inventoryAfter': after,
        'transactionDate': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Corrects an existing sale and returns stock for any reduced quantity.
  Future<void> updateSaleOrder({
    required List<
      ({String transactionId, String productId, int oldQuantity, int quantity, double unitPrice})
    > items,
    required String party,
    required String city,
  }) async {
    final batch = _firestore.batch();
    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError.value(item.quantity, 'quantity', 'Must be at least one');
      }
      final stockDifference = item.oldQuantity - item.quantity;
      batch.update(_firestore.collection('inventory').doc(item.productId), {
        'quantity': FieldValue.increment(stockDifference),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_firestore.collection('transactions').doc(item.transactionId), {
        'quantity': item.quantity,
        'change': -item.quantity,
        'unitPrice': item.unitPrice,
        'party': party,
        'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
