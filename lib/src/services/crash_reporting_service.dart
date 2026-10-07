import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service for crash reporting and error tracking via Firebase Crashlytics
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService _instance = CrashReportingService._();
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  bool _initialized = false;

  static CrashReportingService get instance => _instance;

  /// Initialize Crashlytics
  Future<void> initialize({
    required bool enableInDevMode,
  }) async {
    if (_initialized) return;

    try {
      // Set whether Crashlytics is enabled in development mode
      await _crashlytics.setCrashlyticsCollectionEnabled(
        !kDebugMode || enableInDevMode,
      );

      // Enable stack trace unwinding for iOS
      if (!kDebugMode) {
        // Pass all uncaught exceptions to Crashlytics
        FlutterError.onError = _crashlytics.recordFlutterError;
      }

      _initialized = true;
      print('Crashlytics initialized successfully');
    } catch (e) {
      print('Error initializing Crashlytics: $e');
    }
  }

  /// Record a handled exception with optional context
  Future<void> recordException({
    required Object exception,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (context != null) {
        _crashlytics.log('Context: $context');
      }

      if (metadata != null && metadata.isNotEmpty) {
        metadata.forEach((key, value) {
          _crashlytics.setCustomKey(key, value.toString());
        });
      }

      await _crashlytics.recordError(exception, stackTrace, fatal: false);
    } catch (e) {
      print('Error recording exception to Crashlytics: $e');
    }
  }

  /// Record a fatal exception (won't crash the app)
  Future<void> recordFatalException({
    required Object exception,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (context != null) {
        _crashlytics.log('Fatal Error Context: $context');
      }

      if (metadata != null && metadata.isNotEmpty) {
        metadata.forEach((key, value) {
          _crashlytics.setCustomKey('fatal_$key', value.toString());
        });
      }

      await _crashlytics.recordError(exception, stackTrace, fatal: true);
    } catch (e) {
      print('Error recording fatal exception to Crashlytics: $e');
    }
  }

  /// Log a message to Crashlytics (non-error log)
  void log(String message, {String? level}) {
    try {
      final logMessage = level != null ? '[$level] $message' : message;
      _crashlytics.log(logMessage);
    } catch (e) {
      print('Error logging to Crashlytics: $e');
    }
  }

  /// Set custom user information
  Future<void> setUserInfo({
    required String userId,
    String? email,
    String? name,
  }) async {
    try {
      await _crashlytics.setUserIdentifier(userId);

      if (email != null) {
        _crashlytics.setCustomKey('user_email', email);
      }

      if (name != null) {
        _crashlytics.setCustomKey('user_name', name);
      }
    } catch (e) {
      print('Error setting user info in Crashlytics: $e');
    }
  }

  /// Clear user information
  Future<void> clearUserInfo() async {
    try {
      await _crashlytics.setUserIdentifier('');
    } catch (e) {
      print('Error clearing user info in Crashlytics: $e');
    }
  }

  /// Set custom key-value pair
  void setCustomKey(String key, Object value) {
    try {
      _crashlytics.setCustomKey(key, value.toString());
    } catch (e) {
      print('Error setting custom key in Crashlytics: $e');
    }
  }

  /// Record game-specific error
  Future<void> recordGameError({
    required String gameId,
    required String errorType,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? gameState,
  }) async {
    try {
      _crashlytics.setCustomKey('error_type', errorType);
      _crashlytics.setCustomKey('game_id', gameId);

      if (gameState != null) {
        _crashlytics.setCustomKey('game_state', gameState.toString());
      }

      await recordException(
        exception: error,
        stackTrace: stackTrace,
        context: 'Game Error: $errorType in game $gameId',
        metadata: {
          'error_type': errorType,
          'game_id': gameId,
          ...?gameState,
        },
      );
    } catch (e) {
      print('Error recording game error: $e');
    }
  }

  /// Record network-related error
  Future<void> recordNetworkError({
    required String endpoint,
    required int statusCode,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    try {
      await recordException(
        exception: error,
        stackTrace: stackTrace,
        context: 'Network Error',
        metadata: {
          'endpoint': endpoint,
          'status_code': statusCode,
          'error_type': 'NetworkException',
        },
      );
    } catch (e) {
      print('Error recording network error: $e');
    }
  }

  /// Record Firebase-specific error
  Future<void> recordFirebaseError({
    required String operation,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    try {
      await recordException(
        exception: error,
        stackTrace: stackTrace,
        context: 'Firebase Operation: $operation',
        metadata: {
          'operation': operation,
          'service': 'Firebase',
        },
      );
    } catch (e) {
      print('Error recording Firebase error: $e');
    }
  }

  /// Check if Crashlytics is initialized
  bool get isInitialized => _initialized;

  /// Get Crashlytics instance for advanced usage
  FirebaseCrashlytics get crashlytics => _crashlytics;
}

/// Singleton accessor
final crashReportingService = CrashReportingService.instance;
