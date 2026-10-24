/**
 * Pure computation of what finishing a game with [result] requires -
 * the game doc patch, and each player's users/{uid} doc patch. Mirrors
 * OnlineGameService._endGameWithResult (Dart) and
 * timeout-handler.js's handleGameTimeout: same rating/wins/
 * losses/draws/gamesPlayed fields, same ELO formula. `rating` is the
 * single canonical rating field both CPU and online games write to
 * (see UserModel.rating's doc comment on the Dart side) - previously
 * this wrote a separate `onlineRating` field here while the Dart
 * client-side ending path wrote the same thing, so as long as both
 * used that name they agreed with each other, but neither agreed with
 * the CPU-game `rating` field the leaderboard (ranking_service.dart)
 * actually sorts by. Kept separate from
 * timeout-handler.js's own inline version (rather than refactoring it
 * to share this) to avoid widening that already-merged fix's surface;
 * a later pass can consolidate both onto this module.
 *
 * Callers apply the three returned patches via whatever write
 * mechanism fits their context (a plain update() here in recordMove, a
 * WriteBatch in timeout-handler.js).
 */

const admin = require("firebase-admin");
const { calculateRatingChanges } = require("./rating-system");

function computeGameEndUpdates(game, result, resultReason) {
  const changes = calculateRatingChanges(
    game.whiteRating,
    game.blackRating,
    result
  );
  const whiteNewRating = game.whiteRating + changes.whiteChange;
  const blackNewRating = game.blackRating + changes.blackChange;

  const whiteOutcome =
    result === "white_win" ? "wins" : result === "draw" ? "draws" : "losses";
  const blackOutcome =
    result === "black_win" ? "wins" : result === "draw" ? "draws" : "losses";

  const gameUpdate = {
    status: "completed",
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    result,
    resultReason,
    whiteRatingDelta: changes.whiteChange,
    blackRatingDelta: changes.blackChange,
    whiteNewRating,
    blackNewRating,
    // Mirrors OnlineGameService._endGameWithResult (Dart) clearing both
    // flags as part of the same write a game-ending update already
    // makes, rather than leaving a stale drawOfferedBy/
    // takebackRequestedBy behind on a now-completed game.
    drawOfferedBy: null,
    takebackRequestedBy: null,
  };

  const whiteUserUpdate = {
    rating: whiteNewRating,
    gamesPlayed: admin.firestore.FieldValue.increment(1),
    [whiteOutcome]: admin.firestore.FieldValue.increment(1),
  };

  const blackUserUpdate = {
    rating: blackNewRating,
    gamesPlayed: admin.firestore.FieldValue.increment(1),
    [blackOutcome]: admin.firestore.FieldValue.increment(1),
  };

  const winnerId =
    result === "white_win"
      ? game.whitePlayerId
      : result === "black_win"
      ? game.blackPlayerId
      : null;

  return { gameUpdate, whiteUserUpdate, blackUserUpdate, winnerId };
}

module.exports = { computeGameEndUpdates };
