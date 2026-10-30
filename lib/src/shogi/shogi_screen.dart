import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'shogi_board.dart';
import 'shogi_engine.dart';
import 'shogi_result_screen.dart';

/// Entry screen for the "bonus: play shogi" novelty mode: a fully local,
/// pass-and-play 9x9 shogi game. No AI, no persistence, no online play -
/// see the PR description for the full list of deliberate simplifications.
class ShogiScreen extends StatefulWidget {
  const ShogiScreen({super.key});

  @override
  State<ShogiScreen> createState() => _ShogiScreenState();
}

class _ShogiScreenState extends State<ShogiScreen> {
  late ShogiGame _game;
  ShogiPieceType? _selectedHandPiece;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _game = ShogiGame.initial();
  }

  void _restart() {
    setState(() {
      _game = ShogiGame.initial();
      _selectedHandPiece = null;
      _resultShown = false;
    });
  }

  void _onMove(Square from, Square to) {
    final choosable = _game.canChoosePromotion(from, to.$1);
    if (choosable) {
      _showPromotionDialog(from, to);
      return;
    }
    setState(() {
      _game.applyMove(from, to);
    });
    _maybeShowResult();
  }

  Future<void> _showPromotionDialog(Square from, Square to) async {
    final l10n = AppLocalizations.of(context);
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
    if (!mounted) return;
    setState(() {
      _game.applyMove(from, to, promote: promote ?? false);
    });
    _maybeShowResult();
  }

  void _onDrop(ShogiPieceType type, Square to) {
    setState(() {
      _game.applyDrop(type, to);
      _selectedHandPiece = null;
    });
    _maybeShowResult();
  }

  void _maybeShowResult() {
    if (!_game.isGameOver || _resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pushResult(_game.outcome);
    });
  }

  Future<void> _pushResult(ShogiOutcome outcome) async {
    final again = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShogiResultScreen(outcome: outcome),
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmResign() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true || !mounted) return;
    setState(() {
      _game.outcome =
          _game.senteTurn ? ShogiOutcome.goteWins : ShogiOutcome.senteWins;
    });
    _maybeShowResult();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shogiScreenTitle),
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
              Text(
                l10n.shogiLocalPassAndPlayNote,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildTurnBanner(l10n, theme),
              const SizedBox(height: 12),
              _buildHand(l10n, theme, isSente: false),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final boardSize = constraints.maxWidth.clamp(0, 420).toDouble();
                  return ShogiBoard(
                    game: _game,
                    size: boardSize,
                    enabled: !_game.isGameOver,
                    selectedHandPiece: _selectedHandPiece,
                    onMove: _onMove,
                    onDrop: _onDrop,
                    onHandSelectionConsumed: () =>
                        setState(() => _selectedHandPiece = null),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildHand(l10n, theme, isSente: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurnBanner(AppLocalizations l10n, ThemeData theme) {
    final label = _game.senteTurn ? l10n.shogiSenteTurnLabel : l10n.shogiGoteTurnLabel;
    final inCheck = _game.sideToMoveInCheck;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: inCheck
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        inCheck ? '$label - ${l10n.shogiInCheckLabel}' : label,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHand(AppLocalizations l10n, ThemeData theme, {required bool isSente}) {
    final hand = _game.handFor(isSente);
    if (hand.isEmpty) {
      return SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.shogiHandLabel,
            style: theme.textTheme.labelSmall,
          ),
        ),
      );
    }
    final isCurrentTurn = _game.senteTurn == isSente;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Text(l10n.shogiHandLabel, style: theme.textTheme.labelSmall),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: hand.entries.map((entry) {
                final type = entry.key;
                final count = entry.value;
                final selected = _selectedHandPiece == type && isCurrentTurn;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: !_game.isGameOver && isCurrentTurn
                        ? () => setState(() {
                              _selectedHandPiece = selected ? null : type;
                            })
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary.withOpacity(0.25)
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrentTurn
                              ? theme.colorScheme.outline
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text('${shogiPieceLabel(type)}×$count'),
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
}
