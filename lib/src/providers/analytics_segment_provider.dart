import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_revenue_service.dart';

/// User segment for analytics purposes
enum UserSegment {
  /// User has never purchased
  freeTrial,

  /// User has active Pro subscription
  proSubscriber,

  /// User has active Elite subscription
  eliteSubscriber,

  /// User had subscription but cancelled
  churnedSubscriber,

  /// User with high engagement on free plan
  highEngagementFree,

  /// User with low engagement
  lowEngagement,
}

/// User segment provider
///
/// Determines which segment a user belongs to based on subscription status
/// and engagement metrics
final userSegmentProvider = StreamProvider<Set<UserSegment>>((ref) {
  // This would typically combine data from:
  // - Subscription status (from revenuateProvider)
  // - User engagement metrics (from analytics database)
  // - Purchase history
  // - Last activity timestamp

  // For now, return a stream that updates based on subscription changes
  final segments = <UserSegment>{};

  // In a full implementation, this would listen to multiple providers
  // and compute segments dynamically
  // Example:
  // final subscription = ref.watch(subscriptionTierProvider);
  // final purchaseHistory = ref.watch(purchaseHistoryProvider);

  return Stream.value(segments);
});

/// User lifecycle stage
enum UserLifecycleStage {
  /// Just signed up
  new_user,

  /// Actively using app
  active,

  /// Hasn't opened app in 7 days
  dormant,

  /// Hasn't opened app in 30 days
  inactive,

  /// Customer who cancelled
  churned,
}

/// User lifecycle stage provider
///
/// Determines user's lifecycle stage based on activity patterns
final userLifecycleStageProvider =
    StreamProvider<UserLifecycleStage>((ref) async* {
  // This would typically:
  // - Track last activity timestamp
  // - Compare with current time
  // - Check subscription status
  // - Check purchase history

  // For now, return active as default
  yield UserLifecycleStage.active;
});

/// Engagement level based on app usage
enum EngagementLevel {
  /// High: Uses app daily
  high,

  /// Medium: Uses app 2-3x per week
  medium,

  /// Low: Uses app occasionally
  low,

  /// None: Hasn't opened in 30+ days
  none,
}

/// Calculate engagement level
///
/// Based on puzzle completions, games played, and login frequency
final engagementLevelProvider = StreamProvider<EngagementLevel>((ref) async* {
  // This would track:
  // - Puzzles completed in last 7 days
  // - Games played in last 7 days
  // - Daily login streak
  // - Time spent in app

  yield EngagementLevel.medium;
});

/// Premium feature adoption level
enum PremiumAdoptionLevel {
  /// Has never used any premium features
  none,

  /// Tried some premium features but didn't convert
  trial,

  /// Converted to paid, actively using premium features
  active,

  /// Churned from premium
  churned,
}

/// Premium feature adoption provider
final premiumAdoptionLevelProvider =
    StreamProvider<PremiumAdoptionLevel>((ref) async* {
  // Track:
  // - Premium features accessed
  // - Time in premium features
  // - Conversion funnel stage
  // - Cancellation reason

  yield PremiumAdoptionLevel.none;
});

/// Cohort for A/B testing
class UserCohort {
  UserCohort({
    required this.id,
    required this.name,
    required this.createdAt,
    this.experimentId,
  });
  final String id;
  final String name;
  final DateTime createdAt;
  final String? experimentId;
}

/// User cohort assignment provider
///
/// For tracking A/B tests and feature rollouts
final userCohortProvider = StreamProvider<UserCohort>((ref) async* {
  // Assign users to cohorts based on:
  // - User ID (deterministic hashing)
  // - Feature flags
  // - Experiment configuration

  yield UserCohort(
    id: 'control',
    name: 'Control Group',
    createdAt: DateTime.now(),
  );
});

/// Geographic location for segmentation
class UserLocation {
  UserLocation({
    this.country,
    this.region,
    this.timezone,
  });
  final String? country;
  final String? region;
  final String? timezone;
}

/// User location provider
///
/// For geographic segmentation and localization insights
final userLocationProvider = FutureProvider<UserLocation>((ref) async {
  // This would typically:
  // - Use device locale/timezone
  // - Use IP geolocation
  // - Use user's manually set location (if available)

  return UserLocation(
    country: 'US',
    timezone: 'UTC',
  );
});

/// Device information for segmentation
class DeviceInfo {
  DeviceInfo({
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.isTablet,
  });
  final String platform; // iOS or Android
  final String osVersion;
  final String appVersion;
  final bool isTablet;
}

/// Device info provider
///
/// For device-specific segmentation and compatibility tracking
final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  // This would gather:
  // - Platform (iOS/Android)
  // - OS version
  // - App version
  // - Device type
  // - Screen size

  return DeviceInfo(
    platform: 'iOS',
    osVersion: '14.0',
    appVersion: '1.0.0',
    isTablet: false,
  );
});

/// User retention cohort
class RetentionCohort {
  RetentionCohort({
    required this.signupDate,
    required this.daysActive,
    required this.retention30d,
    required this.retention90d,
  });
  final DateTime signupDate;
  final int daysActive;
  final double retention30d;
  final double retention90d;
}

/// Retention cohort provider
///
/// For tracking user retention over time
final retentionCohortProvider = FutureProvider<RetentionCohort>((ref) async {
  // Calculate retention based on:
  // - Days since signup
  // - Active days
  // - Churn patterns

  return RetentionCohort(
    signupDate: DateTime.now().subtract(const Duration(days: 30)),
    daysActive: 15,
    retention30d: 0.8,
    retention90d: 0.6,
  );
});

/// Revenue segment for monetization analysis
enum RevenueSegment {
  /// Never purchased
  never,

  /// Trial user
  trial,

  /// Paid user (active subscription)
  paid,

  /// Churned (was paid, now cancelled)
  churned,

  /// High value (Elite or long-term customer)
  highValue,
}

/// Revenue segment provider
final revenueSegmentProvider = StreamProvider<RevenueSegment>((ref) async* {
  // Determine segment based on:
  // - Subscription status
  // - Lifetime value
  // - Subscription history
  // - Churn status

  yield RevenueSegment.never;
});

/// Update user segment in analytics
///
/// Call this when user's segment changes (e.g., when they purchase)
Future<void> updateUserSegment(WidgetRef ref, Set<UserSegment> segments) async {
  final analyticsService = AnalyticsRevenueService();

  // Set user properties for each segment
  for (final segment in segments) {
    await analyticsService.setUserSubscriptionProperty(
      subscriptionTier: segment.name,
      isActive: true,
    );
  }
}
