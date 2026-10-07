/// Release configuration for Chess Tactics Master

/// Environment configuration
enum Environment { development, staging, production }

class ReleaseConfig {
  /// App version
  static const String appVersion = '1.0.0';

  /// Build number
  static const int buildNumber = 1;

  /// API version
  static const String apiVersion = '1.0';

  /// Minimum iOS version
  static const String minIOSVersion = '14.0';

  /// Minimum Android API level
  static const int minAndroidApiLevel = 24;

  /// Feature flags
  static const Map<String, bool> featureFlags = {
    'enableOnlineMultiplayer': true,
    'enableDarkMode': true,
    'enableNotifications': true,
    'enableAnalytics': true,
    'enableSubscriptions': true,
    'enablePremiumFeatures': true,
    'enableBetaFeatures': false,
  };

  static const Environment currentEnvironment = Environment.production;

  /// Get base API URL
  static String getApiUrl() {
    switch (currentEnvironment) {
      case Environment.development:
        return 'http://localhost:8080';
      case Environment.staging:
        return 'https://staging-api.chess-tactics.com';
      case Environment.production:
        return 'https://api.chess-tactics.com';
    }
  }

  /// Get Firebase project ID
  static String getFirebaseProjectId() {
    switch (currentEnvironment) {
      case Environment.development:
        return 'chess-tactics-dev';
      case Environment.staging:
        return 'chess-tactics-staging';
      case Environment.production:
        return 'yourwish-chess';
    }
  }

  /// Should enable debug logging
  static bool get enableDebugLogging =>
      currentEnvironment != Environment.production;

  /// Should enable analytics
  static bool get enableAnalyticsCollection =>
      currentEnvironment == Environment.production;

  /// Should enable crash reporting
  static bool get enableCrashReporting => true;

  /// Timeout duration for API calls (milliseconds)
  static const int apiTimeoutMs = 30000;

  /// Max retries for failed network requests
  static const int maxNetworkRetries = 3;

  /// Cache duration for offline data (hours)
  static const int offlineCacheDurationHours = 24;
}
