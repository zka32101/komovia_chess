import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'crash_reporting_service.dart';

/// Severity levels for errors
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

/// Error context for logging
class ErrorContext {
  ErrorContext({
    required this.message,
    this.error,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    this.userId,
    this.context,
    this.metadata,
  });
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final String? userId;
  final String? context;
  final Map<String, dynamic>? metadata;
}

/// Centralized error handling and logging service
class ErrorHandlerService {
  ErrorHandlerService._();
  static final ErrorHandlerService _instance = ErrorHandlerService._();
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static ErrorHandlerService get instance => _instance;

  /// Log an error with context
  void logError(ErrorContext context) {
    final formattedMessage = _formatMessage(context);

    switch (context.severity) {
      case ErrorSeverity.info:
        _logger.i(formattedMessage,
            error: context.error, stackTrace: context.stackTrace);
        break;
      case ErrorSeverity.warning:
        _logger.w(formattedMessage,
            error: context.error, stackTrace: context.stackTrace);
        break;
      case ErrorSeverity.error:
        _logger.e(formattedMessage,
            error: context.error, stackTrace: context.stackTrace);
        break;
      case ErrorSeverity.critical:
        _logger.wtf(formattedMessage,
            error: context.error, stackTrace: context.stackTrace);
        break;
    }

    // In production, send critical errors to crash reporting (fire and forget)
    if (context.severity == ErrorSeverity.critical) {
      _reportCriticalError(context).ignore();
    }
  }

  /// Handle a service error with automatic logging and user-friendly message
  String handleServiceError(
    String operationName, {
    required Object error,
    StackTrace? stackTrace,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    final context = ErrorContext(
      message: 'Service error in $operationName',
      error: error,
      stackTrace: stackTrace,
      severity: ErrorSeverity.error,
      userId: userId,
      context: operationName,
      metadata: metadata,
    );

    logError(context);

    // Return user-friendly error message
    if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error);
    }

    return 'An error occurred while $operationName. Please try again.';
  }

  /// Handle validation errors
  String? validateInput(String? input,
      {required String fieldName, int? minLength, int? maxLength}) {
    if (input == null || input.isEmpty) {
      logError(ErrorContext(
        message: 'Validation error: $fieldName is empty',
        severity: ErrorSeverity.warning,
        context: 'Input validation',
        metadata: {'field': fieldName},
      ));
      return '$fieldName cannot be empty';
    }

    if (minLength != null && input.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (maxLength != null && input.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    return null;
  }

  /// Format error message with context
  String _formatMessage(ErrorContext context) {
    final buffer = StringBuffer();
    buffer
        .writeln('[${context.severity.name.toUpperCase()}] ${context.message}');

    if (context.context != null) {
      buffer.writeln('Context: ${context.context}');
    }

    if (context.userId != null) {
      buffer.writeln('User ID: ${context.userId}');
    }

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      buffer.writeln('Metadata: ${context.metadata}');
    }

    return buffer.toString();
  }

  /// Get user-friendly Firebase error message
  String _getFirebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unauthenticated':
        return 'Please log in to continue.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'failed-precondition':
        return 'Operation cannot be completed. Please try again.';
      case 'aborted':
        return 'Operation was cancelled. Please try again.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please check your connection and try again.';
      default:
        return 'An error occurred. Please try again or contact support.';
    }
  }

  /// Report critical errors (send to crash reporting service)
  Future<void> _reportCriticalError(ErrorContext context) async {
    _logger.wtf('CRITICAL ERROR REPORTED: ${context.message}');

    // Report to Crashlytics
    if (crashReportingService.isInitialized) {
      await crashReportingService.recordFatalException(
        exception: context.error ?? Exception(context.message),
        stackTrace: context.stackTrace,
        context: context.context ?? 'Critical Error',
        metadata: {
          'severity': context.severity.name,
          'user_id': context.userId,
          ...?context.metadata,
        },
      );
    }
  }
}

/// Singleton accessor
final errorHandlerService = ErrorHandlerService.instance;
