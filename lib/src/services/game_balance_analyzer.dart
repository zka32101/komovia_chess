import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show pow, sqrt;

/// Game balance analyzer for puzzle difficulty and rating system validation
class GameBalanceAnalyzer {
  GameBalanceAnalyzer(this._firestore);
  final FirebaseFirestore _firestore;

  /// Puzzle difficulty analysis
  Future<PuzzleDifficultyAnalysis> analyzePuzzleDifficulty() async {
    try {
      final puzzlesSnapshot = await _firestore.collection('puzzles').get();

      final puzzles = puzzlesSnapshot.docs;
      if (puzzles.isEmpty) {
        return PuzzleDifficultyAnalysis.empty();
      }

      // Categorize puzzles by difficulty
      final beginner = <int>[];
      final intermediate = <int>[];
      final advanced = <int>[];
      final expert = <int>[];
      final master = <int>[];

      for (final doc in puzzles) {
        final rating = (doc['rating'] as num?)?.toInt() ?? 1500;
        if (rating < 1000) {
          beginner.add(rating);
        } else if (rating < 1500) {
          intermediate.add(rating);
        } else if (rating < 2000) {
          advanced.add(rating);
        } else if (rating < 2600) {
          expert.add(rating);
        } else {
          master.add(rating);
        }
      }

      // Calculate statistics
      final totalPuzzles = puzzles.length;
      final distribution = {
        'beginner': (beginner.length / totalPuzzles * 100).toStringAsFixed(1),
        'intermediate':
            (intermediate.length / totalPuzzles * 100).toStringAsFixed(1),
        'advanced': (advanced.length / totalPuzzles * 100).toStringAsFixed(1),
        'expert': (expert.length / totalPuzzles * 100).toStringAsFixed(1),
        'master': (master.length / totalPuzzles * 100).toStringAsFixed(1),
      };

      return PuzzleDifficultyAnalysis(
        totalPuzzles: totalPuzzles,
        beginnerCount: beginner.length,
        intermediateCount: intermediate.length,
        advancedCount: advanced.length,
        expertCount: expert.length,
        masterCount: master.length,
        distribution: distribution,
        averageRating: _calculateMean(puzzles
            .map((doc) => (doc['rating'] as num?)?.toInt() ?? 1500)
            .toList()),
        medianRating: _calculateMedian(puzzles
            .map((doc) => (doc['rating'] as num?)?.toInt() ?? 1500)
            .toList()),
        standardDeviation: _calculateStdDev(puzzles
            .map((doc) => (doc['rating'] as num?)?.toInt() ?? 1500)
            .toList()),
      );
    } catch (e) {
      throw Exception('Failed to analyze puzzle difficulty: $e');
    }
  }

  /// Analyze rating system for zero-sum property and balance
  Future<RatingSystemAnalysis> analyzeRatingSystem() async {
    try {
      final gamesSnapshot = await _firestore
          .collection('games')
          .where('status', isEqualTo: 'completed')
          .limit(1000)
          .get();

      final games = gamesSnapshot.docs;
      if (games.isEmpty) {
        return RatingSystemAnalysis.empty();
      }

      // Analyze rating changes
      final ratingChanges = <int>[];
      double zeroSumCount = 0;
      double totalGames = 0;

      for (final gameDoc in games) {
        final whiteRatingDelta =
            (gameDoc['whiteRatingDelta'] as num?)?.toInt() ?? 0;
        final blackRatingDelta =
            (gameDoc['blackRatingDelta'] as num?)?.toInt() ?? 0;

        ratingChanges.add(whiteRatingDelta.abs());
        ratingChanges.add(blackRatingDelta.abs());

        // Check zero-sum property: white + black should = 0
        if (whiteRatingDelta + blackRatingDelta == 0) {
          zeroSumCount++;
        }
        totalGames++;
      }

      final zeroSumPercentage =
          totalGames > 0 ? (zeroSumCount / totalGames * 100) : 0.0;

      // Analyze rating distribution
      final allPlayersSnapshot =
          await _firestore.collection('users').limit(1000).get();

      final ratings = allPlayersSnapshot.docs
          .map((doc) => (doc['rating'] as num?)?.toInt() ?? 1500)
          .toList();

      return RatingSystemAnalysis(
        totalGamesAnalyzed: games.length,
        zeroSumCompliance: zeroSumPercentage,
        averageRatingChange:
            _calculateMean(ratingChanges.map((r) => r).toList()),
        medianRatingChange: _calculateMedian(ratingChanges),
        playerAverageRating: _calculateMean(ratings),
        ratingDistributionStdDev: _calculateStdDev(ratings),
        ratingRangeMin:
            ratings.isNotEmpty ? ratings.reduce((a, b) => a < b ? a : b) : 0,
        ratingRangeMax:
            ratings.isNotEmpty ? ratings.reduce((a, b) => a > b ? a : b) : 0,
        zeroSumCompliant: zeroSumPercentage >= 99.0,
      );
    } catch (e) {
      throw Exception('Failed to analyze rating system: $e');
    }
  }

