import '../models/match_record.dart';
import 'ai_opponent_engine.dart' show AIDifficulty;
import 'match_history_service.dart';

/// A recommendation for which CPU difficulty to default to on
/// CPUGameSelectionScreen, derived from the player's own recent CPU game
/// results. Previously the screen always defaulted to [AIDifficulty.medium]
/// regardless of how a player had actually been doing - a player
/// consistently beating Easy, or getting crushed on Hard, had no signal
/// fed back to them at all.
class DifficultyRecommendation {
  const DifficultyRecommendation({
    required this.difficulty,
    required this.reason,
    required this.recentWinRate,
    required this.gamesConsidered,
  });

  final AIDifficulty difficulty;

  /// Why this difficulty was recommended, for a short explanatory hint
  /// in the UI - 'strong'/'struggling'/'steady'/'default' (no data yet).
  final String reason;
  final double recentWinRate;
  final int gamesConsidered;
}

class AdaptiveDifficultyService {
  AdaptiveDifficultyService({MatchHistoryService? matchHistoryService})
      : _matchHistoryService = matchHistoryService ?? MatchHistoryService();

  final MatchHistoryService _matchHistoryService;

  /// How many of the player's most recent games (of any difficulty) to
  /// look at - recent form matters more than all-time history, and
  /// keeping this small means a player who already changed difficulty
  /// gets re-evaluated quickly on just their next couple of games.
  static const _lookback = 8;

  /// Needs at least this many games at the SAME difficulty as their most
  /// recent game before recommending a change - a single win/loss isn't
  /// enough signal, and recommending a swing based on one game would
  /// feel arbitrary.
  static const _minGamesAtDifficulty = 3;

  static const _promoteWinRateThreshold = 0.8;
  static const _demoteWinRateThreshold = 0.25;

  Future<DifficultyRecommendation> getRecommendation(String uid) async {
    final matches = await _matchHistoryService.getMatchHistory(
      uid,
      limit: _lookback,
    );
    final cpuMatches = matches
        .where((m) => m.opponentId.startsWith('cpu_'))
        .toList();

    if (cpuMatches.isEmpty) {
      return const DifficultyRecommendation(
        difficulty: AIDifficulty.medium,
        reason: 'default',
        recentWinRate: 0,
        gamesConsidered: 0,
      );
    }

    // cpuMatches is already ordered most-recent-first (same ordering
    // getMatchHistory returns for every other caller) - the most recent
    // game's difficulty is what "how are they doing lately" should be
    // measured against, not whatever difficulty dominates the whole
    // lookback window.
    final currentDifficulty = _difficultyOf(cpuMatches.first);
    final atCurrentDifficulty =
        cpuMatches.where((m) => _difficultyOf(m) == currentDifficulty).toList();

    if (atCurrentDifficulty.length < _minGamesAtDifficulty) {
      return DifficultyRecommendation(
        difficulty: currentDifficulty,
        reason: 'default',
        recentWinRate: 0,
        gamesConsidered: atCurrentDifficulty.length,
      );
    }

    final wins = atCurrentDifficulty.where((m) => m.result == 'win').length;
    final winRate = wins / atCurrentDifficulty.length;

    if (winRate >= _promoteWinRateThreshold &&
        currentDifficulty != AIDifficulty.master) {
      return DifficultyRecommendation(
        difficulty: _promote(currentDifficulty),
        reason: 'strong',
        recentWinRate: winRate,
        gamesConsidered: atCurrentDifficulty.length,
      );
    }

    if (winRate <= _demoteWinRateThreshold &&
        currentDifficulty != AIDifficulty.beginner) {
      return DifficultyRecommendation(
        difficulty: _demote(currentDifficulty),
        reason: 'struggling',
        recentWinRate: winRate,
        gamesConsidered: atCurrentDifficulty.length,
      );
    }

    return DifficultyRecommendation(
      difficulty: currentDifficulty,
      reason: 'steady',
      recentWinRate: winRate,
      gamesConsidered: atCurrentDifficulty.length,
    );
  }

  AIDifficulty _difficultyOf(MatchRecord match) {
    // Matches ai_opponent_engine.dart's AIDifficulty.name - written by
    // CpuGameNotifier._recordResult as 'cpu_${difficulty.name}'.
    final suffix = match.opponentId.substring('cpu_'.length);
    return AIDifficulty.values.firstWhere(
      (d) => d.name == suffix,
      orElse: () => AIDifficulty.medium,
    );
  }

  AIDifficulty _promote(AIDifficulty d) => switch (d) {
        AIDifficulty.beginner => AIDifficulty.easy,
        AIDifficulty.easy => AIDifficulty.medium,
        AIDifficulty.medium => AIDifficulty.hard,
        AIDifficulty.hard => AIDifficulty.master,
        AIDifficulty.master => AIDifficulty.master,
      };

  AIDifficulty _demote(AIDifficulty d) => switch (d) {
        AIDifficulty.beginner => AIDifficulty.beginner,
        AIDifficulty.easy => AIDifficulty.beginner,
        AIDifficulty.medium => AIDifficulty.easy,
        AIDifficulty.hard => AIDifficulty.medium,
        AIDifficulty.master => AIDifficulty.hard,
      };
}
