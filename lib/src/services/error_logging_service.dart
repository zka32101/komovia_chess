import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';

/// Service for centralized error logging and reporting.
///
/// Logs errors to console and Firebase Crashlytics for visibility into
/// issues during development and production.
class ErrorLoggingService {
  static final Logger _logger = Logger();
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Logs an error with context and reports to Firebase Crashlytics.
  ///
  /// [error]: The exception or error object
  /// [stackTrace]: The stack trace for debugging
  /// [context]: Human-readable context (e.g., 'activeGamesProvider')
  /// [reason]: Optional additional reason/message
  static Future<void> logError(
    Object error,
    StackTrace stackTrace, {
    required String context,
    String? reason,
  }) async {
    // Log to console with color-coded error level
    _logger.e(
      '[$context] Error: $error',
      error: error,
      stackTrace: stackTrace,
    );

    // Report to Firebase Crashlytics for production monitoring
    try {
      await _crashlytics.recordError(
        error,
        stackTrace,
        reason: reason ?? context,
        fatal: false,
      );
    } catch (e) {
      // Fallback if Crashlytics reporting fails
      _logger.e('Failed to report error to Crashlytics: $e');
    }
  }

  /// Logs a warning message (non-fatal issues)
  static Future<void> logWarning(
    String message, {
    required String context,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    _logger.w('[$context] Warning: $message',
        error: error, stackTrace: stackTrace);

    // Only report to Crashlytics if there's an associated error
    if (error != null && stackTrace != null) {
      try {
        await _crashlytics.recordError(
          error,
          stackTrace,
          reason: '$context - Warning: $message',
          fatal: false,
        );
      } catch (e) {
        _logger.e('Failed to report warning to Crashlytics: $e');
      }
    }
  }

  /// Logs an informational message (debugging)
  static void logInfo(String message, {required String context}) {
    _logger.i('[$context] $message');
  }
}