  /// Analyze time control balance
  Future<TimeControlAnalysis> analyzeTimeControlBalance() async {
    try {
      final timeControls = ['blitz', 'rapid', 'classical'];
      final analysis = <String, TimeControlStats>{};

      for (final control in timeControls) {
        final gamesSnapshot = await _firestore
            .collection('games')
            .where('timeControl', isEqualTo: control)
            .where('status', isEqualTo: 'completed')
            .limit(500)
            .get();

        if (gamesSnapshot.docs.isEmpty) continue;

        final games = gamesSnapshot.docs;
        double whiteWins = 0;
        double blackWins = 0;
        double draws = 0;
        double totalGames = 0;

        double totalGameTime = 0;

        for (final gameDoc in games) {
          final result = gameDoc['result'] as String?;
          if (result == 'white_win') whiteWins++;
          if (result == 'black_win') blackWins++;
          if (result == 'draw') draws++;
          totalGames++;

          final duration = gameDoc['duration'] as int?;
          if (duration != null) totalGameTime += duration;
        }

        analysis[control] = TimeControlStats(
          timeControl: control,
          totalGames: games.length,
          whiteWinRate: totalGames > 0 ? whiteWins / totalGames : 0.0,
          blackWinRate: totalGames > 0 ? blackWins / totalGames : 0.0,
          drawRate: totalGames > 0 ? draws / totalGames : 0.0,
          averageGameDuration:
              totalGames > 0 ? (totalGameTime / totalGames).toInt() : 0,
        );
      }

      return TimeControlAnalysis(
        timeControlStats: analysis,
        balanced: _isTimeControlBalanced(analysis),
      );
    } catch (e) {
      throw Exception('Failed to analyze time control balance: $e');
    }
  }

  /// Calculate difficulty progression metrics
  Future<DifficultyProgressionAnalysis> analyzeDifficultyProgression() async {
    try {
      final usersSnapshot =
          await _firestore.collection('users').limit(500).get();

      if (usersSnapshot.docs.isEmpty) {
        return DifficultyProgressionAnalysis.empty();
      }

      // For each user, analyze puzzle solving progression
      final progressionData = <String, num>{};
      double totalProgressionScore = 0;
      int userCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final uid = userDoc.id;
        final userRating = (userDoc['rating'] as num?)?.toInt() ?? 1500;

        // Get puzzles solved by this user
        final solvedPuzzlesSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('solved_puzzles')
            .limit(50)
            .get();

        if (solvedPuzzlesSnapshot.docs.isEmpty) continue;

        final puzzleRatings = solvedPuzzlesSnapshot.docs
            .map((doc) => (doc['puzzleRating'] as num?)?.toInt() ?? 1500)
            .toList();

        // Calculate progression score
        if (puzzleRatings.isNotEmpty) {
          final avgPuzzleRating = _calculateMean(puzzleRatings);
          final progressionScore = avgPuzzleRating / userRating;
          totalProgressionScore += progressionScore;
          userCount++;
          progressionData[uid] = progressionScore;
        }
      }

      final averageProgression =
          userCount > 0 ? (totalProgressionScore / userCount) : 0.0;

      return DifficultyProgressionAnalysis(
        averageProgressionScore: averageProgression,
        healthyProgression:
            averageProgression >= 0.9 && averageProgression <= 1.1,
      );
    } catch (e) {
      throw Exception('Failed to analyze difficulty progression: $e');
    }
  }

  // Statistical helper functions

  double _calculateMean(List<num> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  num _calculateMedian(List<num> values) {
    if (values.isEmpty) return 0;
    final sorted = List<num>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length % 2 == 0
        ? (sorted[middle - 1] + sorted[middle]) / 2
        : sorted[middle];
  }

  double _calculateStdDev(List<num> values) {
    if (values.isEmpty) return 0;
    final mean = _calculateMean(values);
    final variance =
        values.fold<num>(0, (sum, val) => sum + pow(val - mean, 2)) /
            values.length;
    return sqrt(variance).toDouble();
  }

  bool _isTimeControlBalanced(Map<String, TimeControlStats> stats) {
    for (final control in stats.values) {
      // Check if white/black win rates are balanced (close to 50-50)
      final whiteWinRate = control.whiteWinRate;
      final expectedWinRate = (1 - control.drawRate) / 2;

      // Allow 5% deviation
      if ((whiteWinRate - expectedWinRate).abs() > 0.05) {
        return false;
      }
    }
    return true;
  }
}

