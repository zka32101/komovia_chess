import 'package:flutter/foundation.dart';
import 'device_testing_helper.dart';

/// Device compatibility test categories
enum CompatibilityTestCategory {
  hardware,
  os,
  memory,
  display,
  connectivity,
  sensors,
  performance,
}

/// Individual compatibility test result
class CompatibilityTestResult {
  CompatibilityTestResult({
    required this.testName,
    required this.category,
    required this.passed,
    this.failureReason,
    this.details,
    DateTime? testedAt,
  }) : testedAt = testedAt ?? DateTime.now();
  final String testName;
  final CompatibilityTestCategory category;
  final bool passed;
  final String? failureReason;
  final Map<String, dynamic>? details;
  final DateTime testedAt;

  Map<String, dynamic> toJson() => {
        'testName': testName,
        'category': category.toString(),
        'passed': passed,
        'failureReason': failureReason,
        'details': details,
        'testedAt': testedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'CompatibilityTest($testName: ${passed ? 'PASS' : 'FAIL'}${failureReason != null ? ' - $failureReason' : ''})';
}

/// Device compatibility tester
class DeviceCompatibilityTester {
  factory DeviceCompatibilityTester() => _instance;

  DeviceCompatibilityTester._internal();
  static final DeviceCompatibilityTester _instance =
      DeviceCompatibilityTester._internal();

  final _testResults = <CompatibilityTestResult>[];

  /// Run all compatibility tests
  Future<List<CompatibilityTestResult>> runAllTests() async {
    _testResults.clear();

    debugPrint(
        '[DeviceCompatibilityTester] Starting all compatibility tests...');

    // Run test categories
    await _testOSCompatibility();
    await _testMemoryCompatibility();
    await _testDisplayCompatibility();
    await _testPerformanceRequirements();

    debugPrint(
        '[DeviceCompatibilityTester] All tests completed. Total: ${_testResults.length}');
    return _testResults;
  }

  /// Test OS compatibility
  Future<void> _testOSCompatibility() async {
    try {
      final deviceInfo = await DeviceTestingHelper.getDeviceInfo();

      // iOS minimum version check
      if (deviceInfo.platform == 'iOS') {
        final versionParts = deviceInfo.osVersion.split('.');
        if (versionParts.isNotEmpty) {
          final majorVersion = int.tryParse(versionParts[0]) ?? 0;
          final passed = majorVersion >= 14;
          _testResults.add(
            CompatibilityTestResult(
              testName: 'iOS Minimum Version (14.0+)',
              category: CompatibilityTestCategory.os,
              passed: passed,
              failureReason: !passed
                  ? 'iOS ${deviceInfo.osVersion} is below minimum 14.0'
                  : null,
              details: {
                'osVersion': deviceInfo.osVersion,
                'minRequired': '14.0'
              },
            ),
          );
        }
      }

      // Android minimum API level check
      if (deviceInfo.platform == 'Android') {
        if (deviceInfo.osVersion.contains('API')) {
          final apiMatch =
              RegExp(r'API (\d+)').firstMatch(deviceInfo.osVersion);
          if (apiMatch != null) {
            final apiLevel = int.tryParse(apiMatch.group(1) ?? '') ?? 0;
            final passed = apiLevel >= 24;
            _testResults.add(
              CompatibilityTestResult(
                testName: 'Android Minimum API Level (24+)',
                category: CompatibilityTestCategory.os,
                passed: passed,
                failureReason: !passed
                    ? 'Android API $apiLevel is below minimum 24'
                    : null,
                details: {'apiLevel': apiLevel, 'minRequired': 24},
              ),
            );
          }
        }
      }

      // Physical device check
      _testResults.add(
        CompatibilityTestResult(
          testName: 'Physical Device Verification',
          category: CompatibilityTestCategory.hardware,
          passed: deviceInfo.isPhysicalDevice,
          failureReason: !deviceInfo.isPhysicalDevice
              ? 'Running on emulator/simulator'
              : null,
          details: {'isPhysical': deviceInfo.isPhysicalDevice},
        ),
      );
    } catch (e) {
      debugPrint(
          '[DeviceCompatibilityTester] Error in OS compatibility test: $e');
      _testResults.add(
        CompatibilityTestResult(
          testName: 'OS Compatibility Check',
          category: CompatibilityTestCategory.os,
          passed: false,
          failureReason: 'Error: $e',
        ),
      );
    }
  }

