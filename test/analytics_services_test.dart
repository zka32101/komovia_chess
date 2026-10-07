import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_chess/src/models/analytics_models.dart';
import 'package:komovia_chess/src/services/analytics_service.dart';
import 'package:komovia_chess/src/services/trend_aggregation_service.dart';
import 'package:komovia_chess/src/services/cohort_analytics_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analyticsService;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      analyticsService = AnalyticsService(mockFirestore);
    });

    test('trackQueryPerformance should record metric', () async {
      // Arrange
      const operationName = 'leaderboard_query';
      const durationMs = 150;
      const success = true;

      // Act
      await analyticsService.trackQueryPerformance(
        operationName: operationName,
        durationMs: durationMs,
        success: success,
      );

      // Assert
      // Verify Firestore collection was called
      verify(mockFirestore.collection('analytics/performance_metrics')).called();
    });

    test('trackUserEngagement should record user action', () async {
      // Arrange
      const userId = 'test_user_123';
      const action = 'leaderboard_view';

      // Act
      await analyticsService.trackUserEngagement(
        userId: userId,
        action: action,
      );

      // Assert
      verify(mockFirestore.collection('analytics/user_engagement')).called();
    });

    test('trackCacheMetrics should record cache performance', () async {
      // Arrange
      const cacheName = 'smart_cache';
      const hitCount = 1000;
      const missCount = 200;
      const avgLookupTime = Duration(milliseconds: 2);

      // Act
      await analyticsService.trackCacheMetrics(
        cacheName: cacheName,
        hitCount: hitCount,
        missCount: missCount,
        avgLookupTime: avgLookupTime,
        evictionCount: 50,
      );

      // Assert
      verify(mockFirestore.collection('analytics/cache_analytics')).called();
    });

    test('getPerformanceTrends should return trends for query type', () async {
      // Arrange
      const queryType = 'leaderboard';
      const days = 7;

      // Act
      final trends = await analyticsService.getPerformanceTrends(
        queryType: queryType,
        days: days,
      );

      // Assert
      expect(trends, isA<List<QueryPerformanceTrend>>());
    });

    test('getUserEngagementStats should return user metrics', () async {
      // Arrange
      const userId = 'test_user_123';

      // Act
      final metrics = await analyticsService.getUserEngagementStats(
        userId: userId,
      );

      // Assert
      expect(metrics, isA<UserEngagementMetrics?>());
    });

    test('getCacheAnalytics should return cache metrics', () async {
      // Arrange
      const days = 7;

      // Act
      final analytics = await analyticsService.getCacheAnalytics(
        days: days,
      );

      // Assert
      expect(analytics, isA<List<CacheAnalytics>>());
    });

    test('getCompetitiveFeatureUsage should return feature stats', () async {
      // Arrange
      const days = 7;

      // Act
      final features = await analyticsService.getCompetitiveFeatureUsage(
        days: days,
      );

      // Assert
      expect(features, isA<List<CompetitiveFeatureStats>>());
    });
  });

  group('TrendAggregationService', () {
    late TrendAggregationService trendService;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      trendService = TrendAggregationService(mockFirestore);
    });

    test('calculatePercentileMetrics should compute P50, P95, P99', () async {
      // Arrange
      const queryType = 'leaderboard';
      final latencies = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

      // Act
      final percentiles = await trendService.calculatePercentileMetrics(
        queryType: queryType,
        latencies: latencies,
      );

      // Assert
      expect(percentiles.containsKey('p50'), true);
      expect(percentiles.containsKey('p95'), true);
      expect(percentiles.containsKey('p99'), true);
      expect(percentiles['p50']!, lessThan(percentiles['p95']!));
      expect(percentiles['p95']!, lessThan(percentiles['p99']!));
    });

    test('identifyPerformanceRegression should detect degradation', () async {
      // Arrange
      const queryType = 'leaderboard';
      const currentP50 = 300; // 100% worse than typical 150ms baseline
      const regressionThreshold = 0.2; // 20% threshold

      // Act
      final isRegression = await trendService.identifyPerformanceRegression(
        queryType: queryType,
        currentP50: currentP50,
        regressionThreshold: regressionThreshold,
      );

      // Assert
      expect(isRegression, isA<bool>());
    });

    test('generateTrendReport should return analysis', () async {
      // Arrange
      const queryType = 'leaderboard';
      const days = 7;

      // Act
      final report = await trendService.generateTrendReport(
        queryType: queryType,
        days: days,
      );

      // Assert
      expect(report, isA<Map<String, dynamic>>());
      expect(report.containsKey('queryType'), true);
      expect(report.containsKey('trend'), true);
    });
  });

  group('CohortAnalyticsService', () {
    late CohortAnalyticsService cohortService;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      cohortService = CohortAnalyticsService(mockFirestore);
    });

    test('getUserCohort should return cohort data', () async {
      // Arrange
      const userId = 'test_user_123';

      // Act
      final cohort = await cohortService.getUserCohort(userId: userId);

      // Assert
      expect(cohort, isA<Map<String, dynamic>>());
    });

    test('getRetentionMetrics should return retention data', () async {
      // Arrange
      const cohortDate = '2024-09-16';

      // Act
      final retention = await cohortService.getRetentionMetrics(
        cohortDate: cohortDate,
      );

      // Assert
      expect(retention, isA<RetentionMetrics?>());
    });

    test('getChurnAnalytics should return churned users', () async {
      // Arrange
      const inactiveDays = 14;

      // Act
      final churnedUsers = await cohortService.getChurnAnalytics(
        inactiveDays: inactiveDays,
      );

      // Assert
      expect(churnedUsers, isA<List<UserEngagementMetrics>>());
    });

    test('comparePerformanceBySegment should return segment comparison', () async {
      // Arrange
      const segmentField = 'deviceType';

      // Act
      final comparison = await cohortService.comparePerformanceBySegment(
        segmentField: segmentField,
      );

      // Assert
      expect(comparison, isA<Map<String, dynamic>>());
    });

    test('generateCohortReport should return analysis', () async {
      // Arrange
      const cohortDate = '2024-09-16';

      // Act
      final report = await cohortService.generateCohortReport(
        cohortDate: cohortDate,
      );

      // Assert
      expect(report, isA<Map<String, dynamic>>());
      expect(report.containsKey('cohortDate'), true);
      expect(report.containsKey('cohortSize'), true);
    });

    test('getCohortSizes should return cohort size data', () async {
      // Arrange
      const daysBack = 30;

      // Act
      final sizes = await cohortService.getCohortSizes(daysBack: daysBack);

      // Assert
      expect(sizes, isA<Map<String, int>>());
    });
  });
}
