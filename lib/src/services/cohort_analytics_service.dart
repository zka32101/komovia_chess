import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_models.dart';
import 'dart:developer' show log;

class CohortAnalyticsService {
  factory CohortAnalyticsService() => _instance;

  CohortAnalyticsService._internal();
  static final CohortAnalyticsService _instance =
      CohortAnalyticsService._internal();

  static CohortAnalyticsService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user cohort
  Future<Map<String, dynamic>> getUserCohort({
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('analytics')
          .doc('user_cohorts')
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return {'error': 'User not found'};

      return doc.data()!;
    } catch (e) {
      log('Failed to get user cohort: $e');
      return {'error': 'Failed to retrieve cohort'};
    }
  }

  /// Get retention metrics
  Future<RetentionMetrics?> getRetentionMetrics({
    required String cohortDate,
  }) async {
    try {
      final doc = await _firestore
          .collection('analytics')
          .doc('retention_metrics')
          .collection('cohorts')
          .doc(cohortDate)
          .get();

      if (!doc.exists) return null;

      return RetentionMetrics.fromJson(doc.data()!);
    } catch (e) {
      log('Failed to get retention metrics: $e');
      return null;
    }
  }

  /// Get churn analytics
  Future<List<UserEngagementMetrics>> getChurnAnalytics({
    required int inactiveDays,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: inactiveDays));

      final snapshot = await _firestore
          .collection('analytics')
          .doc('user_engagement')
          .collection('users')
          .where('lastActive', isLessThan: cutoffDate)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => UserEngagementMetrics.fromJson(doc.data()))
          .toList();
    } catch (e) {
      log('Failed to get churn analytics: $e');
      return [];
    }
  }

  /// Compare performance by segment
  Future<Map<String, dynamic>> comparePerformanceBySegment({
    required String segmentField,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('analytics')
          .doc('user_engagement')
          .collection('users')
          .limit(1000)
          .get();

      final segmentMap = <String, List<UserEngagementMetrics>>{};

      for (final doc in snapshot.docs) {
        final metrics = UserEngagementMetrics.fromJson(doc.data());
        final segment = doc.data()[segmentField]?.toString() ?? 'unknown';

        segmentMap.putIfAbsent(segment, () => []).add(metrics);
      }

      final comparison = <String, Map<String, dynamic>>{};

      segmentMap.forEach((segment, metrics) {
        final avgSessions =
            metrics.map((m) => m.sessionsCount).reduce((a, b) => a + b) ~/
                metrics.length;
        final churnedCount = metrics.where((m) => m.churnedUser).length;

        comparison[segment] = {
          'count': metrics.length,
          'avgSessions': avgSessions,
          'churnRate': churnedCount / metrics.length,
        };
      });

      return comparison;
    } catch (e) {
      log('Failed to compare performance: $e');
      return {};
    }
  }

  /// Generate cohort report
  Future<Map<String, dynamic>> generateCohortReport({
    required String cohortDate,
  }) async {
    try {
      final retention = await getRetentionMetrics(cohortDate: cohortDate);

      if (retention == null) {
        return {'error': 'No retention data'};
      }

      return {
        'cohortDate': cohortDate,
        'cohortSize': retention.cohortSize,
        'day1Retention': retention.day1Retention,
        'day7Retention': retention.day7Retention,
        'day30Retention': retention.day30Retention,
        'retentionByDay': retention.retentionByDay,
      };
    } catch (e) {
      log('Failed to generate cohort report: $e');
      return {'error': 'Failed to generate report'};
    }
  }

  /// Calculate cohort size by date
  Future<Map<String, int>> getCohortSizes({
    required int daysBack,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('analytics')
          .doc('retention_metrics')
          .collection('cohorts')
          .limit(daysBack)
          .get();

      final sizes = <String, int>{};

      for (final doc in snapshot.docs) {
        sizes[doc.id] = doc['cohortSize'] ?? 0;
      }

      return sizes;
    } catch (e) {
      log('Failed to get cohort sizes: $e');
      return {};
    }
  }
}
