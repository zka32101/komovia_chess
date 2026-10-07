import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../models/board_theme.dart';
import '../services/chess_engine_service.dart';

typedef OnMoveMade = void Function(String from, String to);

/// Chess board widget with piece rendering and interaction
class ChessBoard extends StatefulWidget {
  const ChessBoard({
    required this.engine,
    Key? key,
    this.onMoveMade,
    this.size = 350,
    this.enabled = true,
    this.showCoordinates = true,
    this.theme = BoardThemeCatalog.classic,
  }) : super(key: key);
  final ChessEngineService engine;
  final OnMoveMade? onMoveMade;
  final double size;
  final bool enabled;
  final bool showCoordinates;

  /// Visual theme for squares/pieces. Defaults to [BoardThemeCatalog.classic]
  /// (the board's original hardcoded colors) when omitted, so every existing
  /// caller keeps rendering exactly as before.
  final BoardTheme theme;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  String? _selectedSquare;
  List<String> _legalMovesForSelected = [];

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.enabled ? _handleTap : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Board background
              CustomPaint(
                painter: _ChessBoardPainter(
                  size: widget.size,
                  showCoordinates: widget.showCoordinates,
                  theme: widget.theme,
                ),
                size: Size(widget.size, widget.size),
              ),

              // Legal move indicators
              if (_selectedSquare != null && widget.enabled)
                _buildLegalMoveIndicators(),

