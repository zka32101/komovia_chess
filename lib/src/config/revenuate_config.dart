import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

/// RevenueCat configuration and API key management
///
/// Supports multiple configuration sources:
/// 1. GitHub Secrets (CI/CD environment)
/// 2. .env file (local development)
/// 3. Environment variables
class RevenueCatConfig {
  // Private constructor to prevent instantiation
  RevenueCatConfig._();
  static final Logger _logger = Logger();

  static late String _apiKey;

  /// Get RevenueCat Public SDK Key
  ///
  /// Source priority:
  /// 1. Environment variable: REVENUEAT_API_KEY
  /// 2. .env file: REVENUEAT_API_KEY
  /// 3. Default: empty string (will fail on initialization)
  static String get apiKey => _apiKey;

  /// Initialize RevenueCat configuration
  ///
  /// This should be called early in app startup, before RevenueCat SDK initialization
  static Future<void> initialize() async {
    try {
      // Load .env file for local development
      await dotenv.load(fileName: '.env');

      // Try to get API key from environment first (GitHub Secrets, etc.)
      _apiKey =
          const String.fromEnvironment('REVENUEAT_API_KEY', defaultValue: '');

      // If not found, try .env file
      if (_apiKey.isEmpty) {
        _apiKey = dotenv.env['REVENUEAT_API_KEY'] ?? '';
      }

      // Log status
      if (_apiKey.isEmpty) {
        _logger.w('RevenueCat API key not configured. '
            'Set REVENUEAT_API_KEY environment variable or add to .env file');
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
