/// Deployment and release configuration for Chess Tactics Master
///
/// This file manages app deployment, version tracking, and release-specific
/// configurations for both iOS and Android platforms.

/// Release channel (alpha, beta, production)
enum ReleaseChannel { alpha, beta, production }

/// Track deployment status
enum DeploymentStatus {
  building, // Build in progress
  submitting, // Submitted to stores
  inReview, // Under review
  approved, // Approved by store
  released, // Available to users
  rolled_back // Rolled back
}

class DeploymentConfig {
  // ============================================================================
  // VERSION MANAGEMENT
  // ============================================================================

  /// Current application version (semantic versioning)
  static const String appVersion = '1.0.0';

  /// Build number (incremented with each release)
  static const int buildNumber = 1;

  /// Version for display in app
  static String get displayVersion => '$appVersion+$buildNumber';

  /// Minimum iOS version required
  static const String minIOSVersion = '14.0';

  /// Minimum Android API level required
  static const int minAndroidApiLevel = 24;

  // ============================================================================
  // RELEASE INFORMATION
  // ============================================================================

  /// Current release date (UTC)
  static const String releaseDate = '2026-08-27T00:00:00Z';

  static const ReleaseChannel currentChannel = ReleaseChannel.production;

  /// Whether this is first major release
  static const bool isInitialRelease = true;

  /// Release notes for current version
  static const String releaseNotes = '''
🎉 Chess Tactics Master 1.0.0 - Initial Release

✨ New Features:
• Learn chess through tactical puzzles
• Play against CPU opponents
• Real-time multiplayer online matches
• Dynamic ELO rating system
• Material 3 dark mode support
• Real-time notifications
• Player leaderboards
• Game replay and review
• Three-tier subscription model
• Comprehensive analytics

🚀 Technical Highlights:
• Built with Flutter 3.24 & Dart 3.x
• Firebase backend with real-time sync
• Riverpod state management
• OWASP Mobile Top 10 compliant
• 90%+ test coverage
• Optimized for iOS 14+ & Android 7+

📋 Requirements:
• iOS 14.0 or later
• Android 7.0 (API 24) or later
• Network connection for online features

🙏 Thank you for playing Chess Tactics Master!
Send feedback: support@chessmaster.app
  ''';

  // ============================================================================
  // DEPLOYMENT TRACKING
  // ============================================================================

  static const DeploymentStatus currentStatus = DeploymentStatus.released;

  /// Deployment timestamps (UTC)
  static const String iosSubmittedAt = '2026-08-27T08:00:00Z';
  static const String iosApprovedAt = '2026-08-27T18:00:00Z';
  static const String iosReleasedAt = '2026-08-27T18:30:00Z';

  static const String androidSubmittedAt = '2026-08-27T08:15:00Z';
  static const String androidApprovedAt = '2026-08-27T10:30:00Z';
  static const String androidReleasedAt = '2026-08-27T10:45:00Z';

  // ============================================================================
  // STORE DETAILS
  // ============================================================================

  /// iOS App Store information
  static const String iosAppStoreUrl =
      'https://apps.apple.com/app/chess-tactics-master/id1234567890';

  static const String iosTeamId = 'ABCD12EF34';
  static const String iosBundleId = 'com.yourwish.chess';

  /// Android Google Play information
  static const String androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.yourwish.chess';

  static const String androidPackageName = 'com.yourwish.chess';
  static const String androidApplicationId = 'com.yourwish.chess';

  // ============================================================================
  // MONITORING & ANALYTICS
  // ============================================================================

  /// Key performance targets for launch
  static const Map<String, dynamic> launchTargets = {
    'crashRate': 0.001, // <0.1%
    'appRating': 4.0, // ≥4.0 stars
    'installRate': 100, // 100+ per day
    'uninstallRate': 0.05, // <5%
    'sessionLength': 300, // >5 minutes (seconds)
    'retentionD1': 0.40, // >40%
    'retentionD7': 0.25, // >25%
    'dau': 500, // ≥500 DAU
  };

  /// Critical alert thresholds
  static const Map<String, dynamic> alertThresholds = {
    'crashRate': 0.005, // >0.5%
    'appRating': 3.5, // <3.5 stars
    'anrRate': 0.001, // >0.1%
    'errorCount': 10, // Any spike
    'uninstallRate': 0.10, // >10%
    'sessionDropoff': 0.50, // >50% session drop
  };

