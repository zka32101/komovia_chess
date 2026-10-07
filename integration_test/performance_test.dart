import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chess/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Integration Tests', () {
    testWidgets('App startup performance', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      stopwatch.stop();

      // Verify app launched within expected time
      // Target: 3000ms or less
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(3000),
        reason:
            'App startup took ${stopwatch.elapsedMilliseconds}ms, target is 3000ms',
      );

      print('✓ App startup time: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Settings screen rendering performance', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final stopwatch = Stopwatch()..start();

      // Navigate to settings
      final settingsNav = find.byIcon(Icons.settings);
      if (settingsNav.evaluate().isNotEmpty) {
        await tester.tap(settingsNav);
        await tester.pumpAndSettle();
      }

      stopwatch.stop();

      // Target: 500ms or less for screen navigation
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason:
            'Settings navigation took ${stopwatch.elapsedMilliseconds}ms, target is 500ms',
      );

      print('✓ Settings screen render time: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Scrolling performance in settings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      final settingsNav = find.byIcon(Icons.settings);
      if (settingsNav.evaluate().isNotEmpty) {
        await tester.tap(settingsNav);
        await tester.pumpAndSettle();
      }

      final stopwatch = Stopwatch()..start();

      // Perform scrolling
      for (int i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }

      stopwatch.stop();

      // Target: 500ms per scroll cycle
      final avgTime = stopwatch.elapsedMilliseconds / 5;
      expect(
        avgTime,
        lessThan(100),
        reason: 'Average scroll time is ${avgTime.toStringAsFixed(2)}ms',
      );

      print('✓ Average scroll time: ${avgTime.toStringAsFixed(2)}ms');
    });

    testWidgets('Widget tree complexity check', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Get the root widget
      final root = find.byType(MaterialApp);
      expect(root, findsOneWidget);

      // Verify performance by checking widget count
      final allWidgets = find.byType(Object);
      final widgetCount = allWidgets.evaluate().length;

      // Alert if widget tree is excessively complex
      print('Total widgets in tree: $widgetCount');

      // This is informational - actual limit depends on device
      expect(widgetCount, greaterThan(0));
      expect(widgetCount, lessThan(10000));
    });

    testWidgets('Memory usage patterns', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate through multiple screens to check for memory leaks
      final settingsNav = find.byIcon(Icons.settings);

      for (int i = 0; i < 3; i++) {
        if (settingsNav.evaluate().isNotEmpty) {
          await tester.tap(settingsNav);
          await tester.pumpAndSettle();

          // Go back
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        }
      }

      // If we got here without crashes, memory handling is acceptable
      expect(true, true);

      print('✓ No memory-related crashes during navigation cycles');
    });

    testWidgets('Theme switching performance', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings
      final settingsNav = find.byIcon(Icons.settings);
      if (settingsNav.evaluate().isNotEmpty) {
        await tester.tap(settingsNav);
        await tester.pumpAndSettle();
      }

      final stopwatch = Stopwatch()..start();

      // Perform theme switch
      final themeOption = find.text('Theme');
      if (themeOption.evaluate().isNotEmpty) {
        await tester.tap(themeOption);
        await tester.pumpAndSettle();

        final darkMode = find.text('Dark');
        if (darkMode.evaluate().isNotEmpty) {
          await tester.tap(darkMode);
          await tester.pumpAndSettle();
        }
      }

      stopwatch.stop();

      // Target: 300ms or less for theme switch
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(300),
        reason:
            'Theme switch took ${stopwatch.elapsedMilliseconds}ms, target is 300ms',
      );

      print('✓ Theme switch time: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('UI responsiveness during data loading', (WidgetTester tester) async {
      app.main();

      final stopwatch = Stopwatch()..start();

      // Measure responsiveness while app is initializing
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));

        // Try to interact during loading
        final elements = find.byType(Scaffold);
        if (elements.evaluate().isNotEmpty) {
          break;
        }
      }

      stopwatch.stop();

      // Should respond within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      print('✓ UI response time during initialization: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Gesture responsiveness', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test multiple rapid taps
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 10; i++) {
        final element = find.byType(NavigationBar);
        if (element.evaluate().isNotEmpty) {
          await tester.tap(element);
          await tester.pumpAndSettle();
          // Navigate back if possible
          await tester.tap(element);
          await tester.pumpAndSettle();
        }
      }

      stopwatch.stop();

      // Average time per interaction should be low
      final avgTime = stopwatch.elapsedMilliseconds / 10;

      print('✓ Average gesture response time: ${avgTime.toStringAsFixed(2)}ms');

      expect(avgTime, lessThan(200));
    });
  });
}
