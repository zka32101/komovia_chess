import 'package:logger/logger.dart';

/// Exception thrown when rate limit is exceeded.
class RateLimitException implements Exception {
  RateLimitException(this.message, {this.retryAfter});
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

/// Service for client-side rate limiting on authentication and API endpoints.
///
/// Implements token bucket algorithm with per-endpoint and global limits.
/// Prevents brute force attacks and excessive API calls.
///
/// Examples:
/// - Auth endpoint: max 5 attempts per 15 minutes
/// - SignUp endpoint: max 3 attempts per 24 hours per IP
/// - Password reset: max 3 attempts per 24 hours
class RateLimitingService {
  factory RateLimitingService() => _instance;

  RateLimitingService._internal();
  static final RateLimitingService _instance = RateLimitingService._internal();
  static final _logger = Logger();

  /// Map of endpoint name to request history
  final Map<String, List<DateTime>> _requestHistory = {};

  /// Map of endpoint to last error time (for exponential backoff)
  final Map<String, DateTime> _lastErrorTime = {};

  /// Map of endpoint to consecutive error count
  final Map<String, int> _consecutiveErrors = {};

  /// Rate limit configuration per endpoint
  static const Map<String, _RateLimitConfig> _limits = {
    'signIn': _RateLimitConfig(
      maxAttempts: 5,
      windowDuration: Duration(minutes: 15),
      lockoutDuration: Duration(minutes: 15),
    ),
    'signUp': _RateLimitConfig(
      maxAttempts: 3,
      windowDuration: Duration(hours: 24),
      lockoutDuration: Duration(hours: 1),
    ),
    'passwordReset': _RateLimitConfig(
      maxAttempts: 3,
      windowDuration: Duration(hours: 24),
      lockoutDuration: Duration(hours: 4),
    ),
    'signInWithGoogle': _RateLimitConfig(
      maxAttempts: 10,
      windowDuration: Duration(minutes: 15),
      lockoutDuration: Duration(minutes: 5),
    ),
    'signInWithApple': _RateLimitConfig(
      maxAttempts: 10,
      windowDuration: Duration(minutes: 15),
      lockoutDuration: Duration(minutes: 5),
    ),
    'verifyEmail': _RateLimitConfig(
      maxAttempts: 5,
      windowDuration: Duration(hours: 1),
      lockoutDuration: Duration(minutes: 15),
    ),
    'matchmaking': _RateLimitConfig(
      maxAttempts: 20,
      windowDuration: Duration(minutes: 5),
      lockoutDuration: Duration(minutes: 1),
    ),
    'createGame': _RateLimitConfig(
      maxAttempts: 10,
      windowDuration: Duration(minutes: 10),
      lockoutDuration: Duration(minutes: 2),
    ),
  };

  /// Check if request to endpoint is allowed
  ///
  /// Returns: true if allowed, false if rate limited
  /// Throws: RateLimitException if rate limit exceeded
  bool checkRateLimit(String endpoint) {
    final config = _limits[endpoint];
    if (config == null) {
      _logger.w('No rate limit configuration for endpoint: $endpoint');
      return true; // Allow if no config
    }

    // Check if in lockout period due to errors
    final lastError = _lastErrorTime[endpoint];
    if (lastError != null) {
      final timeSinceError = DateTime.now().difference(lastError);
      if (timeSinceError < config.lockoutDuration) {
        final retryAfter = config.lockoutDuration - timeSinceError;
        _logger.w(
          '[$endpoint] In lockout period. Retry after ${retryAfter.inSeconds}s',
        );
        throw RateLimitException(
          'Too many failed attempts. Please try again in ${retryAfter.inSeconds} seconds.',
          retryAfter: retryAfter,
        );
      }
    }

    // Clean old requests outside window
    _cleanOldRequests(endpoint, config);

    // Get request history
    final history = _requestHistory[endpoint] ?? [];

    // Check if limit exceeded
    if (history.length >= config.maxAttempts) {
      final oldestRequest = history.first;
      final timeSinceOldest = DateTime.now().difference(oldestRequest);

      _logger.w(
        '[$endpoint] Rate limit exceeded: ${history.length}/${config.maxAttempts} in ${config.windowDuration.inSeconds}s',
      );

      // Record this error for exponential backoff
      _recordError(endpoint, config);

      final retryAfter = config.windowDuration - timeSinceOldest;
      throw RateLimitException(
        'Rate limit exceeded. Please try again in ${retryAfter.inSeconds} seconds.',
        retryAfter: retryAfter,
      );
    }

    // Record this request
    history.add(DateTime.now());
    _requestHistory[endpoint] = history;

    _logger.d(
      '[$endpoint] Request allowed: ${history.length}/${config.maxAttempts}',
    );

    return true;
  }

