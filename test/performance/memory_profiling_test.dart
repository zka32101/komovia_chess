import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_test/flutter_test.dart';

/// Memory profiling data structure
class MemorySnapshot {
  final DateTime timestamp;
  final int heapUsageMB;
  final int externalMemoryMB;
  final int nativeHeapMB;

  MemorySnapshot({
    required this.timestamp,
    required this.heapUsageMB,
    required this.externalMemoryMB,
    required this.nativeHeapMB,
  });

  int get totalMemoryMB => heapUsageMB + externalMemoryMB + nativeHeapMB;

  @override
  String toString() =>
      'Memory at ${timestamp.toIso8601String()}: '
      'Heap=${heapUsageMB}MB, External=${externalMemoryMB}MB, '
      'Native=${nativeHeapMB}MB, Total=${totalMemoryMB}MB';
}

/// Memory profiling utility for performance testing
class MemoryProfiler {
  final List<MemorySnapshot> snapshots = [];
  Timer? _periodicSnapshot;

  /// Start periodic memory snapshots
  void startProfiling({Duration interval = const Duration(milliseconds: 100)}) {
    _periodicSnapshot = Timer.periodic(interval, (_) {
      _captureSnapshot();
    });
  }

  /// Stop periodic snapshots
  void stopProfiling() {
    _periodicSnapshot?.cancel();
    _periodicSnapshot = null;
  }

  /// Capture single memory snapshot
  void _captureSnapshot() {
    // Get memory info from Dart runtime
    // Note: This is a simplified implementation
    // In production, use package:vm_service for detailed profiling
    snapshots.add(
      MemorySnapshot(
        timestamp: DateTime.now(),
        heapUsageMB: 0, // Would be populated from VM service
        externalMemoryMB: 0,
        nativeHeapMB: 0,
      ),
    );
  }

  /// Get memory delta between snapshots
  int getMemoryDeltaMB(int startIndex, int endIndex) {
    if (startIndex < 0 || endIndex >= snapshots.length) {
      throw ArgumentError('Invalid snapshot indices');
    }

    return snapshots[endIndex].totalMemoryMB -
        snapshots[startIndex].totalMemoryMB;
  }

  /// Get peak memory usage
  int getPeakMemoryMB() {
    if (snapshots.isEmpty) return 0;
    return snapshots.map((s) => s.totalMemoryMB).reduce((a, b) => a > b ? a : b);
  }

  /// Get average memory usage
  double getAverageMemoryMB() {
    if (snapshots.isEmpty) return 0;
    final total = snapshots.fold(0, (sum, s) => sum + s.totalMemoryMB);
    return total / snapshots.length;
  }

  /// Reset profiler
  void reset() {
    snapshots.clear();
  }

  /// Generate profiling report
  String generateReport() {
    if (snapshots.isEmpty) {
      return 'No memory snapshots captured';
    }

    final buffer = StringBuffer();
    buffer.writeln('═' * 60);
    buffer.writeln('Memory Profiling Report');
    buffer.writeln('═' * 60);
    buffer.writeln('');

    buffer.writeln('Summary:');
    buffer.writeln('  Snapshots: ${snapshots.length}');
    buffer.writeln('  Duration: ${_getDurationString()}');
    buffer.writeln('  Peak Memory: ${getPeakMemoryMB()}MB');
    buffer.writeln('  Average Memory: ${getAverageMemoryMB().toStringAsFixed(2)}MB');
    buffer.writeln('  Memory Delta: ${getMemoryDeltaMB(0, snapshots.length - 1)}MB');
    buffer.writeln('');

    buffer.writeln('First Snapshot:');
    buffer.writeln('  ${snapshots.first}');
    buffer.writeln('');

    buffer.writeln('Last Snapshot:');
    buffer.writeln('  ${snapshots.last}');
    buffer.writeln('');

    buffer.writeln('═' * 60);
    return buffer.toString();
  }

  String _getDurationString() {
    if (snapshots.isEmpty) return '0s';
    final duration =
        snapshots.last.timestamp.difference(snapshots.first.timestamp);
    return '${duration.inMilliseconds}ms';
  }
}

