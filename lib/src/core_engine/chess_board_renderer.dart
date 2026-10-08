import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter/widgets.dart';
import 'package:komovia_core/komovia_core.dart' as core;

import '../models/board_theme.dart';
import 'chess_game.dart';
import 'chess_position.dart';

/// Chess's `BoardRenderer<ChessPosition, Widget>`.
///
/// Like komovia_go's `GoBoardRenderer` found for Go, chess has no single
/// shared, reusable "just render the board" widget to compose: both
/// `ChessBoard` (`widgets/chess_board.dart`) and `GameBoard`
/// (`widgets/game_board.dart`) are self-contained `StatefulWidget`s that
/// own their own selection state and take a mutable `chess_lib.Chess`
/// instance plus `onMove`/`onUndo`/`onResign` callbacks directly — a
/// different, screen-level shape than [core.BoardRenderer]'s stateless
/// `build(position, {lastMove, hints, selected})` contract. [build] is
/// therefore a new, minimal implementation at the same level
/// `GoBoardRenderer`/`ShogiBoardRenderer` operate at (render the
/// position, highlight last move/hints/selection), reusing only the
/// already-shared, non-widget pieces: [BoardThemeCatalog]'s colors and
/// the Unicode piece-glyph convention `GameBoard._pieceSymbol` already
/// uses. It does not reproduce either widget's own extra UI (captured
/// pieces display, promotion dialog, turn indicator, undo/resign/draw
/// buttons) — those stay screen-level concerns, exactly as
/// `GoBoardRenderer`'s doc comment describes for Go's capture-flash/
/// danger-hint overlays.
class ChessBoardRenderer implements core.BoardRenderer<ChessPosition, Widget> {
  final BoardTheme theme;

  const ChessBoardRenderer({this.theme = BoardThemeCatalog.classic});

  @override
  Widget build(
    ChessPosition position, {
    core.Move? lastMove,
    List<core.Square> hints = const [],
    core.Square? selected,
  }) {
    final chess = position.toChess();

    core.Square? lastTo;
    switch (lastMove) {
      case core.BoardMove(to: final to):
        lastTo = to;
      case core.DropMove():
      case core.PassMove():
      case core.ResignMove():
      case null:
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest.shortestSide;
        return SizedBox(
          width: boardSize,
          height: boardSize,
          child: Stack(
            children: [
              CustomPaint(
                painter: _ChessSquaresPainter(
                  theme: theme,
                  hints: {for (final s in hints) (s.rank, s.file)},
                  selected: selected == null ? null : (selected.rank, selected.file),
                  lastMove: lastTo == null ? null : (lastTo.rank, lastTo.file),
                ),
                size: Size(boardSize, boardSize),
              ),
              for (var rank = 0; rank < 8; rank++)
                for (var file = 0; file < 8; file++)
                  if (chess.get(algebraicFromSquare(core.Square(file, rank))) case final piece?)
                    Positioned(
                      left: file * boardSize / 8,
                      top: rank * boardSize / 8,
                      width: boardSize / 8,
                      height: boardSize / 8,
                      child: Center(
                        child: Text(
                          _pieceGlyph(piece),
                          style: TextStyle(
                            fontSize: boardSize / 8 * 0.6,
                            fontWeight: FontWeight.bold,
                            color: piece.color == chess_lib.Color.WHITE
                                ? theme.whitePieceColor
                                : theme.blackPieceColor,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  @override
  core.Square? squareAt(
    core.BoardOffset offset,
    core.BoardSize size,
    ChessPosition position,
  ) {
    if (offset.dx < 0 || offset.dx >= size.width || offset.dy < 0 || offset.dy >= size.height) {
      return null;
    }
    final file = (offset.dx / (size.width / 8)).floor().clamp(0, 7);
    final rank = (offset.dy / (size.height / 8)).floor().clamp(0, 7);
    return core.Square(file, rank);
  }

  // Not `const`: PieceType overrides hashCode/==, which Dart disallows for
  // constant map keys (see the same comment on GameBoard._startingCounts
  // in widgets/game_board.dart).
  static final _whiteGlyphs = {
    chess_lib.PieceType.KING: '♔',
    chess_lib.PieceType.QUEEN: '♕',
    chess_lib.PieceType.ROOK: '♖',
    chess_lib.PieceType.BISHOP: '♗',
    chess_lib.PieceType.KNIGHT: '♘',
    chess_lib.PieceType.PAWN: '♙',
  };
  static final _blackGlyphs = {
    chess_lib.PieceType.KING: '♚',
    chess_lib.PieceType.QUEEN: '♛',
    chess_lib.PieceType.ROOK: '♜',
    chess_lib.PieceType.BISHOP: '♝',
    chess_lib.PieceType.KNIGHT: '♞',
    chess_lib.PieceType.PAWN: '♟',
  };

  static String _pieceGlyph(chess_lib.Piece piece) {
    final glyphs = piece.color == chess_lib.Color.WHITE ? _whiteGlyphs : _blackGlyphs;
    return glyphs[piece.type] ?? '?';
  }
}

class _ChessSquaresPainter extends CustomPainter {
  final BoardTheme theme;
  final Set<(int, int)> hints;
  final (int, int)? selected;
  final (int, int)? lastMove;

  _ChessSquaresPainter({
    required this.theme,
    this.hints = const {},
    this.selected,
    this.lastMove,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 8;
    final paint = Paint();

    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final isLight = (rank + file) % 2 == 0;
        if ((rank, file) == selected) {
          paint.color = theme.selectedSquareColor;
        } else {
          paint.color = isLight ? theme.lightSquareColor : theme.darkSquareColor;
        }
        canvas.drawRect(
          Rect.fromLTWH(file * squareSize, rank * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }

    final last = lastMove;
    if (last != null) {
      canvas.drawRect(
        Rect.fromLTWH(last.$2 * squareSize, last.$1 * squareSize, squareSize, squareSize),
        Paint()
          ..color = theme.selectedSquareColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    for (final (rank, file) in hints) {
      canvas.drawCircle(
        Offset(file * squareSize + squareSize / 2, rank * squareSize + squareSize / 2),
        squareSize / 6,
        Paint()..color = theme.legalMoveIndicatorColor,
      );
    }
  }

  @override
  bool shouldRepaint(_ChessSquaresPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.hints != hints ||
      oldDelegate.selected != selected ||
      oldDelegate.lastMove != lastMove;
}