  /// Record successful request completion
  /// Clears error tracking for this endpoint
  void recordSuccess(String endpoint) {
    _lastErrorTime.remove(endpoint);
    _consecutiveErrors[endpoint] = 0;
    _logger.d('[$endpoint] Request succeeded, error tracking cleared');
  }

  /// Record failed request
  /// Triggers exponential backoff if too many consecutive failures
  void recordFailure(String endpoint) {
    final errorCount = (_consecutiveErrors[endpoint] ?? 0) + 1;
    _consecutiveErrors[endpoint] = errorCount;

    _logger.w('[$endpoint] Request failed. Consecutive failures: $errorCount');

    // After 3 consecutive failures, start lockout
    if (errorCount >= 3) {
      _recordError(endpoint, _limits[endpoint]);
    }
  }

  /// Get time until endpoint is available again
  Duration? getTimeUntilAvailable(String endpoint) {
    final lastError = _lastErrorTime[endpoint];
    if (lastError == null) return null;

    final config = _limits[endpoint];
    if (config == null) return null;

    final timeSinceError = DateTime.now().difference(lastError);
    if (timeSinceError >= config.lockoutDuration) return null;

    return config.lockoutDuration - timeSinceError;
  }

  /// Reset rate limit for endpoint (for testing)
  void resetEndpoint(String endpoint) {
    _requestHistory.remove(endpoint);
    _lastErrorTime.remove(endpoint);
    _consecutiveErrors.remove(endpoint);
    _logger.i('[$endpoint] Rate limit reset');
  }

  /// Reset all rate limits
  void resetAll() {
    _requestHistory.clear();
    _lastErrorTime.clear();
    _consecutiveErrors.clear();
    _logger.i('All rate limits reset');
  }

  /// Get current status for all endpoints
  Map<String, Map<String, dynamic>> getStatus() {
    final status = <String, Map<String, dynamic>>{};

    for (final endpoint in _limits.keys) {
      final history = _requestHistory[endpoint] ?? [];
      final config = _limits[endpoint]!;
      final timeAvailable = getTimeUntilAvailable(endpoint);
      final errors = _consecutiveErrors[endpoint] ?? 0;

      status[endpoint] = {
        'currentAttempts': history.length,
        'maxAttempts': config.maxAttempts,
        'windowDuration': config.windowDuration.inSeconds,
        'consecutiveErrors': errors,
        'isLocked': timeAvailable != null,
        'timeUntilAvailableSeconds': timeAvailable?.inSeconds,
      };
    }

    return status;
  }

  // ============================================
  // PRIVATE HELPERS
  // ============================================

  /// Clean requests older than window duration
  void _cleanOldRequests(String endpoint, _RateLimitConfig config) {
    final history = _requestHistory[endpoint];
    if (history == null || history.isEmpty) return;

    final cutoff = DateTime.now().subtract(config.windowDuration);
    final filtered = history.where((time) => time.isAfter(cutoff)).toList();

    if (filtered.length != history.length) {
      _requestHistory[endpoint] = filtered;
      _logger.d(
        '[$endpoint] Cleaned old requests: ${history.length} -> ${filtered.length}',
      );
    }
  }

  /// Record error and start lockout period
  void _recordError(String endpoint, _RateLimitConfig? config) {
    if (config == null) return;

    _lastErrorTime[endpoint] = DateTime.now();
    _logger.w(
      '[$endpoint] Lockout started for ${config.lockoutDuration.inSeconds}s',
    );
  }
}

/// Rate limit configuration for an endpoint
class _RateLimitConfig {
  const _RateLimitConfig({
    required this.maxAttempts,
    required this.windowDuration,
    required this.lockoutDuration,
  });

  /// Maximum attempts allowed in window
  final int maxAttempts;

  /// Time window for counting attempts
  final Duration windowDuration;

  /// How long endpoint is locked after exceeding limit
  final Duration lockoutDuration;
}