              // Pieces
              _buildPieces(),
            ],
          ),
        ),
      );

  Widget _buildLegalMoveIndicators() => Stack(
        children: _legalMovesForSelected.map((square) {
          final indices = ChessEngineService.squareToIndices(square);
          final squareSize = widget.size / 8;
          final offsetX = indices['file']! * squareSize;
          final offsetY = indices['rank']! * squareSize;

          return Positioned(
            left: offsetX,
            top: offsetY,
            child: Container(
              width: squareSize,
              height: squareSize,
              decoration: BoxDecoration(
                color: widget.theme.legalMoveIndicatorColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(squareSize / 2),
              ),
              child: Center(
                child: Container(
                  width: squareSize / 3,
                  height: squareSize / 3,
                  decoration: BoxDecoration(
                    color: widget.theme.legalMoveIndicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _buildPieces() {
    final squareSize = widget.size / 8;
    final board = widget.engine.getBoard();
    final pieces = <Widget>[];

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = board[rank][file];
        if (piece == null) continue;

        final square = ChessEngineService.indicesToSquare(rank, file);
        final isSelected = _selectedSquare == square;

        pieces.add(
          Positioned(
            left: file * squareSize,
            top: rank * squareSize,
            child: GestureDetector(
              onTap: widget.enabled ? () => _selectPiece(square) : null,
              child: Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.theme.selectedSquareColor.withOpacity(0.5)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    _getPieceSymbol(piece),
                    style: TextStyle(
                      fontSize: squareSize * 0.6,
                      fontWeight: FontWeight.bold,
                      color: piece.color == chess_lib.Color.WHITE
                          ? widget.theme.whitePieceColor
                          : widget.theme.blackPieceColor,
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

  void _selectPiece(String square) {
    final piece = widget.engine.getPieceAt(square);

    // If no piece or wrong color, clear selection
    if (piece == null) {
      setState(() {
        _selectedSquare = null;
        _legalMovesForSelected = [];
      });
      return;
    }

    // Check if piece belongs to current player
    final isWhitePiece = piece.color == chess_lib.Color.WHITE;
    final isWhiteTurn = widget.engine.isWhiteTurn();

    if (isWhitePiece != isWhiteTurn) {
      setState(() {
        _selectedSquare = null;
        _legalMovesForSelected = [];
      });
      return;
    }

    // If clicking the same piece, deselect
    if (_selectedSquare == square) {
      setState(() {
        _selectedSquare = null;
        _legalMovesForSelected = [];
      });
      return;
    }

    // Get legal moves for this square
    final legalMoves = widget.engine.getLegalMovesForSquare(square);
    final moveSquares = legalMoves.map((m) => m.toAlgebraic).toList();

    setState(() {
      _selectedSquare = square;
      _legalMovesForSelected = moveSquares;
    });
  }

  void _handleTap(TapDownDetails details) {
    if (!widget.enabled) return;

    final squareSize = widget.size / 8;
    final file = (details.localPosition.dx / squareSize).floor();
    final rank = (details.localPosition.dy / squareSize).floor();

    if (file < 0 || file > 7 || rank < 0 || rank > 7) return;

    final square = ChessEngineService.indicesToSquare(rank, file);

    // If no piece is selected, select one
    if (_selectedSquare == null) {
      _selectPiece(square);
      return;
    }

    // If clicking the same square, deselect
    if (_selectedSquare == square) {
      _selectPiece(square);
      return;
    }

    // If the clicked square is a legal move, make the move
    if (_legalMovesForSelected.contains(square)) {
      final success = widget.engine.makeMove(_selectedSquare!, square);

      if (success) {
        widget.onMoveMade?.call(_selectedSquare!, square);
        setState(() {
          _selectedSquare = null;
          _legalMovesForSelected = [];
        });
      }
    } else {
      // Select the new square/piece
      _selectPiece(square);
    }
  }

  String _getPieceSymbol(chess_lib.Piece piece) {
    // Not `const`: PieceType overrides hashCode/==, which Dart disallows
    // for constant map keys.
    final whitePieces = {
      chess_lib.PieceType.KING: '♔',
      chess_lib.PieceType.QUEEN: '♕',
      chess_lib.PieceType.ROOK: '♖',
      chess_lib.PieceType.BISHOP: '♗',
      chess_lib.PieceType.KNIGHT: '♘',
      chess_lib.PieceType.PAWN: '♙',
    };

    final blackPieces = {
      chess_lib.PieceType.KING: '♚',
      chess_lib.PieceType.QUEEN: '♛',
      chess_lib.PieceType.ROOK: '♜',
      chess_lib.PieceType.BISHOP: '♝',
      chess_lib.PieceType.KNIGHT: '♞',
      chess_lib.PieceType.PAWN: '♟',
    };

    final pieceMap =
        piece.color == chess_lib.Color.WHITE ? whitePieces : blackPieces;
    return pieceMap[piece.type] ?? '?';
  }
}

/// Custom painter for chess board
class _ChessBoardPainter extends CustomPainter {
  _ChessBoardPainter({
    required this.size,
    required this.showCoordinates,
    required this.theme,
  });
  final double size;
  final bool showCoordinates;
  final BoardTheme theme;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final squareSize = size / 8;
    final paint = Paint();

    // Draw squares
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final isLight = (rank + file) % 2 == 0;
        paint.color = isLight ? theme.lightSquareColor : theme.darkSquareColor;

        canvas.drawRect(
          Rect.fromLTWH(
            file * squareSize,
            rank * squareSize,
            squareSize,
            squareSize,
          ),
          paint,
        );
      }
    }

    // Draw coordinates if enabled
    if (showCoordinates) {
      _drawCoordinates(canvas, squareSize);
    }
  }

  void _drawCoordinates(Canvas canvas, double squareSize) {
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final fontSize = squareSize * 0.15;
    const padding = 3.0;

    // File labels (a-h)
    for (int i = 0; i < 8; i++) {
      textPainter.text = TextSpan(
        text: files[i],
        style: TextStyle(
          color: (i % 2 == 0) ? Colors.grey.shade700 : Colors.grey.shade400,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          i * squareSize + squareSize - textPainter.width - padding,
          size - squareSize + padding,
        ),
      );
    }

    // Rank labels (8-1)
    for (int i = 0; i < 8; i++) {
      textPainter.text = TextSpan(
        text: ranks[i],
        style: TextStyle(
          color: (i % 2 == 0) ? Colors.grey.shade700 : Colors.grey.shade400,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          padding,
          i * squareSize + padding,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_ChessBoardPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.showCoordinates != showCoordinates ||
      oldDelegate.theme != theme;
}