// Data classes for analysis results

class PuzzleDifficultyAnalysis {
  PuzzleDifficultyAnalysis({
    required this.totalPuzzles,
    required this.beginnerCount,
    required this.intermediateCount,
    required this.advancedCount,
    required this.expertCount,
    required this.masterCount,
    required this.distribution,
    required this.averageRating,
    required this.medianRating,
    required this.standardDeviation,
  });

  factory PuzzleDifficultyAnalysis.empty() => PuzzleDifficultyAnalysis(
        totalPuzzles: 0,
        beginnerCount: 0,
        intermediateCount: 0,
        advancedCount: 0,
        expertCount: 0,
        masterCount: 0,
        distribution: {},
        averageRating: 0,
        medianRating: 0,
        standardDeviation: 0,
      );
  final int totalPuzzles;
  final int beginnerCount;
  final int intermediateCount;
  final int advancedCount;
  final int expertCount;
  final int masterCount;
  final Map<String, String> distribution;
  final double averageRating;
  final num medianRating;
  final double standardDeviation;

  bool get isBalanced {
    // Target distribution
    const targetBeginnerPct = 15.0;
    const targetIntermediatePct = 35.0;
    const targetAdvancedPct = 30.0;
    const targetExpertPct = 15.0;
    const targetMasterPct = 5.0;

    final actualBeginnerPct = beginnerCount / totalPuzzles * 100;
    final actualIntermediatePct = intermediateCount / totalPuzzles * 100;
    final actualAdvancedPct = advancedCount / totalPuzzles * 100;
    final actualExpertPct = expertCount / totalPuzzles * 100;
    final actualMasterPct = masterCount / totalPuzzles * 100;

    // Allow 5% deviation from target
    return (actualBeginnerPct - targetBeginnerPct).abs() <= 5 &&
        (actualIntermediatePct - targetIntermediatePct).abs() <= 5 &&
        (actualAdvancedPct - targetAdvancedPct).abs() <= 5 &&
        (actualExpertPct - targetExpertPct).abs() <= 5 &&
        (actualMasterPct - targetMasterPct).abs() <= 5;
  }

  @override
  String toString() => '''
Puzzle Difficulty Analysis
==========================
Total Puzzles: $totalPuzzles
Beginner: $beginnerCount (${distribution['beginner']}%)
Intermediate: $intermediateCount (${distribution['intermediate']}%)
Advanced: $advancedCount (${distribution['advanced']}%)
Expert: $expertCount (${distribution['expert']}%)
Master: $masterCount (${distribution['master']}%)

Statistics:
- Average Rating: ${averageRating.toStringAsFixed(1)}
- Median Rating: $medianRating
- Std Dev: ${standardDeviation.toStringAsFixed(1)}

Balance Status: ${isBalanced ? '✓ BALANCED' : '✗ IMBALANCED'}
''';
}

class RatingSystemAnalysis {
  RatingSystemAnalysis({
    required this.totalGamesAnalyzed,
    required this.zeroSumCompliance,
    required this.averageRatingChange,
    required this.medianRatingChange,
    required this.playerAverageRating,
    required this.ratingDistributionStdDev,
    required this.ratingRangeMin,
    required this.ratingRangeMax,
    required this.zeroSumCompliant,
  });

