/// Exception thrown when validation fails.
class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service for validating user input before authentication.
///
/// Validates email, password, and display name according to security standards
/// and user experience requirements.
class ValidationService {
  /// Validates email format.
  ///
  /// Requires: valid email format (RFC 5322 simplified)
  ///
  /// Throws: [ValidationException] if validation fails
  static String validateEmail(String email) {
    final trimmed = email.trim();

    if (trimmed.isEmpty) {
      throw ValidationException('Email cannot be empty');
    }

    // RFC 5322 simplified email regex
    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    if (!RegExp(pattern).hasMatch(trimmed)) {
      throw ValidationException('Please enter a valid email address');
    }

    if (trimmed.length > 254) {
      throw ValidationException('Email is too long (max 254 characters)');
    }

    return trimmed;
  }

  /// Validates password strength.
  ///
  /// Requirements:
  /// - At least 8 characters
  /// - At least one uppercase letter
  /// - At least one number
  /// - At least one special character (!@#$%^&*(),.?":{}|<>)
  ///
  /// Throws: [ValidationException] if validation fails
  static String validatePassword(String password) {
    if (password.isEmpty) {
      throw ValidationException('Password cannot be empty');
    }

    if (password.length < 8) {
      throw ValidationException('Password must be at least 8 characters');
    }

    if (password.length > 128) {
      throw ValidationException('Password is too long (max 128 characters)');
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      throw ValidationException(
        'Password must contain at least one uppercase letter (A-Z)',
      );
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      throw ValidationException(
        'Password must contain at least one lowercase letter (a-z)',
      );
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      throw ValidationException(
          'Password must contain at least one number (0-9)');
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      throw ValidationException(
        'Password must contain at least one special character '
        r'(!@#$%^&*(),.?":{}|<>)',
      );
    }

    return password;
  }

  /// Validates display name.
  ///
  /// Requirements:
  /// - Between 2-50 characters
  /// - Contains at least one letter
  /// - No leading/trailing whitespace
  ///
  /// Throws: [ValidationException] if validation fails
  static String validateDisplayName(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      throw ValidationException('Display name cannot be empty');
    }

    if (trimmed.length < 2) {
      throw ValidationException('Display name must be at least 2 characters');
    }

    if (trimmed.length > 50) {
      throw ValidationException('Display name must be at most 50 characters');
    }

    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      throw ValidationException(
          'Display name must contain at least one letter');
    }

    // Allow alphanumeric, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z0-9\s\-']+$").hasMatch(trimmed)) {
      throw ValidationException(
        'Display name can only contain letters, numbers, spaces, hyphens, and apostrophes',
      );
    }

    return trimmed;
  }

  /// Validates all auth fields together.
  ///
  /// Returns a map with validated values if all pass.
  /// Throws [ValidationException] if any validation fails.
  static Map<String, String> validateAuthFields({
    required String email,
    required String password,
    required String displayName,
  }) =>
      {
        'email': validateEmail(email),
        'password': validatePassword(password),
        'displayName': validateDisplayName(displayName),
      };
}
