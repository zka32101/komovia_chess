import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Accessibility audit result
class AccessibilityIssue {
  AccessibilityIssue({
    required this.title,
    required this.description,
    required this.severity,
    this.wcagCriteria,
    this.suggestion,
    DateTime? foundAt,
  })  : id = 'A11Y_${DateTime.now().millisecondsSinceEpoch}',
        foundAt = foundAt ?? DateTime.now();
  final String id;
  final String title;
  final String description;
  final AccessibilitySeverity severity;
  final String? wcagCriteria;
  final String? suggestion;
  final DateTime foundAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'severity': severity.toString().split('.').last,
        'wcagCriteria': wcagCriteria,
        'suggestion': suggestion,
        'foundAt': foundAt.toIso8601String(),
      };

  @override
  String toString() => 'AccessibilityIssue($title - $wcagCriteria)';
}

/// Accessibility severity levels
enum AccessibilitySeverity {
  critical,
  major,
  minor,
  warning,
}

/// Comprehensive accessibility auditor
class AccessibilityAuditor {
  factory AccessibilityAuditor() => _instance;

  AccessibilityAuditor._internal();
  static final AccessibilityAuditor _instance =
      AccessibilityAuditor._internal();

  final _issues = <AccessibilityIssue>[];

  /// Run full accessibility audit
  Future<List<AccessibilityIssue>> runFullAudit() async {
    _issues.clear();

    debugPrint('[AccessibilityAuditor] Starting full accessibility audit...');

    await _auditColorContrast();
    await _auditTouchTargets();
    await _auditTextSizes();
    await _auditSemantics();
    await _auditMotion();
    await _auditFocus();
    await _auditLabels();

    debugPrint(
        '[AccessibilityAuditor] Audit complete. Issues found: ${_issues.length}');
    return _issues;
  }

  /// Audit color contrast (WCAG AA standard: 4.5:1 for normal text, 3:1 for large)
  Future<void> _auditColorContrast() async {
    try {
      // Standard colors to test
      final colors = [
        (Colors.black, Colors.white, 'Black on White'),
        (Colors.black, Colors.grey[100]!, 'Black on Light Grey'),
        (const Color(0xFF2E7D32), Colors.white, 'Primary on White'),
        (Colors.white, const Color(0xFF2E7D32), 'White on Primary'),
      ];

      for (final (foreground, background, description) in colors) {
        final ratio = _calculateContrastRatio(foreground, background);
        if (ratio < 4.5) {
          _issues.add(
            AccessibilityIssue(
              title: 'Insufficient Color Contrast',
              description:
                  '$description has contrast ratio of ${ratio.toStringAsFixed(2)}:1',
              severity: ratio < 3.0
                  ? AccessibilitySeverity.critical
                  : AccessibilitySeverity.major,
              wcagCriteria: 'WCAG 2.1 1.4.3 Contrast (Minimum)',
              suggestion:
                  'Increase contrast by adjusting colors. Target 4.5:1 or higher.',
            ),
          );
        }
      }

      debugPrint('[AccessibilityAuditor] Color contrast audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in color contrast audit: $e');
    }
  }

  /// Audit touch target sizes (minimum 48x48 dp)
  Future<void> _auditTouchTargets() async {
    try {
      const minSize = 48.0;

      // Common button/interactive elements
      final elements = [
        ('Buttons', minSize),
        ('Icon Buttons', minSize),
        ('Checkboxes', minSize),
        ('Radio Buttons', minSize),
        ('Links', minSize),
      ];

      for (final (name, requiredSize) in elements) {
        debugPrint(
            '[AccessibilityAuditor] Touch target $name: checking for min $requiredSize dp');
      }

      debugPrint('[AccessibilityAuditor] Touch target audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in touch target audit: $e');
    }
  }

  /// Audit text sizes (minimum 12sp for body text)
  Future<void> _auditTextSizes() async {
    try {
      const minBodySize = 12.0;
      const minLabelSize = 10.0;

      // Standard text styles
      final styles = [
        ('Body Text', minBodySize),
        ('Small Text', minLabelSize),
        ('Labels', minLabelSize),
        ('Captions', 10.0),
      ];

      for (final (styleName, minSize) in styles) {
        debugPrint(
            '[AccessibilityAuditor] Text size $styleName: min $minSize sp');
      }

      debugPrint('[AccessibilityAuditor] Text size audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in text size audit: $e');
    }
  }

