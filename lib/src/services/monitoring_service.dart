import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for comprehensive post-launch monitoring
class MonitoringService {
  // MB

  MonitoringService._();
  static final MonitoringService _instance = MonitoringService._();
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Severity levels
  static const String SEVERITY_FATAL = 'fatal';
  static const String SEVERITY_HIGH = 'high';
  static const String SEVERITY_MEDIUM = 'medium';
  static const String SEVERITY_LOW = 'low';

  // Performance threshold targets (milliseconds)
  static const int STARTUP_TARGET = 2500; // 2.5 seconds
  static const int NAVIGATION_TARGET = 300;
  static const int MOVE_EXECUTION_TARGET = 50;
  static const int MEMORY_TARGET = 120;

  static MonitoringService get instance => _instance;

  /// Record breadcrumb for session tracking
  Future<void> recordBreadcrumb(
      String message, Map<String, dynamic> data) async {
    try {
      _crashlytics.log('[$message] ${data.toString()}');
    } catch (e) {
      debugPrint('Error recording breadcrumb: $e');
    }
  }

  /// Log user action with context
  Future<void> logUserAction(
    String action, {
    required Map<String, dynamic> metadata,
    String? userId,
  }) async {
    final user = userId ?? _auth.currentUser?.uid;

    try {
      await _firestore
          .collection('monitoring')
          .doc('user_actions')
          .collection('events')
          .add({
        'action': action,
        'userId': user,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Also log to Crashlytics breadcrumbs
      _crashlytics.log('Action: $action | ${metadata.toString()}');
    } catch (e) {
      debugPrint('Error logging user action: $e');
    }
  }

  /// Track performance metric
  Future<void> trackPerformance(
    String metricName, {
    required int durationMs,
    required bool exceedsTarget,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore
          .collection('monitoring')
          .doc('performance_metrics')
          .collection('measurements')
          .add({
        'metric': metricName,
        'durationMs': durationMs,
        'exceedsTarget': exceedsTarget,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
      });

      if (exceedsTarget) {
        _crashlytics.log(
          'Performance Warning: $metricName took ${durationMs}ms (target: ${_getTarget(metricName)}ms)',
        );
      }
    } catch (e) {
      debugPrint('Error tracking performance: $e');
    }
  }

  /// Record crash with severity categorization
  Future<void> recordCrash(
    Object exception,
    StackTrace? stackTrace, {
    required String severity,
    Map<String, dynamic>? context,
  }) async {
    try {
      // Log to Crashlytics
      await _crashlytics.recordError(exception, stackTrace);

      // Store in Firestore for analysis
      await _firestore
          .collection('monitoring')
          .doc('crashes')
          .collection('incidents')
          .add({
        'error': exception.toString(),
        'severity': severity,
        'userId': _auth.currentUser?.uid,
        'context': context ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Alert if critical
      if (severity == SEVERITY_FATAL) {
        await _alertCriticalIssue(
            'Critical crash detected', exception.toString());
      }
    } catch (e) {
      debugPrint('Error recording crash: $e');
    }
  }

  /// Track ANR (Application Not Responding) metrics
  Future<void> trackANR({
    required int durationMs,
    required String screen,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore
          .collection('monitoring')
          .doc('anr_events')
          .collection('incidents')
          .add({
        'screen': screen,
        'durationMs': durationMs,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
      });

      if (durationMs > 5000) {
        _crashlytics.log('ANR detected on $screen: ${durationMs}ms');
      }
    } catch (e) {
      debugPrint('Error tracking ANR: $e');
    }
  }

  /// Get crash rate for period
  Future<double> getCrashRate(Duration period) async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(period),
      );

      final crashes = await _firestore
          .collection('monitoring')
          .doc('crashes')
          .collection('incidents')
          .where('timestamp', isGreaterThan: cutoff)
          .count()
          .get();

      final sessions = await _firestore
          .collection('monitoring')
          .doc('sessions')
          .collection('data')
          .where('timestamp', isGreaterThan: cutoff)
          .count()
          .get();

      final crashCount = crashes.count ?? 0;
      final sessionCount = sessions.count ?? 0;
      if (sessionCount == 0) return 1.0;
      return 1.0 - (crashCount / sessionCount);
    } catch (e) {
      debugPrint('Error calculating crash rate: $e');
      return 1.0;
    }
  }

  /// Get ANR rate for period
  Future<double> getANRRate(Duration period) async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(period),
      );

      final anrs = await _firestore
          .collection('monitoring')
          .doc('anr_events')
          .collection('incidents')
          .where('timestamp', isGreaterThan: cutoff)
          .count()
          .get();

