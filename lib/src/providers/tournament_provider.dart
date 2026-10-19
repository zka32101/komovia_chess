import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../models/phase_k_models.dart' show TournamentRanking;
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

/// `entryFee`/`prizePool`/`timeControl` — chess-specific fields kept outside
/// the shared `Tournament` model (see `tournament_service.dart`).
final tournamentExtrasProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, tournamentId) {
  return ref.watch(tournamentServiceProvider).getTournamentExtras(tournamentId);
});

/// A tournament's current standings, ranked by points then wins.
final tournamentStandingsProvider =
    FutureProvider.family<List<TournamentRanking>, String>((ref, tournamentId) {
  return ref.watch(tournamentServiceProvider).getStandings(tournamentId);
});

/// A tournament's full match list, across all rounds.
final tournamentMatchesProvider =
    FutureProvider.family<List<TournamentMatch>, String>((ref, tournamentId) {
  return ref
      .watch(tournamentServiceProvider)
      .getTournamentMatches(tournamentId);
});

/// Mutating tournament actions (registering, and - for the organizer -
/// starting the bracket, recording a match result, and finalizing with
/// prizes), refreshing the relevant providers afterward so the UI
/// reflects the change.
class TournamentActionsNotifier extends StateNotifier<AsyncValue<void>> {
  TournamentActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> register(Tournament tournament) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(tournamentServiceProvider).registerParticipant(
            tournament.id,
            me.uid,
            me.displayName ?? 'Anonymous',
            me.rating,
          );
      _ref.invalidate(activeTournamentsProvider);
      _ref.invalidate(tournamentDetailsProvider(tournament.id));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Organizer-only (enforced by firestore.rules): generate round 1 and
  /// move the tournament to 'active'.
  Future<void> startTournament(String tournamentId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(tournamentServiceProvider).generateBracket(tournamentId);
      _ref.invalidate(activeTournamentsProvider);
      _ref.invalidate(tournamentDetailsProvider(tournamentId));
      _ref.invalidate(tournamentMatchesProvider(tournamentId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Organizer-only: record who won a pending match.
  Future<void> recordMatchResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
    required String loserId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(tournamentServiceProvider).recordMatchResult(
            tournamentId: tournamentId,
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
          );
      _ref.invalidate(tournamentMatchesProvider(tournamentId));
      _ref.invalidate(tournamentStandingsProvider(tournamentId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Organizer-only: pay out the top finishers and mark the tournament
  /// completed.
  Future<void> finishTournament(String tournamentId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(tournamentServiceProvider).distributePrizes(tournamentId);
      _ref.invalidate(activeTournamentsProvider);
      _ref.invalidate(tournamentDetailsProvider(tournamentId));
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
