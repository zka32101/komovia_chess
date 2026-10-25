import 'package:logger/logger.dart';

/// RevenueCat configuration and API key management
///
/// Source: a compile-time `--dart-define-from-file=.env` (or individual
/// `--dart-define=REVENUEAT_API_KEY=...`), never a bundled `.env` asset -
/// Flutter assets ship as plaintext files inside the APK/IPA (extractable
/// with a plain `unzip`), so loading secrets from one at runtime baked the
/// whole `.env` file - Firebase config, this key, anything else ever added
/// to it - into every release build as an easily-scraped flat file. Compile-
/// time dart-define constants are embedded into the binary instead, which
/// is the standard Flutter approach for values like this that don't need
/// to change without a rebuild.
class RevenueCatConfig {
  // Private constructor to prevent instantiation
  RevenueCatConfig._();
  static final Logger _logger = Logger();

  static late String _apiKey;

  /// Get RevenueCat Public SDK Key
  static String get apiKey => _apiKey;

  /// Initialize RevenueCat configuration
  ///
  /// This should be called early in app startup, before RevenueCat SDK initialization
  static Future<void> initialize() async {
    try {
      _apiKey =
          const String.fromEnvironment('REVENUEAT_API_KEY', defaultValue: '');

      // Log status
      if (_apiKey.isEmpty) {
        _logger.w('RevenueCat API key not configured. '
            'Build with --dart-define=REVENUEAT_API_KEY=... or '
            '--dart-define-from-file=.env');
      } else {
        _logger.i('RevenueCat configuration loaded successfully');
        _logger.d('API Key prefix: ${_apiKey.substring(0, 8)}...');
      }
    } catch (e) {
      _logger.e('Error loading RevenueCat configuration', error: e);
      _apiKey = '';
    }
  }

  /// Validate that configuration is complete
  ///
  /// Returns true if all required configuration is present
  static bool validateConfiguration() {
    if (_apiKey.isEmpty) {
      _logger.e('RevenueCat API key is not configured');
      return false;
    }

    _logger.i('RevenueCat configuration is valid');
    return true;
  }

  /// Check if running in production or development
  static bool get isProduction {
    // In production, API key would be from GitHub Secrets
    // In development, it's from .env file
    return _apiKey.isNotEmpty;
  }

  /// Get configuration status for diagnostics
  static Map<String, dynamic> getStatus() => {
        'configured': _apiKey.isNotEmpty,
        'apiKeyPresent': _apiKey.isNotEmpty,
        'apiKeyPrefix':
            _apiKey.isNotEmpty ? '${_apiKey.substring(0, 8)}...' : 'NOT SET',
        'environment': isProduction ? 'production' : 'development',
      };
}
