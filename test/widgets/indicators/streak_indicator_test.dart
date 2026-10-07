import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/indicators/streak_indicator.dart';

void main() {
  group('StreakIndicator', () {
    testWidgets('displays current win streak', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 5,
              longestWin: 10,
              longestLoss: 3,
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('連勝中'), findsOneWidget);
    });

    testWidgets('displays current loss streak', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: -3,
              longestWin: 10,
              longestLoss: 5,
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('連敗中'), findsOneWidget);
    });

    testWidgets('displays longest win streak', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 2,
              longestWin: 15,
              longestLoss: 4,
            ),
          ),
        ),
      );

      expect(find.text('15'), findsOneWidget);
      expect(find.text('最長連勝'), findsOneWidget);
    });

    testWidgets('displays longest loss streak', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 1,
              longestWin: 10,
              longestLoss: 6,
            ),
          ),
        ),
      );

      expect(find.text('6'), findsOneWidget);
      expect(find.text('最長連敗'), findsOneWidget);
    });

    testWidgets('animates when streak value changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 5,
              longestWin: 10,
              longestLoss: 3,
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 6,
              longestWin: 10,
              longestLoss: 3,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('has correct widget structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 5,
              longestWin: 10,
              longestLoss: 3,
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('zero streak displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreakIndicator(
              currentStreak: 0,
              longestWin: 10,
              longestLoss: 3,
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });
  });
}
