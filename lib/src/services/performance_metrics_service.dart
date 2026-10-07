import 'package:cloud_firestore/cloud_firestore.dart';

/// Application size metrics
class AppSizeMetrics {
  // Component breakdown

  AppSizeMetrics({
    required this.buildType,
    required this.sizeInBytes,
    required this.apkSizeInBytes,
    required this.appBundleSizeInBytes,
    required this.measuredAt,
    required this.dartVersion,
    required this.flutterVersion,
    this.componentSizes = const {},
  });

  factory AppSizeMetrics.fromJson(Map<String, dynamic> json) => AppSizeMetrics(
        buildType: json['buildType'] as String,
        sizeInBytes: json['sizeInBytes'] as int,
        apkSizeInBytes: json['apkSizeInBytes'] as int,
        appBundleSizeInBytes: json['appBundleSizeInBytes'] as int,
        measuredAt: DateTime.parse(json['measuredAt'] as String),
        dartVersion: json['dartVersion'] as String,
        flutterVersion: json['flutterVersion'] as String,
        componentSizes: Map<String, int>.from(
          json['componentSizes'] as Map<String, dynamic>? ?? {},
        ),
      );
  final String buildType; // 'release', 'debug', 'profile'
  final int sizeInBytes;
  final int apkSizeInBytes;
  final int appBundleSizeInBytes;
  final DateTime measuredAt;
  final String dartVersion;
  final String flutterVersion;
  final Map<String, int> componentSizes;

  int get sizeInMB => sizeInBytes ~/ (1024 * 1024);
  int get apkSizeInMB => apkSizeInBytes ~/ (1024 * 1024);
  int get appBundleSizeInMB => appBundleSizeInBytes ~/ (1024 * 1024);

  bool exceedsLimit(int limitMB) => sizeInMB > limitMB;

  double getGrowthPercentage(AppSizeMetrics previous) {
    if (previous.sizeInBytes == 0) return 0;
    return ((sizeInBytes - previous.sizeInBytes) / previous.sizeInBytes * 100)
        .toDouble();
  }

  Map<String, dynamic> toJson() => {
        'buildType': buildType,
        'sizeInBytes': sizeInBytes,
        'sizeInMB': sizeInMB,
        'apkSizeInBytes': apkSizeInBytes,
        'apkSizeInMB': apkSizeInMB,
        'appBundleSizeInBytes': appBundleSizeInBytes,
        'appBundleSizeInMB': appBundleSizeInMB,
        'measuredAt': measuredAt.toIso8601String(),
        'dartVersion': dartVersion,
        'flutterVersion': flutterVersion,
        'componentSizes': componentSizes,
      };
}

/// Build time metrics
class BuildTimeMetrics {
  BuildTimeMetrics({
    required this.totalBuildTime,
    required this.analyzeTime,
    required this.compileTime,
    required this.linkTime,
    required this.builtAt,
    required this.buildType,
    this.phaseTimes = const {},
  });

  factory BuildTimeMetrics.fromJson(Map<String, dynamic> json) =>
      BuildTimeMetrics(
        totalBuildTime: Duration(milliseconds: json['totalBuildTime'] as int),
        analyzeTime: Duration(milliseconds: json['analyzeTime'] as int),
        compileTime: Duration(milliseconds: json['compileTime'] as int),
        linkTime: Duration(milliseconds: json['linkTime'] as int),
        builtAt: DateTime.parse(json['builtAt'] as String),
        buildType: json['buildType'] as String,
        phaseTimes: Map<String, Duration>.from(
          (json['phaseTimes'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, Duration(milliseconds: value as int)),
          ),
        ),
      );
  final Duration totalBuildTime;
  final Duration analyzeTime;
  final Duration compileTime;
  final Duration linkTime;
  final DateTime builtAt;
  final String buildType; // 'debug', 'profile', 'release'
  final Map<String, Duration> phaseTimes;

  bool exceedsLimit(Duration limitDuration) => totalBuildTime > limitDuration;

  double getSpeedupPercentage(BuildTimeMetrics previous) {
    if (previous.totalBuildTime.inMilliseconds == 0) return 0;
    return ((previous.totalBuildTime.inMilliseconds -
                totalBuildTime.inMilliseconds) /
            previous.totalBuildTime.inMilliseconds *
            100)
        .toDouble();
  }

  Map<String, dynamic> toJson() => {
        'totalBuildTime': totalBuildTime.inMilliseconds,
        'analyzeTime': analyzeTime.inMilliseconds,
        'compileTime': compileTime.inMilliseconds,
        'linkTime': linkTime.inMilliseconds,
        'builtAt': builtAt.toIso8601String(),
        'buildType': buildType,
        'phaseTimes': phaseTimes.map(
          (key, value) => MapEntry(key, value.inMilliseconds),
        ),
      };
}

