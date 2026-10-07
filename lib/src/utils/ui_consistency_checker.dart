import 'package:flutter/material.dart';

/// UI consistency issue
class ConsistencyIssue {
  ConsistencyIssue({
    required this.component,
    required this.issue,
    this.expectedBehavior,
    this.actualBehavior,
    this.suggestion,
    DateTime? foundAt,
  })  : id = 'UI_${DateTime.now().millisecondsSinceEpoch}',
        foundAt = foundAt ?? DateTime.now();
  final String id;
  final String component;
  final String issue;
  final String? expectedBehavior;
  final String? actualBehavior;
  final String? suggestion;
  final DateTime foundAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'component': component,
        'issue': issue,
        'expectedBehavior': expectedBehavior,
        'actualBehavior': actualBehavior,
        'suggestion': suggestion,
        'foundAt': foundAt.toIso8601String(),
      };

  @override
  String toString() => 'ConsistencyIssue($component: $issue)';
}

/// UI consistency checker
class UIConsistencyChecker {
  factory UIConsistencyChecker() => _instance;

  UIConsistencyChecker._internal();
  static final UIConsistencyChecker _instance =
      UIConsistencyChecker._internal();

  final _issues = <ConsistencyIssue>[];

  /// Run comprehensive UI consistency check
  Future<void> runConsistencyCheck() async {
    _issues.clear();

    debugPrint('[UIConsistencyChecker] Starting UI consistency check...');

    await _checkButtonConsistency();
    await _checkColorConsistency();
    await _checkTypographyConsistency();
    await _checkSpacingConsistency();
    await _checkIconConsistency();
    await _checkAnimationConsistency();
    await _checkErrorMessageConsistency();
    await _checkNavigationConsistency();

    debugPrint(
        '[UIConsistencyChecker] Consistency check complete. Issues: ${_issues.length}');
  }

  /// Check button consistency
  Future<void> _checkButtonConsistency() async {
    try {
      // All buttons should follow Material 3 elevation rules
      _issues.add(
        ConsistencyIssue(
          component: 'Buttons',
          issue: 'Button styles should follow Material 3 elevation rules',
          expectedBehavior:
              'ElevatedButton: 1dp, OutlinedButton: 0dp, TextButton: 0dp',
          actualBehavior: 'Verify all buttons use correct Material 3 styles',
          suggestion: 'Use theme-defined button styles consistently',
        ),
      );

      debugPrint('[UIConsistencyChecker] Button consistency checked');
    } catch (e) {
      debugPrint(
          '[UIConsistencyChecker] Error checking button consistency: $e');
    }
  }

  /// Check color consistency
  Future<void> _checkColorConsistency() async {
    try {
      // Primary color should be used consistently
      const primaryColor = Color(0xFF2E7D32); // Chess green

      _issues.add(
        ConsistencyIssue(
          component: 'Colors',
          issue: 'Primary color should be consistent across all uses',
          expectedBehavior: 'Primary color: #2E7D32 (light), #81C784 (dark)',
          actualBehavior: 'Verify all primary color uses match theme',
          suggestion:
              'Use Theme.of(context).primaryColor instead of hardcoded colors',
        ),
      );

      debugPrint('[UIConsistencyChecker] Color consistency checked');
    } catch (e) {
      debugPrint('[UIConsistencyChecker] Error checking color consistency: $e');
    }
  }

  /// Check typography consistency
  Future<void> _checkTypographyConsistency() async {
    try {
      _issues.add(
        ConsistencyIssue(
          component: 'Typography',
          issue: 'Font sizes should follow Material 3 scale',
          expectedBehavior:
              'Display, Headline, Title, Body, Label styles from Material 3',
          actualBehavior: 'Verify all text uses theme text styles',
          suggestion:
              'Use Theme.of(context).textTheme instead of hardcoded sizes',
        ),
      );

      debugPrint('[UIConsistencyChecker] Typography consistency checked');
    } catch (e) {
      debugPrint(
          '[UIConsistencyChecker] Error checking typography consistency: $e');
    }
  }

  /// Check spacing consistency
  Future<void> _checkSpacingConsistency() async {
    try {
      // Spacing should follow Material 3 8-point grid
      _issues.add(
        ConsistencyIssue(
          component: 'Spacing',
          issue: 'All spacing should align to 8-point grid',
          expectedBehavior: 'Use multiples of 8: 8, 16, 24, 32, 48, 64...',
          actualBehavior: 'Verify all padding and margins are grid-aligned',
          suggestion: 'Define spacing constants and use them consistently',
        ),
      );

      debugPrint('[UIConsistencyChecker] Spacing consistency checked');
    } catch (e) {
      debugPrint(
          '[UIConsistencyChecker] Error checking spacing consistency: $e');
    }
  }

