import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:logger/logger.dart';
import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;
import '../models/user.dart';
import 'validation_service.dart';
import 'rate_limiting_service.dart';

/// Exception thrown for network-related errors.
class NetworkException implements Exception {
  NetworkException(
    this.message, {
    this.retryCount,
    this.retryAfter,
  });
  final String message;
  final int? retryCount;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  final RateLimitingService _rateLimiting = RateLimitingService();

  /// Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  /// Get current app user from Firestore
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return UserModel.fromJson(doc.data()!);
    } catch (e) {
      _logger.e('Error getting current user: $e');
      return null;
    }
  }

  /// Register with email and password
  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _logger.i('Registering user with email: $email');

      // Check rate limit before attempting registration
      _rateLimiting.checkRateLimit('signUp');

      // Validate input before attempting registration
      ValidationService.validateAuthFields(
        email: email,
        password: password,
        displayName: displayName,
      );

      try {
        // Create user in Firebase Auth
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final firebaseUser = userCredential.user;
        if (firebaseUser == null) {
          throw Exception('Failed to create Firebase user');
        }

        // Update profile
        await firebaseUser.updateDisplayName(displayName);

        // Create user document in Firestore
        final newUser = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? email,
          displayName: displayName,
          photoUrl: firebaseUser.photoURL,
          emailVerified: firebaseUser.emailVerified,
          rating: 1500, // Default starting rating
          onlineRating: 1500,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toJson());

        _rateLimiting.recordSuccess('signUp');
        _logger.i('User registered successfully: ${firebaseUser.uid}');
        return newUser;
      } on FirebaseAuthException {
        _rateLimiting.recordFailure('signUp');
        rethrow;
      }
    } on RateLimitException catch (e) {
      _logger.w('Rate limit exceeded for sign-up: ${e.message}');
      rethrow;
    } on ValidationException catch (e) {
      _logger.w('Validation error during registration: ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error registering user: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing in user with email: $email');

      // Check rate limit before attempting sign-in
      _rateLimiting.checkRateLimit('signIn');

      // Validate email format
      ValidationService.validateEmail(email);

      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        _rateLimiting.recordSuccess('signIn');
      } on FirebaseAuthException {
        _rateLimiting.recordFailure('signIn');
        rethrow;
      }

      final user = await getCurrentUser();
      _logger.i('User signed in successfully: ${user?.uid}');
      return user;
    } on RateLimitException catch (e) {
      _logger.w('Rate limit exceeded for sign-in: ${e.message}');
      rethrow;
    } on ValidationException catch (e) {
      _logger.w('Validation error during sign in: ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing in: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  ///
  /// Handles the complete Google Sign-In flow:
  /// 1. Triggers Google Sign-In UI
  /// 2. Gets authentication tokens
  /// 3. Creates Firebase credential
  /// 4. Signs into Firebase
  /// 5. Creates/updates user in Firestore
  ///
  /// Requirements:
  /// - Google OAuth credentials configured in Google Cloud Console
  /// - SHA-1 fingerprint registered for Android app
  /// - Bundle ID registered for iOS app
  Future<UserModel?> signInWithGoogle() async {
    try {
      _logger.i('Signing in with Google');

      // Check rate limit before attempting sign-in
      _rateLimiting.checkRateLimit('signInWithGoogle');

      try {
        // Trigger Google Sign-In UI
        // User sees Google sign-in dialog
        final googleUser = await GoogleSignIn().signIn();

        if (googleUser == null) {
          _logger.i('Google sign-in cancelled by user');
          return null;
        }

        _logger.i('Google user signed in: ${googleUser.email}');

        // Get authentication tokens from Google (network call)
        final googleAuth = await _handleNetworkCall(
          () => googleUser.authentication,
          'Fetch Google auth tokens',
        );

        // Create Firebase credential using Google authentication tokens
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign into Firebase with Google credential
        final userCredential = await _handleNetworkCall(
          () => _auth.signInWithCredential(credential),
          'Sign into Firebase with Google credential',
        );
        final firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Failed to sign in with Google');
        }

        _logger.i('Signed into Firebase with Google: ${firebaseUser.uid}');

        // Check if user already exists in Firestore (with retry)
        final userDoc = await _handleNetworkCall(
          () => _firestore.collection('users').doc(firebaseUser.uid).get(),
          'Fetch user document from Firestore',
        );

        if (!userDoc.exists) {
          // Create new user document in Firestore
          _logger.i('Creating new user document for Google sign-in');
          final newUser = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? 'no-email@google.com',
            displayName: firebaseUser.displayName ?? 'Google User',
            photoUrl: firebaseUser.photoURL,
            emailVerified: firebaseUser.emailVerified,
            rating: 1500, // Default starting rating
            onlineRating: 1500,
            createdAt: DateTime.now(),
          );

          await _handleNetworkCall(
            () => _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .set(newUser.toJson()),
            'Create new user document in Firestore',
          );

          _rateLimiting.recordSuccess('signInWithGoogle');
          _logger.i(
              'User document created from Google sign-in: ${firebaseUser.uid}');
          return newUser;
        } else {
          // User already exists, retrieve from Firestore
          _logger.i('User already exists in Firestore, retrieving data');
          final user = await getCurrentUser();
          _rateLimiting.recordSuccess('signInWithGoogle');
          return user;
        }
      } on SocketException {
        _rateLimiting.recordFailure('signInWithGoogle');
        throw NetworkException(
          'Network error: Unable to connect to sign-in service. Please check your internet connection and try again.',
        );
      } on FirebaseAuthException {
        _rateLimiting.recordFailure('signInWithGoogle');
        rethrow;
      }
    } on RateLimitException catch (e) {
      _logger.w('Rate limit exceeded for Google sign-in: ${e.message}');
      rethrow;
    } on NetworkException catch (e) {
      _logger.w('Network error during Google sign-in: ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      _logger.e(
          'Firebase auth error during Google sign-in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign in with Apple
  ///
  /// Handles the complete Apple Sign-In flow:
  /// 1. Checks if Sign-In with Apple is available on device
  /// 2. Requests user credentials (email, fullName)
  /// 3. Creates Firebase OAuth credential
  /// 4. Signs into Firebase
  /// 5. Creates/updates user in Firestore
  ///
  /// Requirements:
  /// - Apple Developer account with Team ID
  /// - Sign-In with Apple certificates configured
  /// - Service ID registered for the app
  /// - iOS 13+ (automatically handled by package)
  Future<UserModel?> signInWithApple() async {
    try {
      _logger.i('Signing in with Apple');

      // Check rate limit before attempting sign-in
      _rateLimiting.checkRateLimit('signInWithApple');

      try {
        // Check if Sign-In with Apple is available on device
        final isAvailable = await SignInWithApple.isAvailable();
        if (!isAvailable) {
          throw Exception('Sign in with Apple is not available on this device');
        }

        _logger.i('Sign in with Apple is available, requesting credentials');

        // Request Apple Sign-In credential with email and full name
        final credential = await _handleNetworkCall(
          () => SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          ),
          'Request Apple Sign-In credentials',
        );

        _logger.i('Apple credentials received, creating OAuth credential');

        // Create Firebase OAuth credential from Apple tokens
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
        );

        // Sign into Firebase with Apple credential
        final userCredential = await _handleNetworkCall(
          () => _auth.signInWithCredential(oauthCredential),
          'Sign into Firebase with Apple credential',
        );
        final firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Failed to sign in with Apple');
        }

        _logger.i('Signed into Firebase with Apple: ${firebaseUser.uid}');

        // Construct display name from Apple's full name response
        String displayName = firebaseUser.displayName ?? 'Apple User';
        if (credential.givenName != null || credential.familyName != null) {
          final givenName = credential.givenName ?? '';
          final familyName = credential.familyName ?? '';
          displayName = '$givenName $familyName'.trim();
          if (displayName.isEmpty) {
            displayName = 'Apple User';
          }
        }

        // Get email from credential (Apple may not provide it on first sign-in)
        final email =
            credential.email ?? firebaseUser.email ?? 'no-email@apple.com';

        _logger.i('Display name: $displayName, Email: $email');

        // Check if user already exists in Firestore (with retry)
        final userDoc = await _handleNetworkCall(
          () => _firestore.collection('users').doc(firebaseUser.uid).get(),
          'Fetch user document from Firestore',
        );

        if (!userDoc.exists) {
          // Create new user document in Firestore
          _logger.i('Creating new user document for Apple sign-in');
          final newUser = UserModel(
            uid: firebaseUser.uid,
            email: email,
            displayName: displayName,
            photoUrl: null, // Apple doesn't provide photo URL
            emailVerified: firebaseUser.emailVerified,
            rating: 1500, // Default starting rating
            onlineRating: 1500,
            createdAt: DateTime.now(),
          );

          await _handleNetworkCall(
            () => _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .set(newUser.toJson()),
            'Create new user document in Firestore',
          );

          _rateLimiting.recordSuccess('signInWithApple');
          _logger.i(
              'User document created from Apple sign-in: ${firebaseUser.uid}');
          return newUser;
        } else {
          // User already exists, retrieve from Firestore
          _logger.i('User already exists in Firestore, retrieving data');
          final user = await getCurrentUser();
          _rateLimiting.recordSuccess('signInWithApple');
          return user;
        }
      } on SocketException {
        _rateLimiting.recordFailure('signInWithApple');
        throw NetworkException(
          'Network error: Unable to connect to sign-in service. Please check your internet connection and try again.',
        );
      } on FirebaseAuthException {
        _rateLimiting.recordFailure('signInWithApple');
        rethrow;
      }
    } on RateLimitException catch (e) {
      _logger.w('Rate limit exceeded for Apple sign-in: ${e.message}');
      rethrow;
    } on NetworkException catch (e) {
      _logger.w('Network error during Apple sign-in: ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      _logger.e(
          'Firebase auth error during Apple sign-in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing in with Apple: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Sending password reset email to: $email');

      // Check rate limit before attempting password reset
      _rateLimiting.checkRateLimit('passwordReset');

      // Validate email format
      ValidationService.validateEmail(email);

      try {
        await _handleNetworkCall(
          () => _auth.sendPasswordResetEmail(email: email),
          'Send password reset email',
        );
        _rateLimiting.recordSuccess('passwordReset');
        _logger.i('Password reset email sent');
      } on FirebaseAuthException {
        _rateLimiting.recordFailure('passwordReset');
        rethrow;
      }
    } on RateLimitException catch (e) {
      _logger.w('Rate limit exceeded for password reset: ${e.message}');
      rethrow;
    } on ValidationException catch (e) {
      _logger.w('Validation error during password reset request: ${e.message}');
      rethrow;
    } on NetworkException catch (e) {
      _logger.w('Network error during password reset: ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error sending password reset: $e');
      rethrow;
    }
  }

  /// Verify email
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      _logger.i('Sending email verification to: ${user.email}');
      await user.sendEmailVerification();
      _logger.i('Email verification sent');
    } catch (e) {
      _logger.e('Error sending email verification: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      _logger.i('Updating user profile for: ${user.uid}');

      await user.updateDisplayName(displayName ?? user.displayName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      _logger.i('User profile updated');
    } catch (e) {
      _logger.e('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      _logger.i('Deleting account for user: ${user.uid}');

      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete Firebase Auth user
      await user.delete();

      _logger.i('Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error deleting account: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _logger.i('Signing out user');
      await _auth.signOut();
      _logger.i('User signed out');
    } catch (e) {
      _logger.e('Error signing out: $e');
      rethrow;
    }
  }

  /// Auth state stream
  Stream<User?> authStateStream() => _auth.authStateChanges();

  // ============================================
  // NETWORK ERROR HANDLING
  // ============================================

  /// Handle network calls with error handling and conversion
  ///
  /// Wraps async network calls to:
  /// 1. Catch socket/network exceptions
  /// 2. Provide helpful error messages
  /// 3. Enable retry logic in UI
  Future<T> _handleNetworkCall<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } on SocketException catch (e) {
      _logger.e('$operationName - Network error: $e');
      throw NetworkException(
        'Network error: Unable to connect. Please check your internet connection and try again.',
      );
    } on TimeoutException catch (e) {
      _logger.e('$operationName - Timeout: $e');
      throw NetworkException(
        'Connection timeout: The request took too long. Please try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'network-error' || e.code == 'unavailable') {
        _logger.e('$operationName - Firebase network error: ${e.message}');
        throw NetworkException(
          'Network error: Firebase service unavailable. Please try again.',
        );
      }
      rethrow;
    }
  }
}
