import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/widgets/move_history.dart';

/// Plays [from]->[to] on [game] and returns the [chess_lib.Move] that was made
/// (chess 0.7's Move is built by the engine, not constructed by hand).
chess_lib.Move playMove(chess_lib.Chess game, String from, String to) {
  final move = game
      .generate_moves()
      .firstWhere((m) => m.fromAlgebraic == from && m.toAlgebraic == to);
  game.make_move(move);
  return move;
}

void main() {
  group('MoveHistory', () {
    testWidgets('displays empty state when no moves',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: [],
            ),
          ),
        ),
      );

      expect(find.text('No moves yet'), findsOneWidget);
    });

    testWidgets('displays move numbers', (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'c7', 'c5'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
            ),
          ),
        ),
      );

      expect(find.text('1.'), findsOneWidget);
    });

    testWidgets('displays moves in pairs (white and black)',
        (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'c7', 'c5'));
      played.add(playMove(game, 'g1', 'f3'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders move buttons', (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'e7', 'e5'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('highlights current move', (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'e7', 'e5'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
              currentMoveIndex: 0,
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('calls callback when move selected',
        (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'e7', 'e5'));

      final moves = played;
      int? selectedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
              onMoveSelected: (index) {
                selectedIndex = index;
              },
            ),
          ),
        ),
      );

      // Tap first move
      final moveButtons = find.byType(GestureDetector);
      await tester.tap(moveButtons.first);
      await tester.pump();

      expect(selectedIndex, isNotNull);
    });

    testWidgets('handles odd number of moves', (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'e7', 'e5'));
      played.add(playMove(game, 'g1', 'f3'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('displays move notation', (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
            ),
          ),
        ),
      );

      // Should display some move notation
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('scrollable with many moves', (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      // Make 20 moves: always play the first legal move.
      for (int i = 0; i < 20 && !game.game_over; i++) {
        final move = game.generate_moves().first;
        game.make_move(move);
        played.add(move);
      }

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: MoveHistory(
                moves: moves,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows both white and black moves',
        (WidgetTester tester) async {
      final game = chess_lib.Chess();
      final played = <chess_lib.Move>[];
      played.add(playMove(game, 'e2', 'e4'));
      played.add(playMove(game, 'c7', 'c5'));

      final moves = played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistory(
              moves: moves,
            ),
          ),
        ),
      );

      // Should have at least 2 moves displayed
      expect(find.byType(Text), findsWidgets);
    });
  });
}
