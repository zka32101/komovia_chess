import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_models.freezed.dart';
part 'analytics_models.g.dart';

@freezed
abstract class PerformanceMetrics with _$PerformanceMetrics {
  const factory PerformanceMetrics({
    required String operationName,
    required int durationMs,
    required DateTime timestamp,
    required bool success,
    String? errorType,
    @Default({}) Map<String, dynamic> metadata,
  }) = _PerformanceMetrics;

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) =>
      _$PerformanceMetricsFromJson(json);
}

@freezed
abstract class QueryPerformanceTrend with _$QueryPerformanceTrend {
  const factory QueryPerformanceTrend({
    required String queryType,
    required int p50Latency,
    required int p95Latency,
    required int p99Latency,
    required double successRate,
    required DateTime period,
    required int sampleCount,
  }) = _QueryPerformanceTrend;

  factory QueryPerformanceTrend.fromJson(Map<String, dynamic> json) =>
      _$QueryPerformanceTrendFromJson(json);
}

@freezed
abstract class UserEngagementMetrics with _$UserEngagementMetrics {
  const factory UserEngagementMetrics({
    required String userId,
    required int sessionsCount,
    required Duration totalPlayTime,
    required DateTime lastActive,
    required bool churnedUser,
    @Default({}) Map<String, int> featureUsage,
  }) = _UserEngagementMetrics;

  factory UserEngagementMetrics.fromJson(Map<String, dynamic> json) =>
      _$UserEngagementMetricsFromJson(json);
}

@freezed
abstract class CacheAnalytics with _$CacheAnalytics {
  const factory CacheAnalytics({
    required String cacheName,
    required int hitCount,
    required int missCount,
    required double hitRate,
    required Duration avgCacheLookup,
    required int evictionCount,
    required DateTime period,
  }) = _CacheAnalytics;

  factory CacheAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CacheAnalyticsFromJson(json);
}

@freezed
abstract class CompetitiveFeatureStats with _$CompetitiveFeatureStats {
  const factory CompetitiveFeatureStats({
    required String feature,
    required int activeUsers,
    required int totalInteractions,
    required double adoptionRate,
    required DateTime period,
    @Default({}) Map<String, dynamic> topMetrics,
  }) = _CompetitiveFeatureStats;

  factory CompetitiveFeatureStats.fromJson(Map<String, dynamic> json) =>
      _$CompetitiveFeatureStatsFromJson(json);
}

@freezed
abstract class RetentionMetrics with _$RetentionMetrics {
  const factory RetentionMetrics({
    required String cohortDate,
    required int cohortSize,
    required double day1Retention,
    required double day7Retention,
    required double day30Retention,
    @Default({}) Map<String, int> retentionByDay,
  }) = _RetentionMetrics;

  factory RetentionMetrics.fromJson(Map<String, dynamic> json) =>
      _$RetentionMetricsFromJson(json);
}

@freezed
abstract class BuildMetrics with _$BuildMetrics {
  const factory BuildMetrics({
    required String version,
    required int apkSizeMb,
    required int codeSizeMb,
    required int assetsSizeMb,
    required int librariesSizeMb,
    required DateTime buildDate,
    @Default({}) Map<String, dynamic> optimizationMetrics,
  }) = _BuildMetrics;

  factory BuildMetrics.fromJson(Map<String, dynamic> json) =>
      _$BuildMetricsFromJson(json);
}

@freezed
abstract class DashboardKPI with _$DashboardKPI {
  const factory DashboardKPI({
    required String label,
    required String value,
    required String unit,
    String? trend,
    String? trendPercent,
  }) = _DashboardKPI;

  factory DashboardKPI.fromJson(Map<String, dynamic> json) =>
      _$DashboardKPIFromJson(json);
}

// Player-focused Analytics Models

/// Game statistics for a player
@freezed
abstract class GameStats with _$GameStats {
  const factory GameStats({
    required int totalGames,
    required int wins,
    required int losses,
    required int draws,
    required double winRate,
    required double averageAccuracy,
    required int totalMoves,
    required DateTime lastGameDate,
  }) = _GameStats;

  factory GameStats.fromJson(Map<String, dynamic> json) =>
      _$GameStatsFromJson(json);
}

/// Performance metrics over time
@freezed
abstract class PerformanceMetric with _$PerformanceMetric {
  const factory PerformanceMetric({
    required DateTime timestamp,
    required double accuracy,
    required double rating,
    required int gameCount,
    required String difficulty,
  }) = _PerformanceMetric;

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) =>
      _$PerformanceMetricFromJson(json);
}

/// Aggregated performance data for trends
@freezed
abstract class PerformanceTrend with _$PerformanceTrend {
  const factory PerformanceTrend({
    required List<PerformanceMetric> metrics,
    required double trendDirection,
    required double averageAccuracy,
    required double averageRating,
    required int totalDataPoints,
  }) = _PerformanceTrend;

  factory PerformanceTrend.fromJson(Map<String, dynamic> json) =>
      _$PerformanceTrendFromJson(json);
}

/// Difficulty-specific performance breakdown
@freezed
abstract class DifficultyBreakdown with _$DifficultyBreakdown {
  const factory DifficultyBreakdown({
    required String difficulty,
    required int gamesPlayed,
    required int wins,
    required double winRate,
    required double averageAccuracy,
  }) = _DifficultyBreakdown;

  factory DifficultyBreakdown.fromJson(Map<String, dynamic> json) =>
      _$DifficultyBreakdownFromJson(json);
}

/// Streak information
@freezed
abstract class StreakInfo with _$StreakInfo {
  const factory StreakInfo({
    required int currentWinStreak,
    required int longestWinStreak,
    required DateTime longestStreakDate,
    required int currentLossStreak,
    required int longestLossStreak,
  }) = _StreakInfo;

  factory StreakInfo.fromJson(Map<String, dynamic> json) =>
      _$StreakInfoFromJson(json);
}

/// Overall player analytics dashboard
@freezed
abstract class PlayerAnalyticsDashboard with _$PlayerAnalyticsDashboard {
  const factory PlayerAnalyticsDashboard({
    required String userId,
    required GameStats gameStats,
    required StreakInfo streakInfo,
    required PerformanceTrend performanceTrend,
    required List<DifficultyBreakdown> difficultyStats,
    required DateTime generatedAt,
  }) = _PlayerAnalyticsDashboard;

  factory PlayerAnalyticsDashboard.fromJson(Map<String, dynamic> json) =>
      _$PlayerAnalyticsDashboardFromJson(json);
}
