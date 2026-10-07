import 'package:flutter/foundation.dart';

/// Release version model
class ReleaseVersion {
  ReleaseVersion({
    required this.versionString,
    required this.buildNumber,
    required this.releaseDate,
    this.releaseNotes,
    this.features = const [],
    this.bugFixes = const [],
    this.isProduction = false,
  });
  final String versionString; // semantic versioning: major.minor.patch
  final int buildNumber;
  final String releaseDate;
  final String? releaseNotes;
  final List<String> features;
  final List<String> bugFixes;
  final bool isProduction;

  Map<String, dynamic> toJson() => {
        'versionString': versionString,
        'buildNumber': buildNumber,
        'releaseDate': releaseDate,
        'releaseNotes': releaseNotes,
        'features': features,
        'bugFixes': bugFixes,
        'isProduction': isProduction,
      };

  @override
  String toString() => 'ReleaseVersion($versionString build $buildNumber)';
}

/// Release checklist item
class ReleaseChecklistItem {
  ReleaseChecklistItem({
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.notes,
  }) : id = 'RC_${DateTime.now().millisecondsSinceEpoch}';
  final String id;
  final String title;
  final String description;
  bool isCompleted;
  String? notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'notes': notes,
      };

  @override
  String toString() => '$title${isCompleted ? ' ✓' : ' ○'}';
}

/// Release manager
class ReleaseManager {
  factory ReleaseManager() => _instance;

  ReleaseManager._internal() {
    _initializeChecklist();
  }
  static final ReleaseManager _instance = ReleaseManager._internal();

  final _releases = <ReleaseVersion>[];
  final _checklistItems = <ReleaseChecklistItem>[];

  /// Initialize release checklist
  void _initializeChecklist() {
    _checklistItems.addAll([
      ReleaseChecklistItem(
        title: 'All Tests Passing',
        description:
            'Unit, widget, integration, and performance tests all passing',
      ),
      ReleaseChecklistItem(
        title: 'Security Audit Passed',
        description: 'Security audit completed with no critical findings',
      ),
      ReleaseChecklistItem(
        title: 'Performance Benchmarks',
        description:
            'App meets performance targets (startup time, memory, FPS)',
      ),
      ReleaseChecklistItem(
        title: 'UI/UX Review',
        description: 'UI/UX review completed and approved',
      ),
      ReleaseChecklistItem(
        title: 'Accessibility Compliance',
        description: 'WCAG 2.1 AA accessibility standards verified',
      ),
      ReleaseChecklistItem(
        title: 'App Store Submission Ready',
        description: 'All App Store submission requirements met',
      ),
      ReleaseChecklistItem(
        title: 'Google Play Submission Ready',
        description: 'All Google Play submission requirements met',
      ),
      ReleaseChecklistItem(
        title: 'Release Notes Prepared',
        description: 'Clear and comprehensive release notes written',
      ),
      ReleaseChecklistItem(
        title: 'Marketing Assets Ready',
        description: 'Screenshots, descriptions, and keywords prepared',
      ),
      ReleaseChecklistItem(
        title: 'Documentation Updated',
        description: 'README, CHANGELOG, and guides updated',
      ),
      ReleaseChecklistItem(
        title: 'Analytics Configured',
        description: 'Firebase Analytics and event tracking configured',
      ),
      ReleaseChecklistItem(
        title: 'Crash Reporting Enabled',
        description: 'Crashlytics enabled for production monitoring',
      ),
      ReleaseChecklistItem(
        title: 'Version Number Updated',
        description: 'Version string and build number incremented',
      ),
      ReleaseChecklistItem(
        title: 'Code Signing Configured',
        description: 'Certificates and provisioning profiles configured',
      ),
      ReleaseChecklistItem(
        title: 'Final Build Tested',
        description: 'Final release build tested on actual devices',
      ),
    ]);

    debugPrint(
        '[ReleaseManager] Initialized with ${_checklistItems.length} checklist items');
  }

