import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cpu_game_state.dart';
import '../../services/ai_opponent_engine.dart';
import '../../widgets/game_board.dart';
import '../../widgets/game_result.dart';
import '../../widgets/move_history.dart';
import '../../providers/cpu_game_provider.dart';
import '../../providers/board_theme_provider.dart';

class CPUGameScreen extends ConsumerStatefulWidget {
  const CPUGameScreen({
    Key? key,
    this.difficulty = AIDifficulty.medium,
    this.playerIsWhite = true,
  }) : super(key: key);
  final AIDifficulty difficulty;
  final bool playerIsWhite;

  @override
  ConsumerState<CPUGameScreen> createState() => _CPUGameScreenState();
}

class _CPUGameScreenState extends ConsumerState<CPUGameScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize game on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cpuGameProvider.notifier).initGame(
            difficulty: widget.difficulty,
            playerIsWhite: widget.playerIsWhite,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(cpuGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs CPU'),
        centerTitle: true,
        elevation: 0,
      ),
      body: gameState.isGameOver
          ? _buildGameOverScreen(gameState)
          : _buildGamePlayScreen(gameState),
    );
  }

  Widget _buildGamePlayScreen(CpuGameState gameState) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Make AI move if it's AI's turn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!gameState.isPlayerTurn &&
          !gameState.isAIThinking &&
          !gameState.isGameOver) {
        ref.read(cpuGameProvider.notifier).makeAIMove();
      }
    });

    return SafeArea(
      child: isMobile
          ? _buildMobileLayout(gameState)
          : _buildDesktopLayout(gameState),
    );
  }

  Widget _buildMobileLayout(CpuGameState gameState) {
    final boardTheme = ref.watch(selectedBoardThemeProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Turn indicator and status
            _buildStatusBar(gameState),
            const SizedBox(height: 16),

            // Game board with controls
            GameBoard(
              gameState: gameState.gameState,
              theme: boardTheme,
              onMove: (from, to, {promotion}) {
                ref.read(cpuGameProvider.notifier).makePlayerMove(
                      from,
                      to,
                      promotion: promotion,
                    );
              },
              onUndo: gameState.moves.isNotEmpty
                  ? () => ref.read(cpuGameProvider.notifier).undoMove()
                  : null,
              onResign: _showResignDialog,
              moveHistory: gameState.moves,
              isPlayerTurn: gameState.isPlayerTurn,
              showMaterial: true,
            ),

            const SizedBox(height: 24),

            // Move history
            if (gameState.moves.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300] ?? Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: MoveHistory(
                  moves: gameState.moves,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(CpuGameState gameState) {
    final boardTheme = ref.watch(selectedBoardThemeProvider);

    return Row(
      children: [
        // Left side: Board and controls
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatusBar(gameState),
                const SizedBox(height: 16),
                Expanded(
                  child: GameBoard(
                    gameState: gameState.gameState,
                    theme: boardTheme,
                    onMove: (from, to, {promotion}) {
                      ref.read(cpuGameProvider.notifier).makePlayerMove(
                            from,
                            to,
                            promotion: promotion,
                          );
                    },
                    onUndo: gameState.moves.isNotEmpty
                        ? () => ref.read(cpuGameProvider.notifier).undoMove()
                        : null,
                    onResign: _showResignDialog,
                    moveHistory: gameState.moves,
                    isPlayerTurn: gameState.isPlayerTurn,
                    showMaterial: true,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right side: Move history and info
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(color: Colors.grey[300] ?? Colors.grey)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Move History',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: gameState.moves.isEmpty
                        ? Center(
                            child: Text(
                              'No moves yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : MoveHistory(moves: gameState.moves),
                  ),
                  const SizedBox(height: 24),
                  _buildGameInfoPanel(gameState),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(CpuGameState gameState) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameState.playerIsWhite ? 'You (White)' : 'You (Black)',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  gameState.isPlayerTurn ? 'Your Turn' : 'Thinking...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (gameState.isAIThinking)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                'Difficulty: ${widget.difficulty.displayName}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  gameState.playerIsWhite ? 'CPU (Black)' : 'CPU (White)',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  gameState.isPlayerTurn ? 'Idle' : 'Playing...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildGameInfoPanel(CpuGameState gameState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Info',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Moves',
            (gameState.moves.length / 2).ceil().toString(),
          ),
          _buildInfoRow(
            'Duration',
            _formatDuration(gameState.gameDuration),
          ),
          _buildInfoRow(
            'Difficulty',
            widget.difficulty.displayName,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _showResignDialog,
              child: const Text('Resign'),
            ),
          ),
        ],
      );

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );

  Widget _buildGameOverScreen(CpuGameState gameState) => Center(
        child: GameResult(
          result: gameState.result ?? 'draw',
          method: gameState.endReason ?? 'unknown',
          moves: (gameState.moves.length / 2).ceil(),
          duration: gameState.gameDuration,
          onNewGame: () {
            ref.read(cpuGameProvider.notifier).reset();
          },
          onHome: () {
            Navigator.of(context).pop();
          },
          onAnalyze: () {
            // TODO: Implement game analysis
          },
        ),
      );

  void _showResignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign Game'),
        content: const Text(
            'Are you sure you want to resign? You will lose this game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cpuGameProvider.notifier).resign();
              Navigator.pop(context);
            },
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes == 0) {
      return '${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
}
