import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/phase_k_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../online/online_game_screen.dart';
import '../../../l10n/app_localizations.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingChallengesProvider);
    final pendingCount = pending.value?.length ?? 0;
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.challengesTitle),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(
                  text: pendingCount > 0
                      ? l10n.challengesPendingTabWithCount(pendingCount)
                      : l10n.challengesPendingTab),
              Tab(text: l10n.challengesActiveTab),
              Tab(text: l10n.challengesStreakTab),
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
    final l10n = AppLocalizations.of(context);

    return challenges.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.challengesErrorMessage(error.toString()))),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text(l10n.challengesNoPendingMessage));
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
                    ? l10n.challengesChallengedYouLabel(
                        challenge.challengerUsername)
                    : l10n.challengesWaitingOnLabel(
                        challenge.challengeeUsername)),
                subtitle: Text(challenge.timeControl),
                trailing: isIncoming
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: l10n.challengesAcceptTooltip,
                            onPressed: () => _accept(context, ref, challenge),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: l10n.challengesDeclineTooltip,
                            onPressed: () => ref
                                .read(challengeActionsProvider.notifier)
                                .rejectChallenge(challenge),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.challengesCancelTooltip,
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
    final l10n = AppLocalizations.of(context);

    return challenges.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.challengesErrorMessage(error.toString()))),
      data: (list) {
        if (list.isEmpty) {
          return Center(child: Text(l10n.challengesNoActiveMessage));
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
                title: Text(l10n.challengesVersusLabel(opponent)),
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
    final l10n = AppLocalizations.of(context);

    return streak.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.challengesErrorMessage(error.toString()))),
      data: (data) {
        if (data == null) {
          return Center(child: Text(l10n.challengesSignInToSeeStreakMessage));
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
                    Text(l10n.challengesCurrentStreakLabel(data.currentStreak)),
                    Text(l10n.challengesBestStreakLabel(data.bestStreak)),
                    Text(l10n.challengesRecordLabel(
                        data.totalChallengesWon, data.totalChallengesLost)),
                    Text(l10n.challengesWinRateLabel(
                        (data.winRate * 100).toStringAsFixed(0))),
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
