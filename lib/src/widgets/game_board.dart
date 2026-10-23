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
    this.showCoordinates = true,
    this.premoveColor,
    this.onPremove,
    this.blindfold = false,
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
  final bool showCoordinates;

  /// When true, piece glyphs are not drawn on the board at all - the
  /// player must track the position from memory, same as playing
  /// blindfold chess over the board in person. Square highlighting
  /// (selection/legal-move dots) and tap handling are unaffected, so the
  /// board is still fully playable, just not visually readable.
  final bool blindfold;

  /// When set (and [isPlayerTurn] is false), lets the local player select
  /// and queue a move for their own [premoveColor] pieces during the
  /// opponent's turn - standard in competitive online play (chess.com,
  /// lichess) and previously entirely unsupported: `_handleSquareTap`
  /// unconditionally ignored every tap whenever it wasn't the local
  /// player's turn. Destinations are computed against the CURRENT
  /// position with the side-to-move swapped to [premoveColor] (a
  /// pseudo-legal approximation of "if it were my turn right now"),
  /// since the real post-opponent-move position isn't known yet - the
  /// caller is expected to re-validate (and clear, on rejection) the
  /// queued move once it's actually the player's turn.
  final chess_lib.Color? premoveColor;

  /// Called instead of [onMove] when a move is selected while
  /// [premoveColor] is active - the caller queues it rather than
  /// submitting immediately.
  final Function(String, String, {String? promotion})? onPremove;

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
    final isPremoveMode = !widget.isPlayerTurn && widget.premoveColor != null;
    if (!widget.isPlayerTurn && !isPremoveMode) return;

    final activeColor = isPremoveMode ? widget.premoveColor! : widget.gameState.turn;
    List<String> movesForSquare(String sq) => isPremoveMode
        ? _getPremoveDestinations(sq, activeColor)
        : _getLegalMovesForSquare(sq);

    final piece = _getPieceAt(square);

    if (_selectedSquare == null) {
      // Select piece
      if (piece != null && piece.color == activeColor) {
        setState(() {
          _selectedSquare = square;
          _availableMoves = movesForSquare(square);
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
          _showPromotionDialog(from, to, isPremove: isPremoveMode);
        } else {
          if (isPremoveMode) {
            widget.onPremove?.call(from, to);
          } else {
            widget.onMove?.call(from, to);
          }
          setState(() {
            _selectedSquare = null;
            _availableMoves = [];
          });
        }
      } else {
        // Select different piece
        if (piece != null && piece.color == activeColor) {
          setState(() {
            _selectedSquare = square;
            _availableMoves = movesForSquare(square);
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

  /// Pseudo-legal destinations for [square] as if it were [myColor]'s
  /// turn right now - see [GameBoard.premoveColor]'s doc comment for why
  /// this is an approximation rather than the real future position.
  List<String> _getPremoveDestinations(String square, chess_lib.Color myColor) {
    final fenParts = widget.gameState.fen.split(' ');
    if (fenParts.length < 2) return [];
    fenParts[1] = myColor == chess_lib.Color.WHITE ? 'w' : 'b';
    try {
      final hypothetical = chess_lib.Chess.fromFEN(fenParts.join(' '));
      return hypothetical
          .moves({'asObjects': true})
          .cast<chess_lib.Move>()
          .where((move) => move.fromAlgebraic == square)
          .map((move) => move.toAlgebraic)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _showPromotionDialog(String from, String to, {bool isPremove = false}) {
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
                if (isPremove) {
                  widget.onPremove?.call(from, to, promotion: promotion);
                } else {
                  widget.onMove?.call(from, to, promotion: promotion);
                }
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

  List<chess_lib.Piece> _getWhiteCapturedPieces() =>
      _getCapturedPieces(chess_lib.Color.WHITE);

  List<chess_lib.Piece> _getBlackCapturedPieces() =>
      _getCapturedPieces(chess_lib.Color.BLACK);

  /// Pieces of [color] that have been captured by the opponent so far.
  ///
  /// Previously inferred this from "how many of each piece type are
  /// currently on the board vs. the starting count" - that diff breaks
  /// as soon as any pawn promotes: pawn count drops (looking like a
  /// captured pawn) while the promoted piece's type count rises above
  /// its starting count (a negative "missing" value, silently dropped by
  /// the loop), so a promoted-and-still-alive piece vanished from the
  /// material count entirely while a phantom captured pawn appeared in
  /// its place. Derived from `gameState.history` instead - each
  /// recorded [chess_lib.State.move] already carries the real captured
  /// piece type (`move.captured`, set by the `chess` package itself from
  /// the actual board/en-passant state at the time of the move), so this
  /// is correct regardless of promotions. Uses `gameState.history`
  /// rather than `widget.moveHistory` since several call sites
  /// (online_game_screen.dart) never pass the latter at all.
  List<chess_lib.Piece> _getCapturedPieces(chess_lib.Color color) {
    final captured = <chess_lib.Piece>[];
    final opponent = color == chess_lib.Color.WHITE
        ? chess_lib.Color.BLACK
        : chess_lib.Color.WHITE;

    for (final state in widget.gameState.history) {
      final move = state.move;
      // A capturing move is made BY the opponent (move.color == opponent)
      // and takes one of [color]'s own pieces.
      if (move.color == opponent && move.captured != null) {
        captured.add(chess_lib.Piece(move.captured!, color));
      }
    }

    return captured;
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
                        showCoordinates: widget.showCoordinates,
                      ),
                      size: Size(boardSize, boardSize),
                    ),
                    if (!widget.blindfold)
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
    this.showCoordinates = true,
  });
  final double size;
  final BoardTheme theme;
  final String? selectedSquare;
  final List<String> legalMoveSquares;
  final bool showCoordinates;

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

    if (showCoordinates) {
      _drawCoordinates(canvas, squareSize);
    }
  }

  void _drawCoordinates(Canvas canvas, double squareSize) {
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final fontSize = squareSize * 0.15;
    const padding = 3.0;

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
        Offset(padding, i * squareSize + padding),
      );
    }
  }

  @override
  bool shouldRepaint(_GameBoardPainter oldDelegate) =>
      oldDelegate.size != size ||
      oldDelegate.theme != theme ||
      oldDelegate.selectedSquare != selectedSquare ||
      oldDelegate.legalMoveSquares != legalMoveSquares ||
      oldDelegate.showCoordinates != showCoordinates;
}
