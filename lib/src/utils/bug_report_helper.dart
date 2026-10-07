import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'device_testing_helper.dart';

/// Bug severity levels
enum BugSeverity {
  critical,
  high,
  medium,
  low,
  enhancement,
}

/// Bug reproduction frequency
enum ReproductionFrequency {
  always,
  often,
  sometimes,
  rarely,
  unknown,
}

/// Bug report model
class BugReport {
  BugReport({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.reproductionFrequency,
    required this.deviceInfo,
    required this.appState,
    required this.steps,
    this.stackTrace,
    this.expectedBehavior,
    this.actualBehavior,
    DateTime? reportedAt,
    this.resolvedAt,
    this.resolution,
  }) : reportedAt = reportedAt ?? DateTime.now();
  final String id;
  final String title;
  final String description;
  final BugSeverity severity;
  final ReproductionFrequency reproductionFrequency;
  final String? stackTrace;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> appState;
  final List<String> steps;
  final String? expectedBehavior;
  final String? actualBehavior;
  final DateTime reportedAt;
  final String? resolvedAt;
  final String? resolution;

  /// Convert to JSON for logging/sending
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'severity': severity.toString().split('.').last,
        'reproductionFrequency':
            reproductionFrequency.toString().split('.').last,
        'stackTrace': stackTrace,
        'deviceInfo': deviceInfo,
        'appState': appState,
        'steps': steps,
        'expectedBehavior': expectedBehavior,
        'actualBehavior': actualBehavior,
        'reportedAt': reportedAt.toIso8601String(),
        'resolvedAt': resolvedAt,
        'resolution': resolution,
      };

  /// Convert to formatted string
  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('Bug Report: $title');
    buffer.writeln('ID: $id');
    buffer.writeln(
        'Severity: ${severity.toString().split('.').last.toUpperCase()}');
    buffer.writeln(
        'Reproduction Frequency: ${reproductionFrequency.toString().split('.').last}');
    buffer.writeln('Reported: ${reportedAt.toString()}');
    buffer.writeln('');
    buffer.writeln('Description:');
    buffer.writeln(description);
    buffer.writeln('');
    buffer.writeln('Steps to Reproduce:');
    for (int i = 0; i < steps.length; i++) {
      buffer.writeln('${i + 1}. ${steps[i]}');
    }
    if (expectedBehavior != null) {
      buffer.writeln('');
      buffer.writeln('Expected Behavior:');
      buffer.writeln(expectedBehavior);
    }
    if (actualBehavior != null) {
      buffer.writeln('');
      buffer.writeln('Actual Behavior:');
      buffer.writeln(actualBehavior);
    }
    if (stackTrace != null) {
      buffer.writeln('');
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace);
    }
    return buffer.toString();
  }

  @override
  String toString() => 'BugReport($title - $id)';
}

/// Bug report helper for collecting and managing bug reports
class BugReportHelper {
  factory BugReportHelper() => _instance;

  BugReportHelper._internal();
  static final BugReportHelper _instance = BugReportHelper._internal();

  final _reports = <BugReport>[];
  final _reportIdGenerator = _ReportIdGenerator();

  /// Create and store a new bug report
  Future<BugReport> createBugReport({
    required String title,
    required String description,
    required BugSeverity severity,
    required ReproductionFrequency reproductionFrequency,
    required List<String> steps,
    String? stackTrace,
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? appState,
    String? expectedBehavior,
    String? actualBehavior,
  }) async {
    try {
      // Collect device information if not provided
      final finalDeviceInfo = deviceInfo ?? await _collectDeviceInfo();
      final finalAppState = appState ?? {};

      final reportId = _reportIdGenerator.generate();
      final report = BugReport(
        id: reportId,
        title: title,
        description: description,
        severity: severity,
        reproductionFrequency: reproductionFrequency,
        stackTrace: stackTrace,
        deviceInfo: finalDeviceInfo,
        appState: finalAppState,
        steps: steps,
        expectedBehavior: expectedBehavior,
        actualBehavior: actualBehavior,
      );

      _reports.add(report);
      debugPrint('[BugReportHelper] Bug report created: $reportId - $title');
      _logBugReport(report);

      return report;
    } catch (e) {
      debugPrint('[BugReportHelper] Error creating bug report: $e');
      rethrow;
    }
  }

  /// Log exception as bug report
  Future<BugReport> logException({
    required String title,
    required Object exception,
    required StackTrace stackTrace,
    BugSeverity severity = BugSeverity.high,
    Map<String, dynamic>? additionalContext,
  }) async =>
      createBugReport(
        title: title,
        description: exception.toString(),
        severity: severity,
        reproductionFrequency: ReproductionFrequency.unknown,
        stackTrace: stackTrace.toString(),
        appState: additionalContext,
        steps: ['Error occurred during application operation'],
        actualBehavior: 'Exception thrown: ${exception.toString()}',
      );

