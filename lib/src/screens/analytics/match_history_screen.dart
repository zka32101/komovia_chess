import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/match_history_provider.dart';
import '../../widgets/animations/chart_entrance_animation.dart';
import 'pgn_import_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Screen for displaying match history with filtering and pagination
class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({
    required this.playerId,
    required this.playerName,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final String playerName;

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // MatchHistoryNotifier starts in AsyncValue.loading() and only ever
    // transitions out of it when loadHistory() is called - previously
    // nothing called it on screen open, so this screen showed an infinite
    // spinner until the user happened to press "リセット" (the only other
    // caller of loadHistory, via resetFilters).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchHistoryProvider.notifier).loadHistory(widget.playerId);
    });
  }

  String get playerId => widget.playerId;
  String get playerName => widget.playerName;

  @override
  Widget build(BuildContext context) {
    final matchHistoryState = ref.watch(matchHistoryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matchHistoryTitle),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: l10n.matchHistoryImportPgnTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PgnImportScreen()),
              );
            },
          ),
        ],
      ),
      body: matchHistoryState.when(
        data: (state) => _buildContent(context, ref, state, l10n),
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
                l10n.matchHistoryLoadFailedMessage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.refresh(matchHistoryProvider);
                  ref.read(matchHistoryProvider.notifier).loadHistory(widget.playerId);
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.matchHistoryRetryButton),
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
    AppLocalizations l10n,
  ) =>
      Column(
        children: [
          // Filter controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFilterControls(context, ref, l10n),
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
                          l10n.matchHistoryNoMatchesMessage,
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
                            child: Text(l10n.matchHistoryLoadMoreButton),
                          ),
                        );
                      }

                      final match = state.matches[index];
                      return ChartEntranceAnimation(
                        duration: Duration(
                          milliseconds: 300 + (index * 50).clamp(0, 500),
                        ),
                        child: _buildMatchCard(context, match, l10n),
                      );
                    },
                  ),
          ),
        ],
      );

  Widget _buildFilterControls(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) =>
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Show filter dialog
                _showFilterDialog(context, ref, l10n);
              },
              icon: const Icon(Icons.filter_list),
              label: Text(l10n.matchHistoryFilterButton),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(matchHistoryProvider.notifier).resetFilters(playerId);
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.matchHistoryResetButton),
          ),
        ],
      );

  Widget _buildMatchCard(
    BuildContext context,
    dynamic match,
    AppLocalizations l10n,
  ) {
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
                      l10n.matchHistoryTimeControlAndResultLabel(
                        match.timeControl,
                        _getResultText(match.result, l10n),
                      ),
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

  String _getResultText(String result, AppLocalizations l10n) {
    switch (result) {
      case 'win':
        return l10n.matchHistoryResultWin;
      case 'loss':
        return l10n.matchHistoryResultLoss;
      case 'draw':
        return l10n.matchHistoryResultDraw;
      default:
        return result;
    }
  }

  void _showFilterDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    String? selectedResult;
    String? selectedTimeControl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.matchHistoryFilterDialogTitle),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.matchHistoryResultLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: selectedResult,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(l10n.matchHistoryAllLabel)),
                    DropdownMenuItem(
                        value: 'win',
                        child: Text(l10n.matchHistoryResultWin)),
                    DropdownMenuItem(
                        value: 'loss',
                        child: Text(l10n.matchHistoryResultLoss)),
                    DropdownMenuItem(
                        value: 'draw',
                        child: Text(l10n.matchHistoryResultDraw)),
                  ],
                  onChanged: (value) => setState(() => selectedResult = value),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.matchHistoryTimeControlLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: selectedTimeControl,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(l10n.matchHistoryAllLabel)),
                    DropdownMenuItem(
                        value: 'bullet',
                        child: Text(l10n.matchHistoryBulletLabel)),
                    DropdownMenuItem(
                        value: 'blitz',
                        child: Text(l10n.matchHistoryBlitzLabel)),
                    DropdownMenuItem(
                        value: 'rapid',
                        child: Text(l10n.matchHistoryRapidLabel)),
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
            child: Text(l10n.matchHistoryCancelButton),
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
            child: Text(l10n.matchHistoryApplyButton),
          ),
        ],
      ),
    );
  }
}
