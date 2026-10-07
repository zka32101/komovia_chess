/**
 * ELO Rating System
 * 
 * Standard chess rating formula:
 * ΔR = K × (S - E)
 * 
 * Where:
 * - K = Rating factor (32 for standard)
 * - S = Actual score (1, 0.5, 0)
 * - E = Expected score
 */

const K_FACTOR = 32;
const D_CONSTANT = 400;

/**
 * Calculate rating changes for both players
 * @param {number} whiteRating - White player's current rating
 * @param {number} blackRating - Black player's current rating
 * @param {string} result - 'white_win', 'black_win', or 'draw'
 * @returns {Object} Rating changes for both players
 */
function calculateRatingChanges(whiteRating, blackRating, result) {
  // Calculate expected scores
  const whiteExpected = getExpectedScore(whiteRating, blackRating);
  const blackExpected = 1.0 - whiteExpected;

  // Determine actual scores based on result
  let whiteScore, blackScore;
  switch (result) {
    case "white_win":
      whiteScore = 1.0;
      blackScore = 0.0;
      break;
    case "black_win":
      whiteScore = 0.0;
      blackScore = 1.0;
      break;
    case "draw":
      whiteScore = 0.5;
      blackScore = 0.5;
      break;
    default:
      whiteScore = 0.5;
      blackScore = 0.5;
  }

  // Calculate rating changes
  const whiteChange = Math.round(K_FACTOR * (whiteScore - whiteExpected));
  const blackChange = Math.round(K_FACTOR * (blackScore - blackExpected));

  return {
    whiteChange,
    blackChange,
    whiteExpected,
    blackExpected,
  };
}

/**
 * Get expected score for player 1 vs player 2
 * Formula: E = 1 / (1 + 10^((opponent - player) / 400))
 */
function getExpectedScore(playerRating, opponentRating) {
  const diff = opponentRating - playerRating;
  const exponent = diff / D_CONSTANT;
  return 1.0 / (1.0 + Math.pow(10, exponent));
}

/**
 * Validate rating change (for anomaly detection)
 */
function validateRatingChange(change, expectedChange) {
  // Flag unusual rating changes (e.g., >80 points)
  const diff = Math.abs(change - expectedChange);
  return diff <= 80;
}

/**
 * Calculate win probability between two players
 */
function getWinProbability(player1Rating, player2Rating) {
  const player1Expected = getExpectedScore(player1Rating, player2Rating);
  return {
    player1: player1Expected,
    player2: 1.0 - player1Expected,
  };
}

/**
 * Estimate required rating for target win rate
 */
function estimateRequiredRating(opponentRating, targetWinRate) {
  // E = targetWinRate
  // 1 / (1 + 10^((opponent - player) / 400)) = E
  // Solving for player rating:
  // player = opponent - 400 * log10((1 - E) / E)
  
  if (targetWinRate <= 0 || targetWinRate >= 1) {
    return null;
  }
  
  const logValue = Math.log10((1 - targetWinRate) / targetWinRate);
  return opponentRating - D_CONSTANT * logValue;
}

/**
 * Detailed rating analysis for leaderboard/statistics
 */
function analyzeRatingChange(whiteRating, blackRating, result, actualChange) {
  const changes = calculateRatingChanges(whiteRating, blackRating, result);
  const isWhiteWin = result === "white_win";
  const playerChange = isWhiteWin ? changes.whiteChange : changes.blackChange;
  
  return {
    result,
    expectedChange: playerChange,
    actualChange,
    variance: actualChange - playerChange,
    isUpset: (isWhiteWin && changes.whiteExpected < 0.3) ||
             (!isWhiteWin && changes.whiteExpected > 0.7),
    confidence: Math.abs(changes.whiteExpected - 0.5), // 0-0.5, higher = more certain
  };
}

module.exports = {
  calculateRatingChanges,
  getExpectedScore,
  validateRatingChange,
  getWinProbability,
  estimateRequiredRating,
  analyzeRatingChange,
  K_FACTOR,
  D_CONSTANT,
};
