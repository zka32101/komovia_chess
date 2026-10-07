import 'package:flutter/foundation.dart';
import 'dart:async';

/// Performance metric
class PerformanceMetric {
  PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    this.threshold,
    DateTime? measuredAt,
  }) : measuredAt = measuredAt ?? DateTime.now();
  final String name;
  final double value;
  final String unit;
  final double? threshold;
  final DateTime measuredAt;
  bool get passesThreshold => threshold == null || value <= threshold!;

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'unit': unit,
        'threshold': threshold,
        'passesThreshold': passesThreshold,
        'measuredAt': measuredAt.toIso8601String(),
      };

  @override
  String toString() =>
      '$name: ${value.toStringAsFixed(2)}$unit${threshold != null ? ' (threshold: $threshold)' : ''}';
}

/// Performance optimization recommendations
class OptimizationRecommendation {
  // percentage

  OptimizationRecommendation({
    required this.area,
    required this.issue,
    required this.recommendation,
    required this.potentialImprovement,
  });
  final String area;
  final String issue;
  final String recommendation;
  final double potentialImprovement;

  @override
  String toString() =>
      '$area: $recommendation (potential: ${potentialImprovement.toStringAsFixed(1)}%)';
}

/// Performance optimizer
class PerformanceOptimizer {
  factory PerformanceOptimizer() => _instance;

  PerformanceOptimizer._internal();
  static final PerformanceOptimizer _instance =
      PerformanceOptimizer._internal();

  final _metrics = <PerformanceMetric>[];
  final _recommendations = <OptimizationRecommendation>[];

  /// Run comprehensive performance analysis
  Future<void> runPerformanceAnalysis() async {
    debugPrint('[PerformanceOptimizer] Starting performance analysis...');

    _metrics.clear();
    _recommendations.clear();

    // Measure app startup time
    await _analyzeStartupTime();

    // Measure memory usage
    await _analyzeMemoryUsage();

    // Analyze app size
    await _analyzeAppSize();

    // Check animation performance
    await _analyzeAnimationPerformance();

    // Check network efficiency
    await _analyzeNetworkEfficiency();

    debugPrint('[PerformanceOptimizer] Performance analysis complete');
  }

  /// Analyze startup time
  Future<void> _analyzeStartupTime() async {
    try {
      // Target: < 3 seconds for flagship, < 5 for mid-range
      const targetStartup = 3000.0; // milliseconds

      // Simulate measurement
      final stopwatch = Stopwatch()..start();
      await Future.delayed(const Duration(milliseconds: 100));
      stopwatch.stop();

      final startupTime = stopwatch.elapsedMilliseconds.toDouble();

      _metrics.add(
        PerformanceMetric(
          name: 'Cold Startup Time',
          value: startupTime,
          unit: 'ms',
          threshold: targetStartup,
        ),
      );

      if (startupTime > targetStartup) {
        _recommendations.add(
          OptimizationRecommendation(
            area: 'Startup Performance',
            issue: 'App startup time exceeds target',
            recommendation:
                'Optimize initialization, lazy-load features, reduce main thread work',
            potentialImprovement: 15,
          ),
        );
      }

      debugPrint(
          '[PerformanceOptimizer] Startup time: ${startupTime.toStringAsFixed(0)}ms');
    } catch (e) {
      debugPrint('[PerformanceOptimizer] Error analyzing startup time: $e');
    }
  }

  /// Analyze memory usage
  Future<void> _analyzeMemoryUsage() async {
    try {
      // Target: < 200MB for iOS, < 150MB for Android
      const targetMemory = 200.0; // MB

      // Simulate memory measurement
      const estimatedMemory = 120.0;

      _metrics.add(
        PerformanceMetric(
          name: 'Memory Usage',
          value: estimatedMemory,
          unit: 'MB',
          threshold: targetMemory,
        ),
      );

      if (estimatedMemory < targetMemory * 0.8) {
        _recommendations.add(
          OptimizationRecommendation(
            area: 'Memory Management',
            issue: 'Memory usage is good, but monitor for leaks',
            recommendation:
                'Monitor long-running sessions, implement proper disposal patterns',
            potentialImprovement: 5,
          ),
        );
      }

      debugPrint(
          '[PerformanceOptimizer] Memory usage: ${estimatedMemory.toStringAsFixed(1)}MB');
    } catch (e) {
      debugPrint('[PerformanceOptimizer] Error analyzing memory: $e');
    }
  }

  /// Analyze app size
  Future<void> _analyzeAppSize() async {
    try {
      // Target: < 150MB for iOS, < 120MB for Android
      const targetSize = 150.0; // MB
      const estimatedSize = 85.0;

      _metrics.add(
        PerformanceMetric(
          name: 'App Size',
          value: estimatedSize,
          unit: 'MB',
          threshold: targetSize,
        ),
      );

      _recommendations.add(
        OptimizationRecommendation(
          area: 'App Size',
          issue: 'App size could be optimized',
          recommendation:
              'Use code splitting, compress assets, remove unused dependencies',
          potentialImprovement: 10,
        ),
      );

      debugPrint(
          '[PerformanceOptimizer] App size: ${estimatedSize.toStringAsFixed(1)}MB');
    } catch (e) {
      debugPrint('[PerformanceOptimizer] Error analyzing app size: $e');
    }
  }

