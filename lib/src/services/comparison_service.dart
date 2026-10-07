import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/head_to_head_stats.dart';
import '../models/match_record.dart';

/// Service for managing player-to-player comparisons
class ComparisonService {
  ComparisonService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// Get head-to-head statistics between two players
  Future<HeadToHeadStats> getHeadToHeadStats(
    String player1Id,
    String player2Id,
  ) async {
    try {
      final matchupId = _getMatchupId(player1Id, player2Id);

      // Try to get cached stats
      final doc =
          await _firestore.collection('player_matchups').doc(matchupId).get();

      if (doc.exists) {
        return HeadToHeadStats.fromJson({
          ...doc.data()!,
          'recentMatches': <MatchRecord>[],
        });
      }

      // Calculate from match history if not cached
      return _calculateHeadToHeadStats(player1Id, player2Id);
    } catch (e) {
      throw Exception('Failed to get H2H stats: $e');
    }
  }

  /// Stream head-to-head stats for real-time updates
  Stream<HeadToHeadStats> watchHeadToHeadStats(
    String player1Id,
    String player2Id,
  ) {
    final matchupId = _getMatchupId(player1Id, player2Id);

    return _firestore
        .collection('player_matchups')
        .doc(matchupId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return HeadToHeadStats.fromJson({
          ...doc.data()!,
          'recentMatches': <MatchRecord>[],
        });
      }

      // Return default stats if document doesn't exist
      return HeadToHeadStats(
        player1Id: player1Id,
        player2Id: player2Id,
        player1Wins: 0,
        player2Wins: 0,
        draws: 0,
        player1WinRate: 0,
        player2WinRate: 0,
        ratingDifference: 0,
        lastMatch: DateTime.now(),
        recentMatches: [],
      );
    }).handleError((e) => throw Exception('Failed to watch H2H stats: $e'));
  }

  /// Get recent matches between two players
  Future<List<MatchRecord>> getRecentMatches(
    String player1Id,
    String player2Id, {
    int limit = 10,
  }) async {
    try {
      final matches = <MatchRecord>[];

      // Get matches where player1 is the player and player2 is the opponent
      final snapshot1 = await _firestore
          .collection('match_history')
          .doc(player1Id)
          .collection('matches')
          .where('opponentId', isEqualTo: player2Id)
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .get();

      for (final doc in snapshot1.docs) {
        matches.add(MatchRecord.fromJson(doc.data()));
      }

      // Sort by date
      matches.sort((a, b) => b.playedAt.compareTo(a.playedAt));

      // Take top 'limit' matches
      return matches.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to get recent matches: $e');
    }
  }

  /// Get match statistics vs specific opponent
  Future<Map<String, int>> getStatsVsOpponent(
    String playerId,
    String opponentId,
  ) async {
    try {
      int wins = 0;
      int losses = 0;
      int draws = 0;

      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .where('opponentId', isEqualTo: opponentId)
          .get();

      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());
        switch (match.result) {
          case 'win':
            wins++;
            break;
          case 'loss':
            losses++;
            break;
          case 'draw':
            draws++;
            break;
        }
      }

      return {
        'wins': wins,
        'losses': losses,
        'draws': draws,
      };
    } catch (e) {
      throw Exception('Failed to get stats vs opponent: $e');
    }
  }

  /// Calculate win probability based on rating difference
  /// Using ELO probability formula: P = 1 / (1 + 10^(-ratingDiff/400))
  double calculateWinProbability(int ratingDiff) {
    final exponent = -ratingDiff / 400.0;
    return 1.0 / (1.0 + pow(10, exponent));
  }

  /// Get numeric power function (to avoid importing dart:math for just this)
  double pow(double base, double exponent) {
    // Using iterative approach for small exponents
    if (exponent == 0) return 1;
    if (exponent == 1) return base;

    double result = 1;
    final double absExp = exponent.abs();

    for (int i = 0; i < absExp.toInt(); i++) {
      result *= base;
    }

    // Handle fractional part
    if (exponent - exponent.toInt() != 0) {
      // Use approximation for fractional exponents
      final double frac = exponent - exponent.toInt();
      result *= _powFractional(base, frac);
    }

    if (exponent < 0) {
      result = 1.0 / result;
    }

    return result;
  }

  /// Helper for fractional powers using binary exponentiation
  double _powFractional(double base, double frac) {
    // Simplified: use 10 iterations for approximation
    double result = 1;
    for (int i = 0; i < 10; i++) {
      result = (result + base / result) / 2;
    }
    return result;
  }

  /// Calculate H2H stats from match history
  Future<HeadToHeadStats> _calculateHeadToHeadStats(
    String player1Id,
    String player2Id,
  ) async {
    try {
      int wins = 0;
      int losses = 0;
      int draws = 0;
      DateTime lastMatch = DateTime.now();

      final snapshot = await _firestore
          .collection('match_history')
          .doc(player1Id)
          .collection('matches')
          .where('opponentId', isEqualTo: player2Id)
          .orderBy('playedAt', descending: true)
          .get();

      final matches = <MatchRecord>[];

      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());
        matches.add(match);

        if (doc == snapshot.docs.first) {
          lastMatch = match.playedAt;
        }

        switch (match.result) {
          case 'win':
            wins++;
            break;
          case 'loss':
            losses++;
            break;
          case 'draw':
            draws++;
            break;
        }
      }

      final totalGames = wins + losses + draws;
      final player1WinRate =
          totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0.0';
      final player2WinRate = totalGames > 0
          ? (losses / totalGames * 100).toStringAsFixed(1)
          : '0.0';

      return HeadToHeadStats(
        player1Id: player1Id,
        player2Id: player2Id,
        player1Wins: wins,
        player2Wins: losses,
        draws: draws,
        player1WinRate: double.parse(player1WinRate),
        player2WinRate: double.parse(player2WinRate),
        ratingDifference: 0, // Would need to fetch ratings
        lastMatch: lastMatch,
        recentMatches: matches.take(10).toList(),
      );
    } catch (e) {
      throw Exception('Failed to calculate H2H stats: $e');
    }
  }

  /// Generate matchup ID from two player IDs (order-independent)
  String _getMatchupId(String player1Id, String player2Id) {
    final ids = [player1Id, player2Id];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Save/update H2H stats to Firestore
  Future<void> saveHeadToHeadStats(HeadToHeadStats stats) async {
    try {
      final matchupId = _getMatchupId(stats.player1Id, stats.player2Id);

      await _firestore.collection('player_matchups').doc(matchupId).set({
        'player1Id': stats.player1Id,
        'player2Id': stats.player2Id,
        'player1Wins': stats.player1Wins,
        'player2Wins': stats.player2Wins,
        'draws': stats.draws,
        'player1WinRate': stats.player1WinRate,
        'player2WinRate': stats.player2WinRate,
        'ratingDifference': stats.ratingDifference,
        'lastMatch': stats.lastMatch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save H2H stats: $e');
    }
  }
}
