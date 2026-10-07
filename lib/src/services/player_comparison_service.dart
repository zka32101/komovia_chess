import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Player comparison and head-to-head analysis service
class PlayerComparisonService {
  PlayerComparisonService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _gamesCollection = 'games';
  static const String _usersCollection = 'users';

  /// Get comprehensive head-to-head comparison between two players
  Future<HeadToHeadComparison> getHeadToHeadComparison(
    String player1Id,
    String player2Id,
  ) async {
    try {
      // Get all games between the two players
      final games = await _getGamesBetweenPlayers(player1Id, player2Id);

      // Calculate overall statistics
      int player1Wins = 0;
      int player2Wins = 0;
      int draws = 0;
      const double player1AvgAccuracy = 0;
      const double player2AvgAccuracy = 0;
      const int player1TotalMoves = 0;
      const int player2TotalMoves = 0;

      for (final game in games) {
        if (game['result'] == 'white_win') {
          if (game['whitePlayerId'] == player1Id) {
            player1Wins++;
          } else {
            player2Wins++;
          }
        } else if (game['result'] == 'black_win') {
          if (game['blackPlayerId'] == player1Id) {
            player1Wins++;
          } else {
            player2Wins++;
          }
        } else if (game['result'] == 'draw') {
          draws++;
        }
      }

      // Get player profiles
      final player1Profile = await _getPlayerProfile(player1Id);
      final player2Profile = await _getPlayerProfile(player2Id);

      // Calculate recent performance (last 5 games)
      final recentGames =
          games.isNotEmpty ? games.take(5).toList() : <Map<String, dynamic>>[];

      return HeadToHeadComparison(
        player1Id: player1Id,
        player2Id: player2Id,
        player1Name: player1Profile['playerName'] as String? ?? 'Player 1',
        player2Name: player2Profile['playerName'] as String? ?? 'Player 2',
        player1Rating: player1Profile['rating'] as int? ?? 1200,
        player2Rating: player2Profile['rating'] as int? ?? 1200,
        totalGamesPlayed: games.length,
        player1Wins: player1Wins,
        player2Wins: player2Wins,
        draws: draws,
        player1WinRate:
            games.isNotEmpty ? (player1Wins / games.length * 100) : 0.0,
        player2WinRate:
            games.isNotEmpty ? (player2Wins / games.length * 100) : 0.0,
        drawRate: games.isNotEmpty ? (draws / games.length * 100) : 0.0,
        recentGames: recentGames,
        player1Elo: player1Profile['rating'] as int? ?? 1200,
        player2Elo: player2Profile['rating'] as int? ?? 1200,
        eloDifference: (player1Profile['rating'] as int? ?? 1200) -
            (player2Profile['rating'] as int? ?? 1200),
        lastMeetDate: games.isNotEmpty
            ? DateTime.parse(games.first['createdAt'] as String? ??
                DateTime.now().toIso8601String())
            : null,
      );
    } catch (e, st) {
      _logger.e('Failed to get head-to-head comparison',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Analyze player strengths and weaknesses
  Future<PlayerProfile> analyzePlayerProfile(String playerId) async {
    try {
      final playerDoc =
          await _firestore.collection(_usersCollection).doc(playerId).get();

      if (!playerDoc.exists) {
        throw Exception('Player not found');
      }

      final data = playerDoc.data()!;
      final rating = data['rating'] as int? ?? 1200;
      final gamesPlayed = data['gamesPlayed'] as int? ?? 0;

      // Get player's recent games
      final recentGames = await _getPlayerRecentGames(playerId, limit: 20);

      // Analyze performance by result type
      int wins = 0;
      int losses = 0;
      int draws = 0;
      double totalAccuracy = 0;

      for (final game in recentGames) {
        final result = game['result'] as String?;
        final accuracy = game['accuracy'] as double? ?? 0.0;

        if (result == 'white_win' || result == 'black_win') {
          if ((result == 'white_win' && game['whitePlayerId'] == playerId) ||
              (result == 'black_win' && game['blackPlayerId'] == playerId)) {
            wins++;
          } else {
            losses++;
          }
        } else if (result == 'draw') {
          draws++;
        }

        totalAccuracy += accuracy;
      }

      final double avgAccuracy =
          recentGames.isNotEmpty ? totalAccuracy / recentGames.length : 0.0;

      // Determine play style based on win rates
      final String playStyle = _determinePlayStyle(wins, losses, draws);

      // Calculate strengths and weaknesses
      final List<String> strengths = [];
      final List<String> weaknesses = [];

      if (wins > losses) {
        strengths.add('Consistent Winner');
      }
      if (avgAccuracy > 75) {
        strengths.add('High Accuracy');
      }
      if (rating > 1800) {
        strengths.add('High Rated');
      }

      if (losses > wins) {
        weaknesses.add('Needs Improvement');
      }
      if (avgAccuracy < 50) {
        weaknesses.add('Low Accuracy');
      }
      if (gamesPlayed < 20) {
        weaknesses.add('Limited Experience');
      }

      return PlayerProfile(
        playerId: playerId,
        playerName: data['playerName'] as String? ?? 'Unknown',
        rating: rating,
        gamesPlayed: gamesPlayed,
        averageAccuracy: avgAccuracy,
        playStyle: playStyle,
        strengths: strengths,
        weaknesses: weaknesses,
        winRate:
            recentGames.isNotEmpty ? (wins / recentGames.length * 100) : 0.0,
      );
    } catch (e, st) {
      _logger.e('Failed to analyze player profile', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player matchup statistics against specific opponents
  Future<List<MatchupStats>> getPlayerMatchups(String playerId) async {
    try {
      final games = await _getPlayerAllGames(playerId);
      final matchups = <String, Map<String, dynamic>>{};

      for (final game in games) {
        final opponentId = game['whitePlayerId'] == playerId
            ? game['blackPlayerId']
            : game['whitePlayerId'];

        if (!matchups.containsKey(opponentId)) {
          matchups[opponentId] = {
            'wins': 0,
            'losses': 0,
            'draws': 0,
            'games': <Map<String, dynamic>>[],
          };
        }

        final result = game['result'] as String?;
        if (result == 'white_win') {
          if (game['whitePlayerId'] == playerId) {
            matchups[opponentId]!['wins']++;
          } else {
            matchups[opponentId]!['losses']++;
          }
        } else if (result == 'black_win') {
          if (game['blackPlayerId'] == playerId) {
            matchups[opponentId]!['wins']++;
          } else {
            matchups[opponentId]!['losses']++;
          }
        } else if (result == 'draw') {
          matchups[opponentId]!['draws']++;
        }

        matchups[opponentId]!['games'].add(game);
      }

      final matchupList = <MatchupStats>[];
      for (final entry in matchups.entries) {
        final stats = entry.value;
        final totalGames = stats['wins'] + stats['losses'] + stats['draws'];

        matchupList.add(MatchupStats(
          opponentId: entry.key,
          totalGames: totalGames,
          playerWins: stats['wins'] as int,
          playerLosses: stats['losses'] as int,
          draws: stats['draws'] as int,
          winRate: totalGames > 0 ? (stats['wins'] / totalGames * 100) : 0.0,
        ));
      }

      // Sort by total games (most played opponents first)
      matchupList.sort((a, b) => b.totalGames.compareTo(a.totalGames));

      return matchupList;
    } catch (e, st) {
      _logger.e('Failed to get player matchups', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  Future<List<Map<String, dynamic>>> _getGamesBetweenPlayers(
    String player1Id,
    String player2Id,
  ) async {
    final snapshot = await _firestore
        .collection(_gamesCollection)
        .where('status', isEqualTo: 'completed')
        .get();

    final games = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final white = data['whitePlayerId'] as String?;
      final black = data['blackPlayerId'] as String?;

      if ((white == player1Id && black == player2Id) ||
          (white == player2Id && black == player1Id)) {
        games.add(data);
      }
    }

    // Sort by date descending
    games.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt'] as String? ?? '');
      final dateB = DateTime.parse(b['createdAt'] as String? ?? '');
      return dateB.compareTo(dateA);
    });

    return games;
  }

  Future<List<Map<String, dynamic>>> _getPlayerRecentGames(
    String playerId, {
    int limit = 20,
  }) async {
    final snapshot = await _firestore
        .collection(_gamesCollection)
        .where('status', isEqualTo: 'completed')
        .where('whitePlayerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _getPlayerAllGames(String playerId) async {
    final whiteGames = await _firestore
        .collection(_gamesCollection)
        .where('whitePlayerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .get();

    final blackGames = await _firestore
        .collection(_gamesCollection)
        .where('blackPlayerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .get();

    final allGames = [...whiteGames.docs, ...blackGames.docs];
    return allGames.map((doc) => doc.data()).toList();
  }

  Future<Map<String, dynamic>> _getPlayerProfile(String playerId) async {
    final doc =
        await _firestore.collection(_usersCollection).doc(playerId).get();

    if (!doc.exists) {
      return {
        'playerName': 'Unknown Player',
        'rating': 1200,
        'gamesPlayed': 0,
      };
    }

    return doc.data() ?? {};
  }

  String _determinePlayStyle(int wins, int losses, int draws) {
    final total = wins + losses + draws;
    if (total == 0) return 'Unrated';

    final winRate = wins / total;
    final drawRate = draws / total;

    if (winRate > 0.6) return 'Aggressive Winner';
    if (winRate > 0.5 && drawRate > 0.2) return 'Solid Player';
    if (drawRate > 0.3) return 'Positional';
    if (losses > wins) return 'Improving';

    return 'Balanced';
  }
}

/// Head-to-head comparison data
class HeadToHeadComparison {
  HeadToHeadComparison({
    required this.player1Id,
    required this.player2Id,
    required this.player1Name,
    required this.player2Name,
    required this.player1Rating,
    required this.player2Rating,
    required this.totalGamesPlayed,
    required this.player1Wins,
    required this.player2Wins,
    required this.draws,
    required this.player1WinRate,
    required this.player2WinRate,
    required this.drawRate,
    required this.recentGames,
    required this.player1Elo,
    required this.player2Elo,
    required this.eloDifference,
    this.lastMeetDate,
  });
  final String player1Id;
  final String player2Id;
  final String player1Name;
  final String player2Name;
  final int player1Rating;
  final int player2Rating;
  final int totalGamesPlayed;
  final int player1Wins;
  final int player2Wins;
  final int draws;
  final double player1WinRate;
  final double player2WinRate;
  final double drawRate;
  final List<Map<String, dynamic>> recentGames;
  final int player1Elo;
  final int player2Elo;
  final int eloDifference;
  final DateTime? lastMeetDate;
}

/// Player profile with strengths and weaknesses
class PlayerProfile {
  PlayerProfile({
    required this.playerId,
    required this.playerName,
    required this.rating,
    required this.gamesPlayed,
    required this.averageAccuracy,
    required this.playStyle,
    required this.strengths,
    required this.weaknesses,
    required this.winRate,
  });
  final String playerId;
  final String playerName;
  final int rating;
  final int gamesPlayed;
  final double averageAccuracy;
  final String playStyle;
  final List<String> strengths;
  final List<String> weaknesses;
  final double winRate;
}

/// Matchup statistics against a specific opponent
class MatchupStats {
  MatchupStats({
    required this.opponentId,
    required this.totalGames,
    required this.playerWins,
    required this.playerLosses,
    required this.draws,
    required this.winRate,
  });
  final String opponentId;
  final int totalGames;
  final int playerWins;
  final int playerLosses;
  final int draws;
  final double winRate;
}
