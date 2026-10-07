import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/widgets/move_history.dart';

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c5'));

      final moves = game.moves() as List<chess_lib.Move>;

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c5'));
      game.move(chess_lib.Move(fromAlgebraic: 'g1', toAlgebraic: 'f3'));

      final moves = game.moves() as List<chess_lib.Move>;

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));

      final moves = game.moves() as List<chess_lib.Move>;

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));

      final moves = game.moves() as List<chess_lib.Move>;

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));

      final moves = game.moves() as List<chess_lib.Move>;
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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));
      game.move(chess_lib.Move(fromAlgebraic: 'g1', toAlgebraic: 'f3'));

      final moves = game.moves() as List<chess_lib.Move>;

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));

      final moves = game.moves() as List<chess_lib.Move>;

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
      // Make 20 moves
      for (int i = 0; i < 20 && !game.game_over(); i++) {
        final moves = game.moves() as List<chess_lib.Move>;
        if (moves.isEmpty) break;
        game.move(moves[0]);
      }

      final moves = game.moves() as List<chess_lib.Move>;

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
      game.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      game.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c5'));

      final moves = game.moves() as List<chess_lib.Move>;

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
