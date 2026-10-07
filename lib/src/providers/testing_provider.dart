import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/test_runner.dart';
import '../utils/security_auditor.dart';
import '../utils/app_store_submission_checklist.dart';

/// Test runner provider
final testRunnerProvider = Provider((ref) => TestRunner());

/// Security auditor provider
final securityAuditorProvider = Provider((ref) => SecurityAuditor());

/// App store submission checklist provider
final appStoreSubmissionProvider =
    Provider((ref) => AppStoreSubmissionChecklist());

/// Unit tests provider
final unitTestsProvider = FutureProvider((ref) async {
  final runner = ref.watch(testRunnerProvider);
  return runner.runUnitTests();
});

/// Widget tests provider
final widgetTestsProvider = FutureProvider((ref) async {
  final runner = ref.watch(testRunnerProvider);
  return runner.runWidgetTests();
});

/// Integration tests provider
final integrationTestsProvider = FutureProvider((ref) async {
  final runner = ref.watch(testRunnerProvider);
  return runner.runIntegrationTests();
});

/// Performance tests provider
final performanceTestsProvider = FutureProvider((ref) async {
  final runner = ref.watch(testRunnerProvider);
  return runner.runPerformanceTests();
});

/// All tests provider
final allTestsProvider = FutureProvider((ref) async {
  final runner = ref.watch(testRunnerProvider);
  await runner.runAllTests();
  return runner.getAllSuites();
});

/// Test statistics provider
final testStatisticsProvider = Provider((ref) {
  final runner = ref.watch(testRunnerProvider);
  return runner.getStatistics();
});

/// Security audit provider
final securityAuditProvider = FutureProvider((ref) async {
  final auditor = ref.watch(securityAuditorProvider);
  await auditor.runFullAudit();
  return auditor.getAllFindings();
});

/// Security audit status provider
final securityAuditStatusProvider = Provider((ref) {
  final auditor = ref.watch(securityAuditorProvider);
  return auditor.isAuditPassed();
});

/// Critical security findings provider
final criticalSecurityFindingsProvider = Provider((ref) {
  final auditor = ref.watch(securityAuditorProvider);
  return auditor.getCriticalFindings();
});

/// App store requirements provider
final appStoreRequirementsProvider = Provider((ref) {
  final checklist = ref.watch(appStoreSubmissionProvider);
  return checklist.getAllRequirements();
});

/// App store completion provider
final appStoreCompletionProvider = Provider((ref) {
  final checklist = ref.watch(appStoreSubmissionProvider);
  return checklist.getCompletionPercentage();
});

/// App store ready status provider
final appStoreReadyProvider = Provider((ref) {
  final checklist = ref.watch(appStoreSubmissionProvider);
  return checklist.isReadyForSubmission();
});

/// iOS requirements provider
final iosRequirementsProvider = Provider((ref) {
  final checklist = ref.watch(appStoreSubmissionProvider);
  return checklist.getRequirementsForPlatform('ios');
});

/// Android requirements provider
final androidRequirementsProvider = Provider((ref) {
  final checklist = ref.watch(appStoreSubmissionProvider);
  return checklist.getRequirementsForPlatform('android');
});

/// Test execution notifier
class TestExecutionNotifier extends StateNotifier<bool> {
  TestExecutionNotifier() : super(false);
  final _runner = TestRunner();

  Future<void> runAllTests() async {
    state = true;
    try {
      await _runner.runAllTests();
    } finally {
      state = false;
    }
  }
}

/// Test execution provider
final testExecutionProvider =
    StateNotifierProvider<TestExecutionNotifier, bool>(
        (ref) => TestExecutionNotifier());

/// Security audit execution notifier
class SecurityAuditNotifier extends StateNotifier<bool> {
  SecurityAuditNotifier() : super(false);
  final _auditor = SecurityAuditor();

  Future<void> runAudit() async {
    state = true;
    try {
      await _auditor.runFullAudit();
    } finally {
      state = false;
    }
  }
}

/// Security audit execution provider
final securityAuditExecutionProvider =
    StateNotifierProvider<SecurityAuditNotifier, bool>(
        (ref) => SecurityAuditNotifier());
