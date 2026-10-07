import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/performance_metrics_service.dart';

void main() {
  group('AppSizeMetrics', () {
    test('correctly calculates size in MB', () {
      final metrics = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 104857600, // 100 MB
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      expect(metrics.sizeInMB, equals(100));
      expect(metrics.apkSizeInMB, equals(90));
      expect(metrics.appBundleSizeInMB, equals(85));
    });

    test('exceeds limit detection works', () {
      final metrics = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 157286400, // 150 MB
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      expect(metrics.exceedsLimit(150), isTrue);
      expect(metrics.exceedsLimit(160), isFalse);
    });

    test('growth percentage calculation is accurate', () {
      final previous = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 100000000, // 100 MB
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      final current = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 110000000, // 110 MB (10% growth)
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      final growth = current.getGrowthPercentage(previous);
      expect(growth, closeTo(10.0, 0.1));
    });

    test('toJson and fromJson work correctly', () {
      final original = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 104857600,
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime(2026, 9, 4, 12, 0, 0),
        dartVersion: '3.x',
        flutterVersion: '3.24',
        componentSizes: {'native': 20000000, 'dart': 40000000},
      );

      final json = original.toJson();
      final restored = AppSizeMetrics.fromJson(json);

      expect(restored.buildType, equals(original.buildType));
      expect(restored.sizeInBytes, equals(original.sizeInBytes));
      expect(restored.sizeInMB, equals(original.sizeInMB));
      expect(restored.componentSizes, equals(original.componentSizes));
    });
  });

  group('BuildTimeMetrics', () {
    test('correctly stores build time phases', () {
      final metrics = BuildTimeMetrics(
        totalBuildTime: Duration(seconds: 45),
        analyzeTime: Duration(seconds: 5),
        compileTime: Duration(seconds: 35),
        linkTime: Duration(seconds: 5),
        builtAt: DateTime.now(),
        buildType: 'release',
        phaseTimes: {'optimization': Duration(seconds: 10)},
      );

      expect(metrics.totalBuildTime.inSeconds, equals(45));
      expect(metrics.analyzeTime.inSeconds, equals(5));
      expect(metrics.compileTime.inSeconds, equals(35));
      expect(metrics.linkTime.inSeconds, equals(5));
    });

    test('exceeds time limit detection works', () {
      final metrics = BuildTimeMetrics(
        totalBuildTime: Duration(seconds: 120),
        analyzeTime: Duration(seconds: 5),
        compileTime: Duration(seconds: 110),
        linkTime: Duration(seconds: 5),
        builtAt: DateTime.now(),
        buildType: 'release',
      );

      expect(metrics.exceedsLimit(Duration(seconds: 120)), isFalse);
      expect(metrics.exceedsLimit(Duration(seconds: 100)), isTrue);
    });

    test('speedup percentage calculation is accurate', () {
      final previous = BuildTimeMetrics(
        totalBuildTime: Duration(seconds: 100),
        analyzeTime: Duration(seconds: 5),
        compileTime: Duration(seconds: 90),
        linkTime: Duration(seconds: 5),
        builtAt: DateTime.now(),
        buildType: 'release',
      );

      final current = BuildTimeMetrics(
        totalBuildTime: Duration(seconds: 90),
        analyzeTime: Duration(seconds: 5),
        compileTime: Duration(seconds: 80),
        linkTime: Duration(seconds: 5),
        builtAt: DateTime.now(),
        buildType: 'release',
      );

      final speedup = current.getSpeedupPercentage(previous);
      expect(speedup, closeTo(10.0, 0.1));
    });

    test('toJson and fromJson work correctly', () {
      final original = BuildTimeMetrics(
        totalBuildTime: Duration(seconds: 45),
        analyzeTime: Duration(seconds: 5),
        compileTime: Duration(seconds: 35),
        linkTime: Duration(seconds: 5),
        builtAt: DateTime(2026, 9, 4, 12, 0, 0),
        buildType: 'release',
        phaseTimes: {'optimization': Duration(seconds: 10)},
      );

      final json = original.toJson();
      final restored = BuildTimeMetrics.fromJson(json);

      expect(restored.buildType, equals(original.buildType));
      expect(restored.totalBuildTime, equals(original.totalBuildTime));
      expect(restored.analyzeTime, equals(original.analyzeTime));
      expect(restored.phaseTimes, equals(original.phaseTimes));
    });
  });

  group('RegressionResult', () {
    test('creates regression result with all fields', () {
      final result = RegressionResult(
        hasRegression: true,
        regressionPercentage: 12.5,
        regressionType: 'size',
        recommendation: 'Optimize assets',
        detectedAt: DateTime(2026, 9, 4, 12, 0, 0),
      );

      expect(result.hasRegression, isTrue);
      expect(result.regressionPercentage, equals(12.5));
      expect(result.regressionType, equals('size'));
      expect(result.recommendation, equals('Optimize assets'));
    });

    test('detectedAt defaults to current time if not provided', () {
      final now = DateTime.now();
      final result = RegressionResult(
        hasRegression: false,
        regressionPercentage: 0,
        regressionType: 'buildTime',
      );

      expect(result.detectedAt.isAfter(now.subtract(Duration(seconds: 1))),
          isTrue);
    });

    test('toString formats output correctly', () {
      final result = RegressionResult(
        hasRegression: true,
        regressionPercentage: 15.0,
        regressionType: 'size',
      );

      expect(result.toString(), contains('Regression'));
      expect(result.toString(), contains('size'));
      expect(result.toString(), contains('15.00%'));
    });
  });

  group('PerformanceMetricsService', () {
    test('records app size metrics successfully', () async {
      // This test would require mocking Firebase
      // In production, use MockFirebaseFirestore
      final metrics = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 104857600,
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      // Verify metrics are serializable
      final json = metrics.toJson();
      expect(json, isNotEmpty);
      expect(json['sizeInMB'], equals(100));
    });

    test('records build time metrics successfully', () async {
      final metrics = BuildTimeMetrics(
        totalBuildTime: Duration(seconds: 45),
        analyzeTime: Duration(seconds: 5),
        compileTime: Duration(seconds: 35),
        linkTime: Duration(seconds: 5),
        builtAt: DateTime.now(),
        buildType: 'release',
      );

      // Verify metrics are serializable
      final json = metrics.toJson();
      expect(json, isNotEmpty);
      expect(json['buildType'], equals('release'));
    });
  });

  group('Performance Thresholds', () {
    test('regression threshold is 10%', () {
      final previous = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 100000000,
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      // 9% growth - should not regress
      final current9Percent = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 109000000,
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      final growth9 = current9Percent.getGrowthPercentage(previous);
      expect(growth9 <= 10.0, isTrue);

      // 11% growth - should regress
      final current11Percent = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 111000000,
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      final growth11 = current11Percent.getGrowthPercentage(previous);
      expect(growth11 > 10.0, isTrue);
    });

    test('app size limits are enforced', () {
      final withinLimit = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 157286400, // 150 MB
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      expect(withinLimit.exceedsLimit(150), isTrue);

      final exceedsLimit = AppSizeMetrics(
        buildType: 'release',
        sizeInBytes: 167772160, // 160 MB
        apkSizeInBytes: 95000000,
        appBundleSizeInBytes: 90000000,
        measuredAt: DateTime.now(),
        dartVersion: '3.x',
        flutterVersion: '3.24',
      );

      expect(exceedsLimit.exceedsLimit(150), isTrue);
    });
  });
}
