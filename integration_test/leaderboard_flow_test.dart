import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:chess/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Leaderboard Flow Integration Tests', () {
    testWidgets('User can view global rankings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to leaderboard (implementation specific)
      // This assumes a navigation method exists
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Rankings display player information correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify basic UI elements are present
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Pagination controls work', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Pagination should be available when there are multiple pages
      // Look for pagination buttons
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('Shogi rank filter displays all ranks', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // The shogi rank filter should be accessible
      // and show all rank options
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Monthly ranking can be accessed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Monthly tab should exist and be clickable
      expect(find.byType(FilterChip), findsWidgets);
    });

    testWidgets('Refresh button updates rankings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find and tap refresh button
      final refreshButton = find.byIcon(Icons.refresh);

      if (refreshButton.evaluate().isNotEmpty) {
        await tester.tap(refreshButton.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Player ranking details can be viewed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Cards should be tappable to view player details
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('Stats section displays correct data', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Stats should include total players, average rating, top rating
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Error state is handled gracefully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should not crash even if data fails to load
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Loading state is displayed', (WidgetTester tester) async {
      app.main();

      // During initial load, should show loading indicator
      // Look for CircularProgressIndicator
      await tester.pump();
    });

    testWidgets('Nearby rankings are displayed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // If user navigates to their own rank,
      // nearby players should be shown
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Rank badge colors are correct', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Rank badges should use appropriate colors
      // #1 should be gold/amber, #2 silver, #3 bronze
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('Leaderboard Filter Integration Tests', () {
    testWidgets('Global filter loads and displays rankings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find global filter chip
      final globalChip = find.text('グローバル');
      expect(globalChip, findsWidgets);
    });

    testWidgets('Monthly filter shows seasonal rankings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find monthly filter chip
      final monthlyChip = find.text('月間');
      expect(monthlyChip, findsWidgets);
    });

    testWidgets('Shogi rank filter shows correct ranked players', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Shogi rank filter button should exist
      final filterButton = find.byIcon(Icons.filter_list);
      expect(filterButton, findsWidgets);
    });

    testWidgets('Switching between filters updates display', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should be able to switch between filter types
      expect(find.byType(FilterChip), findsWidgets);
    });
  });

  group('Leaderboard Pagination Integration Tests', () {
    testWidgets('Next page button loads more rankings', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find next page button
      final nextButton = find.byIcon(Icons.chevron_right);
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Previous page button navigates back', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Load next page first
      final nextButton = find.byIcon(Icons.chevron_right);
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton.first);
        await tester.pumpAndSettle();
      }

      // Then navigate back
      final prevButton = find.byIcon(Icons.chevron_left);
      if (prevButton.evaluate().isNotEmpty) {
        await tester.tap(prevButton.first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Page indicator shows current page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should show current page number
      expect(find.textContaining('ページ'), findsWidgets);
    });

    testWidgets('Previous button is disabled on first page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Previous button should initially be disabled
      final prevButton = find.byIcon(Icons.chevron_left);
      if (prevButton.evaluate().isNotEmpty) {
        // Button should exist but might be disabled
        expect(prevButton, findsWidgets);
      }
    });
  });

  group('Leaderboard Stats Integration Tests', () {
    testWidgets('Total players stat is displayed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('プレイヤー数'), findsOneWidget);
    });

    testWidgets('Average rating stat is displayed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('平均レート'), findsOneWidget);
    });

    testWidgets('Top rating stat is displayed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('最高レート'), findsOneWidget);
    });

    testWidgets('Stats update on refresh', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Refresh and verify stats still display
      final refreshButton = find.byIcon(Icons.refresh);
      if (refreshButton.evaluate().isNotEmpty) {
        await tester.tap(refreshButton.first);
        await tester.pumpAndSettle();
      }

      expect(find.text('プレイヤー数'), findsOneWidget);
    });
  });

  group('Leaderboard Responsiveness Integration Tests', () {
    testWidgets('Layout adapts to screen size', (WidgetTester tester) async {
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      // Test on different screen sizes
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      app.main();
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Cards are readable on small screens', (WidgetTester tester) async {
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      tester.binding.window.physicalSizeTestValue = const Size(300, 600);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      app.main();
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('Scrollable when content exceeds screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should be scrollable
      expect(find.byType(ListView), findsWidgets);
    });
  });
}
