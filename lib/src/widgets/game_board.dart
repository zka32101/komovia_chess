import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../models/board_theme.dart';
import 'captured_pieces.dart';

/// Game container with board and controls
class GameBoard extends StatefulWidget {
  const GameBoard({
    required this.gameState,
    Key? key,
    this.onMove,
    this.onUndo,
    this.onResign,
    this.onDraw,
    this.moveHistory = const [],
    this.showMaterial = true,
    this.isPlayerTurn = true,
    this.theme = BoardThemeCatalog.classic,
  }) : super(key: key);
  final chess_lib.Chess gameState;
  final Function(String, String, {String? promotion})? onMove;
  final Function()? onUndo;
  final Function()? onResign;
  final Function()? onDraw;
  final List<chess_lib.Move> moveHistory;
  final bool showMaterial;
  final bool isPlayerTurn;
  final BoardTheme theme;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  String? _selectedSquare;
  List<String> _availableMoves = [];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Captured pieces display
          if (widget.showMaterial)
            Padding(
              padding: const EdgeInsets.all(16),
              child: CapturedPieces(
                whiteCapturedPieces: _getWhiteCapturedPieces(),
                blackCapturedPieces: _getBlackCapturedPieces(),
              ),
            ),

          // Turn indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.gameState.turn == chess_lib.Color.WHITE
                  ? 'White to Move'
                  : 'Black to Move',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.gameState.turn == chess_lib.Color.WHITE
                        ? Colors.grey[300]
                        : Colors.grey[700],
                  ),
            ),
          ),

          // Chess board
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBoard(),
          ),

          // Game controls
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.onUndo != null)
                    ElevatedButton.icon(
                      onPressed:
                          widget.moveHistory.isEmpty ? null : widget.onUndo,
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                  if (widget.onResign != null)
                    ElevatedButton.icon(
                      onPressed: widget.onResign,
                      icon: const Icon(Icons.flag),
                      label: const Text('Resign'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  if (widget.onDraw != null)
                    ElevatedButton.icon(
                      onPressed: widget.onDraw,
                      icon: const Icon(Icons.handshake),
                      label: const Text('Offer Draw'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleSquareTap(String square) {
    if (!widget.isPlayerTurn) return;

    final piece = _getPieceAt(square);

    if (_selectedSquare == null) {
      // Select piece
      if (piece != null && piece.color == widget.gameState.turn) {
        setState(() {
          _selectedSquare = square;
          _availableMoves = _getLegalMovesForSquare(square);
        });
      }
    } else {
      // Attempt move or re-select
      if (square == _selectedSquare) {
        // Deselect
        setState(() {
          _selectedSquare = null;
          _availableMoves = [];
        });
      } else if (_availableMoves.contains(square)) {
        // Make move
        final from = _selectedSquare!;
        final to = square;

        // Handle promotion
        final piece = _getPieceAt(from);
        if (piece?.type == chess_lib.PieceType.PAWN &&
            ((piece?.color == chess_lib.Color.WHITE && to[1] == '8') ||
                (piece?.color == chess_lib.Color.BLACK && to[1] == '1'))) {
          // Show promotion dialog
          _showPromotionDialog(from, to);
        } else {
          widget.onMove?.call(from, to);
          setState(() {
            _selectedSquare = null;
            _availableMoves = [];
          });
        }
      } else {
        // Select different piece
        if (piece != null && piece.color == widget.gameState.turn) {
          setState(() {
            _selectedSquare = square;
            _availableMoves = _getLegalMovesForSquare(square);
          });
        } else {
          setState(() {
            _selectedSquare = null;
            _availableMoves = [];
          });
        }
      }
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote Pawn'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['q', 'r', 'b', 'n'].map((promotion) {
            final labels = {
              'q': 'Queen',
              'r': 'Rook',
              'b': 'Bishop',
              'n': 'Knight',
            };
            return ElevatedButton(
              onPressed: () {
                widget.onMove?.call(from, to, promotion: promotion);
                Navigator.pop(context);
                setState(() {
                  _selectedSquare = null;
                  _availableMoves = [];
                });
              },
              child: Text(labels[promotion] ?? promotion),
            );
          }).toList(),
        ),
      ),
    );
  }

  chess_lib.Piece? _getPieceAt(String square) {
    try {
      return widget.gameState.get(square);
    } catch (e) {
      return null;
    }
  }

  List<String> _getLegalMovesForSquare(String square) => widget.gameState
      .moves({'asObjects': true})
      .cast<chess_lib.Move>()
      .where((move) => move.fromAlgebraic == square)
      .map((move) => move.toAlgebraic)
      .toList();

  // Not `const`: PieceType overrides hashCode/==, which Dart disallows for
  // constant map keys.
  static final Map<chess_lib.PieceType, int> _startingCounts = {
    chess_lib.PieceType.PAWN: 8,
    chess_lib.PieceType.KNIGHT: 2,
    chess_lib.PieceType.BISHOP: 2,
    chess_lib.PieceType.ROOK: 2,
    chess_lib.PieceType.QUEEN: 1,
  };

  List<chess_lib.Piece> _getWhiteCapturedPieces() =>
      _getCapturedPieces(chess_lib.Color.WHITE);

  List<chess_lib.Piece> _getBlackCapturedPieces() =>
      _getCapturedPieces(chess_lib.Color.BLACK);

  List<chess_lib.Piece> _getCapturedPieces(chess_lib.Color color) {
    final captured = <chess_lib.Piece>[];
    final onBoard = _countPieces(color);

    _startingCounts.forEach((type, startingCount) {
      final missing = startingCount - (onBoard[type] ?? 0);
      for (var i = 0; i < missing; i++) {
        captured.add(chess_lib.Piece(type, color));
      }
    });

    return captured;
  }

  Map<chess_lib.PieceType, int> _countPieces(chess_lib.Color color) {
    final counts = <chess_lib.PieceType, int>{};
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (final file in files) {
      for (var rank = 1; rank <= 8; rank++) {
        final piece = widget.gameState.get('$file$rank');
        if (piece != null && piece.color == color) {
          counts[piece.type] = (counts[piece.type] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  Widget _buildBoard() => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = constraints.maxWidth;
            final squareSize = boardSize / 8;

            return GestureDetector(
              onTapDown: (details) {
                final file = (details.localPosition.dx / squareSize).floor();
                final rank = (details.localPosition.dy / squareSize).floor();
                if (file < 0 || file > 7 || rank < 0 || rank > 7) return;
                _handleSquareTap(_squareFromIndices(rank, file));
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: _GameBoardPainter(
                        size: boardSize,
                        theme: widget.theme,
                        selectedSquare: _selectedSquare,
                        legalMoveSquares: _availableMoves,
                      ),
                      size: Size(boardSize, boardSize),
                    ),
                    for (var rank = 0; rank < 8; rank++)
                      for (var file = 0; file < 8; file++)
                        if (widget.gameState.get(_squareFromIndices(rank, file))
                            case final piece?)
                          Positioned(
                            left: file * squareSize,
                            top: rank * squareSize,
                            width: squareSize,
                            height: squareSize,
                            child: Center(
                              child: Text(
                                _pieceSymbol(piece),
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
                  ],
                ),
              ),
            );
          },
        ),
      );

  String _squareFromIndices(int rank, int file) =>
      String.fromCharCode('a'.codeUnitAt(0) + file) + (8 - rank).toString();

  String _pieceSymbol(chess_lib.Piece piece) {
    final whiteSymbols = {
      chess_lib.PieceType.KING: '♔',
      chess_lib.PieceType.QUEEN: '♕',
      chess_lib.PieceType.ROOK: '♖',
      chess_lib.PieceType.BISHOP: '♗',
      chess_lib.PieceType.KNIGHT: '♘',
      chess_lib.PieceType.PAWN: '♙',
    };
    final blackSymbols = {
      chess_lib.PieceType.KING: '♚',
      chess_lib.PieceType.QUEEN: '♛',
      chess_lib.PieceType.ROOK: '♜',
      chess_lib.PieceType.BISHOP: '♝',
      chess_lib.PieceType.KNIGHT: '♞',
      chess_lib.PieceType.PAWN: '♟',
    };
    final symbols =
        piece.color == chess_lib.Color.WHITE ? whiteSymbols : blackSymbols;
    return symbols[piece.type] ?? '?';
  }
}

/// Paints the board squares plus selection/legal-move highlights for
/// [GameBoard]. Kept separate from `chess_board.dart`'s painter since that
/// one is private to its own library and this widget is driven by a raw
/// `chess_lib.Chess` rather than a `ChessEngineService`.
class _GameBoardPainter extends CustomPainter {
  _GameBoardPainter({
    required this.size,
    required this.theme,
    required this.selectedSquare,
    required this.legalMoveSquares,
  });
  final double size;
  final BoardTheme theme;
  final String? selectedSquare;
  final List<String> legalMoveSquares;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final squareSize = size / 8;
    final paint = Paint();
    final legalMoveSet = legalMoveSquares.toSet();

    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = String.fromCharCode('a'.codeUnitAt(0) + file) +
            (8 - rank).toString();
        final isLight = (rank + file) % 2 == 0;

        if (square == selectedSquare) {
          paint.color = theme.selectedSquareColor;
        } else if (legalMoveSet.contains(square)) {
          paint.color =
              (isLight ? theme.lightSquareColor : theme.darkSquareColor)
                  .withOpacity(0.85);
        } else {
          paint.color =
              isLight ? theme.lightSquareColor : theme.darkSquareColor;
        }

        canvas.drawRect(
          Rect.fromLTWH(
            file * squareSize,
            rank * squareSize,
            squareSize,
            squareSize,
          ),
          paint,
        );

        if (legalMoveSet.contains(square)) {
          paint.color = theme.legalMoveIndicatorColor;
          canvas.drawCircle(
            Offset(
              file * squareSize + squareSize / 2,
              rank * squareSize + squareSize / 2,
            ),
            squareSize / 6,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GameBoardPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.theme != theme ||
      oldDelegate.selectedSquare != selectedSquare ||
      oldDelegate.legalMoveSquares != legalMoveSquares;
}
