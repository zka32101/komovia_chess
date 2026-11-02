import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:komovia_core/komovia_core.dart'
    show SubscriptionPlan, PurchaseUnavailableException;
import '../models/avatar_frames.dart';
import '../models/cosmetic_catalog.dart';

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
  /// Each tier is sold in two billing periods (monthly / annual). The
  /// pro/premium feature difference is unchanged; only the period varies.
  static const Map<String, Map<BillingPeriod, String>> _productIdsByTier = {
    'pro': {
      BillingPeriod.monthly: 'chess_pro_monthly',
      BillingPeriod.annual: 'chess_pro_annual',
    },
    'premium': {
      BillingPeriod.monthly: 'chess_premium_monthly',
      BillingPeriod.annual: 'chess_premium_annual',
      // Lifetime (one-time, never expires) is offered on the top 'premium'
      // tier ONLY - deliberately not on 'pro', so the lower tier and the
      // permanent top-tier purchase stay clearly distinct.
      BillingPeriod.lifetime: 'chess_premium_lifetime',
    },
  };

  /// Fallback display prices (JPY) used when the store's localized price
  /// isn't available. Same for both tiers and unified with the sibling
  /// Komovia apps (komovia_go: ¥300/month, ¥2,400/year). The real price is
  /// whatever is configured in App Store Connect / Play Console.
  static const Map<BillingPeriod, int> fallbackPriceYenByPeriod = {
    BillingPeriod.monthly: 300,
    BillingPeriod.annual: 2400,
    BillingPeriod.lifetime: 9800,
  };

  /// Billing periods actually sold for [tier] (lifetime is premium-only).
  static List<BillingPeriod> periodsFor(String tier) =>
      _productIdsByTier[tier]?.keys.toList() ?? const [];

  /// Fallback display price (JPY) for the AI分析プラン (monthly).
  static const int aiAnalysisPlanMonthlyFallbackPriceYen = 990;

  /// Product id for [tier] + [period], or null for an unknown tier.
  static String? productIdFor(String tier, BillingPeriod period) =>
      _productIdsByTier[tier]?[period];

  /// Every pro/premium subscription product id (all tiers, all periods).
  static List<String> get allSubscriptionProductIds => [
    for (final byPeriod in _productIdsByTier.values) ...byPeriod.values,
  ];

  /// Reverse lookup: which tier/period a store product id belongs to.
  static ({String tier, BillingPeriod period})? planForProductId(
    String productId,
  ) {
    for (final tierEntry in _productIdsByTier.entries) {
      for (final periodEntry in tierEntry.value.entries) {
        if (periodEntry.value == productId) {
          return (tier: tierEntry.key, period: periodEntry.key);
        }
      }
    }
    return null;
  }

  /// Product id for the AI分析プラン (AI Analysis Plan, ¥990/month - see
  /// [aiAnalysisPlanMonthlyFallbackPriceYen]) - a
  /// separately purchasable subscription, independent of the 'pro'/
  /// 'premium' tiers above (a user may hold either, both, or neither).
  /// Deliberately NOT part of [_productIdsByTier]: buying it must never
  /// overwrite `subscriptionTier`. Its entitlement lives in its own
  /// `aiAnalysisPlanExpiry` field on users/{uid}. Monthly only for now.
  static const String aiAnalysisPlanMonthlyProductId =
      'chess_ai_analysis_monthly';

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
        final plan = planForProductId(purchaseDetails.productID);
        if (plan != null) {
          await _persistEntitlement(plan.tier, plan.period);
        } else if (purchaseDetails.productID ==
            aiAnalysisPlanMonthlyProductId) {
          await _persistAiAnalysisPlan();
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
  Future<void> _persistEntitlement(String tier, BillingPeriod period) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final length = period.entitlementLength;
    if (length == null) {
      await userRef.set(
        lifetimeEntitlementUpdate(tier),
        SetOptions(merge: true),
      );
      return;
    }
    // Never downgrade a lifetime purchaser back to an expiring plan (e.g.
    // a restore that also redelivers an old monthly receipt).
    final existing = await userRef.get();
    if (existing.data()?['isLifetime'] == true) return;
    final expiry = DateTime.now().add(length);
    await userRef.set({
      'subscriptionTier': tier,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'isLifetime': false,
    }, SetOptions(merge: true));
  }

  /// Firestore fields written when a lifetime purchase resolves: permanent
  /// [tier] entitlement plus every lifetime-exclusive avatar frame added to
  /// the user's unlocked set (komovia_core [AvatarFrame.lifetimeExclusive]:
  /// the one documented exception to "frames are earned, never bought").
  static Map<String, Object?> lifetimeEntitlementUpdate(String tier) => {
    'subscriptionTier': tier,
    'subscriptionExpiry': null,
    'isLifetime': true,
    'unlockedFrameIds': FieldValue.arrayUnion(lifetimeExclusiveFrameIds),
  };

  /// Records the AI分析プラン entitlement in its own field so it never
  /// clobbers the separate pro/premium `subscriptionTier`. Same documented
  /// client-trust gap as [_persistEntitlement].
  Future<void> _persistAiAnalysisPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final expiry = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(user.uid).set({
      'aiAnalysisPlanExpiry': Timestamp.fromDate(expiry),
    }, SetOptions(merge: true));
  }

  /// Buy the AI分析プラン (monthly). Same flow as [purchaseSubscription].
  Future<void> purchaseAiAnalysisPlan() async {
    if (!_isAvailable) {
      throw PurchaseUnavailableException(
        'In-app purchases are not available on this device',
      );
    }
    await _buyNonConsumable(aiAnalysisPlanMonthlyProductId);
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
  Future<void> purchaseSubscription(
    String tier, {
    BillingPeriod period = BillingPeriod.monthly,
  }) async {
    if (!_isAvailable) {
      throw PurchaseUnavailableException(
        'In-app purchases are not available on this device',
      );
    }

    final productId = productIdFor(tier, period);
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

/// Billing period of a pro/premium subscription (independent of the tier).
/// Names mirror komovia_core's [SubscriptionPlan] (monthly/annual/lifetime).
enum BillingPeriod {
  monthly(Duration(days: 30)),
  annual(Duration(days: 365)),

  /// One-time purchase that never expires (premium tier only).
  lifetime(null);

  /// How long one purchase/renewal grants the entitlement for; null for
  /// [lifetime] (never expires).
  final Duration? entitlementLength;
  const BillingPeriod(this.entitlementLength);

  /// The equivalent komovia_core plan.
  SubscriptionPlan get plan => SubscriptionPlan.values.byName(name);
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