      final sessions = await _firestore
          .collection('monitoring')
          .doc('sessions')
          .collection('data')
          .where('timestamp', isGreaterThan: cutoff)
          .count()
          .get();

      final anrCount = anrs.count ?? 0;
      final sessionCount = sessions.count ?? 0;
      if (sessionCount == 0) return 0.0;
      return anrCount / sessionCount;
    } catch (e) {
      debugPrint('Error calculating ANR rate: $e');
      return 0.0;
    }
  }

  /// Get average performance metric
  Future<int> getAverageMetric(String metricName, Duration period) async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(period),
      );

      final query = await _firestore
          .collection('monitoring')
          .doc('performance_metrics')
          .collection('measurements')
          .where('metric', isEqualTo: metricName)
          .where('timestamp', isGreaterThan: cutoff)
          .get();

      if (query.docs.isEmpty) return 0;

      final total = query.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc['durationMs'] as int? ?? 0),
      );

      return total ~/ query.docs.length;
    } catch (e) {
      debugPrint('Error getting average metric: $e');
      return 0;
    }
  }

  /// Get performance metrics summary
  Future<PerformanceSummary> getPerformanceSummary(Duration period) async {
    try {
      final startupTime = await getAverageMetric('startup', period);
      final navigationTime = await getAverageMetric('navigation', period);
      final moveExecutionTime =
          await getAverageMetric('move_execution', period);
      final crashRate = await getCrashRate(period);
      final anrRate = await getANRRate(period);

      return PerformanceSummary(
        startupTimeMs: startupTime,
        navigationTimeMs: navigationTime,
        moveExecutionTimeMs: moveExecutionTime,
        crashFreeRate: crashRate,
        anrRate: anrRate,
        period: period,
      );
    } catch (e) {
      debugPrint('Error getting performance summary: $e');
      return PerformanceSummary(
        startupTimeMs: 0,
        navigationTimeMs: 0,
        moveExecutionTimeMs: 0,
        crashFreeRate: 1,
        anrRate: 0,
        period: period,
      );
    }
  }

  /// Alert for critical issues
  Future<void> _alertCriticalIssue(String title, String message) async {
    try {
      await _firestore
          .collection('monitoring')
          .doc('alerts')
          .collection('critical')
          .add({
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'acknowledged': false,
      });
    } catch (e) {
      debugPrint('Error creating alert: $e');
    }
  }

  /// Get target for metric
  static int _getTarget(String metricName) {
    switch (metricName) {
      case 'startup':
        return STARTUP_TARGET;
      case 'navigation':
        return NAVIGATION_TARGET;
      case 'move_execution':
        return MOVE_EXECUTION_TARGET;
      default:
        return 0;
    }
  }

  /// Record session start
  Future<void> startSession(String sessionId, String platform) async {
    try {
      await _firestore
          .collection('monitoring')
          .doc('sessions')
          .collection('data')
          .doc(sessionId)
          .set({
        'userId': _auth.currentUser?.uid,
        'platform': platform,
        'startTime': FieldValue.serverTimestamp(),
        'actions': [],
      });
    } catch (e) {
      debugPrint('Error starting session: $e');
    }
  }

  /// Record session end
  Future<void> endSession(String sessionId, int durationMs) async {
    try {
      await _firestore
          .collection('monitoring')
          .doc('sessions')
          .collection('data')
          .doc(sessionId)
          .update({
        'endTime': FieldValue.serverTimestamp(),
        'durationMs': durationMs,
      });
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  /// Set custom user properties for Crashlytics
  Future<void> setUserProperty(String key, String value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (e) {
      debugPrint('Error setting user property: $e');
    }
  }
}

/// Performance summary data class
class PerformanceSummary {
  PerformanceSummary({
    required this.startupTimeMs,
    required this.navigationTimeMs,
    required this.moveExecutionTimeMs,
    required this.crashFreeRate,
    required this.anrRate,
    required this.period,
  });
  final int startupTimeMs;
  final int navigationTimeMs;
  final int moveExecutionTimeMs;
  final double crashFreeRate;
  final double anrRate;
  final Duration period;

  bool get startupExceedsTarget =>
      startupTimeMs > MonitoringService.STARTUP_TARGET;
  bool get navigationExceedsTarget =>
      navigationTimeMs > MonitoringService.NAVIGATION_TARGET;
  bool get moveExecutionExceedsTarget =>
      moveExecutionTimeMs > MonitoringService.MOVE_EXECUTION_TARGET;
  bool get crashRateUnhealthy => crashFreeRate < 0.99;
  bool get anrRateUnhealthy => anrRate > 0.005;
}