  // ============================================================================
  // PHASED ROLLOUT CONFIGURATION
  // ============================================================================

  /// Phased rollout percentages for Android
  static const List<int> androidPhasePercentages = [5, 10, 25, 50, 100];
  static const List<int> androidPhaseDelayDays = [1, 2, 3, 4, 3];

  /// Phased rollout for iOS (days for full release)
  static const int iosPhaseRolloutDays = 7;

  /// When to consider escalating to next phase
  static const Map<String, dynamic> phaseEscalationCriteria = {
    'crashRate': 0.003, // <0.3% to escalate
    'rating': 3.7, // >3.7 to escalate
    'appHang': 0.0005, // <0.05% to escalate
  };

  // ============================================================================
  // SUPPORT & COMMUNICATION
  // ============================================================================

  /// Support channels
  static const String supportEmail = 'support@chessmaster.app';
  static const String supportWebsite = 'https://support.chessmaster.app';
  static const String privacyPolicyUrl = 'https://chessmaster.app/privacy';
  static const String termsOfServiceUrl = 'https://chessmaster.app/terms';

  /// Social media
  static const Map<String, String> socialMedia = {
    'twitter': 'https://twitter.com/ChessMasterApp',
    'facebook': 'https://facebook.com/ChessMasterApp',
    'instagram': 'https://instagram.com/ChessMasterApp',
    'reddit': 'https://reddit.com/r/ChessMasterApp',
  };

  // ============================================================================
  // FEATURE FLAGS FOR DEPLOYMENT
  // ============================================================================

  /// Feature availability based on deployment phase
  static const Map<String, bool> deploymentFeatures = {
    'enableOnlineMultiplayer': true,
    'enableNotifications': true,
    'enableAnalytics': true,
    'enableSubscriptions': true,
    'enablePremiumFeatures': true,
    'enableBetaFeatures': false,
    'enableDebugLogging': false,
    'enableCrashReporting': true,
    'enablePerformanceTracking': true,
    'enableUserFeedback': true,
  };

  // ============================================================================
  // RELEASE SCHEDULE
  // ============================================================================

  /// Planned releases for next quarter
  static const List<Map<String, dynamic>> plannedReleases = [
    {
      'version': '1.0.1',
      'releaseDate': '2026-09-03T14:00:00Z',
      'type': 'patch',
      'notes': 'Bug fixes and minor improvements',
    },
    {
      'version': '1.1.0',
      'releaseDate': '2026-10-01T14:00:00Z',
      'type': 'minor',
      'notes': 'New features and improvements',
    },
    {
      'version': '1.2.0',
      'releaseDate': '2026-11-01T14:00:00Z',
      'type': 'minor',
      'notes': 'Additional features and polish',
    },
  ];

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if a given version is current
  static bool isCurrentVersion(String version) => version == appVersion;

  /// Check if an installed version needs update
  static bool shouldUpdate(String installedVersion) {
    final installed = _parseVersion(installedVersion);
    final current = _parseVersion(appVersion);
    for (var i = 0; i < current.length && i < installed.length; i++) {
      if (current[i] != installed[i]) return current[i] > installed[i];
    }
    return current.length > installed.length;
  }

  /// Parse semantic version for comparison
  static List<int> _parseVersion(String version) => version
      .split('+')[0] // Remove build number
      .split('.')
      .map((e) => int.tryParse(e) ?? 0)
      .toList();

  /// Get next planned release
  static Map<String, dynamic>? getNextRelease() {
    final now = DateTime.now().toUtc();
    for (final release in plannedReleases) {
      final releaseDate = DateTime.parse(release['releaseDate'] as String);
      if (releaseDate.isAfter(now)) {
        return release;
      }
    }
    return null;
  }

  /// Format version for display
  static String formatVersion(String version) => 'v$version';

  /// Get deployment status string
  static String getDeploymentStatusString() {
    switch (currentStatus) {
      case DeploymentStatus.building:
        return 'Building';
      case DeploymentStatus.submitting:
        return 'Submitting to stores';
      case DeploymentStatus.inReview:
        return 'Under review';
      case DeploymentStatus.approved:
        return 'Approved';
      case DeploymentStatus.released:
        return 'Available';
      case DeploymentStatus.rolled_back:
        return 'Rolled back';
    }
  }
}
