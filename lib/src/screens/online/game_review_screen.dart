import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/online_game.dart';
import '../../services/chess_engine_service.dart';
import '../../services/stockfish_engine_service.dart';
import '../../widgets/game_analysis_bar.dart';
import '../../widgets/game_board.dart';

const _standardStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Screen for reviewing/replaying completed games
class GameReviewScreen extends ConsumerStatefulWidget {
  const GameReviewScreen({
    required this.gameId,
    required this.game,
    Key? key,
  }) : super(key: key);
  final String gameId;
  final OnlineGame game;

  @override
  ConsumerState<GameReviewScreen> createState() => _GameReviewScreenState();
}

class _GameReviewScreenState extends ConsumerState<GameReviewScreen> {
  late int currentMoveIndex;
  late bool isAutoPlaying;
  late int autoPlaySpeed; // milliseconds between moves

  final _chess = ChessEngineService();
  int? _evaluation;
  bool _isEvaluating = false;
  int _evalRequestId = 0;

  List<Map<String, dynamic>> get _movesAsMaps => widget.game.moves
      .map((m) => {'from': m.from, 'to': m.to, 'promotion': m.promotion})
      .toList();

  @override
  void initState() {
    super.initState();
    currentMoveIndex = -1; // Start before first move
    isAutoPlaying = false;
    autoPlaySpeed = 1000;
    _chess.loadFromFenAndMoves(_standardStartingFen, const []);
    // Defer the first evaluation request until after the initial build, so
    // its setState call doesn't race the widget still being mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestEvaluation());
  }

  /// Replays the game from the start up to [currentMoveIndex] and kicks off
  /// a fresh Stockfish evaluation of the resulting position.
  void _updatePosition() {
    _chess.loadFromFenAndMoves(
      _standardStartingFen,
      _movesAsMaps.sublist(0, currentMoveIndex + 1),
    );
    _requestEvaluation();
  }

  Future<void> _requestEvaluation() async {
    final requestId = ++_evalRequestId;
    setState(() => _isEvaluating = true);

    final fen = _chess.getCurrentFen();
    final whiteToMove = _chess.isWhiteTurn();
    final score = await StockfishEngineService.instance.evaluatePosition(fen);

    if (!mounted || requestId != _evalRequestId) return;
    setState(() {
      // Stockfish reports the score from the side-to-move's perspective;
      // normalize to White's perspective for the evaluation bar.
      _evaluation = score == null ? null : (whiteToMove ? score : -score);
      _isEvaluating = false;
    });
  }

  /// Moves to [index] (clamped to the game's move range), updating the
  /// replayed position and triggering a new evaluation.
  void _seekTo(int index) {
    setState(() {
      currentMoveIndex = index.clamp(-1, widget.game.moves.length - 1);
    });
    _updatePosition();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Game Review'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showGameInfo,
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildGameHeader(),
              const SizedBox(height: 16),
              _buildChessBoard(),
              const SizedBox(height: 16),
              _buildControls(),
              const SizedBox(height: 24),
              _buildMoveList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );

  /// Build game header with player info
  Widget _buildGameHeader() => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey[100],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildPlayerCard(
                    name: widget.game.whitePlayerName,
                    rating: widget.game.whiteRating,
                    isWhite: true,
                    won: widget.game.result == 'white_win',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child:
                      Text('vs', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _buildPlayerCard(
                    name: widget.game.blackPlayerName,
                    rating: widget.game.blackRating,
                    isWhite: false,
                    won: widget.game.result == 'black_win',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGameMetadata(),
          ],
        ),
      );

  /// Build player card
  Widget _buildPlayerCard({
    required String name,
    required int rating,
    required bool isWhite,
    required bool won,
  }) {
    final backgroundColor = won ? Colors.green[100] : Colors.red[100];
    final textColor = won ? Colors.green[900] : Colors.red[900];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
          ),
          Text(
            '$rating',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }

