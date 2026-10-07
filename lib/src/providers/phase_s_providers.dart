import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tournament_management_service.dart';
import '../services/bracket_generation_service.dart';

/// Phase S - Tournament System Providers
/// Provides reactive access to tournament management and bracket operations

// Service Providers
final tournamentManagementServiceProvider =
    Provider<TournamentManagementService>((ref) =>
        TournamentManagementService(firestore: FirebaseFirestore.instance));

final bracketGenerationServiceProvider = Provider<BracketGenerationService>(
    (ref) => BracketGenerationService(firestore: FirebaseFirestore.instance));

// Tournament Providers

/// Get tournament details
final tournamentProvider =
    FutureProvider.family<Tournament?, String>((ref, tournamentId) {
  final service = ref.watch(tournamentManagementServiceProvider);
  return service.getTournament(tournamentId);
});

/// Get tournament participants
final tournamentParticipantsProvider =
    FutureProvider.family<List<TournamentParticipant>, String>(
        (ref, tournamentId) {
  final service = ref.watch(tournamentManagementServiceProvider);
  return service.getTournamentParticipants(tournamentId);
});

/// Get tournament standings
final tournamentStandingsProvider =
    FutureProvider.family<List<TournamentStanding>, String>(
        (ref, tournamentId) {
  final service = ref.watch(tournamentManagementServiceProvider);
  return service.getTournamentStandings(tournamentId);
});

// Bracket Providers

/// Get bracket matches for a specific round
final bracketRoundProvider = FutureProvider.family<
    List<TournamentMatch>,
    ({
      String tournamentId,
      int round,
    })>((ref, params) {
  final service = ref.watch(bracketGenerationServiceProvider);
  return service.getBracketRound(params.tournamentId, params.round);
});

// Tournament Management Providers

/// State notifier for tournament creation
final tournamentCreationNotifierProvider =
    StateNotifierProvider<TournamentCreationNotifier, TournamentCreationState>(
  (ref) {
    final service = ref.watch(tournamentManagementServiceProvider);
    return TournamentCreationNotifier(service);
  },
);

/// State notifier for tournament operations
final tournamentOperationNotifierProvider = StateNotifierProvider<
    TournamentOperationNotifier, TournamentOperationState>(
  (ref) {
    final managementService = ref.watch(tournamentManagementServiceProvider);
    final bracketService = ref.watch(bracketGenerationServiceProvider);
    return TournamentOperationNotifier(managementService, bracketService);
  },
);

// Notifier implementations

class TournamentCreationNotifier
    extends StateNotifier<TournamentCreationState> {
  TournamentCreationNotifier(this._service)
      : super(const TournamentCreationState());
  final TournamentManagementService _service;

  Future<void> createTournament({
    required String name,
    required String description,
    required String format,
    required String timeControl,
    required int maxParticipants,
    required DateTime startDate,
    required DateTime endDate,
    required int entryFee,
    required List<int> prizePool,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final tournament = await _service.createTournament(
        name: name,
        description: description,
        format: format,
        timeControl: timeControl,
        maxParticipants: maxParticipants,
        startDate: startDate,
        endDate: endDate,
        entryFee: entryFee,
        prizePool: prizePool,
      );

      state = state.copyWith(
        isLoading: false,
        createdTournament: tournament,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

class TournamentOperationNotifier
    extends StateNotifier<TournamentOperationState> {
  TournamentOperationNotifier(this._managementService, this._bracketService)
      : super(const TournamentOperationState());
  final TournamentManagementService _managementService;
  final BracketGenerationService _bracketService;

  Future<void> registerParticipant({
    required String tournamentId,
    required String playerId,
    required String playerName,
    required int playerRating,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _managementService.registerParticipant(
        tournamentId: tournamentId,
        playerId: playerId,
        playerName: playerName,
        playerRating: playerRating,
      );

      state = state.copyWith(
        isLoading: false,
        lastOperation: 'registered',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> startTournament(String tournamentId) async {
    state = state.copyWith(isLoading: true);

    try {
      await _managementService.startTournament(tournamentId);

      state = state.copyWith(
        isLoading: false,
        lastOperation: 'started',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> recordMatchResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
    String? result,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _bracketService.recordMatchResult(
        tournamentId: tournamentId,
        matchId: matchId,
        winnerId: winnerId,
        result: result,
      );

      state = state.copyWith(
        isLoading: false,
        lastOperation: 'result_recorded',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// State classes

class TournamentCreationState {
  const TournamentCreationState({
    this.isLoading = false,
    this.createdTournament,
    this.error,
  });
  final bool isLoading;
  final Tournament? createdTournament;
  final String? error;

  TournamentCreationState copyWith({
    bool? isLoading,
    Tournament? createdTournament,
    String? error,
  }) =>
      TournamentCreationState(
        isLoading: isLoading ?? this.isLoading,
        createdTournament: createdTournament ?? this.createdTournament,
        error: error ?? this.error,
      );
}

class TournamentOperationState {
  const TournamentOperationState({
    this.isLoading = false,
    this.lastOperation,
    this.error,
  });
  final bool isLoading;
  final String? lastOperation;
  final String? error;

  TournamentOperationState copyWith({
    bool? isLoading,
    String? lastOperation,
    String? error,
  }) =>
      TournamentOperationState(
        isLoading: isLoading ?? this.isLoading,
        lastOperation: lastOperation ?? this.lastOperation,
        error: error ?? this.error,
      );
}