  factory RatingSystemAnalysis.empty() => RatingSystemAnalysis(
        totalGamesAnalyzed: 0,
        zeroSumCompliance: 0,
        averageRatingChange: 0,
        medianRatingChange: 0,
        playerAverageRating: 0,
        ratingDistributionStdDev: 0,
        ratingRangeMin: 0,
        ratingRangeMax: 0,
        zeroSumCompliant: false,
      );
  final int totalGamesAnalyzed;
  final double zeroSumCompliance;
  final double averageRatingChange;
  final num medianRatingChange;
  final double playerAverageRating;
  final double ratingDistributionStdDev;
  final int ratingRangeMin;
  final int ratingRangeMax;
  final bool zeroSumCompliant;

  @override
  String toString() => '''
Rating System Analysis
======================
Total Games Analyzed: $totalGamesAnalyzed
Zero-Sum Compliance: ${zeroSumCompliance.toStringAsFixed(2)}%
Zero-Sum Compliant: ${zeroSumCompliant ? '✓ YES' : '✗ NO'}

Rating Changes:
- Average Change: ${averageRatingChange.toStringAsFixed(1)}
- Median Change: $medianRatingChange

Player Statistics:
- Average Rating: ${playerAverageRating.toStringAsFixed(0)}
- Std Dev: ${ratingDistributionStdDev.toStringAsFixed(1)}
- Range: $ratingRangeMin - $ratingRangeMax

Overall Status: ${zeroSumCompliant ? '✓ HEALTHY' : '✗ NEEDS REVIEW'}
''';
}

class TimeControlStats {
  TimeControlStats({
    required this.timeControl,
    required this.totalGames,
    required this.whiteWinRate,
    required this.blackWinRate,
    required this.drawRate,
    required this.averageGameDuration,
  });
  final String timeControl;
  final int totalGames;
  final double whiteWinRate;
  final double blackWinRate;
  final double drawRate;
  final int averageGameDuration;

  bool get isBalanced {
    final expectedWinRate = (1 - drawRate) / 2;
    // Allow 5% deviation
    return (whiteWinRate - expectedWinRate).abs() <= 0.05;
  }

  @override
  String toString() => '''
Time Control: $timeControl
- Games: $totalGames
- White Win Rate: ${(whiteWinRate * 100).toStringAsFixed(1)}%
- Black Win Rate: ${(blackWinRate * 100).toStringAsFixed(1)}%
- Draw Rate: ${(drawRate * 100).toStringAsFixed(1)}%
- Avg Duration: ${averageGameDuration}ms
- Balance: ${isBalanced ? '✓' : '✗'}
''';
}

class TimeControlAnalysis {
  TimeControlAnalysis({
    required this.timeControlStats,
    required this.balanced,
  });
  final Map<String, TimeControlStats> timeControlStats;
  final bool balanced;

  @override
  String toString() {
    final sb = StringBuffer('Time Control Analysis\n');
    sb.write('=======================\n');
    sb.write(
        'Overall Balance: ${balanced ? '✓ BALANCED' : '✗ IMBALANCED'}\n\n');

    for (final stats in timeControlStats.values) {
      sb.write(stats);
      sb.write('\n');
    }

    return sb.toString();
  }
}

class DifficultyProgressionAnalysis {
  DifficultyProgressionAnalysis({
    required this.averageProgressionScore,
    required this.healthyProgression,
  });

  factory DifficultyProgressionAnalysis.empty() =>
      DifficultyProgressionAnalysis(
        averageProgressionScore: 0,
        healthyProgression: false,
      );
  final double averageProgressionScore;
  final bool healthyProgression;

  @override
  String toString() => '''
Difficulty Progression Analysis
================================
Average Progression Score: ${averageProgressionScore.toStringAsFixed(2)}
Target Range: 0.90 - 1.10
Status: ${healthyProgression ? '✓ HEALTHY' : '✗ NEEDS ADJUSTMENT'}

Note: Score > 1.0 means players are solving puzzles above their rating level
Note: Score < 1.0 means players are solving puzzles below their rating level
''';
}
