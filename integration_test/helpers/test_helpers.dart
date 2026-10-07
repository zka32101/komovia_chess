import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper utilities for integration tests
class TestHelpers {
  /// Initialize Firebase for testing
  static Future<void> initializeFirebaseForTesting() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  /// Clean up Firestore after tests
  static Future<void> cleanupFirestore({
    required List<String> collections,
  }) async {
    final firestore = FirebaseFirestore.instance;

    for (final collection in collections) {
      final docs = await firestore.collection(collection).get();
      for (final doc in docs.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Create test user and return credentials
  static Future<TestUserCredentials> createTestUser({
    String email = 'test@example.com',
    String password = 'Test12345!',
  }) async {
    final auth = FirebaseAuth.instance;

    try {
      // Check if user already exists
      await auth.signOut();

      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return TestUserCredentials(
        uid: userCredential.user!.uid,
        email: email,
        password: password,
      );
    } catch (e) {
      // User might already exist, try to sign in
      await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = auth.currentUser!;
      return TestUserCredentials(
        uid: user.uid,
        email: email,
        password: password,
      );
    }
  }

  /// Sign in test user
  static Future<void> signInTestUser({
    required String email,
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Sign out current user
  static Future<void> signOutCurrentUser() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Delete test user
  static Future<void> deleteTestUser({
    required String uid,
  }) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user != null && user.uid == uid) {
      await user.delete();
    }
  }

  /// Wait for a widget condition
  static Future<void> waitForCondition(
    WidgetTester tester, {
    required Future<bool> Function() condition,
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      if (await condition()) {
        return;
      }
      await tester.pump(interval);
    }

    throw TimeoutException('Condition not met within $timeout');
  }

  /// Find and tap a widget with text
  static Future<void> tapTextButton(
    WidgetTester tester,
    String text,
  ) async {
    await tester.tap(find.text(text));
    await tester.pump();
  }

  /// Enter text into a text field
  static Future<void> enterText(
    WidgetTester tester,
    String text,
  ) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  /// Scroll to find a widget
  static Future<void> scrollUntilVisible(
    WidgetTester tester, {
    required Finder finder,
    Duration timeout = const Duration(seconds: 30),
    int maxScrolls = 20,
  }) async {
    int scrollCount = 0;

    while (!finder.evaluate().isNotEmpty && scrollCount < maxScrolls) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      scrollCount++;
    }

    if (!finder.evaluate().isNotEmpty) {
      throw Exception('Widget not found after $maxScrolls scrolls');
    }
  }

  /// Wait for network request (Firebase)
  static Future<void> waitForNetworkRequest(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpAndSettle(timeout);
  }

  /// Verify snackbar message
  static void verifySnackbarMessage(
    WidgetTester tester,
    String message,
  ) {
    expect(find.text(message), findsWidgets);
  }

  /// Get current route name
  static String? getCurrentRouteName(WidgetTester tester) {
    // This depends on your routing implementation
    // For now, returning null as placeholder
    return null;
  }
}

/// Test user credentials holder
class TestUserCredentials {
  final String uid;
  final String email;
  final String password;

  TestUserCredentials({
    required this.uid,
    required this.email,
    required this.password,
  });
}
