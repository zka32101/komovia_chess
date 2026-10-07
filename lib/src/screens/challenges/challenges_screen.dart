import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/phase_k_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../online/online_game_screen.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingChallengesProvider);
    final pendingCount = pending.value?.length ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Challenges'),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(
                  text:
                      pendingCount > 0 ? 'Pending ($pendingCount)' : 'Pending'),
              const Tab(text: 'Active'),
              const Tab(text: 'Streak'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingChallengesTab(),
            _ActiveChallengesTab(),
            _StreakTab(),
          ],
        ),
      ),
    );
  }
}

class _PendingChallengesTab extends ConsumerWidget {
  const _PendingChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(pendingChallengesProvider);
    final me = ref.watch(currentUserProvider).value;

    return challenges.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No pending challenges'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final challenge = list[index];
            final isIncoming =
                me != null && challenge.challengeeUserId == me.uid;

            return Card(
              child: ListTile(
                title: Text(isIncoming
                    ? '${challenge.challengerUsername} challenged you'
                    : 'Waiting on ${challenge.challengeeUsername}'),
                subtitle: Text(
                  '${challenge.timeControl}'
                  '${challenge.wagerPoints > 0 ? ' · ${challenge.wagerPoints} pts wager' : ''}',
                ),
                trailing: isIncoming
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: 'Accept',
                            onPressed: () => _accept(context, ref, challenge),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'Decline',
                            onPressed: () => ref
                                .read(challengeActionsProvider.notifier)
                                .rejectChallenge(challenge),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel',
                        onPressed: () => ref
                            .read(challengeActionsProvider.notifier)
                            .cancelChallenge(challenge),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
  ) async {
    final gameId = await ref
        .read(challengeActionsProvider.notifier)
        .acceptChallenge(challenge);
    if (gameId != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OnlineGameScreen(gameId: gameId)),
      );
    }
  }
}

class _ActiveChallengesTab extends ConsumerWidget {
  const _ActiveChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(activeChallengesProvider);
    final me = ref.watch(currentUserProvider).value;

    return challenges.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No active challenges'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final challenge = list[index];
            final opponent = me != null && challenge.challengerUserId == me.uid
                ? challenge.challengeeUsername
                : challenge.challengerUsername;

            return Card(
              child: ListTile(
                title: Text('vs $opponent'),
                subtitle: Text(challenge.timeControl),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: challenge.gameId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                OnlineGameScreen(gameId: challenge.gameId!),
                          ),
                        ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StreakTab extends ConsumerWidget {
  const _StreakTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(userChallengeStreakProvider);

    return streak.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (data) {
        if (data == null) {
          return const Center(child: Text('Sign in to see your streak'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current streak: ${data.currentStreak}'),
                    Text('Best streak: ${data.bestStreak}'),
                    Text(
                        'Record: ${data.totalChallengesWon}W - ${data.totalChallengesLost}L'),
                    Text(
                        'Win rate: ${(data.winRate * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
