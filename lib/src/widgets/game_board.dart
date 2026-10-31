import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../l10n/app_localizations.dart';
import '../models/board_theme.dart';
import '../services/attack_map_service.dart';
import 'captured_pieces.dart';
import 'piece_glyph.dart';

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
    this.showAttackMap = false,
    this.flipped = false,
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

  /// When true, draws a tactical-tension overlay on top of the board:
  /// every square tints by which side(s) attack/defend it and shows a
  /// small attacker-count badge per side. Computed fresh from
  /// [gameState] on every build via [AttackMapService] - cheap enough
  /// (a single pass over the 32-or-fewer occupied squares) that there's
  /// no need to cache it outside this widget.
  final bool showAttackMap;

  /// When true, renders the board rotated 180° so the player's own back
  /// rank is at the bottom (standard "playing as Black" orientation,
  /// matching every real chess app/site). When false (the default), the
  /// board always shows White's perspective (rank 8 at top, rank 1 at
  /// bottom, files a-h left to right) regardless of which color is
  /// actually playing - correct for White, wrong for Black. Callers that
  /// let the human choose to play Black should pass `flipped: true` in
  /// that case so the player always sees their own pieces at the bottom.
  final bool flipped;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  String? _selectedSquare;
  List<String> _availableMoves = [];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Captured pieces display
          if (widget.showMaterial)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  ? l10n.boardWhiteToMove
                  : l10n.boardBlackToMove,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.gameState.turn == chess_lib.Color.WHITE
                        ? Colors.grey[300]
                        : Colors.grey[700],
                  ),
            ),
          ),

          // Chess board - minimal horizontal padding so the board uses as
          // much of the available screen width as possible (previously
          // 16px on each side made the board noticeably smaller than it
          // needed to be, on top of callers' own outer padding).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                      label: Text(l10n.boardUndo),
                    ),
                  if (widget.onResign != null)
                    ElevatedButton.icon(
                      onPressed: widget.onResign,
                      icon: const Icon(Icons.flag),
                      label: Text(l10n.cpuResign),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  if (widget.onDraw != null)
                    ElevatedButton.icon(
                      onPressed: widget.onDraw,
                      icon: const Icon(Icons.handshake),
                      label: Text(l10n.boardOfferDraw),
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
        title: Text(AppLocalizations.of(context).boardPromoteTitle),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['q', 'r', 'b', 'n'].map((promotion) {
            final l10n = AppLocalizations.of(context);
            final labels = {
              'q': l10n.boardQueen,
              'r': l10n.boardRook,
              'b': l10n.boardBishop,
              'n': l10n.boardKnight,
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
                        flipped: widget.flipped,
                        attackMap: widget.showAttackMap
                            ? AttackMapService.compute(widget.gameState)
                            : null,
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
                              child: PieceGlyph(
                                type: piece.type.name,
                                isWhite: piece.color == chess_lib.Color.WHITE,
                                fontSize: squareSize * 0.6,
                                whiteColor: widget.theme.whitePieceColor,
                                blackColor: widget.theme.blackPieceColor,
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

  /// Maps a (rank, file) grid position - rank 0 = top row, file 0 = left
  /// column, as iterated everywhere in this widget (rendering, tap
  /// hit-testing, coordinate labels) - to its algebraic square name.
  ///
  /// Not flipped (White's perspective, the default): top row is rank 8,
  /// left column is file a - so rank index 0 -> rank 8 (`8 - rank`) and
  /// file index 0 -> file a (`'a' + file`).
  ///
  /// Flipped (Black's perspective, [GameBoard.flipped]): the whole board
  /// is rotated 180°, so top row is rank 1 (`1 + rank`) AND left column
  /// is file h (`'a' + (7 - file)`) - both axes mirror, not just one,
  /// matching how every real chess app flips the board for the Black
  /// player. Every caller of this method (piece placement, tap
  /// hit-testing in `_buildBoard`, square-coloring/highlight/attack-map
  /// painting and the coordinate labels in `_GameBoardPainter`) shares
  /// this single mapping, so flipping is automatically consistent across
  /// all of them.
  String _squareFromIndices(int rank, int file) {
    final fileIndex = widget.flipped ? 7 - file : file;
    final rankNumber = widget.flipped ? 1 + rank : 8 - rank;
    return String.fromCharCode('a'.codeUnitAt(0) + fileIndex) +
        rankNumber.toString();
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
    this.flipped = false,
    this.attackMap,
  });
  final double size;
  final BoardTheme theme;
  final String? selectedSquare;
  final List<String> legalMoveSquares;
  final bool showCoordinates;

  /// Mirrors [GameBoard.flipped] - must use the exact same (rank, file)
  /// -> algebraic-square mapping as `_GameBoardState._squareFromIndices`
  /// so that `selectedSquare`/`legalMoveSquares`/`attackMap` (all keyed
  /// by algebraic square name computed there) land on the same visual
  /// squares this painter draws.
  final bool flipped;

  /// Per-square attacker counts from [AttackMapService.compute], or null
  /// when the overlay is off. See [GameBoard.showAttackMap].
  final Map<String, SquareAttackers>? attackMap;

  // Tint colors for the attack-map overlay - deliberately distinct from
  // every color already used elsewhere on this board (selection,
  // legal-move dot, both themes' light/dark squares and piece glyphs)
  // so the overlay reads clearly on top of any [BoardTheme].
  // Slightly muted vs. the original 0xFF2E86DE (a fairly bright, saturated
  // "light blue" that read as too garish/flashy on real devices) - same
  // hue, lower saturation/brightness so it's still clearly blue without
  // being harsh on the board.
  static const _whiteAttackColor = Color(0xFF4A7FA8); // blue (muted)
  static const _blackAttackColor = Color(0xFFE74C3C); // red
  static const _contestedColor = Color(0xFF8E44AD); // purple

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final squareSize = size / 8;
    final paint = Paint();
    final legalMoveSet = legalMoveSquares.toSet();

    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = _squareFromIndices(rank, file);
        final isLight = (rank + file) % 2 == 0;

        var baseColor =
            isLight ? theme.lightSquareColor : theme.darkSquareColor;
        final attackers = attackMap?[square];
        if (attackers != null && !attackers.isEmpty) {
          // Intensity grows with how many pieces attack the square (capped
          // so a heavily-contested square doesn't fully obscure the piece
          // on it), so a square hit by 3 pieces reads as more "hot" than
          // one hit by a single piece.
          final total = attackers.white + attackers.black;
          final intensity = 0.18 + 0.06 * total.clamp(1, 4);
          final tint = attackers.isContested
              ? _contestedColor
              : attackers.white > 0
                  ? _whiteAttackColor
                  : _blackAttackColor;
          baseColor = Color.lerp(baseColor, tint, intensity)!;
        }

        if (square == selectedSquare) {
          paint.color = theme.selectedSquareColor;
        } else if (legalMoveSet.contains(square)) {
          paint.color = baseColor.withOpacity(0.85);
        } else {
          paint.color = baseColor;
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

        if (attackers != null && !attackers.isEmpty) {
          _drawAttackBadges(canvas, file, rank, squareSize, attackers);
        }
      }
    }

    if (showCoordinates) {
      _drawCoordinates(canvas, squareSize);
    }
  }

  /// Draws small per-side attacker-count badges in a square's corners -
  /// white's count top-left, black's bottom-right, each in that side's
  /// overlay tint color so it's legible without needing a legend.
  void _drawAttackBadges(
    Canvas canvas,
    int file,
    int rank,
    double squareSize,
    SquareAttackers attackers,
  ) {
    final badgeRadius = squareSize * 0.15;
    final fontSize = squareSize * 0.2;
    final badgePaint = Paint();
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawBadge(int count, Color color, Offset center) {
      if (count <= 0) return;
      badgePaint.color = color;
      canvas.drawCircle(center, badgeRadius, badgePaint);
      textPainter.text = TextSpan(
        text: '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    final left = file * squareSize;
    final top = rank * squareSize;
    drawBadge(
      attackers.white,
      _whiteAttackColor,
      Offset(left + badgeRadius + 2, top + badgeRadius + 2),
    );
    drawBadge(
      attackers.black,
      _blackAttackColor,
      Offset(
        left + squareSize - badgeRadius - 2,
        top + squareSize - badgeRadius - 2,
      ),
    );
  }

  /// Same (rank, file) -> algebraic mapping as
  /// `_GameBoardState._squareFromIndices` - see that method's doc
  /// comment for the flip rationale.
  String _squareFromIndices(int rank, int file) {
    final fileIndex = flipped ? 7 - file : file;
    final rankNumber = flipped ? 1 + rank : 8 - rank;
    return String.fromCharCode('a'.codeUnitAt(0) + fileIndex) +
        rankNumber.toString();
  }

  void _drawCoordinates(Canvas canvas, double squareSize) {
    // File/rank labels in on-screen left-to-right / top-to-bottom order,
    // flipped along with the board so they keep reading correctly next
    // to the squares they label.
    final files = flipped
        ? ['h', 'g', 'f', 'e', 'd', 'c', 'b', 'a']
        : ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final ranks = flipped
        ? ['1', '2', '3', '4', '5', '6', '7', '8']
        : ['8', '7', '6', '5', '4', '3', '2', '1'];

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
      oldDelegate.showCoordinates != showCoordinates ||
      oldDelegate.flipped != flipped ||
      oldDelegate.attackMap != attackMap;
}
