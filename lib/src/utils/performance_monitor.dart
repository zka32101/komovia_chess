import 'dart:async';

class PerformanceMetric {
  PerformanceMetric({
    required this.name,
    required this.duration,
    required this.timestamp,
    required this.success,
    this.error,
  });
  final String name;
  final Duration duration;
  final DateTime timestamp;
  final bool success;
  final String? error;

  @override
  String toString() =>
      'PerformanceMetric($name: ${duration.inMilliseconds}ms, success: $success)';
}

class PerformanceMonitor {
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal({this.maxMetrics = 1000});
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  final List<PerformanceMetric> _metrics = [];
  final int maxMetrics;
  final Map<String, Stopwatch> _activeTimers = {};

  static PerformanceMonitor get instance => _instance;

  /// Start measuring a performance metric
  void startTimer(String operationName) {
    _activeTimers[operationName] = Stopwatch()..start();
  }

  /// Stop measuring and record metric
  void stopTimer(String operationName, {bool success = true, String? error}) {
    final timer = _activeTimers.remove(operationName);
    if (timer == null) {
      return;
    }

    timer.stop();
    final metric = PerformanceMetric(
      name: operationName,
      duration: timer.elapsed,
      timestamp: DateTime.now(),
      success: success,
      error: error,
    );

    _recordMetric(metric);
  }

  /// Measure a synchronous operation
  T measure<T>(String operationName, T Function() operation) {
    startTimer(operationName);
    try {
      final result = operation();
      stopTimer(operationName, success: true);
      return result;
    } catch (e) {
      stopTimer(operationName, success: false, error: e.toString());
      rethrow;
    }
  }

  /// Measure an asynchronous operation
  Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startTimer(operationName);
    try {
      final result = await operation();
      stopTimer(operationName, success: true);
      return result;
    } catch (e) {
      stopTimer(operationName, success: false, error: e.toString());
      rethrow;
    }
  }

  void _recordMetric(PerformanceMetric metric) {
    _metrics.add(metric);
    if (_metrics.length > maxMetrics) {
      _metrics.removeAt(0);
    }
  }

  /// Get metrics for specific operation
  List<PerformanceMetric> getMetricsForOperation(String operationName) =>
      _metrics.where((m) => m.name == operationName).toList();

  /// Get average duration for operation
  Duration getAverageDuration(String operationName) {
    final operationMetrics = getMetricsForOperation(operationName);
    if (operationMetrics.isEmpty) return Duration.zero;

    final totalMs = operationMetrics.fold<int>(
        0, (sum, m) => sum + m.duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ operationMetrics.length);
  }

  /// Get success rate for operation
  double getSuccessRate(String operationName) {
    final operationMetrics = getMetricsForOperation(operationName);
    if (operationMetrics.isEmpty) return 0;

    final successCount = operationMetrics.where((m) => m.success).length;
    return successCount / operationMetrics.length;
  }

  /// Get all metrics
  List<PerformanceMetric> getAllMetrics() => List.from(_metrics);

  /// Get recent metrics (last N)
  List<PerformanceMetric> getRecentMetrics(int count) => _metrics.sublist(
        (_metrics.length - count).clamp(0, _metrics.length),
      );

  /// Get performance summary
  Map<String, PerformanceSummary> getSummary() {
    final summaryMap = <String, PerformanceSummary>{};

    final operationNames = _metrics.map((m) => m.name).toSet();
    for (final name in operationNames) {
      final metrics = getMetricsForOperation(name);
      summaryMap[name] = PerformanceSummary(
        operationName: name,
        callCount: metrics.length,
        averageDuration: getAverageDuration(name),
        minDuration: metrics.map((m) => m.duration).reduce(
              (a, b) => a < b ? a : b,
            ),
        maxDuration: metrics.map((m) => m.duration).reduce(
              (a, b) => a > b ? a : b,
            ),
        successRate: getSuccessRate(name),
      );
    }

    return summaryMap;
  }

  /// Clear all metrics
  void clear() {
    _metrics.clear();
    _activeTimers.clear();
  }

  /// Get slowest operations
  List<PerformanceMetric> getSlowestOperations(int count) {
    final sorted = List<PerformanceMetric>.from(_metrics)
      ..sort((a, b) => b.duration.compareTo(a.duration));
    return sorted.take(count).toList();
  }

  /// Get failed operations
  List<PerformanceMetric> getFailedOperations() =>
      _metrics.where((m) => !m.success).toList();
}

class PerformanceSummary {
  PerformanceSummary({
    required this.operationName,
    required this.callCount,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.successRate,
  });
  final String operationName;
  final int callCount;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final double successRate;

  @override
  String toString() =>
      'PerformanceSummary($operationName: avg=${averageDuration.inMilliseconds}ms, calls=$callCount, success=${(successRate * 100).toStringAsFixed(1)}%)';
}

class PerformanceThreshold {
  PerformanceThreshold({
    required this.operationName,
    required this.warningThreshold,
    required this.errorThreshold,
  });
  final String operationName;
  final Duration warningThreshold;
  final Duration errorThreshold;
}

class PerformanceAlert {
  PerformanceAlert({
    required this.threshold,
    required this.metric,
    required this.level,
  });
  final PerformanceThreshold threshold;
  final PerformanceMetric metric;
  final AlertLevel level;

  @override
  String toString() =>
      'PerformanceAlert(${metric.name}: ${metric.duration.inMilliseconds}ms exceeds $level threshold)';
}

enum AlertLevel { warning, error }

class ThresholdMonitor {
  final Map<String, PerformanceThreshold> _thresholds = {};
  final List<PerformanceAlert> _alerts = [];

  void addThreshold(PerformanceThreshold threshold) {
    _thresholds[threshold.operationName] = threshold;
  }

  void checkMetric(PerformanceMetric metric) {
    final threshold = _thresholds[metric.name];
    if (threshold == null) return;

    if (metric.duration > threshold.errorThreshold) {
      _alerts.add(PerformanceAlert(
        threshold: threshold,
        metric: metric,
        level: AlertLevel.error,
      ));
    } else if (metric.duration > threshold.warningThreshold) {
      _alerts.add(PerformanceAlert(
        threshold: threshold,
        metric: metric,
        level: AlertLevel.warning,
      ));
    }
  }

  List<PerformanceAlert> getAlerts({AlertLevel? level}) {
    if (level == null) return List.from(_alerts);
    return _alerts.where((a) => a.level == level).toList();
  }

  void clearAlerts() => _alerts.clear();
}
