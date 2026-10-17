import 'package:flutter/material.dart';
import '../../models/game_analysis.dart';
import '../../models/online_game.dart';
import '../../services/chess_analysis_service.dart';

/// Shows Stockfish-based per-move analysis for a finished game - see
/// ChessAnalysisService's own doc comment for what "analysis" means here
/// (engine eval classification, not an LLM feature).
class GameAnalysisScreen extends StatefulWidget {
  const GameAnalysisScreen({
    required this.moves,
    required this.whitePlayerName,
    required this.blackPlayerName,
    Key? key,
  }) : super(key: key);
  final List<GameMove> moves;
  final String whitePlayerName;
  final String blackPlayerName;

  @override
  State<GameAnalysisScreen> createState() => _GameAnalysisScreenState();
}

class _GameAnalysisScreenState extends State<GameAnalysisScreen> {
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
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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

  Widget _buildMoveTile(MoveAnalysis move) => ListTile(
        dense: true,
        leading: _qualityIcon(move.quality),
        title: Text(
          '${move.moveIndex + 1}. ${move.isWhiteMove ? 'White' : 'Black'} '
          '${move.notation}',
        ),
        subtitle: Text(
          '${move.quality.label}'
          '${move.centipawnLoss > 0 ? ' (-${move.centipawnLoss} cp)' : ''}',
        ),
      );

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
