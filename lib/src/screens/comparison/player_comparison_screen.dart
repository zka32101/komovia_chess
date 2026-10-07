import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/comparison_provider.dart';
import '../../models/head_to_head_stats.dart';
import '../../widgets/animations/chart_entrance_animation.dart';

/// Screen for displaying player-to-player comparison
class PlayerComparisonScreen extends ConsumerWidget {
  const PlayerComparisonScreen({
    required this.player1Id,
    required this.player1Name,
    required this.player1Rating,
    required this.player2Id,
    required this.player2Name,
    required this.player2Rating,
    Key? key,
  }) : super(key: key);
  final String player1Id;
  final String player1Name;
  final int player1Rating;
  final String player2Id;
  final String player2Name;
  final int player2Rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h2hStats = ref.watch(
      headToHeadStatsProvider(
        (player1Id: player1Id, player2Id: player2Id),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('プレイヤー比較'),
        elevation: 0,
      ),
      body: h2hStats.when(
        data: (stats) => _buildContent(context, ref, stats),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '比較データの取得に失敗しました',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(
                  headToHeadStatsProvider(
                    (player1Id: player1Id, player2Id: player2Id),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HeadToHeadStats stats,
  ) =>
      SingleChildScrollView(
        child: Column(
          children: [
            // Header with player names and ratings
            _buildHeader(context),
            const SizedBox(height: 24),

            // H2H Statistics
            _buildH2HStats(context, stats),
            const SizedBox(height: 24),

            // Recent Matches
            _buildRecentMatches(context, ref, stats),
            const SizedBox(height: 24),
          ],
        ),
      );

  Widget _buildHeader(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            // Player 1
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.withOpacity(0.3),
                    child: Text(
                      player1Name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    player1Name,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'レーティング: $player1Rating',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // VS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'vs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            // Player 2
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.orange.withOpacity(0.3),
                    child: Text(
                      player2Name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    player2Name,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'レーティング: $player2Rating',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildH2HStats(BuildContext context, HeadToHeadStats stats) {
    final totalGames = stats.player1Wins + stats.player2Wins + stats.draws;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '対戦成績',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ChartEntranceAnimation(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Player 1 wins
                  Column(
                    children: [
                      Text(
                        '${stats.player1Wins}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '勝利',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  // Draws
                  Column(
                    children: [
                      Text(
                        '${stats.draws}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '引き分け',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  // Player 2 wins
                  Column(
                    children: [
                      Text(
                        '${stats.player2Wins}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '敗北',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Win rates
          Row(
            children: [
              Expanded(
                child: ChartEntranceAnimation(
                  duration: const Duration(milliseconds: 600),
                  child: _buildWinRateCard(
                    context,
                    player1Name,
                    stats.player1WinRate,
                    Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChartEntranceAnimation(
                  duration: const Duration(milliseconds: 700),
                  child: _buildWinRateCard(
                    context,
                    player2Name,
                    stats.player2WinRate,
                    Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWinRateCard(
    BuildContext context,
    String playerName,
    double winRate,
    Color color,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '${winRate.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '勝率',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _buildRecentMatches(
    BuildContext context,
    WidgetRef ref,
    HeadToHeadStats stats,
  ) {
    if (stats.recentMatches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近の対戦',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '対戦履歴がありません',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近の対戦 (${stats.recentMatches.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.recentMatches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final match = stats.recentMatches[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.playedAt.toString().split(' ')[0],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.timeControl,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getResultColor(match.result),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getResultText(match.result),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getResultColor(String result) {
    switch (result) {
      case 'win':
        return Colors.green;
      case 'loss':
        return Colors.red;
      case 'draw':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getResultText(String result) {
    switch (result) {
      case 'win':
        return '勝利';
      case 'loss':
        return '敗北';
      case 'draw':
        return '引き分け';
      default:
        return result;
    }
  }
}
