import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/validation_service.dart';

void main() {
  group('ValidationService', () {
    group('validateEmail', () {
      test('accepts valid email', () {
        expect(() => ValidationService.validateEmail('user@example.com'), returnsNormally);
        expect(() => ValidationService.validateEmail('test.user+tag@domain.co.uk'), returnsNormally);
      });

      test('rejects empty email', () {
        expect(
          () => ValidationService.validateEmail(''),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('rejects email without @', () {
        expect(
          () => ValidationService.validateEmail('invalid.email'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('valid email'),
          )),
        );
      });

      test('rejects email without domain', () {
        expect(
          () => ValidationService.validateEmail('user@'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('rejects email without TLD', () {
        expect(
          () => ValidationService.validateEmail('user@domain'),
          throwsA(isA<ValidationException>()),
        );
      });

      test('rejects excessively long email', () {
        final longEmail = '${'a' * 250}@example.com';
        expect(
          () => ValidationService.validateEmail(longEmail),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('too long'),
          )),
        );
      });

      test('trims whitespace from email', () {
        final result = ValidationService.validateEmail('  user@example.com  ');
        expect(result, equals('user@example.com'));
      });
    });

    group('validatePassword', () {
      test('accepts valid strong password', () {
        expect(
          () => ValidationService.validatePassword('SecurePass123!'),
          returnsNormally,
        );
      });

      test('rejects empty password', () {
        expect(
          () => ValidationService.validatePassword(''),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('rejects password shorter than 8 characters', () {
        expect(
          () => ValidationService.validatePassword('Weak1!'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('at least 8'),
          )),
        );
      });

      test('rejects password without uppercase letter', () {
        expect(
          () => ValidationService.validatePassword('lowercase123!'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('uppercase'),
          )),
        );
      });

      test('rejects password without lowercase letter', () {
        expect(
          () => ValidationService.validatePassword('UPPERCASE123!'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('lowercase'),
          )),
        );
      });

      test('rejects password without number', () {
        expect(
          () => ValidationService.validatePassword('NoNumbers!'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('number'),
          )),
        );
      });

      test('rejects password without special character', () {
        expect(
          () => ValidationService.validatePassword('NoSpecial123'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('special character'),
          )),
        );
      });

      test('accepts various special characters', () {
        for (final char in '!@#\$%^&*(),.?":{}|<>'.split('')) {
          expect(
            () => ValidationService.validatePassword('SecurePass123$char'),
            returnsNormally,
          );
        }
      });

      test('rejects excessively long password', () {
        final longPassword = 'A1!' + 'a' * 200;
        expect(
          () => ValidationService.validatePassword(longPassword),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('too long'),
          )),
        );
      });
    });

    group('validateDisplayName', () {
      test('accepts valid display name', () {
        expect(() => ValidationService.validateDisplayName('John Doe'), returnsNormally);
        expect(() => ValidationService.validateDisplayName('Jean-Pierre'), returnsNormally);
        expect(() => ValidationService.validateDisplayName("O'Connor"), returnsNormally);
        expect(() => ValidationService.validateDisplayName('User123'), returnsNormally);
      });

      test('rejects empty display name', () {
        expect(
          () => ValidationService.validateDisplayName(''),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('cannot be empty'),
          )),
        );
      });

      test('rejects display name shorter than 2 characters', () {
        expect(
          () => ValidationService.validateDisplayName('A'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('at least 2'),
          )),
        );
      });

      test('rejects display name longer than 50 characters', () {
        final longName = 'A' * 51;
        expect(
          () => ValidationService.validateDisplayName(longName),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('at most 50'),
          )),
        );
      });

      test('rejects display name without any letter', () {
        expect(
          () => ValidationService.validateDisplayName('123 456'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('letter'),
          )),
        );
      });

      test('rejects display name with invalid characters', () {
        expect(
          () => ValidationService.validateDisplayName('User@Name'),
          throwsA(isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('letters, numbers, spaces, hyphens, and apostrophes'),
          )),
        );
      });

      test('trims whitespace from display name', () {
        final result = ValidationService.validateDisplayName('  John Doe  ');
        expect(result, equals('John Doe'));
      });
    });

    group('validateAuthFields', () {
      test('accepts all valid fields', () {
        final result = ValidationService.validateAuthFields(
          email: 'user@example.com',
          password: 'SecurePass123!',
          displayName: 'John Doe',
        );
        expect(result['email'], equals('user@example.com'));
        expect(result['password'], equals('SecurePass123!'));
        expect(result['displayName'], equals('John Doe'));
      });

      test('rejects invalid email', () {
        expect(
          () => ValidationService.validateAuthFields(
            email: 'invalid',
            password: 'SecurePass123!',
            displayName: 'John Doe',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('rejects weak password', () {
        expect(
          () => ValidationService.validateAuthFields(
            email: 'user@example.com',
            password: 'weak',
            displayName: 'John Doe',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('rejects invalid display name', () {
        expect(
          () => ValidationService.validateAuthFields(
            email: 'user@example.com',
            password: 'SecurePass123!',
            displayName: 'A',
          ),
          throwsA(isA<ValidationException>()),
        );
      });
    });
  });
}
