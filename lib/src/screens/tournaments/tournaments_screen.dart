import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../../models/phase_k_models.dart' show TournamentRanking;
import '../../providers/auth_provider.dart';
import '../../providers/tournament_provider.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(activeTournamentsProvider);
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        centerTitle: true,
      ),
      body: tournaments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active tournaments right now.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tournament = list[index];
              final isRegistered =
                  me != null && tournament.participantUids.contains(me.uid);

              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TournamentDetailScreen(
                        tournamentId: tournament.id,
                      ),
                    ),
                  ),
                  title: Text(tournament.name),
                  subtitle: Text(
                    '${tournament.format} · '
                    '${tournament.participantUids.length}/${tournament.maxParticipants} players',
                  ),
                  trailing: _buildActionWidget(
                    context,
                    ref,
                    tournament,
                    isRegistered: isRegistered,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionWidget(
    BuildContext context,
    WidgetRef ref,
    Tournament tournament, {
    required bool isRegistered,
  }) {
    if (isRegistered) {
      return const Chip(
        avatar: Icon(Icons.check, size: 16),
        label: Text('Registered'),
      );
    }

    if (!tournament.isUpcoming) {
      return Chip(label: Text(tournament.status));
    }

    if (tournament.isFull) {
      return const Chip(label: Text('Full'));
    }

    return FilledButton(
      onPressed: () async {
        await ref.read(tournamentActionsProvider.notifier).register(
              tournament,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registered for ${tournament.name}')),
          );
        }
      },
      child: const Text('Register'),
    );
  }
}

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({Key? key, required this.tournamentId})
      : super(key: key);

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentDetailsProvider(tournamentId));
    final extras = ref.watch(tournamentExtrasProvider(tournamentId));
    final standings = ref.watch(tournamentStandingsProvider(tournamentId));
    final matches = ref.watch(tournamentMatchesProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.value?.name ?? 'Tournament'),
      ),
      body: tournament.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(data, extras.value),
              const SizedBox(height: 24),
              Text('Standings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              standings.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error: $error'),
                data: (data) => _buildStandings(data),
              ),
              const SizedBox(height: 24),
              Text('Matches', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              matches.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error: $error'),
                data: (data) => _buildMatches(data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Tournament tournament, Map<String, dynamic>? extras) {
    final timeControl = extras?['timeControl'] as String? ?? '';
    final prizePool = extras?['prizePool'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tournament.description),
            const SizedBox(height: 8),
            Text('Format: ${tournament.format}'),
            if (timeControl.isNotEmpty) Text('Time control: $timeControl'),
            Text(
              'Participants: ${tournament.participantUids.length}/${tournament.maxParticipants}',
            ),
            if (prizePool > 0) Text('Prize pool: $prizePool'),
          ],
        ),
      ),
    );
  }

  Widget _buildStandings(List<TournamentRanking> rankings) {
    if (rankings.isEmpty) {
      return const Text('No participants yet.');
    }

    return Column(
      children: rankings
          .map((r) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${r.position}'),
                ),
                title: Text(r.username),
                trailing: Text(
                  '${r.points} pts · ${r.wins}W-${r.losses}L-${r.draws}D',
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMatches(List<TournamentMatch> matches) {
    if (matches.isEmpty) {
      return const Text('No matches scheduled yet.');
    }

    String nameFor(String? uid, String? displayName) =>
        displayName ?? uid?.substring(0, uid.length.clamp(0, 8)) ?? 'TBD';

    final byRound = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: byRound.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Round ${entry.key}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ...entry.value.map((match) {
                final p1 = nameFor(match.player1Uid, match.player1DisplayName);
                final p2 = match.isBye
                    ? 'Bye'
                    : nameFor(match.player2Uid, match.player2DisplayName);
                final winnerName = match.winnerUid != null
                    ? nameFor(
                        match.winnerUid,
                        match.winnerUid == match.player1Uid
                            ? match.player1DisplayName
                            : match.player2DisplayName,
                      )
                    : null;

                return ListTile(
                  dense: true,
                  title: Text('$p1 vs $p2'),
                  trailing: Text(
                    match.isCompleted && winnerName != null
                        ? '$winnerName won'
                        : match.status,
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}
