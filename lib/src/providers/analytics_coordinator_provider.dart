import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_engagement_service.dart';
import '../services/analytics_funnel_service.dart';
import '../services/analytics_revenue_service.dart';
import 'analytics_services_provider.dart';

/// Analytics coordinator for orchestrating multi-service events
///
/// Coordinates tracking across multiple analytics services for complex workflows
class AnalyticsCoordinator {
  AnalyticsCoordinator({
    required AnalyticsRevenueService revenueService,
    required AnalyticsEngagementService engagementService,
    required AnalyticsFunnelService funnelService,
  })  : _revenueService = revenueService,
        _engagementService = engagementService,
        _funnelService = funnelService;
  final AnalyticsRevenueService _revenueService;
  final AnalyticsEngagementService _engagementService;
  final AnalyticsFunnelService _funnelService;

  /// Track complete purchase flow end-to-end
  ///
  /// Coordinates all analytics events from paywall view to successful purchase
  Future<void> trackCompletePurchaseFlow({
    required String packageId,
    required String price,
    required String currency,
    required String productId,
    required String subscriptionTier,
    required String transactionId,
    bool isNewUser = false,
    String? couponCode,
  }) async {
    try {
      // Track paywall view
      await _funnelService.trackPaywallViewed(
        paywallId: 'purchase_flow_$packageId',
        triggerContext: isNewUser ? 'onboarding' : 'settings',
        subscriptionTier: subscriptionTier,
      );

      // Track offer selection
      await _funnelService.trackOfferSelected(
        offerId: 'offer_$packageId',
        packageId: packageId,
        price: price,
      );

      // Track purchase initiated
      await _funnelService.trackPurchaseInitiated(
        packageId: packageId,
        price: price,
        couponCode: couponCode,
      );

      // Track subscription purchase
      await _revenueService.trackSubscriptionPurchase(
        productId: productId,
        subscriptionTier: subscriptionTier,
        price: double.parse(price),
        currency: currency,
        transactionId: transactionId,
      );

      // Track purchase completion
      await _funnelService.trackPurchaseCompleted(
        packageId: packageId,
        transactionId: transactionId,
        processingTimeSeconds: 2,
      );

      // Track user subscription property
      await _revenueService.setUserSubscriptionProperty(
        subscriptionTier: subscriptionTier,
        isActive: true,
      );
    } catch (e) {
      // Log error but don't throw - analytics shouldn't break app
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackCompletePurchaseFlow',
      );
    }
  }

  /// Track upgrade flow end-to-end
  Future<void> trackCompleteUpgradeFlow({
    required String fromTier,
    required String toTier,
    required double upgradePrice,
    required String currency,
    required String productId,
    required String transactionId,
  }) async {
    try {
      // Track feature upsell if applicable
      await _funnelService.trackFeatureUpsellShown(
        featureName: 'tier_upgrade',
        subscriptionTier: toTier,
        context: 'settings_upgrade',
      );

      // Track funnel progress
      await _funnelService.trackFunnelProgress(
        funnelName: 'upgrade_flow',
        stageName: 'purchase_initiated',
        stageNumber: 1,
        totalStages: 3,
      );

      // Track upgrade event
      await _revenueService.trackSubscriptionUpgrade(
        fromTier: fromTier,
        toTier: toTier,
        price: upgradePrice,
        currency: currency,
      );

      // Track funnel completion
      await _funnelService.trackFunnelProgress(
        funnelName: 'upgrade_flow',
        stageName: 'purchase_completed',
        stageNumber: 3,
        totalStages: 3,
      );

      // Update user subscription property
      await _revenueService.setUserSubscriptionProperty(
        subscriptionTier: toTier,
        isActive: true,
      );
    } catch (e) {
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackCompleteUpgradeFlow',
      );
    }
  }

  /// Track complete trial-to-paid conversion
  Future<void> trackTrialToPaidConversion({
    required String trialId,
    required String trialTier,
    required String paidTier,
    required double conversionPrice,
    required String currency,
    required String productId,
    required String transactionId,
    required int trialDaysUsed,
  }) async {
    try {
      // Track trial period info
      await _funnelService.trackTrialExpired(
        trialId: trialId,
        convertedToPaid: true,
      );

      // Track conversion event
      await _revenueService.trackTrialConvertedToPaid(
        subscriptionTier: paidTier,
        price: conversionPrice,
        currency: currency,
      );

      // Track revenue
      await _revenueService.trackSubscriptionPurchase(
        productId: productId,
        subscriptionTier: paidTier,
        price: conversionPrice,
        currency: currency,
        transactionId: transactionId,
      );

      // Log engagement milestone
      await _engagementService.trackMilestoneAchieved(
        milestoneId: 'trial_conversion_$trialId',
        milestoneType: 'conversion',
        value: trialDaysUsed,
        milestone: 'Trial to Paid',
      );
    } catch (e) {
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackTrialToPaidConversion',
      );
    }
  }

  /// Track complete churn flow
  Future<void> trackCompleteChurnFlow({
    required String subscriptionTier,
    required int daysActive,
    required String? cancellationReason,
    required double totalSpent,
    required int totalTransactions,
  }) async {
    try {
      // Track cancellation
      await _revenueService.trackSubscriptionCancellation(
        subscriptionTier: subscriptionTier,
        daysActive: daysActive,
        reason: cancellationReason,
      );

      // Track subscription status change
      await _funnelService.trackSubscriptionStatusChanged(
        subscriptionId: 'user_$subscriptionTier',
        fromStatus: 'active',
        toStatus: 'cancelled',
        reason: cancellationReason,
      );

      // Track funnel drop-off
      await _funnelService.trackFunnelDropoff(
        funnelName: 'retention_funnel',
        fromStage: 'active_subscriber',
        reason: cancellationReason ?? 'unknown',
        customData: {
          'total_spent': totalSpent,
          'total_transactions': totalTransactions,
          'days_active': daysActive,
        },
      );

      // Update subscription property
      await _revenueService.setUserSubscriptionProperty(
        subscriptionTier: subscriptionTier,
        isActive: false,
      );
    } catch (e) {
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackCompleteChurnFlow',
      );
    }
  }

  /// Track complete game session with engagement and ratings
  Future<void> trackCompleteGameSession({
    required String gameId,
    required String result,
    required int moves,
    required double durationSeconds,
    required int ratingChange,
    required int newRating,
    required bool isRated,
  }) async {
    try {
      // Track game completion
      await _engagementService.trackGameCompleted(
        gameId: gameId,
        result: result,
        movesCount: moves,
        durationSeconds: durationSeconds,
        ratingChangePoints: ratingChange,
      );

      // Track rating change if game affected rating
      if (ratingChange != 0) {
        await _engagementService.trackRatingChange(
          userId: 'current_user',
          oldRating: newRating - ratingChange,
          newRating: newRating,
          reason: 'game_completion',
        );

        // Check for rating milestones
        if (newRating % 200 == 0) {
          await _engagementService.trackMilestoneAchieved(
            milestoneId: 'rating_$newRating',
            milestoneType: 'rating',
            value: newRating,
            milestone: 'Rating Milestone',
          );
        }
      }

      // Track engagement
      await _engagementService.trackFeatureUsed(
        featureName: 'online_game',
        featureCategory: 'gameplay',
        customData: {
          'result': result,
          'is_rated': isRated,
          'moves': moves,
        },
      );
    } catch (e) {
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackCompleteGameSession',
      );
    }
  }

  /// Track premium feature access with upsell tracking
  Future<void> trackPremiumFeatureAccessWithUpsell({
    required String featureName,
    required String subscriptionTier,
    required bool hasAccess,
  }) async {
    try {
      if (hasAccess) {
        // User has access - track feature usage
        await _revenueService.trackPremiumFeatureAccess(
          featureName: featureName,
          subscriptionTier: subscriptionTier,
        );

        // Track engagement
        await _engagementService.trackFeatureUsed(
          featureName: featureName,
          featureCategory: 'premium',
        );
      } else {
        // User doesn't have access - track locked feature
        await _revenueService.trackPremiumFeatureLocked(
          featureName: featureName,
          suggestedTier: _getSuggestedTierForFeature(featureName),
        );

        // Track upsell impression
        await _funnelService.trackFeatureUpsellShown(
          featureName: featureName,
          subscriptionTier: subscriptionTier,
          context: 'feature_access_attempt',
        );
      }
    } catch (e) {
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackPremiumFeatureAccessWithUpsell',
      );
    }
  }

  /// Get suggested tier for a feature
  String _getSuggestedTierForFeature(String featureName) {
    // This would be moved to a feature config in production
    const featureTiers = {
      'advanced_analysis': 'pro',
      'custom_training': 'pro',
      'unlimited_puzzles': 'pro',
      'ai_coach': 'elite',
      'priority_support': 'elite',
    };
    return featureTiers[featureName] ?? 'pro';
  }

  /// Track purchase failure with recovery suggestions
  Future<void> trackPurchaseFailureWithRecovery({
    required String packageId,
    required String price,
    required String errorCode,
    required String errorMessage,
    required bool isNetworkError,
    String? recoveryAction,
  }) async {
    try {
      // Track purchase failure
      await _revenueService.trackPurchaseFailure(
        productId: packageId,
        subscriptionTier: 'unknown',
        errorCode: errorCode,
        errorMessage: errorMessage,
        isNetworkError: isNetworkError,
      );

      // Track funnel drop-off
      await _funnelService.trackFunnelDropoff(
        funnelName: 'purchase_funnel',
        fromStage: 'payment_processing',
        reason: errorCode,
        customData: {
          'is_network_error': isNetworkError,
          'recovery_action': recoveryAction ?? 'retry_suggested',
        },
      );

      // Track error in engagement
      await _engagementService.trackErrorOccurred(
        errorCode: errorCode,
        errorMessage: errorMessage,
        errorContext: 'purchase_flow',
        errorDetails: isNetworkError ? 'Network error' : 'Payment error',
      );
    } catch (e) {
      await _engagementService.trackErrorOccurred(
        errorCode: 'ANALYTICS_COORDINATOR_ERROR',
        errorMessage: e.toString(),
        errorContext: 'trackPurchaseFailureWithRecovery',
      );
    }
  }
}

/// Analytics coordinator provider
final analyticsCoordinatorProvider = Provider<AnalyticsCoordinator>((ref) {
  final revenueService = ref.watch(analyticsRevenueServiceProvider);
  final engagementService = ref.watch(analyticsEngagementServiceProvider);
  final funnelService = ref.watch(analyticsFunnelServiceProvider);

  return AnalyticsCoordinator(
    revenueService: revenueService,
    engagementService: engagementService,
    funnelService: funnelService,
  );
});
