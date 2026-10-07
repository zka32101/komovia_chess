import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics.freezed.dart';
part 'analytics.g.dart';

/// Analytics event types
enum AnalyticsEventType {
  // Authentication events
  userSignUp('user_sign_up'),
  userLogin('user_login'),
  userLogout('user_logout'),

  // Game events
  gameStarted('game_started'),
  gameCompleted('game_completed'),
  puzzleSolved('puzzle_solved'),
  puzzleFailed('puzzle_failed'),

  // Multiplayer events
  matchmakingStarted('matchmaking_started'),
  matchFound('match_found'),
  matchTimeout('match_timeout'),

  // Subscription events
  paywalShown('paywallShown'),
  subscriptionPurchased('subscription_purchased'),
  subscriptionCancelled('subscription_cancelled'),
  subscriptionRenewed('subscription_renewed'),
  trialStarted('trial_started'),
  trialEnded('trial_ended'),

  // Feature usage events
  premiumFeatureUsed('premium_feature_used'),
  featureExplored('feature_explored'),

  // UI events
  screenViewed('screen_viewed'),
  buttonTapped('button_tapped'),

  // Error events
  errorOccurred('error_occurred'),

  // Custom events
  ratingChanged('rating_changed'),
  achievementUnlocked('achievement_unlocked');

  final String analyticsName;
  const AnalyticsEventType(this.analyticsName);
}

/// Analytics event model
@freezed
class AnalyticsEvent with _$AnalyticsEvent {
  const factory AnalyticsEvent({
    required String eventName,
    required AnalyticsEventType eventType,
    required DateTime timestamp,
    required Map<String, dynamic> parameters,
    String? userId,
    String? sessionId,
  }) = _AnalyticsEvent;

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsEventFromJson(json);
}

/// User property for analytics
@freezed
class UserAnalyticsProperty with _$UserAnalyticsProperty {
  const factory UserAnalyticsProperty({
    required String userId,
    required String propertyName,
    required dynamic propertyValue,
    required DateTime setAt,
  }) = _UserAnalyticsProperty;

  factory UserAnalyticsProperty.fromJson(Map<String, dynamic> json) =>
      _$UserAnalyticsPropertyFromJson(json);
}

/// Game analytics data
@freezed
class GameAnalyticsData with _$GameAnalyticsData {
  const factory GameAnalyticsData({
    required String gameId,
    required String gameType, // 'puzzle', 'cpu', 'online_pvp'
    required int duration, // milliseconds
    required bool won,
    required int? ratingBefore,
    required int? ratingAfter,
    required String timeControl, // '3min', '5min', '10min', 'unlimited'
    required int moveCount,
    required String? result, // 'checkmate', 'resignation', 'timeout', 'draw'
  }) = _GameAnalyticsData;

  factory GameAnalyticsData.fromJson(Map<String, dynamic> json) =>
      _$GameAnalyticsDataFromJson(json);
}

/// Screen view tracking
@freezed
class ScreenViewData with _$ScreenViewData {
  const factory ScreenViewData({
    required String screenName,
    required String screenClass,
    required DateTime viewedAt,
    Duration? timeSpent,
    Map<String, dynamic>? customData,
  }) = _ScreenViewData;

  factory ScreenViewData.fromJson(Map<String, dynamic> json) =>
      _$ScreenViewDataFromJson(json);
}

/// Analytics session
@freezed
class AnalyticsSession with _$AnalyticsSession {
  const factory AnalyticsSession({
    required String sessionId,
    required String userId,
    required DateTime startTime,
    required List<AnalyticsEvent> events,
    required int eventCount,
    DateTime? endTime,
  }) = _AnalyticsSession;
  const AnalyticsSession._();

  factory AnalyticsSession.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsSessionFromJson(json);

  /// Get session duration
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }
}

/// Cohort analysis
@freezed
class CohortAnalytics with _$CohortAnalytics {
  const factory CohortAnalytics({
    required String cohortId,
    required DateTime cohortDate,
    required int userCount,
    required int activeUsers,
    required int retainedUsers,
    required double retentionRate,
    required int totalGamesPlayed,
    required double averageSessionDuration,
  }) = _CohortAnalytics;

  factory CohortAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CohortAnalyticsFromJson(json);
}

/// User engagement metrics
@freezed
class EngagementMetrics with _$EngagementMetrics {
  const factory EngagementMetrics({
    required String userId,
    required int totalSessions,
    required int totalGamesPlayed,
    required int premiumFeaturesUsed,
    required double averageSessionDuration,
    required DateTime lastActiveAt,
    required int daysSinceLastActive,
    required bool isChurned,
  }) = _EngagementMetrics;

  factory EngagementMetrics.fromJson(Map<String, dynamic> json) =>
      _$EngagementMetricsFromJson(json);
}
