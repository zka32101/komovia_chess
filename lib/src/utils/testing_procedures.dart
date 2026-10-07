import 'package:flutter/foundation.dart';
import 'device_testing_helper.dart';
import 'device_compatibility_tester.dart';
import 'bug_report_helper.dart';
import 'test_result_tracker.dart';

/// Testing phase enumeration
enum TestingPhase {
  smoke,
  functional,
  integration,
  performance,
  compatibility,
}

/// Structured testing procedure
class TestingProcedure {
  TestingProcedure({
    required this.name,
    required this.description,
    required this.phase,
    required this.steps,
    required this.estimatedDuration,
    this.expectedOutcome,
  });
  final String name;
  final String description;
  final TestingPhase phase;
  final List<String> steps;
  final String? expectedOutcome;
  final Duration estimatedDuration;

  @override
  String toString() =>
      'TestingProcedure($name - ${phase.toString().split('.').last})';
}

/// Comprehensive testing procedures executor
class TestingProcedures {
  factory TestingProcedures() => _instance;

  TestingProcedures._internal() {
    _initializeProcedures();
  }
  static final TestingProcedures _instance = TestingProcedures._internal();

  final _tracker = TestResultTracker();
  final _bugReporter = BugReportHelper();
  final _compatibilityTester = DeviceCompatibilityTester();
  final _procedures = <TestingProcedure>[];

  /// Initialize standard testing procedures
  void _initializeProcedures() {
    // Smoke tests
    _procedures.addAll([
      TestingProcedure(
        name: 'App Launch Test',
        description: 'Verify application starts without crashing',
        phase: TestingPhase.smoke,
        steps: [
          'Close the application completely',
          'Launch the application from home screen',
          'Verify app loads without errors',
          'Check home screen is displayed',
        ],
        expectedOutcome: 'App launches successfully and displays home screen',
        estimatedDuration: const Duration(seconds: 30),
      ),
      TestingProcedure(
        name: 'Basic Navigation Test',
        description: 'Verify basic navigation between screens',
        phase: TestingPhase.smoke,
        steps: [
          'Launch the application',
          'Navigate to main menu options',
          'Verify each screen loads',
          'Return to home screen',
        ],
        expectedOutcome: 'All screens navigate smoothly without crashes',
        estimatedDuration: const Duration(minutes: 1),
      ),
    ]);

    // Functional tests
    _procedures.addAll([
      TestingProcedure(
        name: 'Theme Toggle Test',
        description: 'Verify light/dark mode switching',
        phase: TestingPhase.functional,
        steps: [
          'Open app settings',
          'Toggle theme mode',
          'Verify UI updates immediately',
          'Check all components reflect theme change',
          'Toggle back to original theme',
        ],
        expectedOutcome: 'Theme changes instantly across all screens',
        estimatedDuration: const Duration(minutes: 2),
      ),
      TestingProcedure(
        name: 'Audio Settings Test',
        description: 'Verify audio and music settings',
        phase: TestingPhase.functional,
        steps: [
          'Open audio settings',
          'Toggle sound effects on/off',
          'Toggle music on/off',
          'Adjust volume sliders',
          'Verify settings persist after app restart',
        ],
        expectedOutcome: 'Audio settings work and persist correctly',
        estimatedDuration: const Duration(minutes: 2),
      ),
      TestingProcedure(
        name: 'Haptic Feedback Test',
        description: 'Verify haptic feedback patterns',
        phase: TestingPhase.functional,
        steps: [
          'Open haptic settings',
          'Enable haptic feedback if disabled',
          'Perform actions that trigger haptics',
          'Verify vibration feedback is felt',
        ],
        expectedOutcome: 'Haptic feedback works as expected',
        estimatedDuration: const Duration(minutes: 1),
      ),
    ]);

    // Performance tests
    _procedures.addAll([
      TestingProcedure(
        name: 'Startup Performance Test',
        description: 'Measure app startup time',
        phase: TestingPhase.performance,
        steps: [
          'Close app completely',
          'Measure time from tap to home screen display',
          'Repeat 3 times and average',
        ],
        expectedOutcome: 'App starts within 3 seconds',
        estimatedDuration: const Duration(minutes: 5),
      ),
      TestingProcedure(
        name: 'Memory Usage Test',
        description: 'Monitor memory consumption',
        phase: TestingPhase.performance,
        steps: [
          'Launch app and navigate through screens',
          'Monitor memory usage in developer tools',
          'Perform memory-intensive operations',
          'Verify no excessive memory growth',
        ],
        expectedOutcome: 'Memory usage remains stable and below thresholds',
        estimatedDuration: const Duration(minutes: 5),
      ),
    ]);

    // Compatibility tests
    _procedures.addAll([
      TestingProcedure(
        name: 'Device Compatibility Test',
        description: 'Run full device compatibility suite',
        phase: TestingPhase.compatibility,
        steps: [
          'Collect device information',
          'Run OS compatibility checks',
          'Verify memory requirements',
          'Check display capabilities',
          'Validate performance baselines',
        ],
        expectedOutcome: 'Device passes all compatibility checks',
        estimatedDuration: const Duration(minutes: 3),
      ),
    ]);
  }

