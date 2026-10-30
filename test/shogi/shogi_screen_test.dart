import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/shogi/shogi_board.dart';
import 'package:komovia_chess/src/shogi/shogi_engine.dart';
import 'package:komovia_chess/src/shogi/shogi_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

void main() {
  testWidgets('ShogiScreen renders the board and sente-to-move banner',
      (tester) async {
    await tester.pumpWidget(_wrap(const ShogiScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(ShogiBoard), findsOneWidget);
    expect(find.textContaining('Sente'), findsWidgets);
  });

  testWidgets('tapping a pawn then a legal square moves it', (tester) async {
    await tester.pumpWidget(_wrap(const ShogiScreen()));
    await tester.pumpAndSettle();

    final boardFinder = find.byType(ShogiBoard);
    final boardWidget = tester.widget<ShogiBoard>(boardFinder);
    final game = boardWidget.game;

    // Sente's pawn in column 4 (0-indexed) starts at row 6.
    expect(game.board[6][4]?.type, ShogiPieceType.pawn);
    expect(game.board[5][4], isNull);

    final boardTopLeft = tester.getTopLeft(boardFinder);
    final boardSize = tester.getSize(boardFinder);
    final squareSize = boardSize.width / 9;

    Offset squareCenter(int row, int col) => boardTopLeft +
        Offset((col + 0.5) * squareSize, (row + 0.5) * squareSize);

    await tester.tapAt(squareCenter(6, 4));
    await tester.pumpAndSettle();
    await tester.tapAt(squareCenter(5, 4));
    await tester.pumpAndSettle();

    expect(game.board[6][4], isNull);
    expect(game.board[5][4]?.type, ShogiPieceType.pawn);
    expect(game.senteTurn, isFalse, reason: 'turn should pass to gote');
  });

  testWidgets('tapping a pawn then an illegal square does not move it',
      (tester) async {
    await tester.pumpWidget(_wrap(const ShogiScreen()));
    await tester.pumpAndSettle();

    final boardFinder = find.byType(ShogiBoard);
    final boardWidget = tester.widget<ShogiBoard>(boardFinder);
    final game = boardWidget.game;

    final boardTopLeft = tester.getTopLeft(boardFinder);
    final boardSize = tester.getSize(boardFinder);
    final squareSize = boardSize.width / 9;
    Offset squareCenter(int row, int col) => boardTopLeft +
        Offset((col + 0.5) * squareSize, (row + 0.5) * squareSize);

    // Select the sente pawn at (6,4), then tap a square 2 rows forward,
    // which is not a legal pawn move (pawns move exactly one step).
    await tester.tapAt(squareCenter(6, 4));
    await tester.pumpAndSettle();
    await tester.tapAt(squareCenter(4, 4));
    await tester.pumpAndSettle();

    // The pawn never moved, and it's still sente's turn.
    expect(game.board[6][4]?.type, ShogiPieceType.pawn);
    expect(game.board[4][4], isNull);
    expect(game.senteTurn, isTrue);
  });
}
