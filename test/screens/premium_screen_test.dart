import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_chess/src/screens/premium/premium_screen.dart';
import 'package:komovia_chess/src/services/subscription_service.dart';

void main() {
  group('PremiumScreen Widget Tests', () {
    testWidgets('displays premium features list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      // Check for header
      expect(find.text('Premium Features'), findsOneWidget);
      expect(find.text('♟️ Upgrade to Premium'), findsOneWidget);

      // Check for feature items
      expect(find.text('Unlimited Puzzles'), findsOneWidget);
      expect(find.text('Custom Themes'), findsOneWidget);
      expect(find.text('No Advertisements'), findsOneWidget);
    });

    testWidgets('displays pricing plans', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for pricing section
      expect(find.text('Choose Your Plan'), findsOneWidget);

      // Check for plan names
      expect(find.text('Premium (Monthly)'), findsOneWidget);
      expect(find.text('Premium+ (Annual)'), findsOneWidget);
    });

    testWidgets('displays correct pricing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for prices
      expect(find.text('\$4.99'), findsOneWidget);
      expect(find.text('\$2.92'), findsOneWidget);
    });

    testWidgets('displays subscription info section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Subscription Details'), findsOneWidget);
      expect(
        find.text(
          contains('Renews automatically'),
        ),
        findsWidgets,
      );
    });

    testWidgets('has subscribe buttons for each plan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Look for subscribe buttons
      expect(find.text('Subscribe Now'), findsWidgets);
    });

    testWidgets('has restore purchases button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Restore Purchases'), findsOneWidget);
    });

    testWidgets('displays app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      expect(find.text('Premium Features'), findsWidgets);
    });

    testWidgets('scrolls to show all content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PremiumScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to bottom
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
        1000,
      );

      await tester.pumpAndSettle();

      // Should still find content even after scrolling
      expect(find.text('Restore Purchases'), findsOneWidget);
    });
  });
}