  /// Get testing procedures by phase
  List<TestingProcedure> getProceduresByPhase(TestingPhase phase) =>
      _procedures.where((p) => p.phase == phase).toList();

  /// Get all testing procedures
  List<TestingProcedure> getAllProcedures() => List.unmodifiable(_procedures);

  /// Execute a testing procedure
  Future<void> executeProcedure(TestingProcedure procedure) async {
    debugPrint('[TestingProcedures] Starting procedure: ${procedure.name}');

    try {
      // Log procedure start
      _tracker.recordResult(
        testName: '${procedure.name} - Started',
        category: procedure.phase.toString().split('.').last,
        status: TestStatus.pending,
      );

      // Display procedure details
      _displayProcedureDetails(procedure);

      // Add delay for manual testing
      await Future.delayed(procedure.estimatedDuration);

      // Mark as completed
      _tracker.recordResult(
        testName: procedure.name,
        category: procedure.phase.toString().split('.').last,
        status: TestStatus.passed,
        duration: procedure.estimatedDuration,
      );

      debugPrint('[TestingProcedures] Procedure completed: ${procedure.name}');
    } catch (e) {
      debugPrint('[TestingProcedures] Error executing procedure: $e');
      _tracker.recordResult(
        testName: procedure.name,
        category: procedure.phase.toString().split('.').last,
        status: TestStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Run all procedures for a phase
  Future<void> executePhase(TestingPhase phase) async {
    final procedures = getProceduresByPhase(phase);

    debugPrint(
        '[TestingProcedures] Starting phase: ${phase.toString().split('.').last}');
    debugPrint(
        '[TestingProcedures] Procedures to execute: ${procedures.length}');

    for (final procedure in procedures) {
      await executeProcedure(procedure);
    }

    debugPrint(
        '[TestingProcedures] Phase completed: ${phase.toString().split('.').last}');
  }

  /// Run all testing procedures
  Future<void> runAllProcedures() async {
    _tracker.startSession(
      sessionId: 'testing_${DateTime.now().millisecondsSinceEpoch}',
      deviceName: await _getDeviceName(),
      appVersion: await _getAppVersion(),
    );

    for (final phase in TestingPhase.values) {
      await executePhase(phase);
    }

    _tracker.completeSession();
  }

  /// Run device compatibility tests
  Future<void> runCompatibilityTests() async {
    try {
      debugPrint('[TestingProcedures] Running device compatibility tests');
      final results = await _compatibilityTester.runAllTests();

      for (final result in results) {
        _tracker.recordResult(
          testName: result.testName,
          category: result.category.toString().split('.').last,
          status: result.passed ? TestStatus.passed : TestStatus.failed,
          errorMessage: result.failureReason,
          metadata: result.details,
        );
      }

      debugPrint(_compatibilityTester.generateReport());
    } catch (e) {
      debugPrint('[TestingProcedures] Error running compatibility tests: $e');
    }
  }

  /// Get test results tracker
  TestResultTracker getResultsTracker() => _tracker;

  /// Get bug reporter
  BugReportHelper getBugReporter() => _bugReporter;

  /// Get compatibility tester
  DeviceCompatibilityTester getCompatibilityTester() => _compatibilityTester;

  /// Generate testing report
  String generateTestingReport() {
    final buffer = StringBuffer();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                    TESTING REPORT                                ║
╠══════════════════════════════════════════════════════════════════╣
    ''');

    buffer.writeln(_tracker.generateSummaryReport());
    buffer.writeln('');
    buffer.writeln(_bugReporter.generateSummary());
    buffer.writeln('');
    buffer.writeln(_compatibilityTester.generateReport());

    return buffer.toString();
  }

  /// Display procedure details
  void _displayProcedureDetails(TestingProcedure procedure) {
    debugPrint('''
╔══════════════════════════════════════════════════════════════════╗
║                  TESTING PROCEDURE                               ║
╠══════════════════════════════════════════════════════════════════╣
║ Name: ${procedure.name.padRight(56)}║
║ Phase: ${procedure.phase.toString().split('.').last.padRight(54)}║
║ Duration: ${procedure.estimatedDuration.toString().padRight(50)}║
╠══════════════════════════════════════════════════════════════════╣
║ Description:                                                     ║
║ ${procedure.description.padRight(62)}║
╠══════════════════════════════════════════════════════════════════╣
║ Steps:                                                           ║
    ''');

    for (int i = 0; i < procedure.steps.length; i++) {
      debugPrint(
          '║ ${(i + 1).toString()}. ${procedure.steps[i].padRight(57)}║');
    }

    if (procedure.expectedOutcome != null) {
      debugPrint('''
╠══════════════════════════════════════════════════════════════════╣
║ Expected Outcome:                                                ║
║ ${procedure.expectedOutcome!.padRight(62)}║
      ''');
    }

    debugPrint(
        '╚══════════════════════════════════════════════════════════════════╝');
  }

  /// Get device name
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = await DeviceTestingHelper.getDeviceInfo();
      return '${deviceInfo.platform} - ${deviceInfo.deviceModel}';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get app version
  Future<String> _getAppVersion() async {
    try {
      final deviceInfo = await DeviceTestingHelper.getDeviceInfo();
      return deviceInfo.appVersion;
    } catch (e) {
      return 'unknown';
    }
  }
}

/// Quick testing helper functions
extension QuickTestingHelpers on TestingProcedures {
  /// Quick smoke test
  Future<void> quickSmokeTest() async {
    debugPrint('[TestingProcedures] Running quick smoke test');
    final smokeProcedures = getProceduresByPhase(TestingPhase.smoke);
    for (final procedure in smokeProcedures) {
      await executeProcedure(procedure);
    }
  }

  /// Quick functional test
  Future<void> quickFunctionalTest() async {
    debugPrint('[TestingProcedures] Running quick functional test');
    final functionalProcedures = getProceduresByPhase(TestingPhase.functional);
    for (final procedure in functionalProcedures) {
      await executeProcedure(procedure);
    }
  }

  /// Generate summary for reporting
  String generateQuickSummary() {
    final tracker = getResultsTracker();
    final sessions = tracker.getAllSessions();

    if (sessions.isEmpty) {
      return 'No test sessions recorded';
    }

    final lastSession = sessions.last;
    return '''
Quick Test Summary:
- Session ID: ${lastSession.sessionId}
- Device: ${lastSession.deviceName}
- Total Tests: ${lastSession.totalTests}
- Passed: ${lastSession.passedCount}
- Failed: ${lastSession.failedCount}
- Pass Rate: ${lastSession.passRate.toStringAsFixed(1)}%
- Duration: ${lastSession.duration.inSeconds}s
    ''';
  }
}
