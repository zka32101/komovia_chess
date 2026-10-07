import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/phase_k_models.dart';
import '../services/tournament_service.dart';
import 'auth_provider.dart';

final tournamentServiceProvider =
    Provider<TournamentService>((ref) => TournamentService.instance);

/// Tournaments currently open for registration or in progress.
final activeTournamentsProvider = FutureProvider<List<Tournament>>((ref) {
  return ref.watch(tournamentServiceProvider).getActiveTournaments();
});

/// A single tournament's details.
final tournamentDetailsProvider =
    FutureProvider.family<Tournament, String>((ref, tournamentId) {
  return ref.watch(tournamentServiceProvider).getTournament(tournamentId);
});

/// A tournament's current standings, ranked by points then wins.
final tournamentStandingsProvider =
    FutureProvider.family<TournamentStandings, String>((ref, tournamentId) {
  return ref.watch(tournamentServiceProvider).getStandings(tournamentId);
});

/// A tournament's full match list, across all rounds.
final tournamentMatchesProvider =
    FutureProvider.family<List<TournamentMatch>, String>((ref, tournamentId) {
  return ref
      .watch(tournamentServiceProvider)
      .getTournamentMatches(tournamentId);
});

/// Mutating tournament actions (registering), refreshing the relevant
/// providers afterward so the UI reflects the change.
class TournamentActionsNotifier extends StateNotifier<AsyncValue<void>> {
  TournamentActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> register(Tournament tournament) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(tournamentServiceProvider).registerParticipant(
            tournament.tournamentId,
            me.uid,
            me.displayName ?? 'Anonymous',
            me.rating,
          );
      _ref.invalidate(activeTournamentsProvider);
      _ref.invalidate(tournamentDetailsProvider(tournament.tournamentId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final tournamentActionsProvider =
    StateNotifierProvider<TournamentActionsNotifier, AsyncValue<void>>(
  (ref) => TournamentActionsNotifier(ref),
);
