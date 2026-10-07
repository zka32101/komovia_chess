import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../models/user.dart';
import '../../services/shogi_rank_service.dart';
import '../../widgets/shogi_rank_display.dart';
import 'player_detail_screen.dart';

/// Screen showing the current user's ranking position
class MyRankingScreen extends ConsumerWidget {
  const MyRankingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('マイランキング')),
        body: const Center(
          child: Text('ログインが必要です'),
        ),
      );
    }

    final userRankAsync = ref.watch(userRankProvider(currentUser.uid));
    final nearbyRankingsAsync =
        ref.watch(nearbyRankingsProvider(currentUser.uid));
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイランキング'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(userRankProvider(currentUser.uid).notifier).refresh();
              ref
                  .read(nearbyRankingsProvider(currentUser.uid).notifier)
                  .refresh();
            },
            tooltip: '更新',
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('ユーザー情報を取得できません'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // User rank position card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: userRankAsync.when(
                    data: (rank) => _buildMyRankCard(
                      context,
                      user,
                      rank,
                      ref,
                    ),
                    loading: () => const Card(
                      child: SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (err, st) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('エラー: $err'),
                      ),
                    ),
                  ),
                ),

                // Nearby players section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '周辺のプレイヤー',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      nearbyRankingsAsync.when(
                        data: (rankings) => _buildNearbyPlayersList(
                            context, rankings, currentUser.uid),
                        loading: () => const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, st) => Text('エラー: $err'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('エラー: $err')),
      ),
    );
  }

  /// Build my rank card
  Widget _buildMyRankCard(
    BuildContext context,
    UserModel user,
    int? rank,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    if (rank == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.info_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'ランク情報を取得できません',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'ゲームをプレイしてランキングに参加してください',
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // My rank position
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'プレイヤー',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (user.shogiRank != null)
                        ShogiRankDisplay(
                          rank: user.shogiRank!,
                          eloRating: user.rating,
                          compact: false,
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$rank',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '位',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  context,
                  'レート',
                  user.rating.toString(),
                  Icons.trending_up,
                ),
                _buildStatColumn(
                  context,
                  'ゲーム数',
                  user.gamesPlayed.toString(),
                  Icons.sports_esports,
                ),
                _buildStatColumn(
                  context,
                  '勝利',
                  user.wins.toString(),
                  Icons.thumb_up,
                ),
                _buildStatColumn(
                  context,
                  '敗北',
                  user.losses.toString(),
                  Icons.thumb_down,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Win rate bar
            _buildWinRateBar(context, user),
            const SizedBox(height: 16),

            // Detail button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PlayerDetailScreen(
                      uid: user.uid,
                      displayName: user.displayName ?? 'プレイヤー',
                      shogiRankString: ShogiRankService.displayName(
                        user.shogiRank ??
                            ShogiRankService.calculateRank(user.rating),
                      ),
                      rating: user.rating,
                      gamesPlayed: user.gamesPlayed,
                      wins: user.wins,
                      losses: user.losses,
                      draws: user.draws,
                    ),
                  ),
                ),
                child: const Text('詳細を見る'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build stat column
  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
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
        ),
      ],
    );
  }

  /// Build win rate progress bar
  Widget _buildWinRateBar(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final winRate = user.gamesPlayed > 0 ? user.wins / user.gamesPlayed : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '勝率',
              style: theme.textTheme.labelMedium,
            ),
            Text(
              '${(winRate * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: winRate,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// Build nearby players list
  Widget _buildNearbyPlayersList(
    BuildContext context,
    List<RankingEntry> rankings,
    String currentUserId,
  ) {
    final theme = Theme.of(context);

    if (rankings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'ランキングにまだプレイヤーがいません',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rankings.length,
      itemBuilder: (context, index) {
        final entry = rankings[index];
        final isCurrentUser = entry.uid == currentUserId;
        final winRate = entry.gamesPlayed > 0
            ? (entry.winRate * 100).toStringAsFixed(1)
            : '0.0';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isCurrentUser ? 4.0 : 0.0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : null,
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
                // Rank badge
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser)
                            Chip(
                              label: const Text('YOU'),
                              backgroundColor: theme.colorScheme.primary,
                              labelStyle: const TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.shogiRankString} • 勝率 $winRate% • ${entry.rating}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