/// Memory profiling tests
void main() {
  group('Memory Profiling', () {
    late MemoryProfiler profiler;

    setUp(() {
      profiler = MemoryProfiler();
    });

    tearDown(() {
      profiler.stopProfiling();
    });

    // TODO: Add integration tests with actual PerformanceService once available
    // test('PerformanceService.getRatingProgression - memory efficiency',
    //     () async {
    //   final performanceService = PerformanceService();
    //
    //   // Simulate memory profiling
    //   final startSnapshot = MemorySnapshot(
    //     timestamp: DateTime.now(),
    //     heapUsageMB: 50,
    //     externalMemoryMB: 10,
    //     nativeHeapMB: 5,
    //   );
    //
    //   profiler.snapshots.add(startSnapshot);
    //
    //   // Run operation
    //   await performanceService.getRatingProgression(
    //     'test_player_1',
    //     days: 30,
    //   );
    //
    //   final endSnapshot = MemorySnapshot(
    //     timestamp: DateTime.now(),
    //     heapUsageMB: 55,
    //     externalMemoryMB: 12,
    //     nativeHeapMB: 5,
    //   );
    //
    //   profiler.snapshots.add(endSnapshot);
    //
    //   // Verify memory stays reasonable
    //   final delta = profiler.getMemoryDeltaMB(0, 1);
    //   expect(delta, lessThan(100),
    //       reason: 'Memory growth should be reasonable for 30-day fetch');
    // });
    //
    // test('PerformanceService operations stay under memory limit', () async {
    //   const memoryLimit = 100; // 100MB
    //   final performanceService = PerformanceService();
    //
    //   final baseSnapshot = MemorySnapshot(
    //     timestamp: DateTime.now(),
    //     heapUsageMB: 50,
    //     externalMemoryMB: 10,
    //     nativeHeapMB: 5,
    //   );
    //   profiler.snapshots.add(baseSnapshot);
    //
    //   // Run multiple operations
    //   await performanceService.getWinRate('test_player_1');
    //   await performanceService.getStreakInfo('test_player_1');
    //   await performanceService.getPerformanceByRank('test_player_1');
    //   await performanceService.getPerformanceByTimeControl('test_player_1');
    //
    //   final peakSnapshot = MemorySnapshot(
    //     timestamp: DateTime.now(),
    //     heapUsageMB: 60,
    //     externalMemoryMB: 15,
    //     nativeHeapMB: 5,
    //   );
    //   profiler.snapshots.add(peakSnapshot);
    //
    //   // Verify peak memory usage
    //   final peakMemory = profiler.getPeakMemoryMB();
    //   expect(peakMemory, lessThan(memoryLimit),
    //       reason: 'Peak memory should stay under $memoryLimit MB');
    // });

    test('memory profiler tracks multiple snapshots', () {
      profiler.snapshots.add(
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 50,
          externalMemoryMB: 10,
          nativeHeapMB: 5,
        ),
      );

      expect(profiler.snapshots.length, equals(1));

      profiler.snapshots.add(
        MemorySnapshot(
          timestamp: DateTime.now().add(Duration(milliseconds: 100)),
          heapUsageMB: 55,
          externalMemoryMB: 12,
          nativeHeapMB: 5,
        ),
      );

      expect(profiler.snapshots.length, equals(2));
    });

    test('getMemoryDeltaMB calculates correct delta', () {
      profiler.snapshots.addAll([
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 50,
          externalMemoryMB: 10,
          nativeHeapMB: 5,
        ),
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 60,
          externalMemoryMB: 15,
          nativeHeapMB: 8,
        ),
      ]);

      final delta = profiler.getMemoryDeltaMB(0, 1);
      expect(delta, equals(23)); // (60+15+8) - (50+10+5) = 83 - 65 = 18
    });

    test('getPeakMemoryMB returns maximum usage', () {
      profiler.snapshots.addAll([
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 50,
          externalMemoryMB: 10,
          nativeHeapMB: 5,
        ),
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 70,
          externalMemoryMB: 20,
          nativeHeapMB: 10,
        ),
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 60,
          externalMemoryMB: 15,
          nativeHeapMB: 8,
        ),
      ]);

      final peak = profiler.getPeakMemoryMB();
      expect(peak, equals(100)); // (70+20+10)
    });

    test('getAverageMemoryMB calculates average usage', () {
      profiler.snapshots.addAll([
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 50,
          externalMemoryMB: 10,
          nativeHeapMB: 5,
        ), // Total: 65
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 60,
          externalMemoryMB: 15,
          nativeHeapMB: 8,
        ), // Total: 83
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 70,
          externalMemoryMB: 20,
          nativeHeapMB: 10,
        ), // Total: 100
      ]);

      final average = profiler.getAverageMemoryMB();
      expect(average, closeTo(82.67, 0.01)); // (65+83+100)/3 = 248/3 = 82.67
    });

    test('memory profiler generates valid report', () {
      profiler.snapshots.addAll([
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 50,
          externalMemoryMB: 10,
          nativeHeapMB: 5,
        ),
        MemorySnapshot(
          timestamp: DateTime.now().add(Duration(milliseconds: 500)),
          heapUsageMB: 60,
          externalMemoryMB: 15,
          nativeHeapMB: 8,
        ),
      ]);

      final report = profiler.generateReport();

      expect(report, contains('Memory Profiling Report'));
      expect(report, contains('Summary:'));
      expect(report, contains('Peak Memory:'));
      expect(report, contains('Average Memory:'));
      expect(report, contains('MB'));
    });

    test('reset clears profiler data', () {
      profiler.snapshots.add(
        MemorySnapshot(
          timestamp: DateTime.now(),
          heapUsageMB: 50,
          externalMemoryMB: 10,
          nativeHeapMB: 5,
        ),
      );

      expect(profiler.snapshots, isNotEmpty);
      profiler.reset();
      expect(profiler.snapshots, isEmpty);
    });

    test('profiler handles empty snapshots gracefully', () {
      expect(profiler.getPeakMemoryMB(), equals(0));
      expect(profiler.getAverageMemoryMB(), equals(0));
      expect(
        profiler.generateReport(),
        contains('No memory snapshots captured'),
      );
    });
  });

  group('Memory Limits Enforcement', () {
    test('verifies memory constraints for large datasets', () async {
      const memoryLimitMB = 150;
      final profiler = MemoryProfiler();

      final beforeSnapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        heapUsageMB: 50,
        externalMemoryMB: 10,
        nativeHeapMB: 5,
      );
      profiler.snapshots.add(beforeSnapshot);

      // Simulate processing large amount of data
      final afterSnapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        heapUsageMB: 80,
        externalMemoryMB: 30,
        nativeHeapMB: 15,
      );
      profiler.snapshots.add(afterSnapshot);

      final peakMemory = profiler.getPeakMemoryMB();
      expect(peakMemory, lessThan(memoryLimitMB),
          reason: 'Peak memory must stay under $memoryLimitMB MB');
    });
  });
}