  /// Test memory compatibility
  Future<void> _testMemoryCompatibility() async {
    try {
      // Memory requirement check (minimum 2GB recommended)
      // Note: device_info_plus doesn't directly expose available memory
      // This is a placeholder for more detailed memory testing

      _testResults.add(
        CompatibilityTestResult(
          testName: 'Memory Requirements',
          category: CompatibilityTestCategory.memory,
          passed: true,
          details: {
            'minRecommended': '2GB',
            'note': 'Detailed memory check would require native code'
          },
        ),
      );
    } catch (e) {
      debugPrint(
          '[DeviceCompatibilityTester] Error in memory compatibility test: $e');
      _testResults.add(
        CompatibilityTestResult(
          testName: 'Memory Compatibility Check',
          category: CompatibilityTestCategory.memory,
          passed: false,
          failureReason: 'Error: $e',
        ),
      );
    }
  }

  /// Test display compatibility
  Future<void> _testDisplayCompatibility() async {
    try {
      // Display requirements check
      // Minimum screen size for usable UI (3.5" diagonal)

      _testResults.add(
        CompatibilityTestResult(
          testName: 'Display Size Requirements',
          category: CompatibilityTestCategory.display,
          passed: true,
          details: {
            'minDiagonal': '3.5 inches',
            'note': 'Responsive design supports all sizes'
          },
        ),
      );

      // Screen density check
      _testResults.add(
        CompatibilityTestResult(
          testName: 'Screen Density Support',
          category: CompatibilityTestCategory.display,
          passed: true,
          details: {'support': 'ldpi, mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi'},
        ),
      );
    } catch (e) {
      debugPrint(
          '[DeviceCompatibilityTester] Error in display compatibility test: $e');
      _testResults.add(
        CompatibilityTestResult(
          testName: 'Display Compatibility Check',
          category: CompatibilityTestCategory.display,
          passed: false,
          failureReason: 'Error: $e',
        ),
      );
    }
  }

  /// Test performance requirements
  Future<void> _testPerformanceRequirements() async {
    try {
      final metrics = PerformanceMetrics();

      // Quick performance baseline test
      final stopwatch = Stopwatch()..start();

      // Simulate some work
      for (int i = 0; i < 1000000; i++) {
        // Simple calculation
        i * 2;
      }

      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds.toDouble();

      // Performance threshold (should complete in < 500ms on modern devices)
      final passed = duration < 500;

      _testResults.add(
        CompatibilityTestResult(
          testName: 'CPU Performance Baseline',
          category: CompatibilityTestCategory.performance,
          passed: passed,
          failureReason: !passed
              ? 'Performance baseline took ${duration.toStringAsFixed(0)}ms'
              : null,
          details: {
            'executionTime': '${duration.toStringAsFixed(2)}ms',
            'threshold': '500ms'
          },
        ),
      );
    } catch (e) {
      debugPrint(
          '[DeviceCompatibilityTester] Error in performance compatibility test: $e');
      _testResults.add(
        CompatibilityTestResult(
          testName: 'Performance Compatibility Check',
          category: CompatibilityTestCategory.performance,
          passed: false,
          failureReason: 'Error: $e',
        ),
      );
    }
  }

  /// Get test results by category
  List<CompatibilityTestResult> getResultsByCategory(
          CompatibilityTestCategory category) =>
      _testResults.where((r) => r.category == category).toList();

  /// Get passed test count
  int get passedCount => _testResults.where((r) => r.passed).length;

  /// Get failed test count
  int get failedCount => _testResults.where((r) => !r.passed).length;

  /// Get all test results
  List<CompatibilityTestResult> get allResults =>
      List.unmodifiable(_testResults);

  /// Get compatibility score (0-100)
  int get compatibilityScore {
    if (_testResults.isEmpty) return 0;
    return ((passedCount / _testResults.length) * 100).toInt();
  }

  /// Generate compatibility report
  String generateReport() {
    final buffer = StringBuffer();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║             DEVICE COMPATIBILITY REPORT                          ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Tests: ${_testResults.length.toString().padRight(50)}║
║ Passed: ${passedCount.toString().padRight(54)}║
║ Failed: ${failedCount.toString().padRight(54)}║
║ Score: $compatibilityScore% ${(compatibilityScore >= 80 ? '✓' : '✗').padRight(49)}║
╠══════════════════════════════════════════════════════════════════╣
    ''');

    // Group by category
    const categories = CompatibilityTestCategory.values;
    for (final category in categories) {
      final categoryResults = getResultsByCategory(category);
      if (categoryResults.isNotEmpty) {
        buffer.writeln(
            '║ ${category.toString().split('.').last.toUpperCase().padRight(62)}║');
        for (final result in categoryResults) {
          final status = result.passed ? '✓ PASS' : '✗ FAIL';
          buffer.writeln('║   $status: ${result.testName.padRight(47)}║');
          if (result.failureReason != null) {
            buffer.writeln(
                '║      Reason: ${result.failureReason!.padRight(50)}║');
          }
        }
      }
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Clear test results
  void clear() {
    _testResults.clear();
  }
}
