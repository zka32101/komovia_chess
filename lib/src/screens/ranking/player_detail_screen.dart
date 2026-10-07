import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leaderboard_provider.dart';
import '../../services/shogi_rank_service.dart';
import '../../widgets/shogi_rank_display.dart';

/// Screen showing detailed player statistics and ranking
class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({
    required this.uid,
    required this.displayName,
    required this.shogiRankString,
    required this.rating,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    Key? key,
  }) : super(key: key);
  final String uid;
  final String displayName;
  final String shogiRankString;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRankAsync = ref.watch(userRankProvider(uid));
    final nearbyRankingsAsync = ref.watch(nearbyRankingsProvider(uid));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プレイヤー詳細'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Player header card
            _buildPlayerHeader(context, theme),

            // Stats cards
            _buildStatsCards(context, theme),

            // Rank position section
            Padding(
              padding: const EdgeInsets.all(16),
              child: userRankAsync.when(
                data: (rank) => _buildRankPositionCard(context, theme, rank),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, st) => const SizedBox.shrink(),
              ),
            ),

            // Nearby players section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '周辺のランキング',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  nearbyRankingsAsync.when(
                    data: (rankings) => _buildNearbyRankings(context, rankings),
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, st) => Text('エラー: $err'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build player header with name, photo, and shogi rank
  Widget _buildPlayerHeader(BuildContext context, ThemeData theme) {
    final winRate = gamesPlayed > 0 ? wins / gamesPlayed : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          // Player name
          Text(
            displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Shogi rank
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShogiRankDisplay(
                rank: ShogiRankService.calculateRank(rating),
                eloRating: rating,
                compact: false,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rating display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    'レーティング',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rating.toString(),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 40),
              Column(
                children: [
                  Text(
                    '勝率',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(winRate * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build stats cards
  Widget _buildStatsCards(BuildContext context, ThemeData theme) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildStatCard(
              context,
              theme,
              'ゲーム数',
              gamesPlayed.toString(),
              Icons.sports_esports,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              context,
              theme,
              '勝利',
              wins.toString(),
              Icons.thumb_up,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              context,
              theme,
              '敗北',
              losses.toString(),
              Icons.thumb_down,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              context,
              theme,
              '引き分け',
              draws.toString(),
              Icons.handshake,
            ),
          ],
        ),
      );

  /// Build individual stat card
  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  /// Build rank position card
  Widget _buildRankPositionCard(
    BuildContext context,
    ThemeData theme,
    int? rank,
  ) {
    if (rank == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('ランク情報を取得できません'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '現在のランク',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '#$rank',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank位',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build nearby rankings list
  Widget _buildNearbyRankings(
    BuildContext context,
    List<RankingEntry> rankings,
  ) {
    if (rankings.isEmpty) {
      return const Text('近くのプレイヤーが見つかりません');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final entry = rankings[index];
        final theme = Theme.of(context);
        final isCurrentUser = entry.uid == uid;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: isCurrentUser
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Rank
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#${entry.rank}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Player info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.shogiRankString,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),

              // Rating
              Text(
                entry.rating.toString(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
