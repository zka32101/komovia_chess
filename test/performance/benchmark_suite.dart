import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/performance_service.dart';
import 'package:komovia_chess/src/models/rating_progression.dart';

/// Benchmark results structure
class BenchmarkResult {
  final String name;
  final Duration duration;
  final bool passed;
  final String? error;
  final Map<String, dynamic> metadata;

  BenchmarkResult({
    required this.name,
    required this.duration,
    required this.passed,
    this.error,
    this.metadata = const {},
  });

  @override
  String toString() =>
      '$name: ${duration.inMilliseconds}ms ${passed ? "✓" : "✗"}';
}

/// Performance benchmark suite for core services
class PerformanceBenchmarkSuite {
  static const String suiteName =
      'Chess Tactics Master - Performance Benchmarks';
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration defaultWarnThreshold = Duration(seconds: 5);

  final List<BenchmarkResult> results = [];
  final Map<String, Duration> thresholds = {};

  /// Initialize benchmark suite with custom thresholds
  PerformanceBenchmarkSuite({
    Map<String, Duration>? customThresholds,
  }) {
    if (customThresholds != null) {
      thresholds.addAll(customThresholds);
    }
  }

  /// Run a single benchmark test
  Future<BenchmarkResult> runBenchmark(
    String name, {
    required Future<void> Function() test,
    Duration? warnThreshold,
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    dynamic error;

    try {
      await test();
    } catch (e) {
      error = e;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsed;
    final threshold = warnThreshold ?? thresholds[name] ?? defaultWarnThreshold;
    final passed = error == null && duration < threshold;

    final result = BenchmarkResult(
      name: name,
      duration: duration,
      passed: passed,
      error: error?.toString(),
      metadata: metadata ?? {},
    );

    results.add(result);
    return result;
  }

  /// Generate performance report
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('═' * 60);
    buffer.writeln(suiteName);
    buffer.writeln('═' * 60);
    buffer.writeln('');

    buffer.writeln('Summary:');
    buffer.writeln('  Total Benchmarks: ${results.length}');
    buffer.writeln('  Passed: ${results.where((r) => r.passed).length}');
    buffer.writeln('  Failed: ${results.where((r) => !r.passed).length}');
    buffer.writeln(
        '  Total Time: ${_sumDuration(results.map((r) => r.duration))}ms');
    buffer.writeln('');

    buffer.writeln('Results:');
    for (final result in results) {
      final status = result.passed ? '✓' : '✗';
      buffer.writeln('  $status ${result.name}');
      buffer.writeln('     Duration: ${result.duration.inMilliseconds}ms');
      if (result.error != null) {
        buffer.writeln('     Error: ${result.error}');
      }
      if (result.metadata.isNotEmpty) {
        buffer.writeln('     Metadata: ${result.metadata}');
      }
    }

    buffer.writeln('');
    buffer.writeln('═' * 60);
    return buffer.toString();
  }

  /// Reset results for new run
  void reset() {
    results.clear();
  }

  int _sumDuration(Iterable<Duration> durations) {
    return durations.fold(0, (sum, d) => sum + d.inMilliseconds);
  }
}

/// Performance benchmark tests
void main() {
  group('Performance Benchmarks', () {
    late PerformanceBenchmarkSuite suite;

    setUp(() {
      suite = PerformanceBenchmarkSuite(
        customThresholds: {
          'getRatingProgression_30days': Duration(milliseconds: 500),
          'getWinRate': Duration(milliseconds: 300),
          'getStreakInfo': Duration(milliseconds: 400),
          'getPerformanceByRank': Duration(milliseconds: 500),
          'getPerformanceByTimeControl': Duration(milliseconds: 500),
        },
      );
    });

    test('PerformanceService.getRatingProgression - 30 days', () async {
      final performanceService = PerformanceService();

      final result = await suite.runBenchmark(
        'getRatingProgression_30days',
        test: () async {
          await performanceService.getRatingProgression(
            'test_player_1',
            days: 30,
          );
        },
        metadata: {'days': 30, 'service': 'PerformanceService'},
      );

      expect(result.passed, isTrue,
          reason: 'Rating progression should complete within threshold');
    });

    test('PerformanceService.getWinRate - optimization check', () async {
      final performanceService = PerformanceService();

      final result = await suite.runBenchmark(
        'getWinRate',
        test: () async {
          await performanceService.getWinRate('test_player_1');
        },
        metadata: {'service': 'PerformanceService'},
      );

      expect(result.passed, isTrue,
          reason: 'Win rate calculation should be fast');
    });

    test('PerformanceService.getStreakInfo - optimization check', () async {
      final performanceService = PerformanceService();

      final result = await suite.runBenchmark(
        'getStreakInfo',
        test: () async {
          await performanceService.getStreakInfo('test_player_1');
        },
        metadata: {'service': 'PerformanceService'},
      );

      expect(result.passed, isTrue,
          reason: 'Streak calculation should be fast');
    });

    test('PerformanceService.getPerformanceByRank - optimization check',
        () async {
      final performanceService = PerformanceService();

      final result = await suite.runBenchmark(
        'getPerformanceByRank',
        test: () async {
          await performanceService.getPerformanceByRank('test_player_1');
        },
        metadata: {'service': 'PerformanceService'},
      );

      expect(result.passed, isTrue,
          reason: 'Performance by rank should be optimized');
    });

    test('PerformanceService.getPerformanceByTimeControl - optimization check',
        () async {
      final performanceService = PerformanceService();

      final result = await suite.runBenchmark(
        'getPerformanceByTimeControl',
        test: () async {
          await performanceService.getPerformanceByTimeControl('test_player_1');
        },
        metadata: {'service': 'PerformanceService'},
      );

      expect(result.passed, isTrue,
          reason: 'Performance by time control should be optimized');
    });

    test('Benchmark suite generates valid report', () {
      final report = suite.generateReport();

      expect(report, contains('Chess Tactics Master'));
      expect(report, contains('Performance Benchmarks'));
      expect(report, contains('Summary:'));
      expect(report, contains('Total Benchmarks:'));
      expect(report, isNotEmpty);
    });
  });

  group('Benchmark Suite Configuration', () {
    test('allows custom thresholds', () {
      final customThresholds = {
        'custom_test': Duration(milliseconds: 100),
      };

      final suite =
          PerformanceBenchmarkSuite(customThresholds: customThresholds);

      expect(suite.thresholds,
          containsPair('custom_test', Duration(milliseconds: 100)));
    });

    test('reset clears results', () {
      final suite = PerformanceBenchmarkSuite();

      suite.results.add(
        BenchmarkResult(
          name: 'test',
          duration: Duration(milliseconds: 100),
          passed: true,
        ),
      );

      expect(suite.results, isNotEmpty);
      suite.reset();
      expect(suite.results, isEmpty);
    });
  });
}