/// Performance regression detection result
class RegressionResult {
  RegressionResult({
    required this.hasRegression,
    required this.regressionPercentage,
    required this.regressionType,
    this.recommendation,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
  final bool hasRegression;
  final double regressionPercentage;
  final String regressionType; // 'size', 'buildTime', 'memory'
  final String? recommendation;
  final DateTime detectedAt;

  @override
  String toString() =>
      'Regression($regressionType): ${hasRegression ? regressionPercentage.toStringAsFixed(2) : 'None'}%';
}

/// Performance metrics service for tracking app performance
class PerformanceMetricsService {
  // 10% threshold

  PerformanceMetricsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  static const String _collection = 'performance_metrics';
  static const double _regressionThreshold = 10;

  /// Record app size metrics
  Future<void> recordAppSizeMetrics(AppSizeMetrics metrics) async {
    try {
      await _firestore
          .collection(_collection)
          .doc('app_size')
          .collection('history')
          .doc(metrics.measuredAt.toIso8601String())
          .set(metrics.toJson());
    } catch (e) {
      throw Exception('Failed to record app size metrics: $e');
    }
  }

  /// Record build time metrics
  Future<void> recordBuildTimeMetrics(BuildTimeMetrics metrics) async {
    try {
      await _firestore
          .collection(_collection)
          .doc('build_time')
          .collection('history')
          .doc(metrics.builtAt.toIso8601String())
          .set(metrics.toJson());
    } catch (e) {
      throw Exception('Failed to record build time metrics: $e');
    }
  }

  /// Detect size regression compared to previous build
  Future<RegressionResult> detectSizeRegression(
    AppSizeMetrics current,
  ) async {
    try {
      final previousSnapshot = await _firestore
          .collection(_collection)
          .doc('app_size')
          .collection('history')
          .orderBy('measuredAt', descending: true)
          .limit(2)
          .get();

      if (previousSnapshot.docs.length < 2) {
        return RegressionResult(
          hasRegression: false,
          regressionPercentage: 0,
          regressionType: 'size',
        );
      }

      final previousData = previousSnapshot.docs[1].data();
      final previous = AppSizeMetrics.fromJson(previousData);

      final growthPercentage = current.getGrowthPercentage(previous);

      return RegressionResult(
        hasRegression: growthPercentage > _regressionThreshold,
        regressionPercentage: growthPercentage,
        regressionType: 'size',
        recommendation: growthPercentage > _regressionThreshold
            ? 'App size grew ${growthPercentage.toStringAsFixed(2)}%. '
                'Consider optimizing assets or dependencies.'
            : null,
      );
    } catch (e) {
      throw Exception('Failed to detect size regression: $e');
    }
  }

  /// Detect build time regression
  Future<RegressionResult> detectBuildTimeRegression(
    BuildTimeMetrics current,
  ) async {
    try {
      final previousSnapshot = await _firestore
          .collection(_collection)
          .doc('build_time')
          .collection('history')
          .orderBy('builtAt', descending: true)
          .limit(2)
          .get();

      if (previousSnapshot.docs.length < 2) {
        return RegressionResult(
          hasRegression: false,
          regressionPercentage: 0,
          regressionType: 'buildTime',
        );
      }

      final previousData = previousSnapshot.docs[1].data();
      final previous = BuildTimeMetrics.fromJson(previousData);

      final speedupPercentage = current.getSpeedupPercentage(previous);
      final regressionPercentage = -speedupPercentage;

      return RegressionResult(
        hasRegression: regressionPercentage > _regressionThreshold,
        regressionPercentage: regressionPercentage,
        regressionType: 'buildTime',
        recommendation: regressionPercentage > _regressionThreshold
            ? 'Build time increased ${regressionPercentage.toStringAsFixed(2)}%. '
                'Check recent dependency or code changes.'
            : null,
      );
    } catch (e) {
      throw Exception('Failed to detect build time regression: $e');
    }
  }

  /// Get latest app size metrics
  Future<AppSizeMetrics?> getLatestAppSizeMetrics() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc('app_size')
          .collection('history')
          .orderBy('measuredAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return AppSizeMetrics.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get latest app size metrics: $e');
    }
  }

  /// Get latest build time metrics
  Future<BuildTimeMetrics?> getLatestBuildTimeMetrics() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc('build_time')
          .collection('history')
          .orderBy('builtAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return BuildTimeMetrics.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get latest build time metrics: $e');
    }
  }

  /// Get metrics history for comparison
  Future<List<AppSizeMetrics>> getAppSizeHistory({
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc('app_size')
          .collection('history')
          .orderBy('measuredAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AppSizeMetrics.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get app size history: $e');
    }
  }

  /// Get build time history for comparison
  Future<List<BuildTimeMetrics>> getBuildTimeHistory({
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc('build_time')
          .collection('history')
          .orderBy('builtAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BuildTimeMetrics.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get build time history: $e');
    }
  }

  /// Stream app size metrics history
  Stream<List<AppSizeMetrics>> watchAppSizeMetrics() => _firestore
      .collection(_collection)
      .doc('app_size')
      .collection('history')
      .orderBy('measuredAt', descending: true)
      .limit(30)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppSizeMetrics.fromJson(doc.data()))
          .toList())
      .handleError(
          (e) => throw Exception('Failed to watch app size metrics: $e'));

  /// Stream build time metrics history
  Stream<List<BuildTimeMetrics>> watchBuildTimeMetrics() => _firestore
      .collection(_collection)
      .doc('build_time')
      .collection('history')
      .orderBy('builtAt', descending: true)
      .limit(30)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BuildTimeMetrics.fromJson(doc.data()))
          .toList())
      .handleError(
          (e) => throw Exception('Failed to watch build time metrics: $e'));
}
