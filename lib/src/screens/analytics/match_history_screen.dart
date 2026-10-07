import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/match_history_provider.dart';
import '../../widgets/animations/chart_entrance_animation.dart';

/// Screen for displaying match history with filtering and pagination
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({
    required this.playerId,
    required this.playerName,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final String playerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchHistoryState = ref.watch(matchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('対戦履歴'),
        elevation: 0,
      ),
      body: matchHistoryState.when(
        data: (state) => _buildContent(context, ref, state),
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
                '対戦履歴の取得に失敗しました',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(matchHistoryProvider),
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
    dynamic state,
  ) =>
      Column(
        children: [
          // Filter controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilterControls(context, ref),
          ),

          // Match list
          Expanded(
            child: state.matches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sports_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '対戦履歴がありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.matches.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == state.matches.length) {
                        // Load more button
                        return Center(
                          child: ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(matchHistoryProvider.notifier)
                                  .loadMore(playerId);
                            },
                            child: const Text('さらに読み込む'),
                          ),
                        );
                      }

                      final match = state.matches[index];
                      return ChartEntranceAnimation(
                        duration: Duration(
                          milliseconds: 300 + (index * 50).clamp(0, 500),
                        ),
                        child: _buildMatchCard(context, match),
                      );
                    },
                  ),
          ),
        ],
      );

  Widget _buildFilterControls(BuildContext context, WidgetRef ref) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Show filter dialog
                _showFilterDialog(context, ref);
              },
              icon: const Icon(Icons.filter_list),
              label: const Text('フィルター'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(matchHistoryProvider.notifier).resetFilters(playerId);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('リセット'),
          ),
        ],
      );

  Widget _buildMatchCard(BuildContext context, dynamic match) {
    final ratingChange = match.playerRatingAfter - match.playerRatingBefore;
    final ratingChangeText =
        ratingChange >= 0 ? '+$ratingChange' : '$ratingChange';

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
        children: [
          // Result indicator
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: _getResultColor(match.result),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Match details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      match.opponentName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      match.playedAt.toString().split(' ')[0],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${match.timeControl} • ${_getResultText(match.result)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      ratingChangeText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                ratingChange >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
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

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    String? selectedResult;
    String? selectedTimeControl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フィルター'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '結果',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: selectedResult,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('すべて')),
                    DropdownMenuItem(value: 'win', child: Text('勝利')),
                    DropdownMenuItem(value: 'loss', child: Text('敗北')),
                    DropdownMenuItem(value: 'draw', child: Text('引き分け')),
                  ],
                  onChanged: (value) => setState(() => selectedResult = value),
                ),
                const SizedBox(height: 16),
                Text(
                  '時間制',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: selectedTimeControl,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('すべて')),
                    DropdownMenuItem(value: 'bullet', child: Text('バレット')),
                    DropdownMenuItem(value: 'blitz', child: Text('ブリッツ')),
                    DropdownMenuItem(value: 'rapid', child: Text('ラピッド')),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedTimeControl = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(matchHistoryProvider.notifier).filterMatches(
                    playerId: playerId,
                    result: selectedResult,
                    timeControl: selectedTimeControl,
                  );
              Navigator.pop(context);
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );
  }
}
