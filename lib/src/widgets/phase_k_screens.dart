import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/phase_k_providers.dart';

// ========== Leaderboard Screen ==========

class GlobalLeaderboardScreen extends ConsumerWidget {
  const GlobalLeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(globalLeaderboardProvider(100));

    return leaderboard.when(
      data: (entries) => ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            leading: Text('${entry.rank}'),
            title: Text(entry.username),
            subtitle: Text('${entry.rating} • ${entry.wins}W ${entry.losses}L'),
            trailing: Text('${entry.winRate.toStringAsFixed(2)}%'),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// ========== Friends Screen ==========

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const userId = ''; // TODO: Get from auth
    final friends = ref.watch(userFriendsProvider(userId));

    return friends.when(
      data: (friendsList) => ListView.builder(
        itemCount: friendsList.length,
        itemBuilder: (context, index) {
          final friend = friendsList[index];
          return ListTile(
            leading: CircleAvatar(child: Text(friend.friendUsername[0])),
            title: Text(friend.friendUsername),
            subtitle: Text('Rating: ${friend.friendRating}'),
            trailing:
                Icon(friend.isOnline ? Icons.circle : Icons.circle_outlined),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// ========== Challenges Screen ==========

class PendingChallengesScreen extends ConsumerWidget {
  const PendingChallengesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const userId = ''; // TODO: Get from auth
    final challenges = ref.watch(pendingChallengesProvider(userId));

    return challenges.when(
      data: (challengesList) => ListView.builder(
        itemCount: challengesList.length,
        itemBuilder: (context, index) {
          final challenge = challengesList[index];
          return Card(
            child: ListTile(
              title: Text('Challenge from ${challenge.challengerUsername}'),
              subtitle: Text(
                  '${challenge.timeControl} • ${challenge.wagerPoints} points'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      // TODO: Accept challenge
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      // TODO: Reject challenge
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// ========== Challenge Streaks Screen ==========

class ChallengeStreaksScreen extends ConsumerWidget {
  const ChallengeStreaksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topStreaks = ref.watch(topChallengeStreaksProvider);

    return topStreaks.when(
      data: (streaks) => ListView.builder(
        itemCount: streaks.length,
        itemBuilder: (context, index) {
          final streak = streaks[index];
          return ListTile(
            leading: Text('${index + 1}'),
            title: Text('${streak.currentStreak} streak'),
            subtitle: Text(
                '${streak.totalChallengesWon}W ${streak.totalChallengesLost}L'),
            trailing: Text('${(streak.winRate * 100).toStringAsFixed(1)}%'),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// ========== Tournaments Screen ==========

class TournamentsListScreen extends ConsumerWidget {
  const TournamentsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(activeTournamentsProvider);

    return tournaments.when(
      data: (tournamentsList) => ListView.builder(
        itemCount: tournamentsList.length,
        itemBuilder: (context, index) {
          final tournament = tournamentsList[index];
          return Card(
            child: ListTile(
              title: Text(tournament.name),
              subtitle: Text(
                  '${tournament.currentParticipants}/${tournament.maxParticipants} • ${tournament.format}'),
              trailing: Chip(
                label: Text(tournament.status),
                backgroundColor: tournament.status == 'registration'
                    ? Colors.blue
                    : Colors.green,
              ),
              onTap: () {
                // TODO: Navigate to tournament details
              },
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// ========== Tournament Details Screen ==========

class TournamentDetailsScreen extends ConsumerWidget {
  const TournamentDetailsScreen({
    required this.tournamentId,
    Key? key,
  }) : super(key: key);
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentDetailsProvider(tournamentId));
    final standings = ref.watch(tournamentStandingsProvider(tournamentId));

    return tournament.when(
      data: (tournamentData) => standings.when(
        data: (standingsData) => CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(tournamentData.name),
              pinned: true,
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${tournamentData.currentParticipants}/${tournamentData.maxParticipants} Participants'),
                      const SizedBox(height: 16),
                      const Text('Standings'),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: standingsData.rankings.length,
                        itemBuilder: (context, index) {
                          final ranking = standingsData.rankings[index];
                          return ListTile(
                            leading: Text('${ranking.position}'),
                            title: Text(ranking.username),
                            subtitle: Text(
                                '${ranking.wins}W ${ranking.losses}L ${ranking.draws}D'),
                            trailing: Text('${ranking.points} pts'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// ========== Social Stats Widget ==========

class SocialStatsWidget extends ConsumerWidget {
  const SocialStatsWidget({
    required this.userId,
    Key? key,
  }) : super(key: key);
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userSocialStatsProvider(userId));

    return stats.when(
      data: (socialStats) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn('Friends', '${socialStats.friendsCount}'),
                  _StatColumn('Rank', '#${socialStats.globalRank}'),
                  _StatColumn('Rating', '${socialStats.currentRating}'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                      'Challenges', '${socialStats.activeChallengesCount}'),
                  _StatColumn('Win Rate',
                      '${(socialStats.winRate * 100).toStringAsFixed(1)}%'),
                  _StatColumn(
                      'Requests', '${socialStats.pendingRequestsCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
      loading: () => const Skeleton(),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

// ========== Skeleton Loader ==========

class Skeleton extends StatelessWidget {
  const Skeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
}
