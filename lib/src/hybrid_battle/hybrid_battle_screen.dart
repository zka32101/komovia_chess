import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shogi/shogi_engine.dart' show ShogiPiece;
import '../widgets/piece_glyph.dart';
import 'hybrid_battle_engine.dart';

/// Local pass-and-play screen for the "将棋駒 vs チェス駒" event mode. No AI,
/// no persistence, no online play (same scope as the bonus shogi mode).
class HybridBattleScreen extends StatefulWidget {
  const HybridBattleScreen({super.key});

  @override
  State<HybridBattleScreen> createState() => _HybridBattleScreenState();
}

class _HybridBattleScreenState extends State<HybridBattleScreen> {
  HybridBattleGame _game = HybridBattleGame.initial();
  HSquare? _selected;
  ShogiPieceType? _selectedDrop;
  List<HybridMove> _candidates = [];
  bool _resultShown = false;

  void _restart() => setState(() {
        _game = HybridBattleGame.initial();
        _selected = null;
        _selectedDrop = null;
        _candidates = [];
        _resultShown = false;
      });

  void _clearSelection() {
    _selected = null;
    _selectedDrop = null;
    _candidates = [];
  }

  Future<void> _onSquareTapped(HSquare sq) async {
    if (_game.isGameOver) return;
    final matching = _candidates.where((m) => m.to == sq).toList();
    if (matching.isNotEmpty) {
      final move = await _chooseVariant(matching);
      if (move == null || !mounted) return;
      setState(() {
        _game.applyMove(move);
        _clearSelection();
      });
      _maybeShowResult();
      return;
    }
    final piece = _game.board[sq.$1][sq.$2];
    setState(() {
      if (piece != null && piece.army == _game.sideToMove && _selected != sq) {
        _selected = sq;
        _selectedDrop = null;
        _candidates = _game.legalMovesFrom(sq.$1, sq.$2);
      } else {
        _clearSelection();
      }
    });
  }

  void _onHandTapped(ShogiPieceType type) {
    setState(() {
      if (_selectedDrop == type) {
        _clearSelection();
        return;
      }
      _selected = null;
      _selectedDrop = type;
      _candidates = _game
          .legalDropSquaresFor(type)
          .map((s) => HybridMove(to: s, drop: type))
          .toList();
    });
  }

  /// Several legal moves to one square = a promotion choice.
  Future<HybridMove?> _chooseVariant(List<HybridMove> moves) async {
    if (moves.length == 1) return moves.single;
    final l10n = AppLocalizations.of(context);
    if (moves.first.chessPromotion != null) {
      return showDialog<HybridMove>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.hybridChessPromotionTitle),
          children: moves
              .map((m) => SimpleDialogOption(
                    onPressed: () => Navigator.of(ctx).pop(m),
                    child: SizedBox(
                      height: 40,
                      child: PieceGlyph(
                        type: chessKindLetter(m.chessPromotion!),
                        isWhite: true,
                        fontSize: 32,
                        whiteColor: const Color(0xFFF8F8F8),
                        blackColor: Colors.black,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    }
    final promote = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shogiPromotionDialogTitle),
        content: Text(l10n.shogiPromotionDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.shogiDoNotPromoteButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.shogiPromoteButton),
          ),
        ],
      ),
    );
    if (promote == null) return null;
    return moves.firstWhere((m) => m.shogiPromote == promote);
  }

  void _maybeShowResult() {
    if (!_game.isGameOver || _resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final title = switch (_game.outcome) {
        HybridOutcome.chessWins => l10n.hybridResultChessWins,
        HybridOutcome.shogiWins => l10n.hybridResultShogiWins,
        _ => l10n.hybridResultDraw,
      };
      final reason = switch (_game.endReason) {
        HybridEndReason.checkmate => l10n.hybridReasonCheckmate,
        HybridEndReason.stalemate => l10n.hybridReasonStalemate,
        HybridEndReason.noLegalMoves => l10n.hybridReasonNoLegalMoves,
        HybridEndReason.resignation => l10n.hybridReasonResignation,
        HybridEndReason.none => '',
      };
      final again = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(reason),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.shogiBackToHomeButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.shogiPlayAgainButton),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (again == true) {
        _restart();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _confirmResign() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shogiResignConfirmTitle),
        content: Text(l10n.shogiResignConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.shogiResignButton),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _game.resign(_game.sideToMove));
    _maybeShowResult();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final inCheck = _game.sideToMoveInCheck;
    final turn = _game.chessToMove ? l10n.hybridChessTurnLabel : l10n.hybridShogiTurnLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hybridScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: l10n.shogiResignButton,
            onPressed: _game.isGameOver ? null : _confirmResign,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(l10n.hybridRulesNote,
                  style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: inCheck
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  inCheck ? '$turn - ${l10n.shogiInCheckLabel}' : turn,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              _buildHand(l10n, theme),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final size = c.maxWidth.clamp(0, 420).toDouble();
                return _buildBoard(theme, size);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHand(AppLocalizations l10n, ThemeData theme) {
    final hand = _game.shogiHand;
    final canDrop = !_game.isGameOver && !_game.chessToMove;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Text(l10n.shogiHandLabel, style: theme.textTheme.labelSmall),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: hand.entries.map((e) {
                final selected = _selectedDrop == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    key: ValueKey('hybrid-hand-${e.key.name}'),
                    onTap: canDrop ? () => _onHandTapped(e.key) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary.withOpacity(0.25)
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Text('${shogiPieceLabel(e.key)}×${e.value}'),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(ThemeData theme, double size) {
    final sq = size / 8;
    final targets = _candidates.map((m) => m.to).toSet();
    return SizedBox(
      width: size,
      height: size,
      child: GridView.count(
        crossAxisCount: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(64, (i) {
          final r = i ~/ 8, c = i % 8;
          final piece = _game.board[r][c];
          final light = (r + c).isEven;
          return GestureDetector(
            key: ValueKey('hybrid-sq-$r-$c'),
            onTap: () => _onSquareTapped((r, c)),
            child: Container(
              color: _selected == (r, c)
                  ? theme.colorScheme.primary.withOpacity(0.45)
                  : (light ? const Color(0xFFF0D9B5) : const Color(0xFFB58863)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (piece != null) _buildPiece(piece, sq),
                  if (targets.contains((r, c)))
                    Container(
                      width: sq * 0.3,
                      height: sq * 0.3,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPiece(HybridPiece piece, double sq) {
    if (piece.isChess) {
      return PieceGlyph(
        type: chessKindLetter(piece.chess!),
        isWhite: true,
        fontSize: sq * 0.75,
        whiteColor: const Color(0xFFF8F8F8),
        blackColor: Colors.black,
      );
    }
    // Same kanji-tile rendering as the bonus shogi mode; the shogi army
    // sits at the top, so its labels are rotated to face that player.
    final sp = ShogiPiece(piece.shogi!, false);
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.brown.shade400),
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: 3.14159,
        child: Text(
          sp.label,
          style: TextStyle(
            fontSize: sq * 0.46,
            fontWeight: FontWeight.bold,
            color: sp.isPromoted ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
