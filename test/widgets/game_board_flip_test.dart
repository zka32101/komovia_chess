import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/widgets/game_board.dart';
import 'package:komovia_chess/src/widgets/piece_glyph.dart';

/// Covers the board-orientation fix: when [GameBoard.flipped] is true
/// (the human player is Black), the board must render rotated 180° -
/// both rank AND file mirrored, not just rank - so the player's own
/// back rank ends up at the bottom, matching every real chess app.
///
/// Uses a position with exactly two pieces at opposite corners (White
/// king a1, Black king h8) and compares their on-screen positions
/// *relative to each other*, rather than against some absolute "board
/// center" derived from the whole [GameBoard] widget (which also
/// includes the turn-indicator text and control buttons around the
/// actual 8x8 grid) - that keeps the assertions correct regardless of
/// exactly how much padding/surrounding UI the widget has.
void main() {
  const cornersFen = '7k/8/8/8/8/8/8/K7 w - - 0 1';

  Future<void> pumpBoard(WidgetTester tester, {required bool flipped}) async {
    final game = chess_lib.Chess.fromFEN(cornersFen);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBoard(gameState: game, showMaterial: false, flipped: flipped),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset whiteKingPos(WidgetTester tester) => tester.getCenter(
        find.byWidgetPredicate((w) => w is PieceGlyph && w.type == 'k' && w.isWhite),
      );
  Offset blackKingPos(WidgetTester tester) => tester.getCenter(
        find.byWidgetPredicate((w) => w is PieceGlyph && w.type == 'k' && !w.isWhite),
      );

  group('GameBoard orientation (flipped)', () {
    testWidgets(
        'not flipped: White king (a1) bottom-left, Black king (h8) top-right',
        (tester) async {
      await pumpBoard(tester, flipped: false);

      final white = whiteKingPos(tester);
      final black = blackKingPos(tester);

      // White's own back-rank piece is at the bottom (White's
      // perspective is the default/correct one when White is playing).
      expect(white.dy, greaterThan(black.dy));
      // a1 is to the left of h8.
      expect(white.dx, lessThan(black.dx));
    });

    testWidgets(
        'flipped: Black king (h8) moves to the bottom, White king (a1) to the top',
        (tester) async {
      await pumpBoard(tester, flipped: true);

      final white = whiteKingPos(tester);
      final black = blackKingPos(tester);

      // The whole board rotates 180°: Black's own piece (h8) must now
      // be at the bottom (Black's own back rank, matching standard
      // "playing as Black" orientation) ...
      expect(black.dy, greaterThan(white.dy));
      // ... AND the files mirror too, not just the ranks - a rank-only
      // flip bug would leave White's king still to the left of Black's;
      // a real 180° flip must also swap left/right.
      expect(white.dx, greaterThan(black.dx));
    });

    testWidgets('tap hit-testing uses the same flipped mapping as rendering',
        (tester) async {
      String? reportedFrom;
      String? reportedTo;
      final game = chess_lib.Chess.fromFEN(cornersFen);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameBoard(
              gameState: game,
              showMaterial: false,
              flipped: true,
              isPlayerTurn: true,
              onMove: (from, to, {promotion}) {
                reportedFrom = from;
                reportedTo = to;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final white = whiteKingPos(tester);
      final black = blackKingPos(tester);
      // White king is at a1 (row0,col7 when flipped) and Black king at
      // h8 (row7,col0 when flipped) - their on-screen centers are 7
      // squares apart on each axis, so this derives the real rendered
      // square size without hardcoding any padding/layout assumption.
      final squareX = (white.dx - black.dx) / 7;
      final squareY = (black.dy - white.dy) / 7;
      // b2 (file=1, rank=2) maps, when flipped, to row=1, col=6 - one
      // square down-and-left of White's king at a1 (row0, col7).
      final b2Offset = Offset(white.dx - squareX, white.dy + squareY);

      // Select the White king (tapping exactly where it renders)...
      await tester.tapAt(white);
      await tester.pumpAndSettle();
      // ...then tap the computed on-screen position for b2, a legal
      // one-square king move. If tap hit-testing used a different
      // (row,file)->square mapping than rendering did, this tap would
      // land on the wrong square and either select nothing (no onMove)
      // or report the wrong from/to pair.
      await tester.tapAt(b2Offset);
      await tester.pumpAndSettle();

      expect(reportedFrom, 'a1');
      expect(reportedTo, 'b2');
    });
  });
}
