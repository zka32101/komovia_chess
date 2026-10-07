import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/firebase_auth_service.dart';

// Firebase Auth Service provider
final firebaseAuthServiceProvider = Provider((ref) => FirebaseAuthService());

// Current Firebase user stream provider
final firebaseUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateStream();
});

// Current app user stream provider
final currentUserProvider = StreamProvider<UserModel?>((ref) async* {
  final authService = ref.watch(firebaseAuthServiceProvider);

  // Listen to Firebase auth state changes
  await for (final firebaseUser in authService.authStateStream()) {
    if (firebaseUser == null) {
      yield null;
    } else {
      // Get user data from Firestore
      final userModel = await authService.getCurrentUser();
      yield userModel;
    }
  }
});

// Authentication state notifier
class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthStateNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }
  final FirebaseAuthService _authService;

  Future<void> _init() async {
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithGoogle();
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithApple();
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      await _authService.updateUserProfile(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      // Refresh user data
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

// Auth state notifier provider
final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return AuthStateNotifier(authService);
});

// Auth methods convenience provider
final authProvider = Provider((ref) => ref.watch(firebaseAuthServiceProvider));

// User is authenticated check
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  return authState.whenData((user) => user != null).value ?? false;
});

// User loading state
final isAuthLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  return authState.isLoading;
});

// User error state
final authErrorProvider = Provider<Exception?>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  return authState.maybeWhen(
    error: (error, _) => error as Exception?,
    orElse: () => null,
  );
});
