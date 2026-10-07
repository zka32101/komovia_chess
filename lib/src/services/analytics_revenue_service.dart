import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

/// Revenue and purchase analytics tracking service
///
/// Tracks subscription purchases, upgrades, downgrades, and cancellations
/// for monetization analytics
class AnalyticsRevenueService {
  factory AnalyticsRevenueService() => _instance;

  AnalyticsRevenueService._internal();
  static final AnalyticsRevenueService _instance =
      AnalyticsRevenueService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Logger _logger = Logger();

  /// Track subscription purchase event
  ///
  /// Called when user successfully purchases a subscription
  Future<void> trackSubscriptionPurchase({
    required String productId,
    required String subscriptionTier,
    required double price,
    required String currency,
    String? transactionId,
  }) async {
    try {
      _logger.i(
          'Tracking subscription purchase: $subscriptionTier for $price $currency');

      await _analytics.logEvent(
        name: 'subscription_purchase',
        parameters: {
          'product_id': productId,
          'subscription_tier': subscriptionTier,
          'value': price,
          'currency': currency,
          'transaction_id': transactionId ?? 'unknown',
        },
      );

      // Also log as purchase event for Firebase revenue tracking
      await _analytics.logPurchase(
        value: price,
        currency: currency,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: 'Premium Subscription - $subscriptionTier',
            itemCategory: 'subscription',
            itemVariant: subscriptionTier,
            price: price,
            quantity: 1,
          ),
        ],
      );

      _logger.d('Purchase event logged successfully');
    } catch (e) {
      _logger.e('Failed to track subscription purchase', error: e);
    }
  }

  /// Track subscription upgrade event
  ///
  /// Called when user upgrades from one tier to another
  Future<void> trackSubscriptionUpgrade({
    required String fromTier,
    required String toTier,
    required double price,
    required String currency,
  }) async {
    try {
      _logger.i('Tracking subscription upgrade: $fromTier → $toTier');

      await _analytics.logEvent(
        name: 'subscription_upgrade',
        parameters: {
          'from_tier': fromTier,
          'to_tier': toTier,
          'value': price,
          'currency': currency,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Upgrade event logged successfully');
    } catch (e) {
      _logger.e('Failed to track subscription upgrade', error: e);
    }
  }

  /// Track subscription downgrade event
  ///
  /// Called when user downgrades to a lower tier
  Future<void> trackSubscriptionDowngrade({
    required String fromTier,
    required String toTier,
  }) async {
    try {
      _logger.i('Tracking subscription downgrade: $fromTier → $toTier');

      await _analytics.logEvent(
        name: 'subscription_downgrade',
        parameters: {
          'from_tier': fromTier,
          'to_tier': toTier,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Downgrade event logged successfully');
    } catch (e) {
      _logger.e('Failed to track subscription downgrade', error: e);
    }
  }

  /// Track subscription cancellation
  ///
  /// Called when user cancels their subscription
  Future<void> trackSubscriptionCancellation({
    required String subscriptionTier,
    required int daysActive,
    String? reason,
  }) async {
    try {
      _logger.i(
          'Tracking subscription cancellation: $subscriptionTier after $daysActive days');

      await _analytics.logEvent(
        name: 'subscription_cancellation',
        parameters: {
          'subscription_tier': subscriptionTier,
          'days_active': daysActive,
          'reason': reason ?? 'not_specified',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Cancellation event logged successfully');
    } catch (e) {
      _logger.e('Failed to track subscription cancellation', error: e);
    }
  }

  /// Track subscription renewal event
  ///
  /// Called when subscription automatically renews
  Future<void> trackSubscriptionRenewal({
    required String subscriptionTier,
    required double renewalPrice,
    required String currency,
    String? transactionId,
  }) async {
    try {
      _logger.i(
          'Tracking subscription renewal: $subscriptionTier for $renewalPrice $currency');

      await _analytics.logEvent(
        name: 'subscription_renewal',
        parameters: {
          'subscription_tier': subscriptionTier,
          'value': renewalPrice,
          'currency': currency,
          'transaction_id': transactionId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Renewal event logged successfully');
    } catch (e) {
      _logger.e('Failed to track subscription renewal', error: e);
    }
  }

  /// Track trial started event
  ///
  /// Called when user starts a free trial
  Future<void> trackTrialStarted({
    required String trialTier,
    required int daysRemaining,
  }) async {
    try {
      _logger.i('Tracking trial started: $trialTier for $daysRemaining days');

      await _analytics.logEvent(
        name: 'trial_started',
        parameters: {
          'trial_tier': trialTier,
          'days_remaining': daysRemaining,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Trial started event logged successfully');
    } catch (e) {
      _logger.e('Failed to track trial started', error: e);
    }
  }

  /// Track trial converted to paid
  ///
  /// Called when trial user converts to paid subscription
  Future<void> trackTrialConvertedToPaid({
    required String subscriptionTier,
    required double price,
    required String currency,
  }) async {
    try {
      _logger.i(
          'Tracking trial conversion: $subscriptionTier for $price $currency');

      await _analytics.logEvent(
        name: 'trial_converted_to_paid',
        parameters: {
          'subscription_tier': subscriptionTier,
          'value': price,
          'currency': currency,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Trial conversion event logged successfully');
    } catch (e) {
      _logger.e('Failed to track trial conversion', error: e);
    }
  }

  /// Track purchase attempt failure
  ///
  /// Called when a purchase attempt fails
  Future<void> trackPurchaseFailure({
    required String productId,
    required String subscriptionTier,
    required String errorCode,
    required String errorMessage,
    bool isNetworkError = false,
  }) async {
    try {
      _logger.i('Tracking purchase failure: $subscriptionTier - $errorCode');

      await _analytics.logEvent(
        name: 'purchase_failed',
        parameters: {
          'product_id': productId,
          'subscription_tier': subscriptionTier,
          'error_code': errorCode,
          'error_message': errorMessage,
          'is_network_error': isNetworkError,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Purchase failure event logged successfully');
    } catch (e) {
      _logger.e('Failed to track purchase failure', error: e);
    }
  }

  /// Set user subscription property
  ///
  /// Sets user-level subscription status for segmentation
  Future<void> setUserSubscriptionProperty({
    required String subscriptionTier,
    bool isActive = true,
  }) async {
    try {
      await _analytics.setUserProperty(
        name: 'subscription_tier',
        value: subscriptionTier,
      );

      await _analytics.setUserProperty(
        name: 'subscription_active',
        value: isActive.toString(),
      );

      _logger.d(
          'User subscription properties set: $subscriptionTier (active: $isActive)');
    } catch (e) {
      _logger.e('Failed to set user subscription property', error: e);
    }
  }

  /// Track premium feature access
  ///
  /// Called when user accesses a premium feature
  Future<void> trackPremiumFeatureAccess({
    required String featureName,
    required String subscriptionTier,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'premium_feature_accessed',
        parameters: {
          'feature_name': featureName,
          'subscription_tier': subscriptionTier,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Premium feature access logged: $featureName');
    } catch (e) {
      _logger.e('Failed to track premium feature access', error: e);
    }
  }

  /// Track premium feature attempted without access
  ///
  /// Called when free user attempts to access premium feature
  Future<void> trackPremiumFeatureLocked({
    required String featureName,
    String? suggestedTier,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'premium_feature_locked',
        parameters: {
          'feature_name': featureName,
          'suggested_tier': suggestedTier ?? 'pro',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Premium feature locked event: $featureName');
    } catch (e) {
      _logger.e('Failed to track premium feature locked', error: e);
    }
  }
}
