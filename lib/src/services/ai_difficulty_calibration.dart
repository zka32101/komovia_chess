import 'package:chess/chess.dart' as chess_lib;

/// Enhanced AI difficulty levels with precise calibration
enum AIDifficultyLevel {
  beginner,
  intermediate,
  advanced,
  expert,
  master,
}

/// Extension providing calibration parameters for each difficulty level
extension AIDifficultyCalibration on AIDifficultyLevel {
  /// Target Elo rating for this difficulty level
  int get targetElo {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 100;
      case AIDifficultyLevel.intermediate:
        return 1000;
      case AIDifficultyLevel.advanced:
        return 1500;
      case AIDifficultyLevel.expert:
        return 2000;
      case AIDifficultyLevel.master:
        return 2600;
    }
  }

  /// Search depth (plies) for minimax algorithm
  int get searchDepth {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 3;
      case AIDifficultyLevel.intermediate:
        return 5;
      case AIDifficultyLevel.advanced:
        return 7;
      case AIDifficultyLevel.expert:
        return 10;
      case AIDifficultyLevel.master:
        return 12;
    }
  }

  /// Thinking time in milliseconds
  int get thinkingTimeMs {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 300;
      case AIDifficultyLevel.intermediate:
        return 800;
      case AIDifficultyLevel.advanced:
        return 1500;
      case AIDifficultyLevel.expert:
        return 3000;
      case AIDifficultyLevel.master:
        return 5000;
    }
  }

  /// Move quality threshold - percentage of best moves to consider (0-100)
  /// Lower values = more random/weaker play
  int get moveQualityThreshold {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 40; // Considers only top 40% of legal moves
      case AIDifficultyLevel.intermediate:
        return 60; // Considers top 60% of legal moves
      case AIDifficultyLevel.advanced:
        return 80; // Considers top 80% of legal moves
      case AIDifficultyLevel.expert:
        return 90; // Considers top 90% of legal moves
      case AIDifficultyLevel.master:
        return 100; // Considers all moves, picks best
    }
  }

  /// Target move quality score (0-100)
  int get targetMoveQuality {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 60;
      case AIDifficultyLevel.intermediate:
        return 75;
      case AIDifficultyLevel.advanced:
        return 85;
      case AIDifficultyLevel.expert:
        return 92;
      case AIDifficultyLevel.master:
        return 96;
    }
  }

  /// Expected accuracy percentage (percentage of best/good moves)
  double get expectedAccuracy {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 0.65;
      case AIDifficultyLevel.intermediate:
        return 0.80;
      case AIDifficultyLevel.advanced:
        return 0.88;
      case AIDifficultyLevel.expert:
        return 0.93;
      case AIDifficultyLevel.master:
        return 0.96;
    }
  }

  /// Probability of making a blunder (0-1)
  double get blunderProbability {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 0.15; // 15% blunder rate
      case AIDifficultyLevel.intermediate:
        return 0.08; // 8% blunder rate
      case AIDifficultyLevel.advanced:
        return 0.03; // 3% blunder rate
      case AIDifficultyLevel.expert:
        return 0.01; // 1% blunder rate
      case AIDifficultyLevel.master:
        return 0.005; // 0.5% blunder rate
    }
  }

  /// Probability of playing a move one rank lower in quality (0-1)
  double get secondBestProbability {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 0.30;
      case AIDifficultyLevel.intermediate:
        return 0.18;
      case AIDifficultyLevel.advanced:
        return 0.08;
      case AIDifficultyLevel.expert:
        return 0.03;
      case AIDifficultyLevel.master:
        return 0.01;
    }
  }

  /// Use opening book (pre-computed good openings)
  bool get useOpeningBook {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return true;
      case AIDifficultyLevel.intermediate:
        return true;
      case AIDifficultyLevel.advanced:
        return true;
      case AIDifficultyLevel.expert:
        return true;
      case AIDifficultyLevel.master:
        return true;
    }
  }

  /// Use endgame tablebases for perfect endgame play
  bool get useEndgameTablebases {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return false;
      case AIDifficultyLevel.intermediate:
        return false;
      case AIDifficultyLevel.advanced:
        return true;
      case AIDifficultyLevel.expert:
        return true;
      case AIDifficultyLevel.master:
        return true;
    }
  }

  /// Quiescence search depth for tactical evaluation
  int get quiescenceDepth {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 1;
      case AIDifficultyLevel.intermediate:
        return 2;
      case AIDifficultyLevel.advanced:
        return 3;
      case AIDifficultyLevel.expert:
        return 4;
      case AIDifficultyLevel.master:
        return 5;
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 'Beginner';
      case AIDifficultyLevel.intermediate:
        return 'Intermediate';
      case AIDifficultyLevel.advanced:
        return 'Advanced';
      case AIDifficultyLevel.expert:
        return 'Expert';
      case AIDifficultyLevel.master:
        return 'Master';
    }
  }

  /// Description for difficulty selection screen
  String get description {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 'Perfect for beginners. AI plays basic moves and makes frequent mistakes.';
      case AIDifficultyLevel.intermediate:
        return 'Good challenge for casual players. AI plays with basic strategy.';
      case AIDifficultyLevel.advanced:
        return 'Challenging. AI understands tactics and maintains positions.';
      case AIDifficultyLevel.expert:
        return 'Very challenging. AI plays strong tactics and strategy.';
      case AIDifficultyLevel.master:
        return 'Master level. AI plays at expert competitive level.';
    }
  }

  /// Win rate expectation against human players (0-1)
  double get estimatedHumanWinRate {
    switch (this) {
      case AIDifficultyLevel.beginner:
        return 0.75; // Beginner AI loses 75% to intermediate players
      case AIDifficultyLevel.intermediate:
        return 0.55; // Intermediate AI beats beginner players 55%
      case AIDifficultyLevel.advanced:
        return 0.65; // Advanced AI beats casual players 65%
      case AIDifficultyLevel.expert:
        return 0.80; // Expert AI beats most players 80%
      case AIDifficultyLevel.master:
        return 0.85; // Master AI beats almost everyone
    }
  }
}

