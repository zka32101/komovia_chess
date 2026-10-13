import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown when a purchase can't be started - the store isn't available on
/// this device, or the requested plan's product id isn't configured in
/// App Store Connect / Play Console yet. Distinct from a user-canceled or
/// store-rejected purchase so the UI can show an honest message instead
/// of a generic "purchase failed".
class PurchaseUnavailableException implements Exception {
  PurchaseUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Service for managing in-app purchases and subscriptions
class PaywallService {
  PaywallService._();
  static final PaywallService _instance = PaywallService._();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Product ids for each paid tier - these must match whatever is
  /// actually configured in App Store Connect / Play Console; until then
  /// `queryProductDetails` simply returns nothing for them and
  /// purchaseSubscription reports that honestly via
  /// PurchaseUnavailableException rather than faking success.
  static const Map<String, String> _productIdsByTier = {
    'pro': 'chess_pro_monthly',
    'premium': 'chess_premium_monthly',
  };

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  bool _initialized = false;

  static PaywallService get instance => _instance;

  /// Initialize in-app purchase and attach the single listener that
  /// persists a successful/restored purchase's entitlement to Firestore
  /// and completes it with the store - safe to call more than once
  /// (idempotent), since the Riverpod provider calls it on every cold
  /// start of the app.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
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

  /// Persists entitlement for any purchased/restored subscription, and
  /// completes every terminal purchase (success or error) - an
  /// uncompleted transaction gets redelivered by the platform store on
  /// every future app launch.
  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final tier = _productIdsByTier.entries
            .firstWhere(
              (e) => e.value == purchaseDetails.productID,
              orElse: () => const MapEntry('', ''),
            )
            .key;
        if (tier.isNotEmpty) {
          await _persistEntitlement(tier);
        }
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _persistEntitlement(String tier) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final expiry = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(user.uid).set({
      'subscriptionTier': tier,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'isLifetime': false,
    }, SetOptions(merge: true));
  }

  /// Restore previously made purchases (triggers updates on
  /// [_handlePurchaseUpdates], which re-persists entitlement for any
  /// still-valid subscription the store returns).
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

  /// Buy the subscription for [tier] ('pro' or 'premium'), waiting for the
  /// platform store to actually resolve the purchase (success, failure, or
  /// cancellation) before returning - entitlement itself is persisted by
  /// the single listener set up in [initialize], not by this method, so
  /// it's correctly recorded even if the app is killed mid-purchase and
  /// the result only arrives on a later launch.
  Future<void> purchaseSubscription(String tier) async {
    if (!_isAvailable) {
      throw PurchaseUnavailableException(
        'In-app purchases are not available on this device',
      );
    }

    final productId = _productIdsByTier[tier];
    if (productId == null) {
      throw PurchaseUnavailableException('Unknown plan: $tier');
    }

    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw PurchaseUnavailableException(
        'This plan is not yet available for purchase',
      );
    }
    final product = response.productDetails.first;

    final completer = Completer<void>();
    late final StreamSubscription<List<PurchaseDetails>> resultSub;
    resultSub = _inAppPurchase.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        if (purchase.productID != productId || completer.isCompleted) {
          continue;
        }
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            completer.complete();
            break;
          case PurchaseStatus.error:
            completer.completeError(
              purchase.error ?? Exception('Purchase failed'),
            );
            break;
          case PurchaseStatus.canceled:
            completer.completeError(Exception('Purchase canceled'));
            break;
          case PurchaseStatus.pending:
            break;
        }
      }
    });

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      await completer.future;
    } finally {
      await resultSub.cancel();
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
    _subscription?.cancel();
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