  /// Build game metadata
  Widget _buildGameMetadata() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMetadataItem('Type', widget.game.type),
          _buildMetadataItem('Time', widget.game.timeControl),
          _buildMetadataItem('Moves', '${widget.game.moves.length}'),
          _buildMetadataItem('Result', widget.game.resultReason ?? ''),
        ],
      );

  /// Build metadata item
  Widget _buildMetadataItem(String label, String value) => Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );

  /// Build the chess board at [currentMoveIndex], with a live Stockfish
  /// evaluation bar above it.
  Widget _buildChessBoard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildEvaluationBar(),
            const SizedBox(height: 8),
            GameBoard(
              gameState: _chess.rawChess,
              isPlayerTurn: false,
              showMaterial: false,
            ),
            const SizedBox(height: 8),
            Text(
              'Move ${currentMoveIndex + 1}/${widget.game.moves.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _buildEvaluationBar() {
    if (_evaluation == null) {
      return SizedBox(
        height: 30,
        child: _isEvaluating
            ? const Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      );
    }
    return EvaluationBar(evaluation: _evaluation!);
  }

  /// Build control buttons
  Widget _buildControls() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: _goToStart,
                  tooltip: 'Go to start',
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: _previousMove,
                  tooltip: 'Previous move',
                ),
                SizedBox(
                  width: 50,
                  child: IconButton(
                    icon: Icon(isAutoPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _toggleAutoPlay,
                    tooltip: isAutoPlaying ? 'Pause' : 'Play',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: _nextMove,
                  tooltip: 'Next move',
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: _goToEnd,
                  tooltip: 'Go to end',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: currentMoveIndex.toDouble(),
              min: -1,
              max: (widget.game.moves.length - 1)
                  .toDouble()
                  .clamp(-1, double.infinity),
              onChanged: (value) => _seekTo(value.toInt()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Speed:',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Slider(
                  value: autoPlaySpeed.toDouble(),
                  min: 500,
                  max: 3000,
                  divisions: 5,
                  label: '${autoPlaySpeed}ms',
                  onChanged: (value) {
                    setState(() {
                      autoPlaySpeed = value.toInt();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      );

  /// Build move list
  Widget _buildMoveList() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moves',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildMoveListContent(),
          ],
        ),
      );

  /// Build move list content
  Widget _buildMoveListContent() {
    if (widget.game.moves.isEmpty) {
      return Center(
        child: Text(
          'No moves recorded',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(widget.game.moves.length, (index) {
        final move = widget.game.moves[index];
        final moveStr = move.promotion != null
            ? '${move.from}${move.to}=${move.promotion}'
            : '${move.from}${move.to}';
        final isSelected = index == currentMoveIndex;

        return GestureDetector(
          onTap: () => _seekTo(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[100] : Colors.grey[200],
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              moveStr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.blue[900] : null,
                  ),
            ),
          ),
        );
      }),
    );
  }

  // Control callbacks
  void _goToStart() {
    setState(() => isAutoPlaying = false);
    _seekTo(-1);
  }

  void _previousMove() {
    if (currentMoveIndex > -1) {
      _seekTo(currentMoveIndex - 1);
    }
  }

  void _nextMove() {
    if (currentMoveIndex < widget.game.moves.length - 1) {
      _seekTo(currentMoveIndex + 1);
    }
  }

  void _goToEnd() {
    setState(() => isAutoPlaying = false);
    _seekTo(widget.game.moves.length - 1);
  }

  void _toggleAutoPlay() {
    setState(() {
      isAutoPlaying = !isAutoPlaying;
    });

    if (isAutoPlaying) {
      _playMoves();
    }
  }

  Future<void> _playMoves() async {
    while (isAutoPlaying && currentMoveIndex < widget.game.moves.length - 1) {
      await Future.delayed(Duration(milliseconds: autoPlaySpeed));
      if (!mounted) return;
      if (currentMoveIndex < widget.game.moves.length - 1) {
        _seekTo(currentMoveIndex + 1);
      } else {
        setState(() => isAutoPlaying = false);
      }
    }
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Game ID', widget.game.gameId),
            _buildInfoRow('Type', widget.game.type),
            _buildInfoRow('Time Control', widget.game.timeControl),
            _buildInfoRow('Result', widget.game.result ?? ''),
            _buildInfoRow('Result Reason', widget.game.resultReason ?? ''),
            _buildInfoRow(
              'Duration',
              _formatDuration(
                widget.game.endedAt?.difference(
                        widget.game.startedAt ?? widget.game.createdAt) ??
                    Duration.zero,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
