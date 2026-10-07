import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Crashlytics service provider (singleton)
///
/// Provides Firebase Crashlytics for error reporting and crash tracking
final crashlyticsProvider =
    Provider<FirebaseCrashlytics>((ref) => FirebaseCrashlytics.instance);

/// Crashlytics initialization provider
///
/// Call this once at app startup to initialize Crashlytics
final crashlyticsInitProvider = FutureProvider<void>((ref) async {
  final crashlytics = ref.watch(crashlyticsProvider);
  final logger = Logger();

  try {
    // Enable Crashlytics only in production
    if (!kDebugMode) {
      await crashlytics.setCrashlyticsCollectionEnabled(true);
      logger.i('Crashlytics enabled in production mode');
    } else {
      logger.i('Crashlytics disabled in debug mode');
    }

    // Set up exception handler
    FlutterError.onError = (errorDetails) {
      if (!kDebugMode) {
        crashlytics.recordFlutterError(errorDetails);
      }
      logger.e('Flutter error caught', error: errorDetails.exception);
    };
  } catch (e) {
    logger.e('Failed to initialize Crashlytics', error: e);
  }
});

/// Report custom exception to Crashlytics
///
/// Use this to manually report non-fatal exceptions
Future<void> reportException(
  dynamic exception,
  StackTrace stackTrace, {
  String? reason,
  Map<String, dynamic>? additionalData,
}) async {
  if (!kDebugMode) {
    await FirebaseCrashlytics.instance.recordError(
      exception,
      stackTrace,
      reason: reason,
      fatal: false,
      printDetails: true,
    );
  }

  Logger().e(
    'Exception reported to Crashlytics: $reason',
    error: exception,
    stackTrace: stackTrace,
  );

  // Log additional data if provided
  if (additionalData != null) {
    for (final entry in additionalData.entries) {
      await FirebaseCrashlytics.instance.setCustomKey(
        entry.key,
        entry.value.toString(),
      );
    }
  }
}

/// Set user ID for Crashlytics
///
/// Use this when user logs in to track user-specific crashes
Future<void> setCrashlyticsUserId(String userId) async {
  if (!kDebugMode) {
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }
  Logger().d('Crashlytics user ID set: $userId');
}

/// Clear user ID from Crashlytics
///
/// Use this when user logs out
Future<void> clearCrashlyticsUserId() async {
  if (!kDebugMode) {
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }
  Logger().d('Crashlytics user ID cleared');
}

/// Set custom key-value pair for Crashlytics context
///
/// Use this to add contextual information to crash reports
Future<void> setCrashlyticsCustomKey(String key, dynamic value) async {
  if (!kDebugMode) {
    await FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
  }
  Logger().d('Crashlytics custom key set: $key=$value');
}