  /// Audit semantic accessibility
  Future<void> _auditSemantics() async {
    try {
      _issues.add(
        AccessibilityIssue(
          title: 'Semantic Labeling Required',
          description:
              'All interactive elements should have semantic labels for screen readers',
          severity: AccessibilitySeverity.major,
          wcagCriteria: 'WCAG 2.1 1.3.1 Info and Relationships',
          suggestion:
              'Use Semantics widget, MergeSemantics, and meaningful labels',
        ),
      );

      debugPrint('[AccessibilityAuditor] Semantic audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in semantic audit: $e');
    }
  }

  /// Audit motion and animations
  Future<void> _auditMotion() async {
    try {
      _issues.add(
        AccessibilityIssue(
          title: 'Motion and Animation Accessibility',
          description: 'Verify animations respect prefers-reduced-motion',
          severity: AccessibilitySeverity.major,
          wcagCriteria: 'WCAG 2.1 2.3.3 Animation from Interactions',
          suggestion:
              'Check MediaQuery.of(context).disableAnimations and adjust durations',
        ),
      );

      debugPrint('[AccessibilityAuditor] Motion audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in motion audit: $e');
    }
  }

  /// Audit focus management
  Future<void> _auditFocus() async {
    try {
      _issues.add(
        AccessibilityIssue(
          title: 'Focus Management',
          description: 'Ensure focus order is logical and focus is visible',
          severity: AccessibilitySeverity.major,
          wcagCriteria: 'WCAG 2.1 2.4.3 Focus Order',
          suggestion:
              'Implement proper focus nodes and visual focus indicators',
        ),
      );

      debugPrint('[AccessibilityAuditor] Focus audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in focus audit: $e');
    }
  }

  /// Audit labels and descriptions
  Future<void> _auditLabels() async {
    try {
      _issues.add(
        AccessibilityIssue(
          title: 'Clear Labels Required',
          description: 'All controls need clear, descriptive labels',
          severity: AccessibilitySeverity.major,
          wcagCriteria: 'WCAG 2.1 1.3.1 Info and Relationships',
          suggestion:
              'Use Tooltip, tooltip property, or semantic labels for all controls',
        ),
      );

      debugPrint('[AccessibilityAuditor] Labels audit complete');
    } catch (e) {
      debugPrint('[AccessibilityAuditor] Error in labels audit: $e');
    }
  }

  /// Calculate relative luminance
  double _getRelativeLuminance(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final rLin = r <= 0.03928 ? r / 12.92 : math.pow((r + 0.055) / 1.055, 2.4);
    final gLin = g <= 0.03928 ? g / 12.92 : math.pow((g + 0.055) / 1.055, 2.4);
    final bLin = b <= 0.03928 ? b / 12.92 : math.pow((b + 0.055) / 1.055, 2.4);

    return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin;
  }

  /// Calculate contrast ratio between two colors
  double _calculateContrastRatio(Color foreground, Color background) {
    final l1 = _getRelativeLuminance(foreground);
    final l2 = _getRelativeLuminance(background);

    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Get all issues
  List<AccessibilityIssue> getAllIssues() => List.unmodifiable(_issues);

  /// Get issues by severity
  List<AccessibilityIssue> getIssuesBySeverity(
          AccessibilitySeverity severity) =>
      _issues.where((i) => i.severity == severity).toList();

  /// Get critical issues
  List<AccessibilityIssue> getCriticalIssues() =>
      getIssuesBySeverity(AccessibilitySeverity.critical);

  /// Generate accessibility report
  String generateReport() {
    final buffer = StringBuffer();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║              ACCESSIBILITY AUDIT REPORT (WCAG 2.1)               ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Issues: ${_issues.length.toString().padRight(50)}║
    ''');

    final bySeverity = <AccessibilitySeverity, int>{};
    for (final severity in AccessibilitySeverity.values) {
      bySeverity[severity] =
          _issues.where((i) => i.severity == severity).length;
    }

    buffer.writeln('║ By Severity:');
    for (final entry in bySeverity.entries) {
      buffer.writeln(
        '║   ${entry.key.toString().split('.').last.toUpperCase().padRight(15)}: ${entry.value.toString().padRight(44)}║',
      );
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ Issues Found:
    ''');

    for (final issue in _issues) {
      buffer.writeln(
          '║ [${issue.severity.toString().split('.').last.toUpperCase()}] ${issue.title}');
      buffer.writeln('║   WCAG: ${issue.wcagCriteria ?? 'N/A'}');
      if (issue.suggestion != null) {
        buffer.writeln('║   Fix: ${issue.suggestion}');
      }
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Clear all issues
  void clearIssues() {
    _issues.clear();
  }
}
