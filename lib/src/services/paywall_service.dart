import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing in-app purchases and subscriptions
class PaywallService {
  PaywallService._();
  static final PaywallService _instance = PaywallService._();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;

  static PaywallService get instance => _instance;

  /// Initialize in-app purchase
  Future<void> initialize() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      _isAvailable = isAvailable;

      if (!isAvailable) {
        print('In-app purchase not available');
        return;
      }

      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) => print('Purchase stream error: $error'),
      );

      print('PaywallService initialized');
    } catch (e) {
      print('Error initializing paywall: $e');
    }
  }

  /// Complete any purchases that are still pending completion
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Restore previously made purchases (triggers updates on [purchaseStream])
  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  /// Get available products
  Future<List<ProductDetails>> getProducts(List<String> productIds) async {
    if (!_isAvailable) {
      return [];
    }

    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds.toSet());
      return response.productDetails;
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  /// Purchase a product
  Future<bool> purchaseProduct(ProductDetails product) async {
    if (!_isAvailable) {
      return false;
    }

    try {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);
      return await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Error purchasing product: $e');
      return false;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      final tier = data['subscriptionTier'] as String?;

      if (tier == null || tier == 'free') {
        return false;
      }

      final expiry = data['subscriptionExpiry'] as Timestamp?;
      if (expiry == null) {
        return false;
      }

      return expiry.toDate().isAfter(DateTime.now());
    } catch (e) {
      print('Error checking subscription: $e');
      return false;
    }
  }

  /// Get current subscription tier
  Future<String> getCurrentSubscriptionTier() async {
    final user = _auth.currentUser;
    if (user == null) return 'free';

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        return 'free';
      }

      return (doc.data()!)['subscriptionTier'] ?? 'free';
    } catch (e) {
      print('Error getting subscription tier: $e');
      return 'free';
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription.cancel();
  }
}

/// Subscription tier enum
enum SubscriptionTier {
  free('free'),
  pro('pro'),
  premium('premium');

  final String value;
  const SubscriptionTier(this.value);
}

/// Singleton accessor
final paywallService = PaywallService.instance;
