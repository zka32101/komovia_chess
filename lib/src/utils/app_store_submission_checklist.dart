import 'package:flutter/foundation.dart';

/// App store submission requirement
class SubmissionRequirement {
  SubmissionRequirement({
    required this.title,
    required this.description,
    required this.platform,
    this.isCompleted = false,
    this.notes,
    DateTime? createdAt,
  })  : id = 'REQ_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String title;
  final String description;
  final String platform; // 'both', 'ios', 'android'
  bool isCompleted;
  String? notes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'platform': platform,
        'isCompleted': isCompleted,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  String toString() => '$title${isCompleted ? ' ✓' : ' ○'}';
}

/// App store submission checklist
class AppStoreSubmissionChecklist {
  factory AppStoreSubmissionChecklist() => _instance;

  AppStoreSubmissionChecklist._internal() {
    _initializeRequirements();
  }
  static final AppStoreSubmissionChecklist _instance =
      AppStoreSubmissionChecklist._internal();

  final _requirements = <SubmissionRequirement>[];

  /// Initialize requirements
  void _initializeRequirements() {
    // App Store (iOS) requirements
    _createRequirement(
      'Bundle ID Configuration',
      'Ensure Bundle ID matches App Store app ID (com.yourwish.chess)',
      'ios',
    );

    _createRequirement(
      'App Icons (iOS)',
      'Provide icons: 1024x1024 (App Store), 40x40, 60x60, 120x120, 180x180 (App)',
      'ios',
    );

    _createRequirement(
      'App Screenshots (iOS)',
      'Provide minimum 2 screenshots per screen size (iPhone 6.7", iPhone 5.5")',
      'ios',
    );

    _createRequirement(
      'Privacy Policy URL',
      'Include valid privacy policy URL in App Store Connect',
      'both',
    );

    _createRequirement(
      'Terms of Service',
      'Include valid terms of service URL if applicable',
      'both',
    );

    _createRequirement(
      'App Description',
      'Write compelling app description (170 characters max for subtitle)',
      'both',
    );

    _createRequirement(
      'Keywords',
      'Add up to 30 characters of relevant keywords (comma-separated)',
      'both',
    );

    _createRequirement(
      'Support Email',
      'Provide valid support email address',
      'both',
    );

    _createRequirement(
      'Demo Account',
      'Provide demo account if login is required for testing',
      'both',
    );

    _createRequirement(
      'IDFA Declaration',
      'Declare IDFA usage if tracking is implemented',
      'ios',
    );

    // Google Play (Android) requirements
    _createRequirement(
      'Package Name Configuration',
      'Ensure package name matches Google Play app ID (com.yourwish.chess)',
      'android',
    );

    _createRequirement(
      'App Icons (Android)',
      'Provide 512x512 icon for Google Play + launcher icons (192x192)',
      'android',
    );

    _createRequirement(
      'App Screenshots (Android)',
      'Provide minimum 2 screenshots in 9:16 aspect ratio',
      'android',
    );

    _createRequirement(
      'Feature Graphics',
      'Provide 1024x500 feature graphic for app listing',
      'android',
    );

    _createRequirement(
      'Content Rating Questionnaire',
      'Complete IARC content rating questionnaire',
      'android',
    );

    _createRequirement(
      'Privacy Policy Compliance',
      'Ensure compliance with Google Play privacy policy requirements',
      'android',
    );

    _createRequirement(
      'Version Number',
      'Increment version code and version name appropriately',
      'both',
    );

    _createRequirement(
      'Target SDK Version',
      'Target SDK >= 33 (Android 13) minimum',
      'android',
    );

    _createRequirement(
      'Minimum SDK Version',
      'Minimum SDK >= 24 (Android 7) for compatibility',
      'android',
    );

    _createRequirement(
      'Release Notes',
      'Write clear release notes describing new features and fixes',
      'both',
    );

    _createRequirement(
      'Code Review',
      'Ensure all code reviewed and passes security audit',
      'both',
    );

    _createRequirement(
      'Testing Certification',
      'Confirm all tests pass: unit, widget, integration, performance',
      'both',
    );

    _createRequirement(
      'Analytics Integration',
      'Verify Firebase Analytics is configured and tracking events',
      'both',
    );

    _createRequirement(
      'Crash Reporting',
      'Ensure Crashlytics is enabled for crash reporting',
      'both',
    );

    debugPrint(
        '[AppStoreSubmissionChecklist] Initialized with ${_requirements.length} requirements');
  }

  /// Create requirement
  void _createRequirement(String title, String description, String platform) {
    _requirements.add(
      SubmissionRequirement(
        title: title,
        description: description,
        platform: platform,
      ),
    );
  }

  /// Get all requirements
  List<SubmissionRequirement> getAllRequirements() =>
      List.unmodifiable(_requirements);

  /// Get requirements for platform
  List<SubmissionRequirement> getRequirementsForPlatform(String platform) =>
      _requirements
          .where((r) => r.platform == 'both' || r.platform == platform)
          .toList();

  /// Get completed requirements
  List<SubmissionRequirement> getCompletedRequirements() =>
      _requirements.where((r) => r.isCompleted).toList();

  /// Get incomplete requirements
  List<SubmissionRequirement> getIncompleteRequirements() =>
      _requirements.where((r) => !r.isCompleted).toList();

  /// Get completion percentage
  double getCompletionPercentage() {
    if (_requirements.isEmpty) return 0;
    return (getCompletedRequirements().length / _requirements.length) * 100;
  }

  /// Check if ready for submission
  bool isReadyForSubmission() => getCompletionPercentage() == 100.0;

  /// Mark requirement as completed
  void markCompleted(String id, {String? notes}) {
    final req = _requirements.firstWhere((r) => r.id == id,
        orElse: () => null as dynamic);
    req.isCompleted = true;
    req.notes = notes;
  }

  /// Mark requirement as incomplete
  void markIncomplete(String id) {
    final req = _requirements.firstWhere((r) => r.id == id,
        orElse: () => null as dynamic);
    req.isCompleted = false;
  }

  /// Generate submission checklist report
  String generateReport() {
    final buffer = StringBuffer();
    final completion = getCompletionPercentage();
    final isReady = isReadyForSubmission();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║          APP STORE SUBMISSION CHECKLIST                         ║
╠══════════════════════════════════════════════════════════════════╣
║ Completion: ${completion.toStringAsFixed(1)}%${' '.padRight(44)}║
║ Status: ${(isReady ? '✓ READY' : '⏳ IN PROGRESS').padRight(49)}║
╠══════════════════════════════════════════════════════════════════╣
║ REQUIREMENTS:
    ''');

    final byPlatform = <String, List<SubmissionRequirement>>{};
    for (final req in _requirements) {
      byPlatform.putIfAbsent(req.platform, () => []).add(req);
    }

    for (final entry in byPlatform.entries) {
      buffer.writeln('║ ${entry.key.toUpperCase().padRight(60)}║');
      for (final req in entry.value) {
        final status = req.isCompleted ? '✓' : '○';
        buffer.writeln('║ $status ${req.title.padRight(56)}║');
        if (req.notes != null) {
          buffer.writeln('║   Note: ${req.notes!.padRight(54)}║');
        }
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ STATUS: ${(isReady ? '✓ SUBMISSION APPROVED' : '✗ ACTION REQUIRED').padRight(45)}║
╚══════════════════════════════════════════════════════════════════╝
    ''');

    return buffer.toString();
  }

  /// Clear all progress
  void reset() {
    for (final req in _requirements) {
      req.isCompleted = false;
      req.notes = null;
    }
  }
}
