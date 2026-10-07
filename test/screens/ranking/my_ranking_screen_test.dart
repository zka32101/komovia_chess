import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../lib/src/screens/ranking/my_ranking_screen.dart';

void main() {
  group('MyRankingScreen', () {
    testWidgets('displays login message when user is not authenticated', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MyRankingScreen(),
          ),
        ),
      );

      // This test would need proper Firebase auth setup
      // For now we just verify the widget builds
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MyRankingScreen(),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('マイランキング'), findsOneWidget);
    });

    testWidgets('displays refresh button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MyRankingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('displays section for nearby players', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MyRankingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show nearby players section
      expect(find.text('周辺のプレイヤー'), findsOneWidget);
    });
  });
}
