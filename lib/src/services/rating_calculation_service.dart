import 'dart:math';

/// Exception thrown when rating calculation fails.
class RatingCalculationException implements Exception {
  RatingCalculationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service for calculating ELO ratings in chess.
///
/// Implements the standard ELO rating system with K-factor adjustment
/// based on player rating tier.
///
/// References:
/// - https://en.wikipedia.org/wiki/Elo_rating_system
/// - FIDE Rating System (https://www.fide.com)
class RatingCalculationService {
  /// Minimum rating threshold
  static const int minRating = 100;

  /// Maximum rating threshold
  static const int maxRating = 3000;

  /// Rating range for developing players (K-factor = 40)
  static const int developingPlayerThreshold = 1400;

  /// Rating range for expert players (K-factor = 24)
  static const int expertPlayerThreshold = 1800;

  /// K-factor for developing players (rating < 1400)
  static const int kFactorDeveloping = 40;

  /// K-factor for standard players (1400 <= rating <= 1800)
  static const int kFactorStandard = 32;

  /// K-factor for expert players (rating > 1800)
  static const int kFactorExpert = 24;

  /// Calculates new rating after a game.
  ///
  /// Parameters:
  /// - [playerRating]: Current rating of the player
  /// - [opponentRating]: Current rating of the opponent
  /// - [result]: Game result (1.0 = win, 0.5 = draw, 0.0 = loss)
  ///
  /// Returns: New rating clamped to [minRating, maxRating]
  ///
  /// Formula: new_rating = old_rating + K * (result - expectedScore)
  /// where expectedScore = 1 / (1 + 10^((opponentRating - playerRating) / 400))
  static int calculateNewRating(
    int playerRating,
    int opponentRating,
    double result,
  ) {
    // Validate inputs
    if (!isValidRating(playerRating)) {
      throw RatingCalculationException(
        'Player rating $playerRating is outside valid range [$minRating, $maxRating]',
      );
    }
    if (!isValidRating(opponentRating)) {
      throw RatingCalculationException(
        'Opponent rating $opponentRating is outside valid range [$minRating, $maxRating]',
      );
    }
    if (result < 0.0 || result > 1.0) {
      throw RatingCalculationException(
        'Result $result must be between 0.0 (loss) and 1.0 (win)',
      );
    }

    // Get appropriate K-factor for player's rating
    final K = getKFactor(playerRating);

    // Calculate expected score
    final expectedScore = calculateExpectedScore(playerRating, opponentRating);

    // Calculate rating change
    final ratingChange = (K * (result - expectedScore)).round();

    // Calculate new rating and clamp to valid range
    final newRating = playerRating + ratingChange;
    return newRating.clamp(minRating, maxRating);
  }

  /// Calculates the expected score for a player against an opponent.
  ///
  /// Expected score represents the probability of winning:
  /// - 1.0 = strong player vs weak player (should win)
  /// - 0.5 = equal strength players (50/50 chance)
  /// - 0.0 = weak player vs strong player (will likely lose)
  ///
  /// Formula: expectedScore = 1 / (1 + 10^((opponentRating - playerRating) / 400))
  static double calculateExpectedScore(int playerRating, int opponentRating) {
    final ratingDifference = opponentRating - playerRating;
    final exponent = ratingDifference / 400.0;
    return 1.0 / (1.0 + pow(10, exponent));
  }

  /// Gets the K-factor based on player's current rating.
  ///
  /// K-factor determines rating volatility:
  /// - Higher K-factor = larger rating swings (for developing players)
  /// - Lower K-factor = smaller rating swings (for expert players)
  ///
  /// Tiers:
  /// - Developing (< 1400): K = 40 (encourages rating growth)
  /// - Standard (1400-1800): K = 32 (standard progression)
  /// - Expert (> 1800): K = 24 (stable ratings)
  static int getKFactor(int rating) {
    if (rating < developingPlayerThreshold) {
      return kFactorDeveloping;
    } else if (rating <= expertPlayerThreshold) {
      return kFactorStandard;
    } else {
      return kFactorExpert;
    }
  }

  /// Gets the rating tier name for a given rating.
  ///
  /// Tiers (chess strength levels):
  /// - Beginner: < 1000
  /// - Intermediate: 1000-1399
  /// - Advanced: 1400-1799
  /// - Expert: 1800-1999
  /// - Master: 2000-2199
  /// - Grandmaster: 2200+
  static String getRatingTier(int rating) {
    if (rating < 1000) {
      return 'Beginner';
    } else if (rating < 1400) {
      return 'Intermediate';
    } else if (rating < 1800) {
      return 'Advanced';
    } else if (rating < 2000) {
      return 'Expert';
    } else if (rating < 2200) {
      return 'Master';
    } else {
      return 'Grandmaster';
    }
  }

  /// Checks if a rating is within valid range.
  static bool isValidRating(int rating) =>
      rating >= minRating && rating <= maxRating;

  /// Calculates rating change (delta) for a player.
  ///
  /// Useful for displaying to user how much rating changed.
  static int calculateRatingDelta(
    int playerRating,
    int opponentRating,
    double result,
  ) {
    final K = getKFactor(playerRating);
    final expectedScore = calculateExpectedScore(playerRating, opponentRating);
    return (K * (result - expectedScore)).round();
  }

  /// Gets color/emoji representation of rating tier for UI display.
  static String getRatingTierEmoji(int rating) {
    switch (getRatingTier(rating)) {
      case 'Beginner':
        return '🥉'; // Bronze
      case 'Intermediate':
        return '🥈'; // Silver
      case 'Advanced':
        return '🥇'; // Gold
      case 'Expert':
        return '🏆'; // Trophy
      case 'Master':
        return '👑'; // Crown
      case 'Grandmaster':
        return '♔'; // Chess King
      default:
        return '♟️'; // Pawn
    }
  }

  /// Calculates rating change for both players in a game.
  ///
  /// Returns a map with:
  /// - 'whiteRatingDelta': Change for white player
  /// - 'blackRatingDelta': Change for black player
  ///
  /// Note: Sum of deltas may not be exactly zero due to rounding.
  static Map<String, int> calculateBothPlayersRatingDelta(
    int whiteRating,
    int blackRating,
    String result, // 'white_win', 'black_win', 'draw'
  ) {
    double whiteResult;
    double blackResult;

    switch (result) {
      case 'white_win':
        whiteResult = 1.0;
        blackResult = 0.0;
        break;
      case 'black_win':
        whiteResult = 0.0;
        blackResult = 1.0;
        break;
      case 'draw':
        whiteResult = 0.5;
        blackResult = 0.5;
        break;
      default:
        throw RatingCalculationException('Invalid result: $result');
    }

    final whiteDelta =
        calculateRatingDelta(whiteRating, blackRating, whiteResult);
    final blackDelta =
        calculateRatingDelta(blackRating, whiteRating, blackResult);

    return {
      'whiteRatingDelta': whiteDelta,
      'blackRatingDelta': blackDelta,
    };
  }
}
