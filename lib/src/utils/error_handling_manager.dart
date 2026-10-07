import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

/// Error severity levels
enum ErrorSeverity {
  critical,
  high,
  medium,
  low,
  info,
}

/// Error recovery strategy
enum RecoveryStrategy {
  retry,
  fallback,
  gracefulDegradation,
  userIntervention,
  abort,
}

/// Comprehensive error model
class AppError {
  AppError({
    required this.code,
    required this.message,
    required this.severity,
    this.userMessage,
    this.originalError,
    this.stackTrace,
    this.context,
    this.suggestedRecovery,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now(),
        id = 'ERR_${DateTime.now().millisecondsSinceEpoch}_${code.hashCode}';
  final String id;
  final String code;
  final String message;
  final String? userMessage;
  final ErrorSeverity severity;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime timestamp;
  final RecoveryStrategy? suggestedRecovery;

  /// User-friendly error message
  String getDisplayMessage() => userMessage ?? message;

  /// Is error recoverable
  bool get isRecoverable => suggestedRecovery != null;

  /// Is error critical
  bool get isCritical => severity == ErrorSeverity.critical;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'message': message,
        'userMessage': userMessage,
        'severity': severity.toString().split('.').last,
        'suggestedRecovery': suggestedRecovery?.toString().split('.').last,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => 'AppError($code: $message)';
}

/// Error recovery handler
typedef ErrorRecoveryHandler = Future<bool> Function(AppError error);

/// Global error handling manager
class ErrorHandlingManager {
  factory ErrorHandlingManager() => _instance;

  ErrorHandlingManager._internal();
  static final ErrorHandlingManager _instance =
      ErrorHandlingManager._internal();

  final _errorLog = <AppError>[];
  final _recoveryHandlers = <ErrorSeverity, List<ErrorRecoveryHandler>>{};
  final _errorCallbacks = <Function(AppError)>[];
  final int _maxErrorsKept = 100;

  /// Handle an error with recovery attempt
  Future<bool> handleError({
    required String code,
    required String message,
    required ErrorSeverity severity,
    String? userMessage,
    dynamic originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    RecoveryStrategy? suggestedRecovery,
  }) async {
    try {
      final appError = AppError(
        code: code,
        message: message,
        userMessage: userMessage,
        severity: severity,
        originalError: originalError,
        stackTrace: stackTrace,
        context: context,
        suggestedRecovery: suggestedRecovery,
      );

      // Log error
      _logError(appError);

      // Notify listeners
      _notifyErrorListeners(appError);

      // Attempt recovery
      if (appError.isRecoverable) {
        return await _attemptRecovery(appError);
      }

      // Log critical errors
      if (appError.isCritical) {
        debugPrint(
            '[ErrorHandlingManager] CRITICAL ERROR: ${appError.message}');
        if (stackTrace != null) {
          debugPrint('Stack trace:\n$stackTrace');
        }
      }

      return false;
    } catch (e) {
      debugPrint('[ErrorHandlingManager] Error in error handler: $e');
      return false;
    }
  }

  /// Handle exception with automatic recovery
  Future<bool> handleException(
    Object exception, {
    StackTrace? stackTrace,
    String? code,
    String? userMessage,
    Map<String, dynamic>? context,
  }) async {
    final errorCode = code ?? _getErrorCode(exception);
    final message = exception.toString();

    return handleError(
      code: errorCode,
      message: message,
      userMessage: userMessage,
      severity: _getErrorSeverity(exception),
      originalError: exception,
      stackTrace: stackTrace,
      context: context,
      suggestedRecovery: _suggestRecoveryStrategy(exception),
    );
  }

  /// Register error recovery handler
  void registerRecoveryHandler(
    ErrorSeverity severity,
    ErrorRecoveryHandler handler,
  ) {
    _recoveryHandlers.putIfAbsent(severity, () => []).add(handler);
  }

  /// Register error listener
  void addErrorListener(Function(AppError) callback) {
    _errorCallbacks.add(callback);
  }

  /// Remove error listener
  void removeErrorListener(Function(AppError) callback) {
    _errorCallbacks.remove(callback);
  }

  /// Get all logged errors
  List<AppError> getAllErrors() => List.unmodifiable(_errorLog);

  /// Get errors by severity
  List<AppError> getErrorsBySeverity(ErrorSeverity severity) =>
      _errorLog.where((e) => e.severity == severity).toList();

  /// Get critical errors
  List<AppError> getCriticalErrors() =>
      getErrorsBySeverity(ErrorSeverity.critical);

  /// Get recent errors
  List<AppError> getRecentErrors({int limit = 10}) =>
      _errorLog.reversed.take(limit).toList();

  /// Clear error log
  void clearErrorLog() {
    _errorLog.clear();
    debugPrint('[ErrorHandlingManager] Error log cleared');
  }

  /// Generate error report
  String generateErrorReport() {
    final buffer = StringBuffer();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                    ERROR REPORT                                  ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Errors: ${_errorLog.length.toString().padRight(50)}║
    ''');

    final bySeverity = <ErrorSeverity, int>{};
    for (final severity in ErrorSeverity.values) {
      bySeverity[severity] =
          _errorLog.where((e) => e.severity == severity).length;
    }

    buffer.writeln('║ By Severity:');
    for (final entry in bySeverity.entries) {
      buffer.writeln(
        '║   ${entry.key.toString().split('.').last.toUpperCase().padRight(15)}: ${entry.value.toString().padRight(44)}║',
      );
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ Recent Errors:
    ''');

    final recent = getRecentErrors(limit: 5);
    for (final error in recent) {
      buffer.writeln(
        '║ [${error.severity.toString().split('.').last.toUpperCase()}] ${error.code}: ${error.message.padRight(38)}║',
      );
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Log error to file/analytics
  void _logError(AppError error) {
    _errorLog.add(error);

    // Keep log size manageable
    if (_errorLog.length > _maxErrorsKept) {
      _errorLog.removeAt(0);
    }

    debugPrint(
      '[ErrorHandlingManager] [${error.severity.toString().split('.').last.toUpperCase()}] '
      '${error.code}: ${error.message}',
    );
  }

  /// Notify error listeners
  void _notifyErrorListeners(AppError error) {
    for (final callback in _errorCallbacks) {
      try {
        callback(error);
      } catch (e) {
        debugPrint('[ErrorHandlingManager] Error in error listener: $e');
      }
    }
  }

  /// Attempt error recovery
  Future<bool> _attemptRecovery(AppError error) async {
    final handlers = _recoveryHandlers[error.severity] ?? [];

    for (final handler in handlers) {
      try {
        final recovered = await handler(error);
        if (recovered) {
          debugPrint('[ErrorHandlingManager] Error recovered: ${error.code}');
          return true;
        }
      } catch (e) {
        debugPrint('[ErrorHandlingManager] Recovery handler error: $e');
      }
    }

    return false;
  }

  /// Determine error code from exception type
  String _getErrorCode(Object exception) {
    if (exception is TimeoutException) return 'TIMEOUT';
    if (exception is SocketException) return 'NETWORK';
    if (exception is FormatException) return 'FORMAT';
    if (exception is StateError) return 'STATE';
    if (exception is ArgumentError) return 'ARGUMENT';
    return 'UNKNOWN';
  }

  /// Determine error severity
  ErrorSeverity _getErrorSeverity(Object exception) {
    if (exception is TimeoutException) return ErrorSeverity.high;
    if (exception is SocketException) return ErrorSeverity.medium;
    return ErrorSeverity.medium;
  }

  /// Suggest recovery strategy
  RecoveryStrategy _suggestRecoveryStrategy(Object exception) {
    if (exception is TimeoutException) return RecoveryStrategy.retry;
    if (exception is SocketException) return RecoveryStrategy.fallback;
    return RecoveryStrategy.userIntervention;
  }
}
