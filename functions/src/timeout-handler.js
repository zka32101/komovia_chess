/**
 * Game timeout handling
 * 
 * Responsibilities:
 * - Detect timeouts
 * - End games with timeout result
 * - Calculate rating changes
 * - Log timeout events
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
 * `users/{uid}` docs (onlineRating/wins/losses/draws/gamesPlayed) were
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

  // Update game with timeout result
  batch.update(gameRef, {
    status: "completed",
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    result: result,
    resultReason: "timeout",
    whiteRatingDelta: changes.whiteChange,
    blackRatingDelta: changes.blackChange,
    whiteNewRating: whiteNewRating,
    blackNewRating: blackNewRating,
  });

  const winnerId = isWhiteTimeout ? game.blackPlayerId : game.whitePlayerId;
  const loserId = isWhiteTimeout ? game.whitePlayerId : game.blackPlayerId;

  if (game.whitePlayerId) {
    batch.update(db.collection("users").doc(game.whitePlayerId), {
      onlineRating: whiteNewRating,
      gamesPlayed: admin.firestore.FieldValue.increment(1),
      [isWhiteTimeout ? "losses" : "wins"]: admin.firestore.FieldValue.increment(1),
    });
  }
  if (game.blackPlayerId) {
    batch.update(db.collection("users").doc(game.blackPlayerId), {
      onlineRating: blackNewRating,
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

/**
 * Check and handle timeouts in active games
 */
async function checkAndHandleTimeouts() {
  try {
    const snapshot = await db
      .collection("games")
      .where("status", "==", "active")
      .get();

    let timeoutCount = 0;
    const batch = db.batch();
    const winnerIds = [];

    const now = Date.now();

    for (const doc of snapshot.docs) {
      const game = doc.data();

      // Get start time and last move time
      const startTime = game.startedAt ? game.startedAt.toMillis() : now;
      const lastMoveTime = game.lastMoveTimestamp
        ? game.lastMoveTimestamp.toMillis()
        : startTime;

      // Calculate elapsed time since last move
      const elapsedMs = now - lastMoveTime;

      // Check white timeout
      if (game.whiteTimeRemainingMs - elapsedMs <= 0) {
        const { winnerId } = handleGameTimeout(batch, doc.ref, game, "white");
        if (winnerId) winnerIds.push(winnerId);
        timeoutCount++;
        continue;
      }

      // Check black timeout
      if (game.blackTimeRemainingMs - elapsedMs <= 0) {
        const { winnerId } = handleGameTimeout(batch, doc.ref, game, "black");
        if (winnerId) winnerIds.push(winnerId);
        timeoutCount++;
      }
    }

    if (timeoutCount > 0) {
      await batch.commit();
      console.log(`Handled ${timeoutCount} timeouts`);
      await maybeUnlockAchievementsAfterTimeouts(winnerIds);
    }

    return { timeoutCount };
  } catch (error) {
    console.error("Timeout check error:", error);
    throw error;
  }
}

module.exports = {
  handleGameTimeout,
  maybeUnlockAchievementsAfterTimeouts,
  cleanupExpiredQueues,
  checkAndHandleTimeouts,
};
