import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/game_analysis.dart';
import '../../models/online_game.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fair_play_provider.dart';
import '../../providers/weakness_analysis_provider.dart';
import '../../services/chess_analysis_service.dart';
import '../../services/move_commentary_service.dart';

/// Shows Stockfish-based per-move analysis for a finished game - see
/// ChessAnalysisService's own doc comment for what "analysis" means here
/// (engine eval classification, not an LLM feature).
class GameAnalysisScreen extends ConsumerStatefulWidget {
  const GameAnalysisScreen({
    required this.moves,
    required this.whitePlayerName,
    required this.blackPlayerName,
    this.startingFen,
    this.gameId,
    this.whitePlayerId,
    this.blackPlayerId,
    Key? key,
  }) : super(key: key);
  final List<GameMove> moves;
  final String whitePlayerName;
  final String blackPlayerName;

  /// The position [moves] were actually played from - null defaults to
  /// ChessAnalysisService.analyzeGame's own standard-array default,
  /// correct for every real online game but not for a CPU game started
  /// from a custom position (see GameReviewScreen's matching doc
  /// comment).
  final String? startingFen;

  /// When provided alongside [whitePlayerId]/[blackPlayerId], the
  /// resulting analysis is saved (best-effort) to the signed-in user's
  /// weakness profile if they played in this game - see
  /// WeaknessAnalysisService. Optional so this screen stays usable
  /// without a real backing game (none of the three are known for a
  /// one-off/offline review).
  final String? gameId;
  final String? whitePlayerId;
  final String? blackPlayerId;

  @override
  ConsumerState<GameAnalysisScreen> createState() => _GameAnalysisScreenState();
}

class _GameAnalysisScreenState extends ConsumerState<GameAnalysisScreen> {
  final _service = ChessAnalysisService();
  GameAnalysis? _result;
  int _done = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _total = widget.moves.length;
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final result = await _service.analyzeGame(
        widget.moves,
        startingFen: widget.startingFen ?? standardStartingFen,
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (mounted) setState(() => _result = result);
      await _recordWeaknessAnalysis(result);
      await _recordFairPlaySignals(result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Best-effort: feeds this analysis into the signed-in user's
  /// cross-game weakness profile (learn_hub_screen.dart's recommendation
  /// card), if this screen was opened for a real game the current user
  /// actually played in.
  Future<void> _recordWeaknessAnalysis(GameAnalysis result) async {
    final gameId = widget.gameId;
    final whiteId = widget.whitePlayerId;
    final blackId = widget.blackPlayerId;
    if (gameId == null || whiteId == null || blackId == null) return;

    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid == null) return;

    // CpuGameScreen's synthetic OnlineGame (see its _showGameReview) uses
    // the literal sentinel 'player'/'cpu' instead of a real uid for its
    // two sides, since there's no second real account in a CPU game -
    // without this branch, every CPU game's analysis silently failed to
    // match either id and was never recorded at all, unlike real online
    // games.
    final bool isWhitePlayer;
    if (uid == whiteId || whiteId == 'player') {
      isWhitePlayer = true;
    } else if (uid == blackId || blackId == 'player') {
      isWhitePlayer = false;
    } else {
      return; // Spectator/analysis of someone else's game - nothing to record.
    }

    await ref.read(weaknessAnalysisServiceProvider).recordGameAnalysis(
          uid: uid,
          gameId: gameId,
          analysis: result,
          isWhitePlayer: isWhitePlayer,
        );
    ref.invalidate(weaknessProfileProvider);
  }

  /// Best-effort: computes and persists a backend-only fair-play review
  /// signal (see FairPlayService) for BOTH real players of this game -
  /// unlike [_recordWeaknessAnalysis], which only records for the
  /// currently signed-in viewer, this isn't gated on who's looking at
  /// the screen, since the signal itself is never shown to either
  /// player and the whole point is to also cover the case where the
  /// viewer is the *other* side (or a moderator re-running analysis).
  ///
  /// Skipped entirely for CpuGameScreen's synthetic games (whiteId or
  /// blackId == the 'player'/'cpu' sentinel - see
  /// `_recordWeaknessAnalysis`'s own comment) - there's no second real
  /// account to flag in a CPU game, so there's nothing to compute this
  /// for.
  Future<void> _recordFairPlaySignals(GameAnalysis result) async {
    final gameId = widget.gameId;
    final whiteId = widget.whitePlayerId;
    final blackId = widget.blackPlayerId;
    if (gameId == null || whiteId == null || blackId == null) return;
    if (whiteId == 'player' || whiteId == 'cpu' || blackId == 'player' || blackId == 'cpu') {
      return;
    }

    final service = ref.read(fairPlayServiceProvider);
    await service.recordGameSignal(
      uid: whiteId,
      gameId: gameId,
      analysis: result,
      isWhitePlayer: true,
    );
    await service.recordGameSignal(
      uid: blackId,
      gameId: gameId,
      analysis: result,
      isWhitePlayer: false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Game Analysis')),
        body: _error != null
            ? Center(child: Text('Analysis failed: $_error'))
            : _result == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_total == 0
                            ? 'Analyzing...'
                            : 'Analyzing move $_done of $_total...'),
                      ],
                    ),
                  )
                : _buildResult(_result!),
      );

  Widget _buildResult(GameAnalysis analysis) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAccuracyCard(
                  widget.whitePlayerName,
                  analysis.whiteAccuracy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccuracyCard(
                  widget.blackPlayerName,
                  analysis.blackAccuracy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (analysis.blunders.isNotEmpty) ...[
            Text(
              'Blunders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final m in analysis.blunders) _buildMoveTile(m),
            const SizedBox(height: 16),
          ],
          if (analysis.mistakes.isNotEmpty) ...[
            Text(
              'Mistakes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final m in analysis.mistakes) _buildMoveTile(m),
            const SizedBox(height: 16),
          ],
          Text(
            'All moves',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final m in analysis.moves) _buildMoveTile(m),
        ],
      );

  Widget _buildAccuracyCard(String name, double accuracy) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(name, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text('accuracy', style: TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _buildMoveTile(MoveAnalysis move) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      dense: false,
      isThreeLine: true,
      leading: _qualityIcon(move.quality),
      title: Text(
        '${move.moveIndex + 1}. ${move.isWhiteMove ? 'White' : 'Black'} '
        '${move.san ?? move.notation}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${move.quality.label}'
            '${move.centipawnLoss > 0 ? ' (-${move.centipawnLoss} cp)' : ''}',
          ),
          const SizedBox(height: 2),
          Text(
            MoveCommentaryService.generate(l10n, move),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _qualityIcon(MoveQuality quality) {
    switch (quality) {
      case MoveQuality.best:
        return const Icon(Icons.star, color: Colors.green);
      case MoveQuality.good:
        return const Icon(Icons.check_circle_outline, color: Colors.teal);
      case MoveQuality.inaccuracy:
        return const Icon(Icons.info_outline, color: Colors.amber);
      case MoveQuality.mistake:
        return const Icon(Icons.warning_amber, color: Colors.orange);
      case MoveQuality.blunder:
        return const Icon(Icons.dangerous_outlined, color: Colors.red);
    }
  }
}