  /// Mark bug as resolved
  void resolveBugReport(String reportId, {String? resolution}) {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      final original = _reports[index];
      _reports[index] = BugReport(
        id: original.id,
        title: original.title,
        description: original.description,
        severity: original.severity,
        reproductionFrequency: original.reproductionFrequency,
        stackTrace: original.stackTrace,
        deviceInfo: original.deviceInfo,
        appState: original.appState,
        steps: original.steps,
        expectedBehavior: original.expectedBehavior,
        actualBehavior: original.actualBehavior,
        reportedAt: original.reportedAt,
        resolvedAt: DateTime.now().toIso8601String(),
        resolution: resolution,
      );
      debugPrint('[BugReportHelper] Bug report resolved: $reportId');
    }
  }

  /// Get all bug reports
  List<BugReport> getAllReports() => List.unmodifiable(_reports);

  /// Get unresolved reports
  List<BugReport> getUnresolvedReports() =>
      _reports.where((r) => r.resolvedAt == null).toList();

  /// Get reports by severity
  List<BugReport> getReportsBySeverity(BugSeverity severity) =>
      _reports.where((r) => r.severity == severity).toList();

  /// Get report by ID
  BugReport? getReportById(String id) =>
      _reports.firstWhere((r) => r.id == id, orElse: () => null as dynamic);

  /// Get critical/high severity reports
  List<BugReport> getCriticalReports() => [
        ..._reports.where((r) => r.severity == BugSeverity.critical),
        ..._reports.where((r) => r.severity == BugSeverity.high),
      ].toList();

  /// Generate bug report summary
  String generateSummary() {
    final buffer = StringBuffer();
    final unresolvedCount = getUnresolvedReports().length;
    final criticalCount = getCriticalReports().length;

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                   BUG REPORT SUMMARY                             ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Reports: ${_reports.length.toString().padRight(50)}║
║ Unresolved: ${unresolvedCount.toString().padRight(54)}║
║ Critical/High: ${criticalCount.toString().padRight(49)}║
╠══════════════════════════════════════════════════════════════════╣
║ SEVERITY BREAKDOWN:                                              ║
    ''');

    for (final severity in BugSeverity.values) {
      final count = _reports.where((r) => r.severity == severity).length;
      buffer.writeln(
        '║   ${severity.toString().split('.').last.toUpperCase().padRight(15)}: $count${' '.padRight(47 - count.toString().length)}║',
      );
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Export reports as JSON
  String exportAsJson({bool unresolvedOnly = false}) {
    final reportsToExport = unresolvedOnly ? getUnresolvedReports() : _reports;
    final jsonList = reportsToExport.map((r) => r.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Clear all reports
  void clearReports() {
    _reports.clear();
    debugPrint('[BugReportHelper] All bug reports cleared');
  }

  /// Collect device information for bug report
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    try {
      final deviceInfo = await DeviceTestingHelper.getDeviceInfo();
      return {
        'platform': deviceInfo.platform,
        'osVersion': deviceInfo.osVersion,
        'deviceModel': deviceInfo.deviceModel,
        'deviceName': deviceInfo.deviceName,
        'appVersion': deviceInfo.appVersion,
        'buildNumber': deviceInfo.buildNumber,
        'isPhysicalDevice': deviceInfo.isPhysicalDevice,
        'manufacturer': deviceInfo.manufacturer,
      };
    } catch (e) {
      debugPrint('[BugReportHelper] Error collecting device info: $e');
      return {'error': e.toString()};
    }
  }

  /// Log bug report to debug console
  void _logBugReport(BugReport report) {
    debugPrint('''
╔══════════════════════════════════════════════════════════════════╗
║                    BUG REPORT LOGGED                             ║
╠══════════════════════════════════════════════════════════════════╣
║ ID: ${report.id.padRight(60)}║
║ Title: ${report.title.padRight(56)}║
║ Severity: ${report.severity.toString().split('.').last.toUpperCase().padRight(54)}║
║ Reproduction: ${report.reproductionFrequency.toString().split('.').last.padRight(50)}║
╠══════════════════════════════════════════════════════════════════╣
║ ${report.description.padRight(62)}║
╚══════════════════════════════════════════════════════════════════╝
    ''');
  }
}

/// Report ID generator
class _ReportIdGenerator {
  int _counter = 0;

  String generate() {
    _counter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'BUG-$timestamp-$_counter';
  }
}
