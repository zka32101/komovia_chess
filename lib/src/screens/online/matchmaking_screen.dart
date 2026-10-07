import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import 'online_game_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final queueStats = ref.watch(queueStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Opponent'),
        elevation: 0,
      ),
      body: _isSearching
          ? _buildSearchingState(context)
          : _buildInitialState(context, queueStats),
    );
  }

  /// Initial state: Show game options and start search
  Widget _buildInitialState(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> queueStats,
  ) =>
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Time Control Selection
          _buildSectionTitle('Time Control'),
          _buildTimeControlSelector(),
          const SizedBox(height: 24),

          // Color Selection
          _buildSectionTitle('Preferred Color'),
          _buildColorSelector(),
          const SizedBox(height: 24),

          // Queue Statistics
          _buildSectionTitle('Queue Status'),
          queueStats.when(
            data: _buildQueueStats,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text('Error: $err'),
          ),
          const SizedBox(height: 32),

          // Start Search Button
          ElevatedButton.icon(
            onPressed: _startSearch,
            icon: const Icon(Icons.search),
            label: const Text('Find Opponent'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );

  /// Searching state: Show spinner and match notification
  Widget _buildSearchingState(BuildContext context) {
    if (_currentQueueId != null) {
      return _buildQueueWaitingState(context);
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
          const Text(
            'Searching for opponent...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Time Control: $_selectedTimeControl',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cancelSearch,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Waiting for match state: Show queue entry status and wait time
  Widget _buildQueueWaitingState(BuildContext context) {
    final queueStatus = ref.watch(queueStatusProvider(_currentQueueId!));

    return queueStatus.when(
      data: (status) {
        if (status['status'] == 'matched') {
          // Game created, navigate to game screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => OnlineGameScreen(
                  gameId: status['matchedGameId'] as String,
                ),
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
                const Text(
                  'Waiting for opponent...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _buildQueueWaitInfo(status),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _cancelSearch,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => _buildErrorState(err),
    );
  }

  /// Build queue wait information widget
  Widget _buildQueueWaitInfo(Map<String, dynamic> status) {
    final waitSeconds = status['waitTimeSeconds'] as int? ?? 0;
    final minutes = waitSeconds ~/ 60;
    final seconds = waitSeconds % 60;

    return Column(
      children: [
        Text(
          'Wait Time: ${minutes}m ${seconds}s',
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
            'Searching: ±${_getRatingRangeForWait(waitSeconds)}',
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
  Widget _buildTimeControlSelector() {
    final controls = ['3min', '5min', '10min'];

    return Row(
      children: controls
          .map((control) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(control),
                    selected: _selectedTimeControl == control,
                    onSelected: (selected) {
                      setState(() => _selectedTimeControl = control);
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Build color selector
  Widget _buildColorSelector() {
    final colors = ['white', 'black', 'random'];
    final labels = ['White', 'Black', 'Random'];

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
  Widget _buildQueueStats(Map<String, dynamic> stats) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                'Total Waiting',
                (stats['totalWaiting'] as int? ?? 0).toString(),
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('By Time Control:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ...((stats['byTimeControl'] as Map<String, dynamic>?) ?? {})
                  .entries
                  .map((e) => _buildStatRow(e.key, e.value.toString())),
              const Divider(),
              const SizedBox(height: 8),
              _buildStatRow(
                'Avg Wait Time',
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
  Widget _buildErrorState(Object error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cancelSearch,
              child: const Text('Go Back'),
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
        try {
          setState(() => _isSearching = true);

          final userProfile = ref.read(currentUserProvider).value;

          final entry = await notifier.joinQueue(
            playerId: user.uid,
            playerName: user.displayName ?? 'Anonymous',
            currentRating: userProfile?.rating ?? 1500,
            timeControlType: _selectedTimeControl,
            color: _selectedColor,
          );

          setState(() => _currentQueueId = entry.queueId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
            setState(() => _isSearching = false);
          }
        }
      }
    });
  }

  /// Cancel matchmaking search
  Future<void> _cancelSearch() async {
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