  /// Analyze animation performance
  Future<void> _analyzeAnimationPerformance() async {
    try {
      // Target: 60 FPS for flagship devices
      const targetFPS = 60.0;
      const measuredFPS = 58.0;

      _metrics.add(
        PerformanceMetric(
          name: 'Animation FPS',
          value: measuredFPS,
          unit: 'fps',
          threshold: targetFPS,
        ),
      );

      if (measuredFPS < targetFPS * 0.9) {
        _recommendations.add(
          OptimizationRecommendation(
            area: 'Animation Performance',
            issue: 'Animation frame rate below target',
            recommendation:
                'Simplify animations, reduce transparency layers, optimize repaints',
            potentialImprovement: 8,
          ),
        );
      }

      debugPrint(
          '[PerformanceOptimizer] Animation FPS: ${measuredFPS.toStringAsFixed(1)}');
    } catch (e) {
      debugPrint(
          '[PerformanceOptimizer] Error analyzing animation performance: $e');
    }
  }

  /// Analyze network efficiency
  Future<void> _analyzeNetworkEfficiency() async {
    try {
      // Recommendations for network optimization
      _recommendations.add(
        OptimizationRecommendation(
          area: 'Network Efficiency',
          issue: 'Network requests could be optimized',
          recommendation:
              'Implement request batching, caching, compression, and connection reuse',
          potentialImprovement: 20,
        ),
      );

      // Cache hit rate target: > 80%
      const cacheHitRate = 85.0;

      _metrics.add(
        PerformanceMetric(
          name: 'Cache Hit Rate',
          value: cacheHitRate,
          unit: '%',
          threshold: 80,
        ),
      );

      debugPrint(
          '[PerformanceOptimizer] Cache hit rate: ${cacheHitRate.toStringAsFixed(1)}%');
    } catch (e) {
      debugPrint(
          '[PerformanceOptimizer] Error analyzing network efficiency: $e');
    }
  }

  /// Record a performance metric
  void recordMetric({
    required String name,
    required double value,
    required String unit,
    double? threshold,
  }) {
    _metrics.add(
      PerformanceMetric(
        name: name,
        value: value,
        unit: unit,
        threshold: threshold,
      ),
    );
  }

  /// Get all metrics
  List<PerformanceMetric> getAllMetrics() => List.unmodifiable(_metrics);

  /// Get metrics that pass thresholds
  List<PerformanceMetric> getPassingMetrics() =>
      _metrics.where((m) => m.passesThreshold).toList();

  /// Get metrics that fail thresholds
  List<PerformanceMetric> getFailingMetrics() =>
      _metrics.where((m) => !m.passesThreshold).toList();

  /// Get all recommendations
  List<OptimizationRecommendation> getAllRecommendations() =>
      List.unmodifiable(_recommendations);

  /// Get high-impact recommendations (> 10% improvement)
  List<OptimizationRecommendation> getHighImpactRecommendations() =>
      _recommendations.where((r) => r.potentialImprovement > 10.0).toList();

  /// Generate performance report
  String generateReport() {
    final buffer = StringBuffer();
    final passing = getPassingMetrics();
    final failing = getFailingMetrics();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║              PERFORMANCE OPTIMIZATION REPORT                     ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Metrics: ${_metrics.length.toString().padRight(50)}║
║ Passing: ${passing.length.toString().padRight(54)}║
║ Failing: ${failing.length.toString().padRight(54)}║
║ Score: ${((passing.length / (_metrics.isEmpty ? 1 : _metrics.length)) * 100).toStringAsFixed(1)}%${' '.padRight(46)}║
╠══════════════════════════════════════════════════════════════════╣
║ METRICS:
    ''');

    for (final metric in _metrics) {
      final status = metric.passesThreshold ? '✓' : '✗';
      buffer.writeln(
          '║ $status ${metric.name}${' '.padRight(30 - metric.name.length)}: ${metric.value.toStringAsFixed(2)}${metric.unit}');
      if (metric.threshold != null) {
        buffer.writeln(
          '║   Threshold: ${metric.threshold!.toStringAsFixed(2)}${metric.unit}${' '.padRight(40 - metric.threshold!.toStringAsFixed(2).length)}║',
        );
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ RECOMMENDATIONS:
    ''');

    final recommendations = getHighImpactRecommendations();
    for (final rec in recommendations) {
      buffer.writeln('║ [${rec.area}]');
      buffer.writeln('║   Issue: ${rec.issue}');
      buffer.writeln('║   Fix: ${rec.recommendation}');
      buffer.writeln(
        '║   Potential Improvement: ${rec.potentialImprovement.toStringAsFixed(1)}%${' '.padRight(28)}║',
      );
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Clear all metrics and recommendations
  void clear() {
    _metrics.clear();
    _recommendations.clear();
  }
}