/// Move quality scorer for evaluating move strength
class MoveQualityScorer {
  /// Score a move from 0 (blunder) to 100 (best move)
  ///
  /// Scoring criteria:
  /// - 95-100: Best or only move (winning, mate, win material)
  /// - 85-94: Excellent move (clear advantage)
  /// - 75-84: Good move (maintains advantage)
  /// - 65-74: Acceptable move (no significant change)
  /// - 50-64: Mediocre move (slight disadvantage)
  /// - 0-49: Blunder (losing move)
  static int scoreMove({
    required chess_lib.Chess position,
    required String moveFrom,
    required String moveTo,
    required int evaluation,
    required int bestEvaluation,
  }) {
    final evaluationDiff = bestEvaluation - evaluation;

    // If this is the best move
    if (evaluationDiff == 0) {
      return 100;
    }

    // Loss of material (> 300 centipawns)
    if (evaluationDiff > 300) {
      return 0; // Blunder
    }

    // Losing move (> 100 centipawns loss)
    if (evaluationDiff > 100) {
      return 25 + (75 * (1 - evaluationDiff / 300)).toInt();
    }

    // Mediocre move (50-100 centipawns worse)
    if (evaluationDiff > 50) {
      return 50 + (25 * (1 - evaluationDiff / 100)).toInt();
    }

    // Acceptable move (20-50 centipawns difference)
    if (evaluationDiff > 20) {
      return 65 + (10 * (1 - evaluationDiff / 50)).toInt();
    }

    // Good move (< 20 centipawns difference)
    return 85 + (15 * (1 - evaluationDiff / 20)).toInt();
  }

  /// Calculate accuracy percentage for a set of moves
  static double calculateAccuracy(List<int> moveQualities) {
    if (moveQualities.isEmpty) return 0;

    // Count good (75+) and excellent (85+) moves
    final goodMoves = moveQualities.where((q) => q >= 75).length;

    return (goodMoves / moveQualities.length) * 100;
  }
}

/// Difficulty calibration validator
class DifficultyValidator {
  /// Validate that AI is playing at expected difficulty level
  /// based on move quality scores from a game
  static bool validateDifficulty({
    required AIDifficultyLevel difficulty,
    required List<int> aiMoveQualities,
  }) {
    if (aiMoveQualities.isEmpty) return false;

    final averageQuality =
        aiMoveQualities.reduce((a, b) => a + b) / aiMoveQualities.length;
    final accuracy = MoveQualityScorer.calculateAccuracy(aiMoveQualities);

    final expectedQuality = difficulty.targetMoveQuality;
    final expectedAccuracy = difficulty.expectedAccuracy * 100;

    // Allow 10% tolerance
    final qualityOk =
        (averageQuality - expectedQuality).abs() <= (expectedQuality * 0.1);
    final accuracyOk =
        (accuracy - expectedAccuracy).abs() <= (expectedAccuracy * 0.1);

    return qualityOk && accuracyOk;
  }

  /// Get recommendation for adjusting difficulty
  static String? getDifficultyAdjustment({
    required AIDifficultyLevel difficulty,
    required double actualWinRate,
    required double targetWinRate,
  }) {
    final diff = actualWinRate - targetWinRate;

    // If AI is winning too much (> 10% higher than target)
    if (diff > 0.10) {
      final index = difficulty.index;
      if (index > 0) {
        return 'Reduce difficulty: AI playing too strong. Current win rate: ${(actualWinRate * 100).toStringAsFixed(1)}%, Target: ${(targetWinRate * 100).toStringAsFixed(1)}%';
      }
    }

    // If AI is losing too much (> 10% lower than target)
    if (diff < -0.10) {
      final index = difficulty.index;
      if (index < AIDifficultyLevel.values.length - 1) {
        return 'Increase difficulty: AI playing too weak. Current win rate: ${(actualWinRate * 100).toStringAsFixed(1)}%, Target: ${(targetWinRate * 100).toStringAsFixed(1)}%';
      }
    }

    return null; // Difficulty is well calibrated
  }
}
