import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/phase_u_providers.dart';
import '../services/season_management_service.dart';
import '../services/battle_pass_service.dart';
import '../services/season_challenge_service.dart';
import '../services/seasonal_event_service.dart';

/// Season Progress Display Widget
class SeasonProgressCard extends ConsumerWidget {
  const SeasonProgressCard({
    required this.playerId,
    required this.seasonId,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(seasonByIdProvider(seasonId));
    final progressAsync = ref.watch(playerSeasonProgressProvider(playerId));

    return seasonAsync.when(
      data: (season) => progressAsync.when(
        data: (progress) => _buildSeasonCard(context, ref, season, progress),
        loading: () => const SeasonLoadingWidget(),
        error: (e, st) => SeasonErrorWidget(error: e.toString()),
      ),
      loading: () => const SeasonLoadingWidget(),
      error: (e, st) => SeasonErrorWidget(error: e.toString()),
    );
  }

  Widget _buildSeasonCard(
    BuildContext context,
    WidgetRef ref,
    Season? season,
    PlayerSeasonProgress? progress,
  ) {
    if (season == null || progress == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Season data unavailable'),
        ),
      );
    }

    final daysRemaining = season.endDate.difference(DateTime.now()).inDays;
    final progressPercent =
        (progress.currentLevel / season.maxLevel * 100).clamp(0, 100).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Level ${progress.currentLevel}/${season.maxLevel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$daysRemaining',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'days left',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$progressPercent% complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              season.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Battle Pass Progression Widget
class BattlePassProgressCard extends ConsumerWidget {
  const BattlePassProgressCard({
    required this.playerId,
    required this.seasonId,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(
      playerBattlePassProvider(
        SeasonChallengesParams(playerId: playerId, seasonId: seasonId),
      ),
    );
    final currentBPAsync = ref.watch(currentBattlePassProvider);
    final claimedFreeAsync = ref.watch(
      claimedBattlePassRewardsProvider(
        BattlePassRewardsParams(
          playerId: playerId,
          seasonId: seasonId,
          isPremium: false,
        ),
      ),
    );
    final claimedPremiumAsync = ref.watch(
      claimedBattlePassRewardsProvider(
        BattlePassRewardsParams(
          playerId: playerId,
          seasonId: seasonId,
          isPremium: true,
        ),
      ),
    );

    return progressAsync.when(
      data: (progress) => currentBPAsync.when(
        data: (bp) => claimedFreeAsync.when(
          data: (freeRewards) => claimedPremiumAsync.when(
            data: (premiumRewards) => _buildBattlePassCard(
              context,
              progress,
              bp,
              freeRewards,
              premiumRewards,
            ),
            loading: () => const BattlePassLoadingWidget(),
            error: (e, st) => BattlePassErrorWidget(error: e.toString()),
          ),
          loading: () => const BattlePassLoadingWidget(),
          error: (e, st) => BattlePassErrorWidget(error: e.toString()),
        ),
        loading: () => const BattlePassLoadingWidget(),
        error: (e, st) => BattlePassErrorWidget(error: e.toString()),
      ),
      loading: () => const BattlePassLoadingWidget(),
      error: (e, st) => BattlePassErrorWidget(error: e.toString()),
    );
  }

  Widget _buildBattlePassCard(
    BuildContext context,
    PlayerBattlePassProgress? progress,
    BattlePass? bp,
    List<int> freeRewards,
    List<int> premiumRewards,
  ) {
    if (progress == null || bp == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Battle pass data unavailable'),
        ),
      );
    }

    final progressPercent = (progress.currentLevel / bp.maxLevel * 100).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bp.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: progress.hasPremiumPass ? Colors.amber : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    progress.hasPremiumPass ? 'Premium' : 'Free',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Level ${progress.currentLevel}/${bp.maxLevel}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPercent / 100,
                minHeight: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.currentExperience}/${bp.experiencePerLevel} XP',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Claimed Rewards',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free: ${freeRewards.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium: ${premiumRewards.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Challenge Tracker Widget
class ChallengeTrackerCard extends ConsumerWidget {
  // daily, weekly, seasonal, event

  const ChallengeTrackerCard({
    required this.playerId,
    required this.seasonId,
    Key? key,
    this.challengeType,
  }) : super(key: key);
  final String playerId;
  final String seasonId;
  final String? challengeType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(
      activeChallengesProvider(
        ChallengesParams(seasonId: seasonId, type: challengeType),
      ),
    );

    return challengesAsync.when(
      data: (challenges) => _buildChallengeList(context, ref, challenges),
      loading: () => const ChallengeLoadingWidget(),
      error: (e, st) => ChallengeErrorWidget(error: e.toString()),
    );
  }

  Widget _buildChallengeList(
    BuildContext context,
    WidgetRef ref,
    List<Challenge> challenges,
  ) {
    if (challenges.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No active challenges',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Challenges',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ...challenges.take(5).map(
                  (challenge) => _buildChallengeItem(context, ref, challenge),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeItem(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
  ) {
    final progressAsync = ref.watch(
      playerChallengeProgressProvider(
        PlayerChallengeParams(
          playerId: playerId,
          challengeId: challenge.challengeId,
        ),
      ),
    );

    return progressAsync.when(
      data: (progress) {
        final progressPercent = progress != null
            ? ((progress.currentProgress / progress.targetProgress) * 100)
                .clamp(0, 100)
                .toInt()
            : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            challenge.objective,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(challenge.difficulty),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        challenge.difficulty,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent / 100,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${progress?.currentProgress ?? 0}/'
                  '${progress?.targetProgress ?? challenge.target}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Error loading challenge',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Event Leaderboard Widget
class EventLeaderboardCard extends ConsumerWidget {
  const EventLeaderboardCard({
    required this.eventId,
    Key? key,
    this.limit = 10,
  }) : super(key: key);
  final String eventId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(
      eventLeaderboardProvider(
        EventLeaderboardParams(eventId: eventId, limit: limit),
      ),
    );

    return leaderboardAsync.when(
      data: (entries) => _buildLeaderboard(context, entries),
      loading: () => const EventLoadingWidget(),
      error: (e, st) => EventErrorWidget(error: e.toString()),
    );
  }

  Widget _buildLeaderboard(
    BuildContext context,
    List<EventLeaderboardEntry> entries,
  ) {
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No leaderboard data',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Leaderboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map((e) {
              final index = e.key;
              final entry = e.value;
              return _buildLeaderboardEntry(context, index, entry);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardEntry(
    BuildContext context,
    int index,
    EventLeaderboardEntry entry,
  ) {
    final medals = ['🥇', '🥈', '🥉'];
    final medal = index < 3 ? medals[index] : '${index + 1}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          Text(
            entry.score.toString(),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Season Statistics Widget
class SeasonStatisticsCard extends ConsumerWidget {
  const SeasonStatisticsCard({
    required this.playerId,
    required this.seasonId,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(playerSeasonProgressProvider(playerId));
    final challengesAsync = ref.watch(
      playerSeasonChallengesProvider(
        SeasonChallengesParams(playerId: playerId, seasonId: seasonId),
      ),
    );

    return progressAsync.when(
      data: (progress) => challengesAsync.when(
        data: (challenges) => _buildStatistics(context, progress, challenges),
        loading: () => const StatisticsLoadingWidget(),
        error: (e, st) => StatisticsErrorWidget(error: e.toString()),
      ),
      loading: () => const StatisticsLoadingWidget(),
      error: (e, st) => StatisticsErrorWidget(error: e.toString()),
    );
  }

  Widget _buildStatistics(
    BuildContext context,
    PlayerSeasonProgress? progress,
    List<PlayerChallengeProgress> challenges,
  ) {
    if (progress == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Statistics unavailable'),
        ),
      );
    }

    final completedChallenges = challenges.where((c) => c.isCompleted).length;
    final totalChallenges = challenges.length;
    final completionRate = totalChallenges > 0
        ? ((completedChallenges / totalChallenges) * 100).toInt()
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season Statistics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              context,
              'Current Level',
              progress.currentLevel.toString(),
              Icons.trending_up,
            ),
            _buildStatRow(
              context,
              'Total Experience',
              progress.totalExperience.toString(),
              Icons.star,
            ),
            _buildStatRow(
              context,
              'Season Rating',
              progress.seasonRating.toString(),
              Icons.grade,
            ),
            _buildStatRow(
              context,
              'Challenges Completed',
              '$completedChallenges/$totalChallenges ($completionRate%)',
              Icons.check_circle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}

/// Loading and Error Widgets

class SeasonLoadingWidget extends StatelessWidget {
  const SeasonLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
}

class SeasonErrorWidget extends StatelessWidget {
  const SeasonErrorWidget({required this.error, Key? key}) : super(key: key);
  final String error;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      );
}

class BattlePassLoadingWidget extends StatelessWidget {
  const BattlePassLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
}

class BattlePassErrorWidget extends StatelessWidget {
  const BattlePassErrorWidget({required this.error, Key? key})
      : super(key: key);
  final String error;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      );
}

class ChallengeLoadingWidget extends StatelessWidget {
  const ChallengeLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
}

class ChallengeErrorWidget extends StatelessWidget {
  const ChallengeErrorWidget({required this.error, Key? key}) : super(key: key);
  final String error;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      );
}

class EventLoadingWidget extends StatelessWidget {
  const EventLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
}

class EventErrorWidget extends StatelessWidget {
  const EventErrorWidget({required this.error, Key? key}) : super(key: key);
  final String error;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      );
}

class StatisticsLoadingWidget extends StatelessWidget {
  const StatisticsLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
}

class StatisticsErrorWidget extends StatelessWidget {
  const StatisticsErrorWidget({required this.error, Key? key})
      : super(key: key);
  final String error;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      );
}
