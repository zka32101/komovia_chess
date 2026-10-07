import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leaderboard_provider.dart';
import '../../services/shogi_rank_service.dart';
import '../../widgets/shogi_rank_display.dart';
import 'package:intl/intl.dart';

/// Leaderboard screen displaying player rankings
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({
    Key? key,
    this.initialShogiRank,
  }) : super(key: key);
  final String? initialShogiRank;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // If initial shogi rank provided, load those rankings
    if (widget.initialShogiRank != null) {
      Future.microtask(() {
        ref
            .read(leaderboardProvider.notifier)
            .loadRankingByShogi(widget.initialShogiRank!);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardState = ref.watch(leaderboardProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ランキング'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(context, leaderboardState),

          // Stats section
          if (leaderboardState.stats != null)
            _buildStatsSection(context, leaderboardState.stats!, isDarkMode),

          // Leaderboard content
          Expanded(
            child: leaderboardState.isLoading &&
                    leaderboardState.entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : leaderboardState.error != null &&
                        leaderboardState.entries.isEmpty
                    ? _buildErrorWidget(context, leaderboardState.error!)
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(leaderboardProvider.notifier).refresh(),
                        child: _buildRankingsList(context, leaderboardState),
                      ),
          ),

          // Pagination controls
          if (leaderboardState.entries.isNotEmpty)
            _buildPaginationControls(context, leaderboardState),
        ],
      ),
    );
  }

  /// Filter tabs for changing ranking view
  Widget _buildFilterTabs(BuildContext context, LeaderboardState state) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              // Global tab
              FilterChip(
                label: const Text('グローバル'),
                selected: state.filter == LeaderboardFilter.global,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(leaderboardProvider.notifier).loadGlobalRanking();
                  }
                },
              ),

              // Monthly tab
              FilterChip(
                label: const Text('月間'),
                selected: state.filter == LeaderboardFilter.monthly,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(leaderboardProvider.notifier).loadMonthlyRanking();
                  }
                },
              ),

              // Shogi rank filter button
              Tooltip(
                message: '段級別ランキング',
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.filter_list),
                  label: const Text('段級別'),
                  onPressed: () => _showShogiRankFilter(context),
                ),
              ),
            ],
          ),
        ),
      );

  /// Show shogi rank filter dialog
  void _showShogiRankFilter(BuildContext context) {
    final ranks = [
      '20級',
      '19級',
      '18級',
      '17級',
      '16級',
      '15級',
      '14級',
      '13級',
      '12級',
      '11級',
      '10級',
      '9級',
      '8級',
      '7級',
      '6級',
      '5級',
      '4級',
      '3級',
      '2級',
      '1級',
      '初段',
      '2段',
      '3段',
      '4段',
      '5段',
      '6段',
      '7段',
      '8段',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('段級を選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ranks.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(ranks[index]),
              onTap: () {
                ref
                    .read(leaderboardProvider.notifier)
                    .loadRankingByShogi(ranks[index]);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Build stats section
  Widget _buildStatsSection(
    BuildContext context,
    RankingStats stats,
    bool isDarkMode,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            'プレイヤー数',
            stats.totalPlayers.toString(),
            Icons.people,
          ),
          _buildStatItem(
            context,
            '平均レート',
            stats.averageRating.toStringAsFixed(0),
            Icons.trending_up,
          ),
          _buildStatItem(
            context,
            '最高レート',
            stats.topRating.toString(),
            Icons.star,
          ),
        ],
      ),
    );
  }

  /// Build individual stat item
  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) =>
      Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );

  /// Build rankings list
  Widget _buildRankingsList(BuildContext context, LeaderboardState state) =>
      ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: state.entries.length,
        itemBuilder: (context, index) => RankCard(
          entry: state.entries[index],
          index: index,
        ),
      );

  /// Build pagination controls
  Widget _buildPaginationControls(
          BuildContext context, LeaderboardState state) =>
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.chevron_left),
              label: const Text('前へ'),
              onPressed: state.currentPage > 0
                  ? () => ref.read(leaderboardProvider.notifier).previousPage()
                  : null,
            ),
            Text(
              'ページ ${state.currentPage + 1}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.chevron_right),
              label: const Text('次へ'),
              onPressed: () =>
                  ref.read(leaderboardProvider.notifier).nextPage(),
            ),
          ],
        ),
      );

  /// Build error widget
  Widget _buildErrorWidget(BuildContext context, String error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'エラーが発生しました',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
              child: const Text('再試行'),
            ),
          ],
        ),
      );
}

/// Rank card widget for displaying individual ranking entry
class RankCard extends ConsumerWidget {
  const RankCard({
    required this.entry,
    required this.index,
    Key? key,
  }) : super(key: key);
  final RankingEntry entry;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Determine rank color
    Color getRankColor() {
      final rank = entry.rank;
      if (rank == 1) return Colors.amber;
      if (rank == 2) return Colors.grey[400] ?? Colors.grey;
      if (rank == 3) return Colors.orange[700] ?? Colors.orange;
      return theme.colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: getRankColor(),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '#${entry.rank}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDarkMode ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player name
                  Text(
                    entry.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Shogi rank and stats
                  Row(
                    children: [
                      // Shogi rank badge
                      ShogiRankDisplay(
                        rank: ShogiRankService.calculateRank(entry.rating),
                        eloRating: entry.rating,
                        compact: true,
                      ),
                      const SizedBox(width: 8),

                      // Stats
                      Expanded(
                        child: Text(
                          '${entry.gamesPlayed} 試合 | 勝率 ${(entry.winRate * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Rating
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.rating.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'レート',
                  style: theme.textTheme.labelSmall,
                ),
                if (entry.lastGameAt != null)
                  Text(
                    _formatTime(entry.lastGameAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Format time since last game
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return DateFormat('M月d日').format(dateTime);
    }
  }
}
