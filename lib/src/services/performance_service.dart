import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_progression.dart';
import '../models/match_record.dart';

/// Information about streaks
class StreakInfo {
  StreakInfo({
    required this.current,
    required this.longestWin,
    required this.longestLoss,
  });
  final int current; // positive = wins, negative = losses
  final int longestWin;
  final int longestLoss;
}

/// Service for managing player performance analytics
class PerformanceService {
  PerformanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// Get rating progression for different time ranges
  Future<List<RatingProgression>> getRatingProgression(
    String playerId, {
    required int days,
  }) async {
    try {
      final fromDate = DateTime.now().subtract(Duration(days: days));

      // For now, fetch from match history and calculate
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .where('playedAt', isGreaterThanOrEqualTo: fromDate)
          .orderBy('playedAt', descending: true)
          .get();

      final matches =
          snapshot.docs.map((doc) => MatchRecord.fromJson(doc.data())).toList();

      // Group by date and calculate daily progression
      final progressionMap = <DateTime, RatingProgression>{};

      for (final match in matches) {
        final date = DateTime(
            match.playedAt.year, match.playedAt.month, match.playedAt.day);

        // Get or initialize progression for this date
        final existing = progressionMap[date];
        if (existing == null) {
          progressionMap[date] = RatingProgression(
            date: date,
            rating: match.playerRatingAfter,
            gamesPlayed: 1,
            winRate: match.result == 'win' ? 100.0 : 0.0,
          );
        } else {
          // Update with cumulative data (simplified - would need better aggregation)
          progressionMap[date] = RatingProgression(
            date: date,
            rating: match.playerRatingAfter,
            gamesPlayed: existing.gamesPlayed + 1,
            winRate: match.result == 'win'
                ? (existing.winRate + 100.0) / 2
                : (existing.winRate) / 2,
          );
        }
      }

      // Convert to sorted list
      final progression = progressionMap.values.toList();
      progression.sort((a, b) => a.date.compareTo(b.date));

      return progression;
    } catch (e) {
      throw Exception('Failed to get rating progression: $e');
    }
  }

  /// Stream rating progression updates
  Stream<List<RatingProgression>> watchRatingProgression(
    String playerId, {
    required int days,
  }) {
    final fromDate = DateTime.now().subtract(Duration(days: days));

    return _firestore
        .collection('match_history')
        .doc(playerId)
        .collection('matches')
        .where('playedAt', isGreaterThanOrEqualTo: fromDate)
        .orderBy('playedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final matches =
          snapshot.docs.map((doc) => MatchRecord.fromJson(doc.data())).toList();

      final progressionMap = <DateTime, RatingProgression>{};

      for (final match in matches) {
        final date = DateTime(
            match.playedAt.year, match.playedAt.month, match.playedAt.day);

        final existing = progressionMap[date];
        if (existing == null) {
          progressionMap[date] = RatingProgression(
            date: date,
            rating: match.playerRatingAfter,
            gamesPlayed: 1,
            winRate: match.result == 'win' ? 100.0 : 0.0,
          );
        } else {
          progressionMap[date] = RatingProgression(
            date: date,
            rating: match.playerRatingAfter,
            gamesPlayed: existing.gamesPlayed + 1,
            winRate: match.result == 'win'
                ? (existing.winRate + 100.0) / 2
                : existing.winRate / 2,
          );
        }
      }

      final progression = progressionMap.values.toList();
      progression.sort((a, b) => a.date.compareTo(b.date));

      return progression;
    }).handleError(
            (e) => throw Exception('Failed to watch rating progression: $e'));
  }

  /// Calculate current win rate
  Future<double> getWinRate(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .get();

      if (snapshot.size == 0) return 0.0;

      int wins = 0;
      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());
        if (match.result == 'win') wins++;
      }

      return wins / snapshot.size * 100;
    } catch (e) {
      throw Exception('Failed to get win rate: $e');
    }
  }

  /// Get performance by opponent rank
  Future<Map<String, int>> getPerformanceByRank(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .get();

      final performanceByRank = <String, List<bool>>{};

      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());
        final opponentRank =
            match.opponentId; // Would need rank from user collection

        if (!performanceByRank.containsKey(opponentRank)) {
          performanceByRank[opponentRank] = [];
        }

        performanceByRank[opponentRank]!.add(match.result == 'win');
      }

      // Calculate win rates
      final result = <String, int>{};
      performanceByRank.forEach((rank, results) {
        if (results.isNotEmpty) {
          final wins = results.where((w) => w).length;
          final winRate = (wins / results.length * 100).toInt();
          result[rank] = winRate;
        }
      });

      return result;
    } catch (e) {
      throw Exception('Failed to get performance by rank: $e');
    }
  }

  /// Get performance by time control
  Future<Map<String, int>> getPerformanceByTimeControl(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .get();

      final performanceByTimeControl = <String, List<bool>>{};

      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());

        if (!performanceByTimeControl.containsKey(match.timeControl)) {
          performanceByTimeControl[match.timeControl] = [];
        }

        performanceByTimeControl[match.timeControl]!.add(match.result == 'win');
      }

      // Calculate win rates
      final result = <String, int>{};
      performanceByTimeControl.forEach((timeControl, results) {
        if (results.isNotEmpty) {
          final wins = results.where((w) => w).length;
          final winRate = (wins / results.length * 100).toInt();
          result[timeControl] = winRate;
        }
      });

      return result;
    } catch (e) {
      throw Exception('Failed to get performance by time control: $e');
    }
  }

  /// Calculate streak information
  Future<StreakInfo> getStreakInfo(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .orderBy('playedAt', descending: true)
          .limit(100) // Look at last 100 games
          .get();

      if (snapshot.docs.isEmpty) {
        return StreakInfo(
          current: 0,
          longestWin: 0,
          longestLoss: 0,
        );
      }

      final matches =
          snapshot.docs.map((doc) => MatchRecord.fromJson(doc.data())).toList();

      int currentStreak = 0;
      int longestWin = 0;
      int longestLoss = 0;
      bool? lastWasWin;

      for (final match in matches) {
        final isWin = match.result == 'win';

        if (lastWasWin == null) {
          lastWasWin = isWin;
          currentStreak = isWin ? 1 : -1;
        } else if (lastWasWin == isWin) {
          currentStreak += isWin ? 1 : -1;
        } else {
          // Streak ended
          if (lastWasWin) {
            longestWin =
                longestWin > currentStreak ? longestWin : currentStreak;
          } else {
            longestLoss =
                longestLoss < currentStreak ? longestLoss : currentStreak;
          }

          lastWasWin = isWin;
          currentStreak = isWin ? 1 : -1;
        }
      }

      // Update final streak
      if (lastWasWin == true) {
        longestWin = longestWin > currentStreak ? longestWin : currentStreak;
      } else {
        longestLoss = longestLoss < currentStreak ? longestLoss : currentStreak;
      }

      return StreakInfo(
        current: currentStreak,
        longestWin: longestWin,
        longestLoss: longestLoss.abs(),
      );
    } catch (e) {
      throw Exception('Failed to get streak info: $e');
    }
  }

  /// Record daily progression
  Future<void> recordDailyProgression(
    String playerId,
    RatingProgression progression,
  ) async {
    try {
      final daysKey = progression.date.toString().split(' ')[0]; // YYYY-MM-DD

      await _firestore
          .collection('performance_stats')
          .doc(playerId)
          .collection('progression_30days')
          .doc(daysKey)
          .set(progression.toJson());
    } catch (e) {
      throw Exception('Failed to record daily progression: $e');
    }
  }
}
