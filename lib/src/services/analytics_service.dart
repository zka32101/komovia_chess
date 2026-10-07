import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_models.dart';
import 'dart:developer' show log;

class AnalyticsService {
  factory AnalyticsService() => _instance;

  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, PerformanceMetrics> _metricsCache = {};

  /// Track query performance
  Future<void> trackQueryPerformance({
    required String operationName,
    required int durationMs,
    required bool success,
    String? errorType,
  }) async {
    final metric = PerformanceMetrics(
      operationName: operationName,
      durationMs: durationMs,
      timestamp: DateTime.now(),
      success: success,
      errorType: errorType,
    );

    _metricsCache[operationName] = metric;

    try {
      await _firestore
          .collection('analytics')
          .doc('performance_metrics')
          .collection('hourly')
          .doc(DateTime.now().toIso8601String().split('T')[0])
          .collection('metrics')
          .add(metric.toJson());
    } catch (e) {
      log('Failed to track query performance: $e');
    }
  }

  /// Track user engagement
  Future<void> trackUserEngagement({
    required String userId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore
          .collection('analytics')
          .doc('user_engagement')
          .collection('events')
          .add({
        'userId': userId,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      log('Failed to track user engagement: $e');
    }
  }

  /// Track cache metrics
  Future<void> trackCacheMetrics({
    required String cacheName,
    required int hitCount,
    required int missCount,
    required Duration avgLookupTime,
    required int evictionCount,
  }) async {
    final hitRate = hitCount / (hitCount + missCount).toDouble();

    final analytics = CacheAnalytics(
      cacheName: cacheName,
      hitCount: hitCount,
      missCount: missCount,
      hitRate: hitRate,
      avgCacheLookup: avgLookupTime,
      evictionCount: evictionCount,
      period: DateTime.now(),
    );

    try {
      await _firestore
          .collection('analytics')
          .doc('cache_analytics')
          .collection('daily')
          .doc(DateTime.now().toIso8601String().split('T')[0])
          .set({
        cacheName: analytics.toJson(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('Failed to track cache metrics: $e');
    }
  }

  /// Get performance trends for query type
  Future<List<QueryPerformanceTrend>> getPerformanceTrends({
    required String queryType,
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('analytics')
          .doc('query_trends')
          .collection('daily')
          .where('queryType', isEqualTo: queryType)
          .where('period', isGreaterThanOrEqualTo: startDate)
          .orderBy('period', descending: true)
          .limit(days)
          .get();

      return snapshot.docs
          .map((doc) => QueryPerformanceTrend.fromJson(doc.data()))
          .toList();
    } catch (e) {
      log('Failed to get performance trends: $e');
      return [];
    }
  }

  /// Get user engagement stats
  Future<UserEngagementMetrics?> getUserEngagementStats({
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('analytics')
          .doc('user_engagement')
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return UserEngagementMetrics.fromJson(doc.data()!);
    } catch (e) {
      log('Failed to get user engagement stats: $e');
      return null;
    }
  }

  /// Get cache analytics
  Future<List<CacheAnalytics>> getCacheAnalytics({
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('analytics')
          .doc('cache_analytics')
          .collection('daily')
          .where('period', isGreaterThanOrEqualTo: startDate)
          .orderBy('period', descending: true)
          .limit(days)
          .get();

      return snapshot.docs
          .expand((doc) => doc.data().values.cast<Map<String, dynamic>>())
          .map(CacheAnalytics.fromJson)
          .toList();
    } catch (e) {
      log('Failed to get cache analytics: $e');
      return [];
    }
  }

  /// Get competitive feature usage
  Future<List<CompetitiveFeatureStats>> getCompetitiveFeatureUsage({
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('analytics')
          .doc('competitive_features')
          .collection('daily')
          .where('period', isGreaterThanOrEqualTo: startDate)
          .orderBy('period', descending: true)
          .limit(days)
          .get();

      return snapshot.docs
          .map((doc) => CompetitiveFeatureStats.fromJson(doc.data()))
          .toList();
    } catch (e) {
      log('Failed to get competitive feature usage: $e');
      return [];
    }
  }

  /// Record daily metrics snapshot
  Future<void> recordDailySnapshot({
    required BuildMetrics buildMetrics,
    required int activeUsers,
    required double cacheHitRate,
  }) async {
    try {
      await _firestore
          .collection('analytics')
          .doc('daily_snapshots')
          .collection('snapshots')
          .doc(DateTime.now().toIso8601String().split('T')[0])
          .set({
        'buildMetrics': buildMetrics.toJson(),
        'activeUsers': activeUsers,
        'cacheHitRate': cacheHitRate,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('Failed to record daily snapshot: $e');
    }
  }

  /// Clear metrics cache
  void clearCache() {
    _metricsCache.clear();
  }

  /// Get cached metrics for operation
  PerformanceMetrics? getCachedMetric(String operationName) =>
      _metricsCache[operationName];
}
