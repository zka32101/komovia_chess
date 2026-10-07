import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance.dart';

/// Performance Monitoring Service
class PerformanceMonitorService {
  factory PerformanceMonitorService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      _instance._firestore = firestore;
    }
    return _instance;
  }

  PerformanceMonitorService._internal()
      : _firestore = FirebaseFirestore.instance;
  static final PerformanceMonitorService _instance =
      PerformanceMonitorService._internal();

  FirebaseFirestore _firestore;

  /// Track screen load time
  Future<void> trackScreenLoadTime(
      String screenName, int loadTimeMs, String sessionId) async {
    try {
      final metric = PerformanceMetric(
        id: _firestore.collection('performance_metrics').doc().id,
        type: MetricType.screenLoad,
        component: screenName,
        value: loadTimeMs.toDouble(),
        unit: 'ms',
        timestamp: DateTime.now(),
        deviceInfo: 'device_info',
        appVersion: '1.0.0',
        sessionId: sessionId,
      );

      await _firestore
          .collection('performance_metrics')
          .doc(metric.id)
          .set(metric.toJson());
    } catch (e) {
      print('Performance tracking error: $e');
    }
  }

  /// Track API response time
  Future<void> trackAPIResponseTime(
      String endpoint, int responseTimeMs, String sessionId) async {
    try {
      final metric = PerformanceMetric(
        id: _firestore.collection('performance_metrics').doc().id,
        type: MetricType.apiLatency,
        component: endpoint,
        value: responseTimeMs.toDouble(),
        unit: 'ms',
        timestamp: DateTime.now(),
        deviceInfo: 'device_info',
        appVersion: '1.0.0',
        sessionId: sessionId,
      );

      await _firestore
          .collection('performance_metrics')
          .doc(metric.id)
          .set(metric.toJson());
    } catch (e) {
      print('API tracking error: $e');
    }
  }

  /// Track memory usage
  Future<void> trackMemoryUsage(double memoryMB, String sessionId) async {
    try {
      final metric = PerformanceMetric(
        id: _firestore.collection('performance_metrics').doc().id,
        type: MetricType.memory,
        component: 'app_memory',
        value: memoryMB,
        unit: 'MB',
        timestamp: DateTime.now(),
        deviceInfo: 'device_info',
        appVersion: '1.0.0',
        sessionId: sessionId,
      );

      await _firestore
          .collection('performance_metrics')
          .doc(metric.id)
          .set(metric.toJson());
    } catch (e) {
      print('Memory tracking error: $e');
    }
  }

  /// Track battery usage
  Future<void> trackBatteryUsage(
      double batteryPercentage, String sessionId) async {
    try {
      final metric = PerformanceMetric(
        id: _firestore.collection('performance_metrics').doc().id,
        type: MetricType.battery,
        component: 'device_battery',
        value: batteryPercentage,
        unit: '%',
        timestamp: DateTime.now(),
        deviceInfo: 'device_info',
        appVersion: '1.0.0',
        sessionId: sessionId,
      );

      await _firestore
          .collection('performance_metrics')
          .doc(metric.id)
          .set(metric.toJson());
    } catch (e) {
      print('Battery tracking error: $e');
    }
  }

  /// Report crash
  Future<void> reportCrash({
    required String userId,
    required String error,
    required String stackTrace,
  }) async {
    try {
      final crashReport = CrashReport(
        id: _firestore.collection('crash_reports').doc().id,
        userId: userId,
        error: error,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
        appVersion: '1.0.0',
        deviceInfo: 'device_info',
        reproducible: false,
        status: CrashStatus.new_,
      );

      await _firestore
          .collection('crash_reports')
          .doc(crashReport.id)
          .set(crashReport.toJson());
    } catch (e) {
      print('Crash reporting error: $e');
      rethrow;
    }
  }

  /// Get performance metrics
  Future<List<PerformanceMetric>> getPerformanceMetrics(
      {int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection('performance_metrics')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => PerformanceMetric.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching performance metrics: $e');
      return [];
    }
  }

  /// Get metrics by type
  Future<List<PerformanceMetric>> getMetricsByType(MetricType type) async {
    try {
      final querySnapshot = await _firestore
          .collection('performance_metrics')
          .where('type', isEqualTo: type.name)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PerformanceMetric.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching metrics by type: $e');
      return [];
    }
  }

  /// Get crash reports
  Future<List<CrashReport>> getCrashReports({int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('crash_reports')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CrashReport.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching crash reports: $e');
      return [];
    }
  }

  /// Identify performance bottlenecks
  Future<List<OptimizationSuggestion>> identifyBottlenecks() async {
    try {
      final metrics = await getPerformanceMetrics(limit: 1000);

      // Calculate averages by component
      final componentMetrics = <String, List<double>>{};
      for (final metric in metrics) {
        componentMetrics
            .putIfAbsent(metric.component, () => [])
            .add(metric.value);
      }

      final suggestions = <OptimizationSuggestion>[];

      for (final entry in componentMetrics.entries) {
        final values = entry.value;
        if (values.isEmpty) continue;

        final average = values.reduce((a, b) => a + b) / values.length;
        final max = values.reduce((a, b) => a > b ? a : b);

        // Suggest optimization if max is significantly higher than average
        if (max > average * 1.5) {
          suggestions.add(OptimizationSuggestion(
            id: _firestore.collection('optimization_suggestions').doc().id,
            component: entry.key,
            issue: 'Performance varies significantly',
            currentBaseline: average,
            suggestedImprovement: average * 0.8,
            estimatedImpact: 20,
            effort: 3,
            priority: 3,
            category: 'performance',
            recommendations: [
              'Review code for inefficiencies',
              'Check for memory leaks',
              'Optimize database queries',
            ],
          ));
        }
      }

      return suggestions;
    } catch (e) {
      print('Error identifying bottlenecks: $e');
      return [];
    }
  }

  /// Update crash report status
  Future<void> updateCrashStatus(String crashId, CrashStatus status) async {
    try {
      await _firestore.collection('crash_reports').doc(crashId).update({
        'status': status.name,
      });
    } catch (e) {
      print('Error updating crash status: $e');
      rethrow;
    }
  }
}
