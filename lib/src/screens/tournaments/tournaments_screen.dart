import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../../models/phase_k_models.dart' show TournamentRanking;
import '../../providers/auth_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../../l10n/app_localizations.dart';

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(activeTournamentsProvider);
    final me = ref.watch(currentUserProvider).value;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tournamentsTitle),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TournamentCreateScreen()),
        ),
        tooltip: l10n.tournamentsCreateTooltip,
        child: const Icon(Icons.add),
      ),
      body: tournaments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.tournamentsErrorMessage(error.toString()))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.tournamentsNoActiveTournamentsMessage),
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
                    l10n.tournamentsFormatAndPlayersLabel(
                      tournament.format,
                      tournament.participantUids.length,
                      tournament.maxParticipants,
                    ),
                  ),
                  trailing: _buildActionWidget(
                    context,
                    ref,
                    tournament,
                    isRegistered: isRegistered,
                    l10n: l10n,
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
    required AppLocalizations l10n,
  }) {
    if (isRegistered) {
      return Chip(
        avatar: const Icon(Icons.check, size: 16),
        label: Text(l10n.tournamentsRegisteredChip),
      );
    }

    if (!tournament.isUpcoming) {
      return Chip(label: Text(tournament.status));
    }

    if (tournament.isFull) {
      return Chip(label: Text(l10n.tournamentsFullChip));
    }

    return FilledButton(
      onPressed: () async {
        await ref.read(tournamentActionsProvider.notifier).register(
              tournament,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.tournamentsRegisteredForMessage(tournament.name),
              ),
            ),
          );
        }
      },
      child: Text(l10n.tournamentsRegisterButton),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tournament.value?.name ?? l10n.tournamentsFallbackTitle),
      ),
      body: tournament.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.tournamentsErrorMessage(error.toString()))),
        data: (data) {
          final isOrganizer = me != null && data.createdBy == me.uid;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(data, extras.value, l10n),
              const SizedBox(height: 24),
              if (isOrganizer) ...[
                _buildOrganizerActions(context, ref, data, l10n),
                const SizedBox(height: 24),
              ],
              Text(l10n.tournamentsStandingsHeading,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              standings.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Text(l10n.tournamentsErrorMessage(error.toString())),
                data: (data) => _buildStandings(data, l10n),
              ),
              const SizedBox(height: 24),
              Text(l10n.tournamentsMatchesHeading,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              matches.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Text(l10n.tournamentsErrorMessage(error.toString())),
                data: (matchList) => _buildMatches(
                  context,
                  ref,
                  matchList,
                  isOrganizer: isOrganizer,
                  l10n: l10n,
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
    AppLocalizations l10n,
  ) {
    if (tournament.isUpcoming) {
      return FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.tournamentsStartTournamentButton),
        onPressed: () async {
          await ref
              .read(tournamentActionsProvider.notifier)
              .startTournament(tournament.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.tournamentsBracketGeneratedMessage)),
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
              ? l10n.tournamentsFinishAndDistributePrizesButton
              : l10n.tournamentsDistributePrizesButton,
        ),
        onPressed: () async {
          await ref
              .read(tournamentActionsProvider.notifier)
              .finishTournament(tournament.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.tournamentsFinishedMessage)),
            );
          }
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHeader(
    Tournament tournament,
    Map<String, dynamic>? extras,
    AppLocalizations l10n,
  ) {
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
            Text(l10n.tournamentsFormatLabel(tournament.format)),
            if (timeControl.isNotEmpty)
              Text(l10n.tournamentsTimeControlLabel(timeControl)),
            Text(
              l10n.tournamentsParticipantsLabel(
                tournament.participantUids.length,
                tournament.maxParticipants,
              ),
            ),
            if (prizePool > 0)
              Text(l10n.tournamentsPrizePoolLabel(prizePool)),
          ],
        ),
      ),
    );
  }

  Widget _buildStandings(
    List<TournamentRanking> rankings,
    AppLocalizations l10n,
  ) {
    if (rankings.isEmpty) {
      return Text(l10n.tournamentsNoParticipantsYetMessage);
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
                  l10n.tournamentsPointsAndRecordLabel(
                    r.points,
                    r.wins,
                    r.losses,
                    r.draws,
                  ),
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
    required AppLocalizations l10n,
  }) {
    if (matches.isEmpty) {
      return Text(l10n.tournamentsNoMatchesScheduledMessage);
    }

    String nameFor(String? uid, String? displayName) =>
        displayName ??
        uid?.substring(0, uid.length.clamp(0, 8)) ??
        l10n.tournamentsTbdLabel;

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
              Text(l10n.tournamentsRoundLabel(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ...entry.value.map((match) {
                final p1 = nameFor(match.player1Uid, match.player1DisplayName);
                final p2 = match.isBye
                    ? l10n.tournamentsByeLabel
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
                  title: Text(l10n.tournamentsVersusLabel(p1, p2)),
                  trailing: canRecordResult
                      ? TextButton(
                          onPressed: () => _showRecordResultDialog(
                            context,
                            ref,
                            match,
                            p1Name: p1,
                            p2Name: p2,
                            l10n: l10n,
                          ),
                          child: Text(l10n.tournamentsRecordResultButton),
                        )
                      : Text(
                          match.isCompleted && winnerName != null
                              ? l10n.tournamentsWonLabel(winnerName)
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
    required AppLocalizations l10n,
  }) async {
    final winnerUid = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.tournamentsWhoWonTitle),
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
        SnackBar(content: Text(l10n.tournamentsResultRecordedMessage)),
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
              prizePool: int.tryParse(_prizePoolController.text) ?? 0,
              startDate: _startDate,
              endDate: _endDate,
            );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (tournament != null) {
      Navigator.of(context).pop();
    } else {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tournamentsCreateFailedMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tournamentsCreateTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.tournamentsNameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration:
                  InputDecoration(labelText: l10n.tournamentsDescriptionLabel),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(l10n.tournamentsMaxParticipantsLabel,
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [4, 8, 16, 32].map((size) {
                return ChoiceChip(
                  label: Text('$size'),
                  selected: _maxParticipants == size,
                  onSelected: (_) => setState(() => _maxParticipants = size),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.tournamentsStartDateLabel),
                    subtitle: Text(_formatDate(_startDate)),
                    onTap: _pickStartDate,
                    trailing: const Icon(Icons.calendar_today, size: 18),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.tournamentsEndDateLabel),
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
              decoration: InputDecoration(
                  labelText: l10n.tournamentsTimeControlFieldLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prizePoolController,
              decoration: InputDecoration(
                  labelText: l10n.tournamentsPrizePoolFieldLabel),
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
                  : Text(l10n.tournamentsCreateButton),
            ),
          ],
        ),
      ),
    );
  }
}
