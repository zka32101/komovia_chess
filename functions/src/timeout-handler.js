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

const db = admin.firestore();

/**
 * Handle timeout for a game
 * @param {admin.firestore.WriteBatch} batch - Firestore batch for atomic updates
 * @param {admin.firestore.DocumentReference} gameRef - Reference to game document
 * @param {Object} game - Game data
 * @param {string} timedOutPlayer - 'white' or 'black'
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

  console.log(
    `Game ${gameRef.id}: ${timedOutPlayer} timed out. Result: ${result}`
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
        handleGameTimeout(batch, doc.ref, game, "white");
        timeoutCount++;
        continue;
      }

      // Check black timeout
      if (game.blackTimeRemainingMs - elapsedMs <= 0) {
        handleGameTimeout(batch, doc.ref, game, "black");
        timeoutCount++;
      }
    }

    if (timeoutCount > 0) {
      await batch.commit();
      console.log(`Handled ${timeoutCount} timeouts`);
    }

    return { timeoutCount };
  } catch (error) {
    console.error("Timeout check error:", error);
    throw error;
  }
}

module.exports = {
  handleGameTimeout,
  cleanupExpiredQueues,
  checkAndHandleTimeouts,
};