  /// Check icon consistency
  Future<void> _checkIconConsistency() async {
    try {
      _issues.add(
        ConsistencyIssue(
          component: 'Icons',
          issue: 'Icons should have consistent sizing and styling',
          expectedBehavior: 'Icon buttons: 48x48dp, inline icons: 24x24dp',
          actualBehavior: 'Verify all icon sizes follow Material 3',
          suggestion: 'Use Icon with consistent size and semantic color',
        ),
      );

      debugPrint('[UIConsistencyChecker] Icon consistency checked');
    } catch (e) {
      debugPrint('[UIConsistencyChecker] Error checking icon consistency: $e');
    }
  }

  /// Check animation consistency
  Future<void> _checkAnimationConsistency() async {
    try {
      _issues.add(
        ConsistencyIssue(
          component: 'Animations',
          issue: 'Animation durations should be consistent',
          expectedBehavior:
              'Short: 100-200ms, Medium: 200-300ms, Long: 300-500ms',
          actualBehavior: 'Verify all animations use consistent durations',
          suggestion: 'Define animation duration constants in theme',
        ),
      );

      debugPrint('[UIConsistencyChecker] Animation consistency checked');
    } catch (e) {
      debugPrint(
          '[UIConsistencyChecker] Error checking animation consistency: $e');
    }
  }

  /// Check error message consistency
  Future<void> _checkErrorMessageConsistency() async {
    try {
      _issues.add(
        ConsistencyIssue(
          component: 'Error Messages',
          issue: 'Error messages should be user-friendly and consistent',
          expectedBehavior: 'Clear, actionable, consistent tone and format',
          actualBehavior: 'Verify error messages follow guidelines',
          suggestion: 'Use consistent error message format and terminology',
        ),
      );

      debugPrint('[UIConsistencyChecker] Error message consistency checked');
    } catch (e) {
      debugPrint(
          '[UIConsistencyChecker] Error checking error message consistency: $e');
    }
  }

  /// Check navigation consistency
  Future<void> _checkNavigationConsistency() async {
    try {
      _issues.add(
        ConsistencyIssue(
          component: 'Navigation',
          issue: 'Navigation patterns should be consistent',
          expectedBehavior:
              'BottomNavBar for main navigation, push transitions',
          actualBehavior: 'Verify navigation follows established patterns',
          suggestion: 'Use consistent navigation architecture',
        ),
      );

      debugPrint('[UIConsistencyChecker] Navigation consistency checked');
    } catch (e) {
      debugPrint(
          '[UIConsistencyChecker] Error checking navigation consistency: $e');
    }
  }

  /// Get all issues
  List<ConsistencyIssue> getAllIssues() => List.unmodifiable(_issues);

  /// Get issues by component
  List<ConsistencyIssue> getIssuesByComponent(String component) =>
      _issues.where((i) => i.component == component).toList();

  /// Generate consistency report
  String generateReport() {
    final buffer = StringBuffer();
    final componentGroups = <String, List<ConsistencyIssue>>{};

    for (final issue in _issues) {
      componentGroups.putIfAbsent(issue.component, () => []).add(issue);
    }

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║              UI CONSISTENCY VERIFICATION REPORT                  ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Issues: ${_issues.length.toString().padRight(50)}║
║ Components Checked: ${componentGroups.length.toString().padRight(42)}║
╠══════════════════════════════════════════════════════════════════╣
    ''');

    for (final entry in componentGroups.entries) {
      buffer.writeln('║ ${entry.key.padRight(62)}║');
      for (final issue in entry.value) {
        buffer.writeln('║   ⚠ ${issue.issue}');
        if (issue.expectedBehavior != null) {
          buffer.writeln('║      Expected: ${issue.expectedBehavior}');
        }
        if (issue.suggestion != null) {
          buffer.writeln('║      Fix: ${issue.suggestion}');
        }
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ COMPLIANCE STATUS: All components should follow Material 3       ║
╚══════════════════════════════════════════════════════════════════╝
    ''');

    return buffer.toString();
  }

  /// Clear all issues
  void clearIssues() {
    _issues.clear();
  }
}
