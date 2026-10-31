import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cosmetic_catalog.dart';

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
        } else if (ChessCosmeticCatalog.purchasableProductIds.contains(
          purchaseDetails.productID,
        )) {
          await _persistCosmeticPurchase(purchaseDetails.productID);
        }
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// KNOWN CLIENT-TRUST GAP (documented, not fixed here - see
  /// firestore.rules' matching comment on users/{userId}): this writes
  /// the entitlement directly from the client with no server-side purchase
  /// receipt verification at all - there is no Cloud Function anywhere in
  /// this app (checked functions/src/*.js) that calls the App Store Server
  /// API / Play Developer API to confirm [purchaseDetails] was a real
  /// purchase before granting it. Any signed-in user can currently write
  /// 'premium'/'pro' + a far-future subscriptionExpiry (or isLifetime:
  /// true) straight into their own users/{uid} doc and
  /// feature_gating_service.dart will honor it immediately, since it only
  /// ever reads these same fields back - a genuine monetization bypass,
  /// not just an theoretical one. Closing it for real needs a receipt-
  /// verifying Cloud Function (Admin SDK write, bypassing rules) plus a
  /// firestore.rules change blocking these three fields from a normal
  /// client write - deliberately not done in this pass, since it would
  /// need App Store/Play credentials and Cloud Functions deploy/test
  /// ability this sandbox doesn't have, and locking the fields down here
  /// without that server-side replacement would break every real purchase
  /// instead of fixing the bypass. Same documented-but-unfixed category as
  /// this app's other self-reported purchase fields (see
  /// firebase_auth_service.dart's account/profile writes).
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

  /// Records a one-time cosmetic skin purchase on the user's own doc.
  /// Same documented client-trust gap as [_persistEntitlement] (no
  /// server-side receipt verification yet).
  Future<void> _persistCosmeticPurchase(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'purchasedCosmeticProductIds': FieldValue.arrayUnion([productId]),
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
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds.toSet());
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
    await _buyNonConsumable(productId);
  }

  /// Buy a one-time cosmetic skin ([productId] must be one of
  /// [ChessCosmeticCatalog.purchasableProductIds]). Same flow as
  /// [purchaseSubscription]: waits for the store's result; ownership is
  /// persisted by the [initialize] listener.
  Future<void> purchaseCosmetic(String productId) async {
    if (!_isAvailable) {
      throw PurchaseUnavailableException(
        'In-app purchases are not available on this device',
      );
    }
    if (!ChessCosmeticCatalog.purchasableProductIds.contains(productId)) {
      throw PurchaseUnavailableException('Unknown item: $productId');
    }
    await _buyNonConsumable(productId);
  }

  Future<void> _buyNonConsumable(String productId) async {
    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null) {
      // A real store/network error querying the product - distinct from
      // the product simply not existing yet, so this doesn't get
      // reported as "not yet available" (which would hide a genuine
      // configuration/connectivity problem behind an expected message).
      throw PurchaseUnavailableException(
        'Could not reach the store: ${response.error}',
      );
    }
    if (response.productDetails.isEmpty) {
      // The query succeeded but returned no matching product - either
      // this plan is genuinely unreleased, or productId doesn't match
      // what's registered in App Store Connect / Play Console. Logging
      // the id here is what makes that second case diagnosable instead
      // of silently indistinguishable from the first.
      print(
        'Product not found in store: $productId '
        '(notFoundIDs: ${response.notFoundIDs})',
      );
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
