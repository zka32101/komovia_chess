import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Test result status
enum TestStatus {
  passed,
  failed,
  skipped,
  pending,
}

/// Test result model
class TestResult {
  TestResult({
    required this.name,
    required this.category,
    required this.status,
    this.duration,
    this.errorMessage,
    this.stackTrace,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  final String name;
  final String category;
  final TestStatus status;
  final Duration? duration;
  final String? errorMessage;
  final String? stackTrace;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  bool get passed => status == TestStatus.passed;
  bool get failed => status == TestStatus.failed;
  bool get skipped => status == TestStatus.skipped;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'status': status.toString().split('.').last,
        'duration': duration?.inMilliseconds,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'TestResult($name: ${status.toString().split('.').last}${duration != null ? ' - ${duration!.inMilliseconds}ms' : ''})';
}

/// Test session tracking
class TestSession {
  TestSession({
    required this.sessionId,
    required this.deviceName,
    required this.appVersion,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();
  final String sessionId;
  final String deviceName;
  final String appVersion;
  final DateTime startTime;
  late DateTime endTime;
  final List<TestResult> results = [];

  bool get isCompleted => endTime.isAfter(startTime);

  Duration get duration =>
      isCompleted ? endTime.difference(startTime) : Duration.zero;

  int get totalTests => results.length;
  int get passedCount => results.where((r) => r.passed).length;
  int get failedCount => results.where((r) => r.failed).length;
  int get skippedCount => results.where((r) => r.skipped).length;

  double get passRate =>
      totalTests > 0 ? (passedCount / totalTests) * 100 : 0.0;

  void completeSession() {
    endTime = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'deviceName': deviceName,
        'appVersion': appVersion,
        'startTime': startTime.toIso8601String(),
        'endTime': isCompleted ? endTime.toIso8601String() : null,
        'duration': isCompleted ? duration.inMilliseconds : null,
        'results': results.map((r) => r.toJson()).toList(),
        'statistics': {
          'totalTests': totalTests,
          'passed': passedCount,
          'failed': failedCount,
          'skipped': skippedCount,
          'passRate': passRate,
        },
      };

  @override
  String toString() =>
      'TestSession($sessionId: $passedCount/$totalTests passed)';
}

/// Test result tracker
class TestResultTracker {
  factory TestResultTracker() => _instance;

  TestResultTracker._internal();
  static final TestResultTracker _instance = TestResultTracker._internal();

  final _sessions = <TestSession>[];
  TestSession? _currentSession;

  /// Start a new test session
  TestSession startSession({
    required String sessionId,
    required String deviceName,
    required String appVersion,
  }) {
    _currentSession = TestSession(
      sessionId: sessionId,
      deviceName: deviceName,
      appVersion: appVersion,
    );
    _sessions.add(_currentSession!);
    debugPrint('[TestResultTracker] Session started: $sessionId');
    return _currentSession!;
  }

  /// Record test result
  void recordResult({
    required String testName,
    required String category,
    required TestStatus status,
    Duration? duration,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    if (_currentSession == null) {
      debugPrint(
          '[TestResultTracker] No active session. Starting default session.');
      _currentSession = TestSession(
        sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
        deviceName: 'unknown',
        appVersion: 'unknown',
      );
      _sessions.add(_currentSession!);
    }

    final result = TestResult(
      name: testName,
      category: category,
      status: status,
      duration: duration,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: metadata,
    );

    _currentSession!.results.add(result);

    final statusStr = status.toString().split('.').last.toUpperCase();
    final durationStr =
        duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    debugPrint('[TestResultTracker] $testName: $statusStr$durationStr');
  }

  /// Complete current session
  void completeSession() {
    if (_currentSession != null) {
      _currentSession!.completeSession();
      debugPrint(
          '[TestResultTracker] Session completed: ${_currentSession!.sessionId}');
      _currentSession = null;
    }
  }

  /// Get current session
  TestSession? getCurrentSession() => _currentSession;

  /// Get all sessions
  List<TestSession> getAllSessions() => List.unmodifiable(_sessions);

  /// Get session by ID
  TestSession? getSessionById(String sessionId) =>
      _sessions.firstWhere((s) => s.sessionId == sessionId,
          orElse: () => null as dynamic);

  /// Get results by category
  List<TestResult> getResultsByCategory(String category) {
    final results = <TestResult>[];
    for (final session in _sessions) {
      results.addAll(session.results.where((r) => r.category == category));
    }
    return results;
  }

  /// Get results by status
  List<TestResult> getResultsByStatus(TestStatus status) {
    final results = <TestResult>[];
    for (final session in _sessions) {
      results.addAll(session.results.where((r) => r.status == status));
    }
    return results;
  }

  /// Get failed tests
  List<TestResult> getFailedTests() => getResultsByStatus(TestStatus.failed);

  /// Get all test results
  List<TestResult> getAllResults() {
    final results = <TestResult>[];
    for (final session in _sessions) {
      results.addAll(session.results);
    }
    return results;
  }

  /// Generate detailed report
  String generateDetailedReport({String? sessionId}) {
    final sessions = sessionId != null
        ? [getSessionById(sessionId)].whereType<TestSession>().toList()
        : _sessions;

    final buffer = StringBuffer();

    for (final session in sessions) {
      buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                      TEST SESSION REPORT                         ║
╠══════════════════════════════════════════════════════════════════╣
║ Session ID:        ${session.sessionId.padRight(46)}║
║ Device:            ${session.deviceName.padRight(46)}║
║ App Version:       ${session.appVersion.padRight(46)}║
║ Start Time:        ${session.startTime.toString().padRight(46)}║
║ Duration:          ${session.duration.toString().padRight(46)}║
╠══════════════════════════════════════════════════════════════════╣
║ RESULTS SUMMARY:                                                 ║
║ Total Tests:       ${session.totalTests.toString().padRight(46)}║
║ Passed:            ${session.passedCount.toString().padRight(46)}║
║ Failed:            ${session.failedCount.toString().padRight(46)}║
║ Skipped:           ${session.skippedCount.toString().padRight(46)}║
║ Pass Rate:         ${session.passRate.toStringAsFixed(1)}%${' '.padRight(44)}║
╠══════════════════════════════════════════════════════════════════╣
      ''');

      // Group results by category
      final categories = <String>{};
      for (final result in session.results) {
        categories.add(result.category);
      }

      for (final category in categories) {
        final categoryResults =
            session.results.where((r) => r.category == category).toList();
        buffer.writeln('${'║ $category'.padRight(62)}║');

        for (final result in categoryResults) {
          final statusIcon = result.passed ? '✓' : (result.failed ? '✗' : '○');
          final duration = result.duration != null
              ? ' (${result.duration!.inMilliseconds}ms)'
              : '';
          final line = '  $statusIcon ${result.name}$duration';
          buffer.writeln('║${line.padRight(62)}║');

          if (result.failed && result.errorMessage != null) {
            buffer.writeln('║    Error: ${result.errorMessage!.padRight(52)}║');
          }
        }
      }

      buffer.writeln(
          '╚══════════════════════════════════════════════════════════════════╝');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Generate summary report
  String generateSummaryReport() {
    int totalTests = 0;
    int passedTests = 0;
    int failedTests = 0;
    int skippedTests = 0;

    for (final session in _sessions) {
      totalTests += session.totalTests;
      passedTests += session.passedCount;
      failedTests += session.failedCount;
      skippedTests += session.skippedCount;
    }

    final passRate = totalTests > 0 ? (passedTests / totalTests) * 100 : 0.0;

    return '''
╔══════════════════════════════════════════════════════════════════╗
║                   TEST RESULTS SUMMARY                           ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Sessions:    ${_sessions.length.toString().padRight(46)}║
║ Total Tests:       ${totalTests.toString().padRight(46)}║
║ Passed:            ${passedTests.toString().padRight(46)}║
║ Failed:            ${failedTests.toString().padRight(46)}║
║ Skipped:           ${skippedTests.toString().padRight(46)}║
║ Pass Rate:         ${passRate.toStringAsFixed(1)}%${' '.padRight(44)}║
╚══════════════════════════════════════════════════════════════════╝
    ''';
  }

  /// Export test results as JSON
  String exportAsJson({String? sessionId}) {
    final sessions = sessionId != null
        ? [getSessionById(sessionId)].whereType<TestSession>().toList()
        : _sessions;

    final jsonList = sessions.map((s) => s.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Clear all test results
  void clearResults() {
    _sessions.clear();
    _currentSession = null;
    debugPrint('[TestResultTracker] All test results cleared');
  }
}
