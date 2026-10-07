import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

/// Purchase funnel tracking service
///
/// Tracks the conversion funnel from free users through various purchase stages
class AnalyticsFunnelService {
  factory AnalyticsFunnelService() => _instance;

  AnalyticsFunnelService._internal();
  static final AnalyticsFunnelService _instance =
      AnalyticsFunnelService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Logger _logger = Logger();

  /// Track paywall view
  ///
  /// Called when user views premium paywall
  Future<void> trackPaywallViewed({
    required String paywallId,
    required String triggerContext,
    required String? subscriptionTier,
  }) async {
    try {
      _logger.i('Tracking paywall view: $paywallId from $triggerContext');

      await _analytics.logEvent(
        name: 'paywall_viewed',
        parameters: {
          'paywall_id': paywallId,
          'trigger_context': triggerContext,
          'subscription_tier': subscriptionTier ?? 'free',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Paywall view event logged');
    } catch (e) {
      _logger.e('Failed to track paywall view', error: e);
    }
  }

  /// Track paywall dismissal
  ///
  /// Called when user closes paywall without purchase
  Future<void> trackPaywallDismissed({
    required String paywallId,
    required double timeViewedSeconds,
    required bool scrolledToBottom,
  }) async {
    try {
      _logger.i('Tracking paywall dismissal: $paywallId');

      await _analytics.logEvent(
        name: 'paywall_dismissed',
        parameters: {
          'paywall_id': paywallId,
          'time_viewed': timeViewedSeconds.toStringAsFixed(2),
          'scrolled_to_bottom': scrolledToBottom,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Paywall dismissal event logged');
    } catch (e) {
      _logger.e('Failed to track paywall dismissal', error: e);
    }
  }

  /// Track offer shown
  ///
  /// Called when specific offer/package is displayed
  Future<void> trackOfferShown({
    required String offerId,
    required String offeringId,
    required String packageId,
    required String price,
    required String currency,
    String? promotionText,
  }) async {
    try {
      _logger.i('Tracking offer shown: $packageId');

      await _analytics.logEvent(
        name: 'offer_shown',
        parameters: {
          'offer_id': offerId,
          'offering_id': offeringId,
          'package_id': packageId,
          'price': price,
          'currency': currency,
          'promotion_text': promotionText ?? 'none',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Offer shown event logged');
    } catch (e) {
      _logger.e('Failed to track offer shown', error: e);
    }
  }

  /// Track offer selected
  ///
  /// Called when user taps on an offer to purchase
  Future<void> trackOfferSelected({
    required String offerId,
    required String packageId,
    required String price,
  }) async {
    try {
      _logger.i('Tracking offer selected: $packageId');

      await _analytics.logEvent(
        name: 'offer_selected',
        parameters: {
          'offer_id': offerId,
          'package_id': packageId,
          'price': price,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Offer selected event logged');
    } catch (e) {
      _logger.e('Failed to track offer selected', error: e);
    }
  }

  /// Track purchase initiated
  ///
  /// Called when purchase flow starts
  Future<void> trackPurchaseInitiated({
    required String packageId,
    required String price,
    String? couponCode,
  }) async {
    try {
      _logger.i('Tracking purchase initiated: $packageId');

      await _analytics.logEvent(
        name: 'purchase_initiated',
        parameters: {
          'package_id': packageId,
          'price': price,
          'coupon_code': couponCode ?? 'none',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Purchase initiated event logged');
    } catch (e) {
      _logger.e('Failed to track purchase initiated', error: e);
    }
  }

  /// Track purchase pending
  ///
  /// Called while purchase is processing
  Future<void> trackPurchasePending({
    required String packageId,
    required double elapsedSeconds,
  }) async {
    try {
      _logger.i('Tracking purchase pending: $packageId');

      await _analytics.logEvent(
        name: 'purchase_pending',
        parameters: {
          'package_id': packageId,
          'elapsed_seconds': elapsedSeconds.toStringAsFixed(2),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Purchase pending event logged');
    } catch (e) {
      _logger.e('Failed to track purchase pending', error: e);
    }
  }

  /// Track purchase completed
  ///
  /// Called when purchase succeeds
  Future<void> trackPurchaseCompleted({
    required String packageId,
    required String transactionId,
    required double processingTimeSeconds,
  }) async {
    try {
      _logger.i('Tracking purchase completed: $packageId');

      await _analytics.logEvent(
        name: 'purchase_completed',
        parameters: {
          'package_id': packageId,
          'transaction_id': transactionId,
          'processing_time': processingTimeSeconds.toStringAsFixed(2),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Purchase completed event logged');
    } catch (e) {
      _logger.e('Failed to track purchase completed', error: e);
    }
  }

  /// Track purchase cancelled by user
  ///
  /// Called when user cancels purchase during flow
  Future<void> trackPurchaseCancelled({
    required String packageId,
    required String reason,
    required double timeInFlowSeconds,
  }) async {
    try {
      _logger.i('Tracking purchase cancelled: $packageId');

      await _analytics.logEvent(
        name: 'purchase_cancelled',
        parameters: {
          'package_id': packageId,
          'reason': reason,
          'time_in_flow': timeInFlowSeconds.toStringAsFixed(2),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Purchase cancelled event logged');
    } catch (e) {
      _logger.e('Failed to track purchase cancelled', error: e);
    }
  }

  /// Track purchase failed
  ///
  /// Called when purchase fails with error
  Future<void> trackPurchaseFailed({
    required String packageId,
    required String errorCode,
    required String errorMessage,
    required double timeInFlowSeconds,
  }) async {
    try {
      _logger.i('Tracking purchase failed: $packageId - $errorCode');

      await _analytics.logEvent(
        name: 'purchase_failed',
        parameters: {
          'package_id': packageId,
          'error_code': errorCode,
          'error_message': errorMessage,
          'time_in_flow': timeInFlowSeconds.toStringAsFixed(2),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Purchase failed event logged');
    } catch (e) {
      _logger.e('Failed to track purchase failed', error: e);
    }
  }

  /// Track trial started
  ///
  /// Called when user starts free trial
  Future<void> trackTrialStarted({
    required String trialId,
    required String trialTier,
    required int daysRemaining,
  }) async {
    try {
      _logger.i('Tracking trial started: $trialTier');

      await _analytics.logEvent(
        name: 'trial_started',
        parameters: {
          'trial_id': trialId,
          'trial_tier': trialTier,
          'days_remaining': daysRemaining,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Trial started event logged');
    } catch (e) {
      _logger.e('Failed to track trial started', error: e);
    }
  }

  /// Track trial expires soon
  ///
  /// Called when trial is about to expire
  Future<void> trackTrialExpiringNotification({
    required String trialId,
    required int daysUntilExpiration,
  }) async {
    try {
      _logger
          .i('Tracking trial expiring notification: $daysUntilExpiration days');

      await _analytics.logEvent(
        name: 'trial_expiring_notification_shown',
        parameters: {
          'trial_id': trialId,
          'days_until_expiration': daysUntilExpiration,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Trial expiring notification event logged');
    } catch (e) {
      _logger.e('Failed to track trial expiring notification', error: e);
    }
  }

  /// Track trial expired
  ///
  /// Called when trial period ends
  Future<void> trackTrialExpired({
    required String trialId,
    required bool convertedToPaid,
  }) async {
    try {
      _logger.i('Tracking trial expired: converted=$convertedToPaid');

      await _analytics.logEvent(
        name: 'trial_expired',
        parameters: {
          'trial_id': trialId,
          'converted_to_paid': convertedToPaid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Trial expired event logged');
    } catch (e) {
      _logger.e('Failed to track trial expired', error: e);
    }
  }

  /// Track subscription status change
  ///
  /// Called for any subscription status transition
  Future<void> trackSubscriptionStatusChanged({
    required String subscriptionId,
    required String fromStatus,
    required String toStatus,
    String? reason,
  }) async {
    try {
      _logger.i('Tracking subscription status: $fromStatus → $toStatus');

      await _analytics.logEvent(
        name: 'subscription_status_changed',
        parameters: {
          'subscription_id': subscriptionId,
          'from_status': fromStatus,
          'to_status': toStatus,
          'reason': reason ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Subscription status change event logged');
    } catch (e) {
      _logger.e('Failed to track subscription status change', error: e);
    }
  }

  /// Track feature upsell impression
  ///
  /// Called when premium feature upsell is shown
  Future<void> trackFeatureUpsellShown({
    required String featureName,
    required String subscriptionTier,
    required String context,
  }) async {
    try {
      _logger.i('Tracking feature upsell: $featureName');

      await _analytics.logEvent(
        name: 'feature_upsell_shown',
        parameters: {
          'feature_name': featureName,
          'subscription_tier': subscriptionTier,
          'context': context,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Feature upsell impression event logged');
    } catch (e) {
      _logger.e('Failed to track feature upsell impression', error: e);
    }
  }

  /// Track feature upsell clicked
  ///
  /// Called when user clicks on feature upsell
  Future<void> trackFeatureUpsellClicked({
    required String featureName,
    required String subscriptionTier,
  }) async {
    try {
      _logger.i('Tracking feature upsell click: $featureName');

      await _analytics.logEvent(
        name: 'feature_upsell_clicked',
        parameters: {
          'feature_name': featureName,
          'subscription_tier': subscriptionTier,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Feature upsell click event logged');
    } catch (e) {
      _logger.e('Failed to track feature upsell click', error: e);
    }
  }

  /// Track funnel progress
  ///
  /// Generic method to track any funnel stage
  Future<void> trackFunnelProgress({
    required String funnelName,
    required String stageName,
    required int stageNumber,
    required int totalStages,
    Map<String, dynamic>? customData,
  }) async {
    try {
      _logger.i('Tracking funnel progress: $funnelName - $stageName');

      final parameters = {
        'funnel_name': funnelName,
        'stage_name': stageName,
        'stage_number': stageNumber,
        'total_stages': totalStages,
        'completion_percent':
            ((stageNumber / totalStages) * 100).toStringAsFixed(1),
        'timestamp': DateTime.now().toIso8601String(),
        ...?customData,
      };

      await _analytics.logEvent(
        name: 'funnel_progress',
        parameters: parameters,
      );

      _logger.d('Funnel progress event logged: $funnelName');
    } catch (e) {
      _logger.e('Failed to track funnel progress', error: e);
    }
  }

  /// Track funnel drop-off
  ///
  /// Called when user drops off from funnel
  Future<void> trackFunnelDropoff({
    required String funnelName,
    required String fromStage,
    required String reason,
    Map<String, dynamic>? customData,
  }) async {
    try {
      _logger.i('Tracking funnel dropoff: $funnelName at $fromStage');

      final parameters = {
        'funnel_name': funnelName,
        'from_stage': fromStage,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
        ...?customData,
      };

      await _analytics.logEvent(
        name: 'funnel_dropoff',
        parameters: parameters,
      );

      _logger.d('Funnel dropoff event logged: $funnelName');
    } catch (e) {
      _logger.e('Failed to track funnel dropoff', error: e);
    }
  }
}
