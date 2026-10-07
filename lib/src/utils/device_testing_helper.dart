import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device information and testing utilities
class DeviceTestingHelper {
  factory DeviceTestingHelper() => _instance;

  DeviceTestingHelper._internal();
  static final DeviceTestingHelper _instance = DeviceTestingHelper._internal();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get device information for testing
  static Future<DeviceInfo> getDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return DeviceInfo(
          platform: 'iOS',
          osVersion: iosInfo.systemVersion,
          deviceModel: iosInfo.model,
          deviceName: iosInfo.name,
          appVersion: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
          isPhysicalDevice: iosInfo.isPhysicalDevice,
        );
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return DeviceInfo(
          platform: 'Android',
          osVersion:
              '${androidInfo.version.release} (API ${androidInfo.version.sdkInt})',
          deviceModel: androidInfo.model,
          deviceName: androidInfo.device,
          appVersion: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
          isPhysicalDevice: androidInfo.isPhysicalDevice,
          manufacturer: androidInfo.manufacturer,
        );
      }

      return DeviceInfo(
        platform: 'Unknown',
        osVersion: 'Unknown',
        deviceModel: 'Unknown',
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
    } catch (e) {
      debugPrint('[DeviceTestingHelper] Error getting device info: $e');
      rethrow;
    }
  }

  /// Check if device meets minimum requirements
  static Future<List<String>> checkDeviceRequirements() async {
    final issues = <String>[];

    try {
      final deviceInfo = await getDeviceInfo();

      // Check OS version
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final versionParts = deviceInfo.osVersion.split('.');
        if (versionParts.isNotEmpty) {
          final majorVersion = int.tryParse(versionParts[0]) ?? 0;
          if (majorVersion < 14) {
            issues.add(
                'iOS version must be 14.0 or higher (current: ${deviceInfo.osVersion})');
          }
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Extract API level from version string
        if (deviceInfo.osVersion.contains('API')) {
          final apiMatch =
              RegExp(r'API (\d+)').firstMatch(deviceInfo.osVersion);
          if (apiMatch != null) {
            final apiLevel = int.tryParse(apiMatch.group(1) ?? '') ?? 0;
            if (apiLevel < 24) {
              issues.add(
                  'Android API level must be 24 or higher (current: $apiLevel)');
            }
          }
        }
      }

      return issues;
    } catch (e) {
      debugPrint('[DeviceTestingHelper] Error checking requirements: $e');
      return ['Error checking device requirements: $e'];
    }
  }

  /// Log device information for debugging
  static Future<void> logDeviceInfo() async {
    try {
      final deviceInfo = await getDeviceInfo();
      debugPrint('''
╔═══════════════════════════════════════════════════════════════╗
║                     DEVICE INFORMATION                        ║
╠═══════════════════════════════════════════════════════════════╣
║ Platform:          ${deviceInfo.platform.padRight(45)}║
║ OS Version:        ${deviceInfo.osVersion.padRight(45)}║
║ Device Model:      ${deviceInfo.deviceModel.padRight(45)}║
║ Device Name:       ${(deviceInfo.deviceName ?? 'Unknown').padRight(45)}║
║ App Version:       ${deviceInfo.appVersion.padRight(45)}║
║ Build Number:      ${deviceInfo.buildNumber.padRight(45)}║
║ Physical Device:   ${(deviceInfo.isPhysicalDevice ? 'Yes' : 'No').padRight(45)}║
${deviceInfo.manufacturer != null ? '║ Manufacturer:      ${deviceInfo.manufacturer!.padRight(45)}║' : ''}
╚═══════════════════════════════════════════════════════════════╝
      ''');
    } catch (e) {
      debugPrint('[DeviceTestingHelper] Error logging device info: $e');
    }
  }
}

/// Device information model
class DeviceInfo {
  DeviceInfo({
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.appVersion,
    required this.buildNumber,
    this.deviceName,
    this.isPhysicalDevice = true,
    this.manufacturer,
  });
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String? deviceName;
  final String appVersion;
  final String buildNumber;
  final bool isPhysicalDevice;
  final String? manufacturer;

  /// Convert to JSON for logging
  Map<String, dynamic> toJson() => {
        'platform': platform,
        'osVersion': osVersion,
        'deviceModel': deviceModel,
        'deviceName': deviceName,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'isPhysicalDevice': isPhysicalDevice,
        'manufacturer': manufacturer,
      };

  @override
  String toString() => 'DeviceInfo('
      'platform: $platform, '
      'osVersion: $osVersion, '
      'deviceModel: $deviceModel, '
      'appVersion: $appVersion'
      ')';
}

/// Performance metrics helper
class PerformanceMetrics {
  factory PerformanceMetrics() => _instance;

  PerformanceMetrics._internal();
  static final PerformanceMetrics _instance = PerformanceMetrics._internal();

  final _metrics = <String, List<double>>{};

  /// Record a performance metric
  void recordMetric(String name, double value) {
    if (!_metrics.containsKey(name)) {
      _metrics[name] = [];
    }
    _metrics[name]!.add(value);
  }

  /// Get average metric value
  double? getAverageMetric(String name) {
    if (!_metrics.containsKey(name) || _metrics[name]!.isEmpty) {
      return null;
    }

    final values = _metrics[name]!;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  /// Get max metric value
  double? getMaxMetric(String name) {
    if (!_metrics.containsKey(name) || _metrics[name]!.isEmpty) {
      return null;
    }
    return _metrics[name]!.reduce((a, b) => a > b ? a : b);
  }

  /// Get min metric value
  double? getMinMetric(String name) {
    if (!_metrics.containsKey(name) || _metrics[name]!.isEmpty) {
      return null;
    }
    return _metrics[name]!.reduce((a, b) => a < b ? a : b);
  }

  /// Clear all metrics
  void clear() {
    _metrics.clear();
  }

  /// Print performance report
  void printReport() {
    if (_metrics.isEmpty) {
      debugPrint('[PerformanceMetrics] No metrics recorded');
      return;
    }

    debugPrint('''
╔═══════════════════════════════════════════════════════════════╗
║                   PERFORMANCE METRICS REPORT                  ║
╠═══════════════════════════════════════════════════════════════╣
    ''');

    for (final name in _metrics.keys) {
      final avg = getAverageMetric(name);
      final max = getMaxMetric(name);
      final min = getMinMetric(name);
      final count = _metrics[name]!.length;

      debugPrint(
        '${'║ $name'.padRight(30)}${'║ Avg: ${avg?.toStringAsFixed(2) ?? 'N/A'}'.padRight(20)}║',
      );
      debugPrint(
        '${'║ '.padRight(30)}${'║ Max: ${max?.toStringAsFixed(2) ?? 'N/A'}'.padRight(20)}║',
      );
      debugPrint(
        '${'║ '.padRight(30)}${'║ Min: ${min?.toStringAsFixed(2) ?? 'N/A'}'.padRight(20)}║',
      );
      debugPrint(
        '${'║ '.padRight(30)}${'║ Count: $count'.padRight(20)}║',
      );
      debugPrint(
          '╠═══════════════════════════════════════════════════════════════╣');
    }

    debugPrint(
        '╚═══════════════════════════════════════════════════════════════╝');
  }
}
