import 'package:flutter/material.dart';

import 'shogi_engine.dart';

/// Callback for a completed board move (not a drop). [promote] is only
/// meaningful when the caller offered a promotion choice.
typedef OnShogiMove = void Function(Square from, Square to);
typedef OnShogiDrop = void Function(ShogiPieceType type, Square to);

/// A minimal 9x9 shogi board widget, following the same tap-to-select /
/// tap-to-move convention as this app's [ChessBoard] widget. Pieces are
/// rendered as simple kanji-labeled wedges (a deliberate simplification -
/// see the PR description - rather than full piece artwork), oriented so a
/// gote (後手) piece's label is upside-down, matching how a real shogi board
/// looks to the player sitting opposite.
class ShogiBoard extends StatefulWidget {
  const ShogiBoard({
    required this.game,
    super.key,
    this.onMove,
    this.onDrop,
    this.size = 360,
    this.enabled = true,
    this.selectedHandPiece,
    this.onHandSelectionConsumed,
  });

  final ShogiGame game;
  final OnShogiMove? onMove;
  final OnShogiDrop? onDrop;
  final double size;
  final bool enabled;

  /// When non-null, the board is in "drop mode": a tap on an empty, legal
  /// square drops this piece type instead of moving a selected board piece.
  /// The screen is responsible for clearing the selection (e.g. after a
  /// successful drop) via [onHandSelectionConsumed].
  final ShogiPieceType? selectedHandPiece;
  final VoidCallback? onHandSelectionConsumed;

  @override
  State<ShogiBoard> createState() => _ShogiBoardState();
}

class _ShogiBoardState extends State<ShogiBoard> {
  Square? _selected;
  List<Square> _legalDestinations = [];

  @override
  void didUpdateWidget(ShogiBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      _selected = null;
      _legalDestinations = [];
    }
    if (widget.selectedHandPiece != null) {
      // Entering drop mode clears any in-progress board-piece selection.
      _selected = null;
      _legalDestinations = widget.game.legalDropSquaresFor(widget.selectedHandPiece!);
    } else if (oldWidget.selectedHandPiece != null) {
      _legalDestinations = [];
    }
  }

  double get _squareSize => widget.size / 9;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: widget.enabled ? _handleTap : null,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFFE8C988), // wood-toned board, like real shogiban.
          border: Border.all(color: Colors.brown.shade700, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            CustomPaint(
              painter: _ShogiGridPainter(size: widget.size),
              size: Size(widget.size, widget.size),
            ),
            if (_legalDestinations.isNotEmpty) _buildDestinationMarkers(theme),
            _buildPieces(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationMarkers(ThemeData theme) => Stack(
        children: _legalDestinations.map((dest) {
          final left = dest.$2 * _squareSize;
          final top = dest.$1 * _squareSize;
          return Positioned(
            left: left,
            top: top,
            child: Container(
              width: _squareSize,
              height: _squareSize,
              alignment: Alignment.center,
              child: Container(
                width: _squareSize * 0.32,
                height: _squareSize * 0.32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _buildPieces(ThemeData theme) {
    final pieces = <Widget>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = widget.game.board[r][c];
        if (piece == null) continue;
        final isSelected = _selected == (r, c);
        pieces.add(
          Positioned(
            left: c * _squareSize,
            top: r * _squareSize,
            width: _squareSize,
            height: _squareSize,
            child: GestureDetector(
              onTap: widget.enabled ? () => _onSquareTapped((r, c)) : null,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.35)
                      : (piece.isSente
                          ? Colors.amber.shade100
                          : Colors.amber.shade50),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.brown.shade400, width: 1),
                ),
                child: Center(
                  // Gote's pieces are rendered upside-down, same visual
                  // convention a real shogiban uses so both sides can read
                  // their own pieces right-side-up from their own side.
                  child: Transform.rotate(
                    angle: piece.isSente ? 0 : 3.14159,
                    child: Text(
                      piece.label,
                      style: TextStyle(
                        fontSize: _squareSize * 0.46,
                        fontWeight: FontWeight.bold,
                        color: piece.isPromoted
                            ? Colors.red.shade700
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Stack(children: pieces);
  }

  void _handleTap(TapDownDetails details) {
    final col = (details.localPosition.dx / _squareSize).floor();
    final row = (details.localPosition.dy / _squareSize).floor();
    if (row < 0 || row > 8 || col < 0 || col > 8) return;
    _onSquareTapped((row, col));
  }

  void _onSquareTapped(Square square) {
    if (!widget.enabled || widget.game.isGameOver) return;

    // Drop mode: any tap on a legal destination drops the selected hand
    // piece; any other tap cancels drop mode (handled by the screen).
    if (widget.selectedHandPiece != null) {
      if (_legalDestinations.contains(square)) {
        widget.onDrop?.call(widget.selectedHandPiece!, square);
        widget.onHandSelectionConsumed?.call();
      }
      return;
    }

    final piece = widget.game.board[square.$1][square.$2];

    if (_selected != null && _legalDestinations.contains(square)) {
      final from = _selected!;
      setState(() {
        _selected = null;
        _legalDestinations = [];
      });
      widget.onMove?.call(from, square);
      return;
    }

    if (piece == null || piece.isSente != widget.game.senteTurn) {
      setState(() {
        _selected = null;
        _legalDestinations = [];
      });
      return;
    }

    if (_selected == square) {
      setState(() {
        _selected = null;
        _legalDestinations = [];
      });
      return;
    }

    setState(() {
      _selected = square;
      _legalDestinations = widget.game.legalMovesFrom(square.$1, square.$2);
    });
  }
}

class _ShogiGridPainter extends CustomPainter {
  _ShogiGridPainter({required this.size});
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final squareSize = size / 9;
    final paint = Paint()
      ..color = Colors.brown.shade800
      ..strokeWidth = 1;
    for (int i = 0; i <= 9; i++) {
      canvas.drawLine(
        Offset(i * squareSize, 0),
        Offset(i * squareSize, size),
        paint,
      );
      canvas.drawLine(
        Offset(0, i * squareSize),
        Offset(size, i * squareSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ShogiGridPainter oldDelegate) => oldDelegate.size != size;
}
