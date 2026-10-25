import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/online_game.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../providers/premium_provider.dart';
import '../premium/premium_screen.dart';
import 'online_game_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Screen for matchmaking queue management
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> {
  String? _currentQueueId;
  String _selectedTimeControl = '5min';
  String _selectedColor = 'random';
  bool _isSearching = false;

  /// Drives MatchmakingService.tryMatch periodically while waiting - see
  /// that method's doc comment for why this has to be client-driven.
  Timer? _matchingTimer;

  @override
  void dispose() {
    _matchingTimer?.cancel();
    super.dispose();
  }

  void _startMatchingTimer(String queueId) {
    _matchingTimer?.cancel();
    _matchingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.read(matchmakingNotifierProvider.notifier).tryMatch(queueId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueStats = ref.watch(queueStatsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.matchmakingFindOpponentTitle),
        elevation: 0,
      ),
      body: _isSearching
          ? _buildSearchingState(context, l10n)
          : _buildInitialState(context, queueStats, l10n),
    );
  }

  /// Initial state: Show game options and start search
  Widget _buildInitialState(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> queueStats,
    AppLocalizations l10n,
  ) =>
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Time Control Selection
          _buildSectionTitle(l10n.matchmakingTimeControlSectionTitle),
          _buildTimeControlSelector(l10n),
          const SizedBox(height: 24),

          // Color Selection
          _buildSectionTitle(l10n.matchmakingPreferredColorSectionTitle),
          _buildColorSelector(l10n),
          const SizedBox(height: 24),

          // Queue Statistics
          _buildSectionTitle(l10n.matchmakingQueueStatusSectionTitle),
          queueStats.when(
            data: (stats) => _buildQueueStats(stats, l10n),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text(l10n.matchmakingErrorMessage(err.toString())),
          ),
          const SizedBox(height: 32),

          // Start Search Button
          ElevatedButton.icon(
            onPressed: _startSearch,
            icon: const Icon(Icons.search),
            label: Text(l10n.matchmakingFindOpponentButton),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );

  /// Searching state: Show spinner and match notification
  Widget _buildSearchingState(BuildContext context, AppLocalizations l10n) {
    if (_currentQueueId != null) {
      return _buildQueueWaitingState(context, l10n);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.matchmakingSearchingForOpponentMessage,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.matchmakingTimeControlLabel(_selectedTimeControl),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cancelSearch,
            icon: const Icon(Icons.close),
            label: Text(l10n.matchmakingCancelButton),
          ),
        ],
      ),
    );
  }

  /// Waiting for match state: Show queue entry status and wait time.
  /// Uses the live [queueEntryStreamProvider] (rather than the old
  /// one-shot [queueStatusProvider]) so it reacts the moment either
  /// side's `tryMatch` poll flips this entry to 'matched'.
  Widget _buildQueueWaitingState(BuildContext context, AppLocalizations l10n) {
    final entryAsync = ref.watch(queueEntryStreamProvider(_currentQueueId!));

    return entryAsync.when(
      data: (entry) {
        if (entry == null) {
          // Queue entry no longer exists (expired/cancelled elsewhere).
          return _buildErrorState(
              l10n.matchmakingEntryNoLongerExistsMessage, l10n);
        }

        // Previously nothing ever checked this - the "Waiting for
        // opponent..." spinner kept polling tryMatch indefinitely with
        // no feedback, even well past the 30s timeoutAt this entry was
        // created with.
        if (entry.status == 'waiting' && entry.isExpired) {
          return _buildTimedOutState(l10n);
        }

        if (entry.status == 'matched' && entry.matchedGameId != null) {
          // Game created, navigate to game screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _matchingTimer?.cancel();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => OnlineGameScreen(gameId: entry.matchedGameId!),
              ),
            );
          });
          return const SizedBox.shrink();
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.matchmakingWaitingForOpponentMessage,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _buildQueueWaitInfo(entry, l10n),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _cancelSearch,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.matchmakingCancelButton),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => _buildErrorState(err, l10n),
    );
  }

  /// Shown once the queue entry's own timeoutAt has passed with no match
  /// found - lets the player retry instead of staring at an endless
  /// spinner or needing to notice Cancel on their own.
  Widget _buildTimedOutState(AppLocalizations l10n) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                l10n.matchmakingNoOpponentFoundMessage,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.matchmakingNoOpponentAvailableMessage,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _cancelSearch,
                    icon: const Icon(Icons.close),
                    label: Text(l10n.matchmakingCancelButton),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _requeue,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.matchmakingTryAgainButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  /// Leaves the now-expired queue entry and immediately starts a fresh
  /// search, without popping the screen the way [_cancelSearch] does.
  Future<void> _requeue() async {
    _matchingTimer?.cancel();
    final queueId = _currentQueueId;
    if (queueId != null) {
      await ref.read(matchmakingNotifierProvider.notifier).leaveQueue(queueId);
    }
    if (!mounted) return;
    setState(() => _currentQueueId = null);
    await _startSearch();
  }

  /// Build queue wait information widget
  Widget _buildQueueWaitInfo(MatchmakingQueueEntry entry, AppLocalizations l10n) {
    final waitSeconds = entry.waitTimeSeconds;
    final minutes = waitSeconds ~/ 60;
    final seconds = waitSeconds % 60;

    return Column(
      children: [
        Text(
          l10n.matchmakingWaitTimeLabel(minutes, seconds),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            l10n.matchmakingSearchingRangeLabel(
                _getRatingRangeForWait(waitSeconds)),
            style: TextStyle(color: Colors.blue[900]),
          ),
        ),
      ],
    );
  }

  /// Get rating range expansion based on wait time
  String _getRatingRangeForWait(int waitSeconds) {
    if (waitSeconds < 10) return '50';
    if (waitSeconds < 20) return '100';
    if (waitSeconds < 30) return '200';
    return '300';
  }

  /// Build time control selector
  Widget _buildTimeControlSelector(AppLocalizations l10n) {
    final liveControls = ['3min', '5min', '10min'];
    // Correspondence controls (⑤ from this round's feature survey) - a
    // much larger shared time bank per side (see
    // OnlineGameService._parseTimeControl's own doc comment on how this
    // differs from a true per-move-replenishing correspondence clock),
    // for playing a move every so often over several days instead of
    // live. Grouped separately from the live controls above and
    // displayed with a day-aware label ('1day' -> '1 day') since they're
    // matched against each other by timeControlType exactly the same way
    // live controls are (MatchmakingService groups the queue by that
    // field), so mixing a live-control seeker with a correspondence one
    // would never pair them anyway.
    final correspondenceControls = ['1day', '3day', '7day'];

    Widget buildRow(List<String> controls) => Row(
          children: controls
              .map((control) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_timeControlLabel(control, l10n)),
                        selected: _selectedTimeControl == control,
                        onSelected: (selected) {
                          setState(() => _selectedTimeControl = control);
                        },
                      ),
                    ),
                  ))
              .toList(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildRow(liveControls),
        const SizedBox(height: 8),
        Text(
          l10n.matchmakingCorrespondenceLabel,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        buildRow(correspondenceControls),
      ],
    );
  }

  String _timeControlLabel(String control, AppLocalizations l10n) {
    if (control.endsWith('day')) {
      final days = control.substring(0, control.length - 3);
      return days == '1'
          ? l10n.matchmakingDayLabel(days)
          : l10n.matchmakingDaysLabel(days);
    }
    return control;
  }

  /// Build color selector
  Widget _buildColorSelector(AppLocalizations l10n) {
    final colors = ['white', 'black', 'random'];
    final labels = [
      l10n.matchmakingColorWhite,
      l10n.matchmakingColorBlack,
      l10n.matchmakingColorRandom,
    ];

    return Row(
      children: colors
          .asMap()
          .entries
          .map((entry) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(labels[entry.key]),
                    selected: _selectedColor == entry.value,
                    onSelected: (selected) {
                      setState(() => _selectedColor = entry.value);
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Build queue statistics widget
  Widget _buildQueueStats(Map<String, dynamic> stats, AppLocalizations l10n) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                l10n.matchmakingTotalWaitingLabel,
                (stats['totalWaiting'] as int? ?? 0).toString(),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(l10n.matchmakingByTimeControlLabel,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ...((stats['byTimeControl'] as Map<String, dynamic>?) ?? {})
                  .entries
                  .map((e) => _buildStatRow(e.key, e.value.toString())),
              const Divider(),
              const SizedBox(height: 8),
              _buildStatRow(
                l10n.matchmakingAvgWaitTimeLabel,
                '${(stats['avgWaitTimeSeconds'] as double? ?? 0).toStringAsFixed(0)}s',
              ),
            ],
          ),
        ),
      );

  /// Build individual stat row
  Widget _buildStatRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      );

  /// Build error state widget
  Widget _buildErrorState(Object error, AppLocalizations l10n) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(l10n.matchmakingErrorMessage(error.toString())),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cancelSearch,
              child: Text(l10n.matchmakingGoBackButton),
            ),
          ],
        ),
      );

  /// Build section title widget
  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );

  /// Start matchmaking search
  Future<void> _startSearch() async {
    final notifier = ref.read(matchmakingNotifierProvider.notifier);
    final auth = ref.read(firebaseAuthProvider);

    auth.whenData((user) async {
      if (user != null) {
        // FeatureGatingService's daily-limit system (DAILY_LIMITS
        // ['daily_games']) was fully implemented but, like the puzzle
        // side before it, had no caller anywhere - free-tier users
        // could join unlimited online-game queues. Checked here only
        // (the simplest, single "start a new game" entry point);
        // accepting a direct challenge (challenges_screen.dart) isn't
        // gated yet, left for a follow-up since it's a different flow.
        final canStart =
            await ref.read(canPerformActionProvider('daily_games').future);
        if (!canStart) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.matchmakingDailyLimitReachedMessage),
                // Direct conversion path right where the limit is hit,
                // instead of leaving the player to find PremiumScreen
                // on their own via Settings.
                action: SnackBarAction(
                  label: l10n.matchmakingUpgradeButton,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  ),
                ),
              ),
            );
          }
          return;
        }

        try {
          setState(() => _isSearching = true);

          final userProfile = ref.read(currentUserProvider).value;

          final entry = await notifier.joinQueue(
            playerId: user.uid,
            playerName: user.displayName ??
                AppLocalizations.of(context).matchmakingAnonymousFallbackName,
            // Online matchmaking is matched on the online rating track,
            // not the separate CPU-game `rating` field.
            currentRating: userProfile?.rating ?? 1500,
            timeControlType: _selectedTimeControl,
            color: _selectedColor,
          );

          await ref.read(trackActionUsageProvider('daily_games').future);

          setState(() => _currentQueueId = entry.queueId);
          _startMatchingTimer(entry.queueId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).matchmakingErrorMessage(
                    e.toString(),
                  ),
                ),
              ),
            );
            setState(() => _isSearching = false);
          }
        }
      }
    });
  }

  /// Cancel matchmaking search
  Future<void> _cancelSearch() async {
    _matchingTimer?.cancel();
    if (_currentQueueId != null) {
      final notifier = ref.read(matchmakingNotifierProvider.notifier);
      await notifier.leaveQueue(_currentQueueId!);
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _currentQueueId = null;
      });
      Navigator.pop(context);
    }
  }
}
