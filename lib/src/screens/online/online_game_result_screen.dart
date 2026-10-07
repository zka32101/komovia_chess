import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/online_game.dart';
import '../../providers/auth_provider.dart';

/// Displays the result of a completed online game
class OnlineGameResultScreen extends ConsumerWidget {
  const OnlineGameResultScreen({
    required this.gameId,
    required this.game,
    Key? key,
  }) : super(key: key);
  final String gameId;
  final OnlineGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Game Result'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildResultHeader(context, ref),
              const SizedBox(height: 24),
              _buildRatingChanges(context),
              const SizedBox(height: 24),
              _buildGameStatistics(context),
              const SizedBox(height: 32),
              _buildActionButtons(context, ref),
            ],
          ),
        ),
      );

  /// Display the game result (win/loss/draw)
  Widget _buildResultHeader(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isCurrentUserWhite = game.whitePlayerId == user?.uid;
    final currentPlayerWon =
        (isCurrentUserWhite && game.result == 'white_win') ||
            (!isCurrentUserWhite && game.result == 'black_win');
    final isDraw = game.result == 'draw';

    final backgroundColor = currentPlayerWon
        ? Colors.green[100]
        : isDraw
            ? Colors.amber[100]
            : Colors.red[100];

    final textColor = currentPlayerWon
        ? Colors.green[900]
        : isDraw
            ? Colors.amber[900]
            : Colors.red[900];

    String resultText = 'Draw';
    if (currentPlayerWon) {
      resultText = 'You Won! 🎉';
    } else if (!isDraw) {
      resultText = 'You Lost';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            resultText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            (game.resultReason ?? '').replaceAll('_', ' ').toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  /// Display rating changes for both players
  Widget _buildRatingChanges(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rating Changes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildRatingChangeRow(
              context: context,
              playerName: game.whitePlayerName,
              oldRating: game.whiteRating,
              ratingDelta: game.whiteRatingDelta ?? 0,
              newRating: game.whiteNewRating ?? game.whiteRating,
            ),
            const SizedBox(height: 12),
            _buildRatingChangeRow(
              context: context,
              playerName: game.blackPlayerName,
              oldRating: game.blackRating,
              ratingDelta: game.blackRatingDelta ?? 0,
              newRating: game.blackNewRating ?? game.blackRating,
            ),
          ],
        ),
      );

  /// Build individual rating change row
  Widget _buildRatingChangeRow({
    required BuildContext context,
    required String playerName,
    required int oldRating,
    required int ratingDelta,
    required int newRating,
  }) {
    final isPositive = ratingDelta >= 0;
    final deltaText = '${isPositive ? '+' : ''}$ratingDelta';
    final deltaColor = isPositive ? Colors.green : Colors.red;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playerName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '$oldRating → $newRating',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: deltaColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            deltaText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: deltaColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  /// Display game statistics
  Widget _buildGameStatistics(BuildContext context) {
    final duration = game.endedAt?.difference(game.startedAt ?? game.createdAt);
    final durationText = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildStatRow(context, 'Game Type', game.type),
          _buildStatRow(context, 'Time Control', game.timeControl),
          _buildStatRow(context, 'Total Moves', '${game.moves.length}'),
          _buildStatRow(context, 'Duration', durationText),
          _buildStatRow(
            context,
            'Reason',
            (game.resultReason ?? '').replaceAll('_', ' '),
          ),
        ],
      ),
    );
  }

  /// Build individual stat row
  Widget _buildStatRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );

  /// Action buttons for next steps
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) => Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              // Navigate to matchmaking for a new game
              Navigator.of(context).pushNamed('/online/matchmaking');
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Play Again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
