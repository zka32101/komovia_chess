/**
 * Game timeout handling
 *
 * Responsibilities:
 * - Detect timeouts
 * - End games with timeout result
 * - Calculate rating changes
 * - Log timeout events
 *
 * This module used to also export `checkAndHandleTimeouts`, a full
 * duplicate of the scan-and-flag loop that `exports.handleTimeout`
 * (index.js) implements inline - it was never actually called from
 * anywhere (index.js only imports `handleGameTimeout`/
 * `maybeUnlockAchievementsAfterTimeouts`), and it carried the same
 * whose-turn-is-it-anyway bug index.js's copy had (checking BOTH
 * players' remaining time against the same elapsed-since-last-move
 * value, regardless of whose turn it actually was) - fixing one copy
 * without the other would have left this dead, misleading twin behind.
 * Removed outright rather than fixed, since nothing used it.
 */

const admin = require("firebase-admin");
const { calculateRatingChanges } = require("./rating-system");
const { checkAndUnlockAchievements } = require("./achievement-service");

const db = admin.firestore();

/**
 * Handle timeout for a game
 *
 * Mirrors OnlineGameService._endGameWithResult (Dart) for a timeout
 * ending: previously this only ever updated the `games/{gameId}` doc
 * itself (status/result/ratingDelta fields) - the game's two players'
 * `users/{uid}` docs (rating/wins/losses/draws/gamesPlayed) were
 * never touched at all when a game ended by timeout specifically, unlike
 * every other way a game can end (resign/draw/abandonment), which all
 * route through `_endGameWithResult` on the client. A player who timed an
 * opponent out server-side never got credit for the win.
 *
 * Achievement unlocking is handled by the caller after the batch commits
 * (see `maybeUnlockAchievementsAfterTimeouts`), since it needs to read the
 * just-incremented `wins` count back from Firestore.
 *
 * @param {admin.firestore.WriteBatch} batch - Firestore batch for atomic updates
 * @param {admin.firestore.DocumentReference} gameRef - Reference to game document
 * @param {Object} game - Game data
 * @param {string} timedOutPlayer - 'white' or 'black'
 * @returns {{winnerId: string}} the uid of the player who won by timeout
 */
function handleGameTimeout(batch, gameRef, game, timedOutPlayer) {
  const isWhiteTimeout = timedOutPlayer === "white";
  const result = isWhiteTimeout ? "black_win" : "white_win";

  // Calculate rating changes
  const changes = calculateRatingChanges(
    game.whiteRating,
    game.blackRating,
    result
  );

  const whiteNewRating = game.whiteRating + changes.whiteChange;
  const blackNewRating = game.blackRating + changes.blackChange;

  // Update game with timeout result. Clears drawOfferedBy/
  // takebackRequestedBy too, mirroring every other game-ending path
  // (OnlineGameService._endGameWithResult on the Dart side, and
  // computeGameEndUpdates for recordMove's own in-transaction endings) -
  // previously only this one path left either field stale on a completed
  // game if a draw offer or takeback request happened to be pending the
  // moment the clock ran out.
  batch.update(gameRef, {
    status: "completed",
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    result: result,
    resultReason: "timeout",
    whiteRatingDelta: changes.whiteChange,
    blackRatingDelta: changes.blackChange,
    whiteNewRating: whiteNewRating,
    blackNewRating: blackNewRating,
    drawOfferedBy: null,
    takebackRequestedBy: null,
  });

  const winnerId = isWhiteTimeout ? game.blackPlayerId : game.whitePlayerId;
  const loserId = isWhiteTimeout ? game.whitePlayerId : game.blackPlayerId;

  if (game.whitePlayerId) {
    batch.update(db.collection("users").doc(game.whitePlayerId), {
      rating: whiteNewRating,
      gamesPlayed: admin.firestore.FieldValue.increment(1),
      [isWhiteTimeout ? "losses" : "wins"]: admin.firestore.FieldValue.increment(1),
    });
  }
  if (game.blackPlayerId) {
    batch.update(db.collection("users").doc(game.blackPlayerId), {
      rating: blackNewRating,
      gamesPlayed: admin.firestore.FieldValue.increment(1),
      [isWhiteTimeout ? "wins" : "losses"]: admin.firestore.FieldValue.increment(1),
    });
  }

  console.log(
    `Game ${gameRef.id}: ${timedOutPlayer} timed out. Result: ${result}`
  );

  return { winnerId, loserId };
}

/**
 * Best-effort achievement check for players who just won a game by
 * timeout, run after the batch that recorded their win has committed (so
 * the `wins` read inside reflects the increment). Swallows its own
 * errors - never lets an achievement-check failure affect the timeout
 * handling that already succeeded.
 * @param {string[]} winnerIds
 */
async function maybeUnlockAchievementsAfterTimeouts(winnerIds) {
  await Promise.all(
    winnerIds.map((uid) => checkAndUnlockAchievements(db, uid))
  );
}

/**
 * Cleanup expired queue entries
 */
async function cleanupExpiredQueues() {
  const now = admin.firestore.Timestamp.now();

  try {
    const snapshot = await db
      .collection("matchmaking_queue")
      .where("timeoutAt", "<", now)
      .get();

    let cleaned = 0;
    const batch = db.batch();

    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      cleaned++;
    }

    if (cleaned > 0) {
      await batch.commit();
      console.log(`Cleaned up ${cleaned} expired queue entries`);
    }

    return { cleaned };
  } catch (error) {
    console.error("Queue cleanup error:", error);
    throw error;
  }
}

module.exports = {
  handleGameTimeout,
  maybeUnlockAchievementsAfterTimeouts,
  cleanupExpiredQueues,
};
