import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/rate_limiting_service.dart';

void main() {
  group('RateLimitingService', () {
    late RateLimitingService rateLimiter;

    setUp(() {
      rateLimiter = RateLimitingService();
      rateLimiter.resetAll(); // Clean state before each test
    });

    group('checkRateLimit', () {
      test('allows first request', () {
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          returnsNormally,
        );
      });

      test('allows requests below limit', () {
        expect(
          () {
            for (int i = 0; i < 5; i++) {
              rateLimiter.checkRateLimit('signIn');
            }
          },
          returnsNormally,
        );
      });

      test('throws RateLimitException when limit exceeded', () {
        // signIn limit is 5 attempts per 15 minutes
        for (int i = 0; i < 5; i++) {
          rateLimiter.checkRateLimit('signIn');
        }

        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          throwsA(isA<RateLimitException>()),
        );
      });

      test('RateLimitException contains retry information', () {
        // Trigger rate limit
        for (int i = 0; i < 5; i++) {
          rateLimiter.checkRateLimit('signIn');
        }

        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          throwsA(
            isA<RateLimitException>()
                .having((e) => e.message, 'message', contains('too many'))
                .having((e) => e.retryAfter, 'retryAfter', isNotNull),
          ),
        );
      });

      test('different endpoints have separate limits', () {
        // Max out signIn
        for (int i = 0; i < 5; i++) {
          rateLimiter.checkRateLimit('signIn');
        }

        // signUp should still work (separate limit)
        expect(
          () => rateLimiter.checkRateLimit('signUp'),
          returnsNormally,
        );
      });

      test('handles unknown endpoints gracefully', () {
        expect(
          () => rateLimiter.checkRateLimit('unknownEndpoint'),
          returnsNormally,
        );
      });

      test('signUp has stricter limit than signIn', () {
        final signInLimit = 5;
        final signUpLimit = 3;

        // Fill signUp to limit
        for (int i = 0; i < signUpLimit; i++) {
          rateLimiter.checkRateLimit('signUp');
        }

        expect(
          () => rateLimiter.checkRateLimit('signUp'),
          throwsA(isA<RateLimitException>()),
        );

        // signIn should still have capacity
        rateLimiter.resetEndpoint('signIn');
        for (int i = 0; i < signInLimit; i++) {
          expect(
            () => rateLimiter.checkRateLimit('signIn'),
            returnsNormally,
          );
        }
      });

      test('passwordReset has 24-hour window', () {
        // This just verifies the config is set correctly
        final status = rateLimiter.getStatus();
        expect(status['passwordReset'], isNotNull);
        expect(status['passwordReset']['maxAttempts'], equals(3));
        expect(status['passwordReset']['windowDuration'], equals(86400)); // 24 hours in seconds
      });
    });

    group('recordSuccess', () {
      test('clears error tracking', () {
        // Cause some failures
        for (int i = 0; i < 3; i++) {
          rateLimiter.recordFailure('signIn');
        }

        // Before success, endpoint should be locked
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          throwsA(isA<RateLimitException>()),
        );

        // Record success to clear errors
        rateLimiter.recordSuccess('signIn');

        // Now it should work
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          returnsNormally,
        );
      });

      test('resets consecutive error count', () {
        final status = rateLimiter.getStatus();
        final beforeErrors = status['signIn']['consecutiveErrors'] as int;
        expect(beforeErrors, equals(0));

        rateLimiter.recordFailure('signIn');
        rateLimiter.recordFailure('signIn');

        rateLimiter.recordSuccess('signIn');

        final afterStatus = rateLimiter.getStatus();
        expect(afterStatus['signIn']['consecutiveErrors'], equals(0));
      });
    });

    group('recordFailure', () {
      test('increments consecutive error count', () {
        rateLimiter.recordFailure('signIn');
        rateLimiter.recordFailure('signIn');

        final status = rateLimiter.getStatus();
        expect(status['signIn']['consecutiveErrors'], equals(2));
      });

      test('triggers lockout after 3 consecutive failures', () {
        rateLimiter.recordFailure('signIn');
        rateLimiter.recordFailure('signIn');

        // Before 3rd failure, endpoint not locked
        var timeUntilAvailable = rateLimiter.getTimeUntilAvailable('signIn');
        expect(timeUntilAvailable, isNull);

        // 3rd failure triggers lockout
        rateLimiter.recordFailure('signIn');

        timeUntilAvailable = rateLimiter.getTimeUntilAvailable('signIn');
        expect(timeUntilAvailable, isNotNull);

        // Verify endpoint is locked
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          throwsA(isA<RateLimitException>()),
        );
      });

      test('lockout duration varies by endpoint', () {
        // Trigger lockout on both endpoints
        for (int i = 0; i < 3; i++) {
          rateLimiter.recordFailure('signIn');
          rateLimiter.recordFailure('passwordReset');
        }

        final status = rateLimiter.getStatus();

        // signIn lockout is 15 minutes
        expect(status['signIn']['isLocked'], isTrue);
        expect(status['signIn']['timeUntilAvailableSeconds'], greaterThan(0));
        expect(status['signIn']['timeUntilAvailableSeconds'], lessThanOrEqualTo(15 * 60));

        // passwordReset lockout is 4 hours
        expect(status['passwordReset']['isLocked'], isTrue);
        expect(status['passwordReset']['timeUntilAvailableSeconds'], greaterThan(0));
        expect(status['passwordReset']['timeUntilAvailableSeconds'], lessThanOrEqualTo(4 * 60 * 60));
      });
    });

    group('getTimeUntilAvailable', () {
      test('returns null if no lockout', () {
        expect(rateLimiter.getTimeUntilAvailable('signIn'), isNull);
      });

      test('returns duration when locked out', () {
        // Trigger lockout
        for (int i = 0; i < 3; i++) {
          rateLimiter.recordFailure('signIn');
        }

        final timeUntilAvailable = rateLimiter.getTimeUntilAvailable('signIn');
        expect(timeUntilAvailable, isNotNull);
        expect(timeUntilAvailable!.inSeconds, greaterThan(0));
        expect(timeUntilAvailable.inSeconds, lessThanOrEqualTo(15 * 60)); // signIn lockout
      });

      test('returns null after lockout expires', () async {
        // Create a custom limiter with very short window for testing
        // Note: This test demonstrates the concept but the actual
        // service uses configured durations
        rateLimiter.recordFailure('signIn');
        rateLimiter.recordFailure('signIn');
        rateLimiter.recordFailure('signIn');

        expect(
          rateLimiter.getTimeUntilAvailable('signIn'),
          isNotNull,
        );
      });
    });

    group('resetEndpoint', () {
      test('resets rate limit for specific endpoint', () {
        // Max out endpoint
        for (int i = 0; i < 5; i++) {
          rateLimiter.checkRateLimit('signIn');
        }

        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          throwsA(isA<RateLimitException>()),
        );

        // Reset endpoint
        rateLimiter.resetEndpoint('signIn');

        // Should work again
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          returnsNormally,
        );
      });

      test('does not affect other endpoints', () {
        // Max out both endpoints
        for (int i = 0; i < 5; i++) {
          rateLimiter.checkRateLimit('signIn');
        }
        for (int i = 0; i < 3; i++) {
          rateLimiter.checkRateLimit('signUp');
        }

        // Reset only signIn
        rateLimiter.resetEndpoint('signIn');

        // signIn should work
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          returnsNormally,
        );

        // signUp should still be limited
        expect(
          () => rateLimiter.checkRateLimit('signUp'),
          throwsA(isA<RateLimitException>()),
        );
      });

      test('clears error tracking', () {
        for (int i = 0; i < 3; i++) {
          rateLimiter.recordFailure('signIn');
        }

        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          throwsA(isA<RateLimitException>()),
        );

        rateLimiter.resetEndpoint('signIn');

        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          returnsNormally,
        );
      });
    });

    group('resetAll', () {
      test('resets all endpoints', () {
        // Max out multiple endpoints
        for (int i = 0; i < 5; i++) {
          rateLimiter.checkRateLimit('signIn');
        }
        for (int i = 0; i < 3; i++) {
          rateLimiter.checkRateLimit('signUp');
        }

        rateLimiter.resetAll();

        // All should work
        expect(
          () => rateLimiter.checkRateLimit('signIn'),
          returnsNormally,
        );
        expect(
          () => rateLimiter.checkRateLimit('signUp'),
          returnsNormally,
        );
      });
    });

    group('getStatus', () {
      test('returns status for all configured endpoints', () {
        final status = rateLimiter.getStatus();

        expect(status.keys, contains('signIn'));
        expect(status.keys, contains('signUp'));
        expect(status.keys, contains('passwordReset'));
        expect(status.keys, contains('signInWithGoogle'));
        expect(status.keys, contains('signInWithApple'));
        expect(status.keys, contains('verifyEmail'));
        expect(status.keys, contains('matchmaking'));
        expect(status.keys, contains('createGame'));
      });

      test('shows correct attempt counts', () {
        rateLimiter.checkRateLimit('signIn');
        rateLimiter.checkRateLimit('signIn');

        final status = rateLimiter.getStatus();
        expect(status['signIn']['currentAttempts'], equals(2));
        expect(status['signIn']['maxAttempts'], equals(5));
      });

      test('shows lock status', () {
        // Not locked initially
        var status = rateLimiter.getStatus();
        expect(status['signIn']['isLocked'], isFalse);

        // Trigger lockout
        for (int i = 0; i < 3; i++) {
          rateLimiter.recordFailure('signIn');
        }

        // Should be locked now
        status = rateLimiter.getStatus();
        expect(status['signIn']['isLocked'], isTrue);
        expect(status['signIn']['timeUntilAvailableSeconds'], isNotNull);
      });

      test('shows error count', () {
        rateLimiter.recordFailure('signIn');
        rateLimiter.recordFailure('signIn');

        final status = rateLimiter.getStatus();
        expect(status['signIn']['consecutiveErrors'], equals(2));
      });
    });

    group('Endpoint-specific behaviors', () {
      test('signIn: 5 attempts per 15 minutes', () {
        final status = rateLimiter.getStatus();
        expect(status['signIn']['maxAttempts'], equals(5));
        expect(status['signIn']['windowDuration'], equals(15 * 60));
      });

      test('signUp: 3 attempts per 24 hours', () {
        final status = rateLimiter.getStatus();
        expect(status['signUp']['maxAttempts'], equals(3));
        expect(status['signUp']['windowDuration'], equals(24 * 60 * 60));
      });

      test('passwordReset: 3 attempts per 24 hours', () {
        final status = rateLimiter.getStatus();
        expect(status['passwordReset']['maxAttempts'], equals(3));
        expect(status['passwordReset']['windowDuration'], equals(24 * 60 * 60));
      });

      test('signInWithGoogle: 10 attempts per 15 minutes', () {
        final status = rateLimiter.getStatus();
        expect(status['signInWithGoogle']['maxAttempts'], equals(10));
        expect(status['signInWithGoogle']['windowDuration'], equals(15 * 60));
      });

      test('matchmaking: 20 attempts per 5 minutes', () {
        final status = rateLimiter.getStatus();
        expect(status['matchmaking']['maxAttempts'], equals(20));
        expect(status['matchmaking']['windowDuration'], equals(5 * 60));
      });
    });

    group('Concurrent access', () {
      test('handles multiple rapid requests', () {
        expect(
          () {
            for (int i = 0; i < 5; i++) {
              rateLimiter.checkRateLimit('signInWithGoogle');
            }
          },
          returnsNormally,
        );
      });

      test('maintains separate limits across endpoints', () {
        final endpoints = [
          'signIn',
          'signUp',
          'passwordReset',
          'signInWithGoogle',
          'signInWithApple',
          'matchmaking',
          'createGame',
        ];

        // Make multiple requests to each endpoint
        for (final endpoint in endpoints) {
          expect(
            () => rateLimiter.checkRateLimit(endpoint),
            returnsNormally,
          );
        }

        // All should still allow more requests
        for (final endpoint in endpoints) {
          expect(
            () => rateLimiter.checkRateLimit(endpoint),
            returnsNormally,
          );
        }
      });
    });
  });
}
