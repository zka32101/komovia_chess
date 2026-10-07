import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_models.dart';
import 'dart:developer' show log;

class TrendAggregationService {
  factory TrendAggregationService() => _instance;

  TrendAggregationService._internal();
  static final TrendAggregationService _instance =
      TrendAggregationService._internal();

  static TrendAggregationService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Aggregate daily metrics to trends
  Future<void> aggregateDailyMetrics({
    required String queryType,
    required List<PerformanceMetrics> metrics,
  }) async {
    if (metrics.isEmpty) return;

    final sorted = List.from(metrics)
      ..sort((a, b) => a.durationMs.compareTo(b.durationMs));
    final length = sorted.length;

    final p50 = sorted[(length * 0.5).toInt()].durationMs;
    final p95 = sorted[(length * 0.95).toInt()].durationMs;
    final p99 = sorted[(length * 0.99).toInt()].durationMs;

    final successCount =
        metrics.where((m) => m.success).length / metrics.length;

    final trend = QueryPerformanceTrend(
      queryType: queryType,
      p50Latency: p50,
      p95Latency: p95,
      p99Latency: p99,
      successRate: successCount,
      period: DateTime.now(),
      sampleCount: metrics.length,
    );

    try {
      await _firestore
          .collection('analytics')
          .doc('query_trends')
          .collection('daily')
          .doc('${DateTime.now().toIso8601String().split('T')[0]}_$queryType')
          .set(trend.toJson());
    } catch (e) {
      log('Failed to aggregate daily metrics: $e');
    }
  }

  /// Calculate percentile metrics
  Future<Map<String, int>> calculatePercentileMetrics({
    required String queryType,
    required List<int> latencies,
  }) async {
    if (latencies.isEmpty) {
      return {'p50': 0, 'p95': 0, 'p99': 0};
    }

    final sorted = List.from(latencies)..sort();
    final length = sorted.length;

    return {
      'p50': sorted[(length * 0.5).toInt()],
      'p95': sorted[(length * 0.95).toInt()],
      'p99': sorted[(length * 0.99).toInt()],
    };
  }

  /// Identify performance regression
  Future<bool> identifyPerformanceRegression({
    required String queryType,
    required int currentP50,
    double regressionThreshold = 0.2,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('analytics')
          .doc('query_trends')
          .collection('daily')
          .where('queryType', isEqualTo: queryType)
          .orderBy('period', descending: true)
          .limit(7)
          .get();

      if (snapshot.docs.length < 2) return false;

      final previous = QueryPerformanceTrend.fromJson(snapshot.docs[1].data());
      final regression =
          (currentP50 - previous.p50Latency) / previous.p50Latency;

      return regression > regressionThreshold;
    } catch (e) {
      log('Failed to identify regression: $e');
      return false;
    }
  }

  /// Generate trend report
  Future<Map<String, dynamic>> generateTrendReport({
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
          .get();

      final trends = snapshot.docs
          .map((doc) => QueryPerformanceTrend.fromJson(doc.data()))
          .toList();

      if (trends.isEmpty) {
        return {'error': 'No data available'};
      }

      final avgP50 = trends.map((t) => t.p50Latency).reduce((a, b) => a + b) ~/
          trends.length;
      final avgP95 = trends.map((t) => t.p95Latency).reduce((a, b) => a + b) ~/
          trends.length;
      final avgP99 = trends.map((t) => t.p99Latency).reduce((a, b) => a + b) ~/
          trends.length;

      return {
        'queryType': queryType,
        'period': '$days days',
        'averageP50': avgP50,
        'averageP95': avgP95,
        'averageP99': avgP99,
        'trend': _calculateTrend(trends),
        'dataPoints': trends.length,
      };
    } catch (e) {
      log('Failed to generate trend report: $e');
      return {'error': 'Failed to generate report'};
    }
  }

  String _calculateTrend(List<QueryPerformanceTrend> trends) {
    if (trends.length < 2) return 'insufficient_data';

    final latest = trends.first;
    final oldest = trends.last;

    if (latest.p50Latency < oldest.p50Latency * 0.9) {
      return 'improving';
    } else if (latest.p50Latency > oldest.p50Latency * 1.1) {
      return 'degrading';
    }
    return 'stable';
  }
}
