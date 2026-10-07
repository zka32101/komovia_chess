import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/game_result.dart';

void main() {
  group('GameResult', () {
    testWidgets('displays white win result', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 42,
              duration: const Duration(minutes: 15),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('White Wins!'), findsOneWidget);
      expect(find.text('by Checkmate'), findsOneWidget);
    });

    testWidgets('displays black win result', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'black_win',
              method: 'checkmate',
              moves: 40,
              duration: const Duration(minutes: 12),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('Black Wins!'), findsOneWidget);
    });

    testWidgets('displays draw result', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'draw',
              method: 'stalemate',
              moves: 50,
              duration: const Duration(minutes: 20),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('by Stalemate'), findsOneWidget);
    });

    testWidgets('displays checkmate method', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 10),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('by Checkmate'), findsOneWidget);
    });

    testWidgets('displays resignation method', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'resignation',
              moves: 25,
              duration: const Duration(minutes: 8),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('by Resignation'), findsOneWidget);
    });

    testWidgets('displays stalemate method', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'draw',
              method: 'stalemate',
              moves: 60,
              duration: const Duration(minutes: 30),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('by Stalemate'), findsOneWidget);
    });

    testWidgets('displays move count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 42,
              duration: const Duration(minutes: 15),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('Total Moves:'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays game duration in seconds',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(seconds: 45),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('Duration:'), findsOneWidget);
      expect(find.text('45s'), findsOneWidget);
    });

    testWidgets('displays game duration in minutes and seconds',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15, seconds: 30),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('Duration:'), findsOneWidget);
    });

    testWidgets('displays result emoji icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('👑'), findsOneWidget);
    });

    testWidgets('shows home button when callback provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
              onHome: () {},
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows new game button when callback provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
              onNewGame: () {},
            ),
          ),
        ),
      );

      expect(find.text('New Game'), findsOneWidget);
    });

    testWidgets('shows analyze button when callback provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
              onAnalyze: () {},
            ),
          ),
        ),
      );

      expect(find.text('Analyze'), findsOneWidget);
    });

    testWidgets('calls home callback when home button pressed',
        (WidgetTester tester) async {
      bool homePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
              onHome: () {
                homePressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(homePressed, true);
    });

    testWidgets('calls new game callback when new game button pressed',
        (WidgetTester tester) async {
      bool newGamePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
              onNewGame: () {
                newGamePressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('New Game'));
      await tester.pump();

      expect(newGamePressed, true);
    });

    testWidgets('renders as dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameResult(
              result: 'white_win',
              method: 'checkmate',
              moves: 30,
              duration: const Duration(minutes: 15),
            ),
          ),
        ),
      );

      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
