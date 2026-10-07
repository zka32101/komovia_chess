import 'package:cloud_firestore/cloud_firestore.dart';

// Phase Q: マネタイゼーション拡張
class MonetizationService {
  factory MonetizationService() => _instance;
  MonetizationService._internal();
  static final MonetizationService _instance = MonetizationService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> recordPurchase(
      String userId, String productId, double amount) async {
    await _firestore
        .collection('purchases')
        .doc(userId)
        .collection('history')
        .add({
      'productId': productId,
      'amount': amount,
      'currency': 'USD',
      'purchasedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Subscription>> getSubscriptionTiers() async {
    final snapshot =
        await _firestore.collection('subscriptions').orderBy('price').get();
    return snapshot.docs.map((d) => Subscription.fromJson(d.data())).toList();
  }

  Future<void> createBundleOffer(
      String bundleId, List<String> productIds, double discountedPrice) async {
    await _firestore.collection('bundles').doc(bundleId).set({
      'productIds': productIds,
      'discountedPrice': discountedPrice,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class Subscription {
  Subscription(
      {required this.tierId,
      required this.name,
      required this.price,
      required this.features});

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        tierId: json['tierId'] ?? '',
        name: json['name'] ?? '',
        price: (json['price'] ?? 0.0).toDouble(),
        features: List<String>.from(json['features'] ?? []),
      );
  final String tierId;
  final String name;
  final double price;
  final List<String> features;
}
