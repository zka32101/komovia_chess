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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TournamentCreateScreen()),
        ),
        tooltip: 'Create tournament',
        child: const Icon(Icons.add),
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
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.value?.name ?? 'Tournament'),
      ),
      body: tournament.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (data) {
          final isOrganizer = me != null && data.createdBy == me.uid;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(data, extras.value),
              const SizedBox(height: 24),
              if (isOrganizer) ...[
                _buildOrganizerActions(context, ref, data),
                const SizedBox(height: 24),
              ],
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
                data: (matchList) => _buildMatches(
                  context,
                  ref,
                  matchList,
                  isOrganizer: isOrganizer,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrganizerActions(
    BuildContext context,
    WidgetRef ref,
    Tournament tournament,
  ) {
    if (tournament.isUpcoming) {
      return FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Tournament'),
        onPressed: () async {
          await ref
              .read(tournamentActionsProvider.notifier)
              .startTournament(tournament.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bracket generated')),
            );
          }
        },
      );
    }

    // Shown for an in-progress tournament (manual early finish) and also
    // for one whose bracket already completed on its own - the bracket
    // auto-completing now pays prizes automatically too (see
    // TournamentService._advanceRoundIfComplete), but this stays as a
    // manual retry path for the rare case that automatic payout failed
    // (e.g. a transient Firestore error). distributePrizes is idempotent
    // either way, so pressing it again when prizes were already paid is
    // a harmless no-op.
    if (tournament.isActive || tournament.isCompleted) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.emoji_events),
        label: Text(
          tournament.isActive
              ? 'Finish & Distribute Prizes'
              : 'Distribute Prizes',
        ),
        onPressed: () async {
          await ref
              .read(tournamentActionsProvider.notifier)
              .finishTournament(tournament.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tournament finished')),
            );
          }
        },
      );
    }

    return const SizedBox.shrink();
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

  Widget _buildMatches(
    BuildContext context,
    WidgetRef ref,
    List<TournamentMatch> matches, {
    required bool isOrganizer,
  }) {
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

                final canRecordResult = isOrganizer &&
                    match.status == 'pending' &&
                    !match.isBye &&
                    match.player2Uid != null;

                return ListTile(
                  dense: true,
                  title: Text('$p1 vs $p2'),
                  trailing: canRecordResult
                      ? TextButton(
                          onPressed: () => _showRecordResultDialog(
                            context,
                            ref,
                            match,
                            p1Name: p1,
                            p2Name: p2,
                          ),
                          child: const Text('Record result'),
                        )
                      : Text(
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

  Future<void> _showRecordResultDialog(
    BuildContext context,
    WidgetRef ref,
    TournamentMatch match, {
    required String p1Name,
    required String p2Name,
  }) async {
    final winnerUid = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Who won?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, match.player1Uid),
            child: Text(p1Name),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, match.player2Uid),
            child: Text(p2Name),
          ),
        ],
      ),
    );

    if (winnerUid == null || !context.mounted) return;

    final loserUid =
        winnerUid == match.player1Uid ? match.player2Uid : match.player1Uid;
    if (loserUid == null) return;

    await ref.read(tournamentActionsProvider.notifier).recordMatchResult(
          tournamentId: match.tournamentId,
          matchId: match.id,
          winnerId: winnerUid,
          loserId: loserUid,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result recorded')),
      );
    }
  }
}

/// Create a new tournament (single-elimination only - see
/// TournamentActionsNotifier.createTournament's doc comment for why
/// round_robin/swiss aren't offered here).
class TournamentCreateScreen extends ConsumerStatefulWidget {
  const TournamentCreateScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TournamentCreateScreen> createState() =>
      _TournamentCreateScreenState();
}

class _TournamentCreateScreenState
    extends ConsumerState<TournamentCreateScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeControlController = TextEditingController(text: '10+0');
  final _entryFeeController = TextEditingController(text: '0');
  final _prizePoolController = TextEditingController(text: '0');
  // Max participants was a free-text number field with no bracket-size
  // guidance - a single-elimination bracket only resolves cleanly for a
  // power-of-two-ish field (generateBracket's bye handling covers odd
  // counts, but an arbitrary number like 11 produces lopsided byes
  // every round). ChoiceChips steer organizers toward the sizes this
  // app's bracket logic is actually designed for.
  int _maxParticipants = 8;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _timeControlController.dispose();
    _entryFeeController.dispose();
    _prizePoolController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      // The end date previously had no UI to change at all and could
      // silently end up before a newly-picked start date - keep it at
      // least a day after start.
      if (!_endDate.isAfter(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 6));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final tournament =
        await ref.read(tournamentActionsProvider.notifier).createTournament(
              name: name,
              description: _descriptionController.text.trim(),
              maxParticipants: _maxParticipants,
              timeControl: _timeControlController.text.trim(),
              entryFee: int.tryParse(_entryFeeController.text) ?? 0,
              prizePool: int.tryParse(_prizePoolController.text) ?? 0,
              startDate: _startDate,
              endDate: _endDate,
            );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (tournament != null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create tournament')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Tournament')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text('Max participants',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [4, 8, 16, 32].map((size) {
                  return ChoiceChip(
                    label: Text('$size'),
                    selected: _maxParticipants == size,
                    onSelected: (_) =>
                        setState(() => _maxParticipants = size),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start date'),
                      subtitle: Text(_formatDate(_startDate)),
                      onTap: _pickStartDate,
                      trailing: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End date'),
                      subtitle: Text(_formatDate(_endDate)),
                      onTap: _pickEndDate,
                      trailing: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeControlController,
                decoration: const InputDecoration(labelText: 'Time control'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _entryFeeController,
                decoration: const InputDecoration(labelText: 'Entry fee'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prizePoolController,
                decoration: const InputDecoration(labelText: 'Prize pool'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _create,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      );
}
