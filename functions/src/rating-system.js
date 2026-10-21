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

module.exports = {
  calculateRatingChanges,
  getExpectedScore,
  K_FACTOR,
  D_CONSTANT,
};
