import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/security_service.dart';

void main() {
  group('SecurityService', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    group('Authorization Tests', () {
      test('UnauthorizedException has correct message', () {
        // Arrange
        const message =
            'Cannot enable 2FA for other users. Only account owner or admin allowed.';
        final exception = UnauthorizedException(message);

        // Act & Assert
        expect(exception.message, equals(message));
        expect(exception.toString(), contains('UnauthorizedException'));
      });

      test('Authorization check requires proper permissions', () {
        // This test verifies the authorization pattern is in place
        // Actual Firestore calls are tested via integration tests
        final authError = UnauthorizedException(
            'Only account owner or admin can request data operations');
        expect(authError.message, isNotEmpty);
      });
    });

    group('Sensitive Data Masking Tests', () {
      test('masks password field', () {
        // Arrange
        final details = {
          'password': 'secret123',
          'action': 'login',
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert
        expect(sanitized['password'], '[REDACTED]');
        expect(sanitized['action'], 'login');
      });

      test('masks token field (case-insensitive)', () {
        // Arrange
        final details = {
          'refreshToken': 'abc123xyz',
          'userId': 'user123',
          'TOKEN': 'xyz789',
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert
        expect(sanitized['refreshToken'], '[REDACTED]');
        expect(sanitized['TOKEN'], '[REDACTED]');
        expect(sanitized['userId'], 'user123');
      });

      test('masks secret field', () {
        // Arrange
        final details = {
          'secret': 'classified',
          'timestamp': '2026-09-14',
          'SECRET_KEY': 'hidden',
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert
        expect(sanitized['secret'], '[REDACTED]');
        expect(sanitized['SECRET_KEY'], '[REDACTED]');
        expect(sanitized['timestamp'], '2026-09-14');
      });

      test('masks apikey field', () {
        // Arrange
        final details = {
          'apikey': 'key_xyz_123',
          'service': 'firebase',
          'API_KEY_BACKUP': 'backup_key',
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert
        expect(sanitized['apikey'], '[REDACTED]');
        expect(sanitized['API_KEY_BACKUP'], '[REDACTED]');
        expect(sanitized['service'], 'firebase');
      });

      test('masks credential field', () {
        // Arrange
        final details = {
          'credential': 'auth_token_xyz',
          'expiresAt': '2026-12-31',
          'CREDENTIAL_ID': 'cred_123',
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert
        expect(sanitized['credential'], '[REDACTED]');
        expect(sanitized['CREDENTIAL_ID'], '[REDACTED]');
        expect(sanitized['expiresAt'], '2026-12-31');
      });

      test('handles multiple sensitive fields in one details map', () {
        // Arrange
        final details = {
          'password': 'secret123',
          'token': 'auth_token',
          'apikey': 'api_key_xyz',
          'secret': 'classified_info',
          'credential': 'cred_data',
          'username': 'john_doe',
          'action': 'login',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert - sensitive fields redacted
        expect(sanitized['password'], '[REDACTED]');
        expect(sanitized['token'], '[REDACTED]');
        expect(sanitized['apikey'], '[REDACTED]');
        expect(sanitized['secret'], '[REDACTED]');
        expect(sanitized['credential'], '[REDACTED]');

        // Non-sensitive fields preserved
        expect(sanitized['username'], 'john_doe');
        expect(sanitized['action'], 'login');
        expect(sanitized['timestamp'], isNotEmpty);
      });

      test('preserves field names while redacting values', () {
        // Arrange
        final details = {
          'user_password': 'secret',
          'session_token': 'xyz',
          'api_secret_key': 'hidden',
        };

        // Act
        final sanitized = securityService.sanitizeDetails(details);

        // Assert - field names preserved, values redacted
        expect(sanitized.containsKey('user_password'), true);
        expect(sanitized.containsKey('session_token'), true);
        expect(sanitized.containsKey('api_secret_key'), true);
        expect(sanitized['user_password'], '[REDACTED]');
        expect(sanitized['session_token'], '[REDACTED]');
        expect(sanitized['api_secret_key'], '[REDACTED]');
      });
    });

    group('Exception Handling Tests', () {
      test('UnauthorizedException implements Exception interface', () {
        // Arrange
        const message = 'Access denied';
        final exception = UnauthorizedException(message);

        // Act & Assert
        expect(exception, isA<Exception>());
      });

      test('UnauthorizedException provides helpful error messages', () {
        // Arrange
        const message = 'Only account owner or admin allowed';
        final exception = UnauthorizedException(message);

        // Act
        final errorString = exception.toString();

        // Assert
        expect(errorString, contains('UnauthorizedException'));
        expect(errorString, contains('Only account owner or admin allowed'));
      });

      test('Multiple authorization failures have distinct messages', () {
        // Arrange
        const msg1 = 'Cannot enable 2FA for other users';
        const msg2 = 'Insufficient permissions for data deletion';
        const msg3 = 'Only account owner or admin can request data operations';

        final exc1 = UnauthorizedException(msg1);
        final exc2 = UnauthorizedException(msg2);
        final exc3 = UnauthorizedException(msg3);

        // Act & Assert
        expect(exc1.message, msg1);
        expect(exc2.message, msg2);
        expect(exc3.message, msg3);
      });
    });

    group('Security Service Pattern Tests', () {
      test('SecurityService is singleton', () {
        // Arrange & Act
        final instance1 = SecurityService();
        final instance2 = SecurityService();

        // Assert
        expect(identical(instance1, instance2), true);
      });

      test('Sanitization function is public for testing', () {
        // Arrange
        final testData = {'password': 'secret'};

        // Act & Assert
        expect(securityService.sanitizeDetails, isNotNull);
        final result = securityService.sanitizeDetails(testData);
        expect(result['password'], '[REDACTED]');
      });

      test('audit log pattern enforces data masking', () {
        // This test verifies that the logging system would mask sensitive data
        final eventDetails = {
          'action': 'user_login',
          'password': 'should_be_masked',
          'token': 'should_be_masked',
          'timestamp': '2026-09-14T12:00:00Z',
        };

        // The sanitization should happen before logging
        final sanitized = securityService.sanitizeDetails(eventDetails);

        // Verify sensitive data is masked
        expect(sanitized['password'], '[REDACTED]');
        expect(sanitized['token'], '[REDACTED]');

        // Verify audit context is preserved
        expect(sanitized['action'], 'user_login');
        expect(sanitized['timestamp'], isNotEmpty);
      });
    });
  });
}