  /// Create new release
  ReleaseVersion createRelease({
    required String versionString,
    required int buildNumber,
    required String releaseDate,
    String? releaseNotes,
    List<String> features = const [],
    List<String> bugFixes = const [],
    bool isProduction = false,
  }) {
    final release = ReleaseVersion(
      versionString: versionString,
      buildNumber: buildNumber,
      releaseDate: releaseDate,
      releaseNotes: releaseNotes,
      features: features,
      bugFixes: bugFixes,
      isProduction: isProduction,
    );

    _releases.add(release);
    debugPrint('[ReleaseManager] Created release: $release');
    return release;
  }

  /// Get all releases
  List<ReleaseVersion> getAllReleases() => List.unmodifiable(_releases);

  /// Get latest release
  ReleaseVersion? getLatestRelease() =>
      _releases.isNotEmpty ? _releases.last : null;

  /// Get checklist items
  List<ReleaseChecklistItem> getChecklistItems() =>
      List.unmodifiable(_checklistItems);

  /// Mark checklist item completed
  void markChecklistItemCompleted(String id, {String? notes}) {
    final item = _checklistItems.firstWhere(
      (i) => i.id == id,
      orElse: () => null as dynamic,
    );
    item.isCompleted = true;
    item.notes = notes;
  }

  /// Get checklist completion percentage
  double getChecklistCompletion() {
    if (_checklistItems.isEmpty) return 0;
    final completed = _checklistItems.where((i) => i.isCompleted).length;
    return (completed / _checklistItems.length) * 100;
  }

  /// Check if release ready
  bool isReleaseReady() => getChecklistCompletion() == 100.0;

  /// Generate release notes template
  String generateReleaseNotesTemplate(ReleaseVersion release) {
    final buffer = StringBuffer();

    buffer.writeln('# Version ${release.versionString}');
    buffer.writeln('## Release Date: ${release.releaseDate}');
    buffer.writeln('## Build: ${release.buildNumber}');
    buffer.writeln();

    if (release.features.isNotEmpty) {
      buffer.writeln('## ✨ New Features');
      for (final feature in release.features) {
        buffer.writeln('- $feature');
      }
      buffer.writeln();
    }

    if (release.bugFixes.isNotEmpty) {
      buffer.writeln('## 🐛 Bug Fixes');
      for (final bugFix in release.bugFixes) {
        buffer.writeln('- $bugFix');
      }
      buffer.writeln();
    }

    buffer.writeln('## 📝 Release Notes');
    buffer.writeln(release.releaseNotes ?? 'N/A');

    return buffer.toString();
  }

  /// Generate release checklist report
  String generateChecklistReport() {
    final buffer = StringBuffer();
    final completion = getChecklistCompletion();
    final isReady = isReleaseReady();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                 RELEASE CHECKLIST                               ║
╠══════════════════════════════════════════════════════════════════╣
║ Completion: ${completion.toStringAsFixed(1)}%${' '.padRight(44)}║
║ Status: ${(isReady ? '✓ READY FOR RELEASE' : '⏳ IN PROGRESS').padRight(43)}║
╠══════════════════════════════════════════════════════════════════╣
║ ITEMS:
    ''');

    for (final item in _checklistItems) {
      final status = item.isCompleted ? '✓' : '○';
      buffer.writeln('║ $status ${item.title.padRight(56)}║');
      if (item.notes != null) {
        buffer.writeln('║   Note: ${item.notes!.padRight(54)}║');
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ RELEASE STATUS: ${(isReady ? '✓ APPROVED FOR RELEASE' : '✗ ACTION REQUIRED').padRight(39)}║
╚══════════════════════════════════════════════════════════════════╝
    ''');

    return buffer.toString();
  }

  /// Clear all data
  void clear() {
    _releases.clear();
    for (final item in _checklistItems) {
      item.isCompleted = false;
      item.notes = null;
    }
  }
}
