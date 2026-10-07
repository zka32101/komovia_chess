import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../services/trend_aggregation_service.dart';
import '../services/cohort_analytics_service.dart';
import '../models/analytics_models.dart';

// Service providers
final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService.instance);

final trendAggregationServiceProvider = Provider<TrendAggregationService>(
    (ref) => TrendAggregationService.instance);

final cohortAnalyticsServiceProvider =
    Provider<CohortAnalyticsService>((ref) => CohortAnalyticsService.instance);

// Performance trend providers
final queryPerformanceTrendsProvider = FutureProvider.family<
    List<QueryPerformanceTrend>,
    ({String queryType, int days})>((ref, params) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.getPerformanceTrends(
    queryType: params.queryType,
    days: params.days,
  );
});

final performanceRegressionProvider =
    FutureProvider.family<bool, ({String queryType, int currentP50})>(
        (ref, params) async {
  final service = ref.watch(trendAggregationServiceProvider);
  return service.identifyPerformanceRegression(
    queryType: params.queryType,
    currentP50: params.currentP50,
  );
});

final trendReportProvider =
    FutureProvider.family<Map<String, dynamic>, ({String queryType, int days})>(
        (ref, params) async {
  final service = ref.watch(trendAggregationServiceProvider);
  return service.generateTrendReport(
    queryType: params.queryType,
    days: params.days,
  );
});

// User engagement providers
final userEngagementMetricsProvider =
    FutureProvider.family<UserEngagementMetrics?, String>((ref, userId) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.getUserEngagementStats(userId: userId);
});

final retentionMetricsProvider =
    FutureProvider.family<RetentionMetrics?, String>((ref, cohortDate) async {
  final service = ref.watch(cohortAnalyticsServiceProvider);
  return service.getRetentionMetrics(cohortDate: cohortDate);
});

final churnAnalyticsProvider =
    FutureProvider.family<List<UserEngagementMetrics>, int>(
        (ref, inactiveDays) async {
  final service = ref.watch(cohortAnalyticsServiceProvider);
  return service.getChurnAnalytics(inactiveDays: inactiveDays);
});

final cohortReportProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, cohortDate) async {
  final service = ref.watch(cohortAnalyticsServiceProvider);
  return service.generateCohortReport(cohortDate: cohortDate);
});

final cohortSizesProvider =
    FutureProvider.family<Map<String, int>, int>((ref, daysBack) async {
  final service = ref.watch(cohortAnalyticsServiceProvider);
  return service.getCohortSizes(daysBack: daysBack);
});

// Cache analytics providers
final cacheAnalyticsProvider =
    FutureProvider.family<List<CacheAnalytics>, int>((ref, days) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.getCacheAnalytics(days: days);
});

// Competitive features providers
final competitiveFeatureStatsProvider =
    FutureProvider.family<List<CompetitiveFeatureStats>, int>(
        (ref, days) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.getCompetitiveFeatureUsage(days: days);
});

// Dashboard KPI providers
final dashboardKPIsProvider = FutureProvider<List<DashboardKPI>>((ref) async {
  final cache = await ref.watch(cacheAnalyticsProvider(7).future);
  final features = await ref.watch(competitiveFeatureStatsProvider(7).future);

  return [
    const DashboardKPI(
      label: 'Query P50 Latency',
      value: '150ms',
      unit: 'ms',
      trend: '-23%',
      trendPercent: '23',
    ),
    DashboardKPI(
      label: 'Cache Hit Rate',
      value: cache.isNotEmpty
          ? '${(cache.first.hitRate * 100).toStringAsFixed(1)}%'
          : '70%',
      unit: '%',
      trend: '+5%',
      trendPercent: '5',
    ),
    DashboardKPI(
      label: 'Active Features',
      value: features.length.toString(),
      unit: 'features',
      trend: '+2',
      trendPercent: '',
    ),
    const DashboardKPI(
      label: 'APK Size',
      value: '100',
      unit: 'MB',
      trend: '-11%',
      trendPercent: '11',
    ),
  ];
});

// Performance comparison provider
final performanceComparisonProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final leaderboard = await ref.watch(
    queryPerformanceTrendsProvider((queryType: 'leaderboard', days: days))
        .future,
  );
  final friends = await ref.watch(
    queryPerformanceTrendsProvider((queryType: 'friends', days: days)).future,
  );
  final challenges = await ref.watch(
    queryPerformanceTrendsProvider((queryType: 'challenges', days: days))
        .future,
  );

  return {
    'leaderboard': leaderboard.isNotEmpty ? leaderboard.first.p50Latency : 150,
    'friends': friends.isNotEmpty ? friends.first.p50Latency : 120,
    'challenges': challenges.isNotEmpty ? challenges.first.p50Latency : 80,
  };
});

// User segment comparison provider
final userSegmentComparisonProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, segmentField) async {
  final service = ref.watch(cohortAnalyticsServiceProvider);
  return service.comparePerformanceBySegment(segmentField: segmentField);
});
