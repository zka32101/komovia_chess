const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { matchPlayers } = require("./matchmaking");
const { validateMove, updateGameState } = require("./game-validation");
const { handleGameTimeout, cleanupExpiredQueues } = require("./timeout-handler");
const { calculateRatingChanges } = require("./rating-system");

admin.initializeApp();

const db = admin.firestore();
const realtimeDb = admin.database();

/**
 * Cloud Function: Find matches in queue every 5 seconds
 * Pairs players with compatible ratings
 */
exports.matchmakingWorker = functions
  .runWith({ timeoutSeconds: 540, memory: "256MB" })
  .pubsub.schedule("every 5 seconds")
  .onRun(async (context) => {
    console.log("Starting matchmaking worker...");

    try {
      // Get all waiting queue entries
      const snapshot = await db
        .collection("matchmaking_queue")
        .where("status", "==", "waiting")
        .orderBy("priority", "descending")
        .orderBy("queuedAt", "ascending")
        .get();

      if (snapshot.empty) {
        console.log("No players in queue");
        return null;
      }

      const queueEntries = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Attempt to match players
      const matches = matchPlayers(queueEntries);
      console.log(`Found ${matches.length} matches`);

      // Create games for each match
      const batch = db.batch();

      for (const match of matches) {
        const gameId = db.collection("games").doc().id;
        const now = admin.firestore.Timestamp.now();

        // Determine colors
        const whiteId =
          match.player1.color === "white"
            ? match.player1.playerId
            : match.player2.playerId;
        const blackId =
          match.player1.color === "black"
            ? match.player1.playerId
            : match.player2.playerId;
        const whitePlayer =
          match.player1.playerId === whiteId ? match.player1 : match.player2;
        const blackPlayer =
          match.player1.playerId === blackId ? match.player1 : match.player2;

        // Create game document
        const gameData = {
          gameId,
          type: "online_pvp",
          status: "matchmaking",
          createdAt: now,
          whitePlayerId: whiteId,
          blackPlayerId: blackId,
          whitePlayerName: whitePlayer.playerName,
          blackPlayerName: blackPlayer.playerName,
          whiteRating: whitePlayer.currentRating,
          blackRating: blackPlayer.currentRating,
          pgn: "",
          currentFen:
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
          moves: [],
          timeControl: match.timeControlType,
          timeControlMs: timeControlMs(match.timeControlType),
          whiteTimeRemainingMs: timeControlMs(match.timeControlType),
          blackTimeRemainingMs: timeControlMs(match.timeControlType),
        };

        batch.set(db.collection("games").doc(gameId), gameData);

        // Update queue entries
        batch.update(
          db.collection("matchmaking_queue").doc(match.player1.queueId),
          {
            status: "matched",
            matchedGameId: gameId,
            matchedOpponentId: match.player2.playerId,
          }
        );

        batch.update(
          db.collection("matchmaking_queue").doc(match.player2.queueId),
          {
            status: "matched",
            matchedGameId: gameId,
            matchedOpponentId: match.player1.playerId,
          }
        );

        // Create Realtime DB game node for real-time sync
        await realtimeDb.ref(`games/${gameId}`).set({
          status: "matchmaking",
          createdAt: Date.now(),
          whitePlayerId: whiteId,
          blackPlayerId: blackId,
        });
      }

      await batch.commit();
      console.log(`Created ${matches.length} games`);

      return { matched: matches.length };
    } catch (error) {
      console.error("Matchmaking error:", error);
      throw error;
    }
  });

/**
 * Cloud Function: Record player move
 * Validates move legality and updates game state
 */
exports.recordMove = functions
  .runWith({ timeoutSeconds: 30, memory: "256MB" })
  .https.onCall(async (data, context) => {
    const { gameId, from, to, promotion, playerId, fen, pgn } = data;

    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    // Verify player is in the game
    if (context.auth.uid !== playerId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Player ID mismatch"
      );
    }

    try {
      const gameRef = db.collection("games").doc(gameId);
      const gameDoc = await gameRef.get();

      if (!gameDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Game not found");
      }

      const game = gameDoc.data();

      // Verify game is active
      if (game.status !== "active") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Game is not active"
        );
      }

      // Verify it's the player's turn
      const moveCount = game.moves ? game.moves.length : 0;
      const isWhiteTurn = moveCount % 2 === 0;
      const isWhitePlayer = playerId === game.whitePlayerId;

      if (isWhiteTurn !== isWhitePlayer) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Not player's turn"
        );
      }

      // Validate move (chess logic validation would go here)
      // In production, use chess.js or similar library
      if (!validateMove(game.currentFen, from, to)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Illegal move"
        );
      }

      // Record move
      const moveRecord = {
        moveNumber: moveCount + 1,
        from,
        to,
        promotion: promotion || null,
        timestamp: admin.firestore.Timestamp.now(),
        playerId,
      };

      // Update game
      await gameRef.update({
        currentFen: fen,
        pgn: pgn,
        moves: admin.firestore.FieldValue.arrayUnion([moveRecord]),
        lastMoveTimestamp: admin.firestore.Timestamp.now(),
        [isWhitePlayer ? "whiteLastActivityTimestamp" : "blackLastActivityTimestamp"]:
          admin.firestore.Timestamp.now(),
      });

      // Sync to Realtime DB
      await realtimeDb.ref(`games/${gameId}/lastMove`).set({
        from,
        to,
        fen,
        playerId,
        timestamp: Date.now(),
      });

      console.log(`Move recorded in game ${gameId}: ${from}${to}`);

      return {
        success: true,
        message: "Move recorded successfully",
      };
    } catch (error) {
      console.error("Move recording error:", error);
      throw error;
    }
  });

/**
 * Cloud Function: Handle game timeout
 * Ends game when player exceeds time limit
 */
exports.handleTimeout = functions
  .runWith({ timeoutSeconds: 540, memory: "256MB" })
  .pubsub.schedule("every 1 minute")
  .onRun(async (context) => {
    console.log("Checking for timeouts...");

    try {
      // Get all active games
      const snapshot = await db
        .collection("games")
        .where("status", "==", "active")
        .get();

      let timeoutCount = 0;
      const batch = db.batch();

      for (const doc of snapshot.docs) {
        const game = doc.data();
        const now = Date.now();

        // Calculate actual time remaining
        const lastMoveTime = game.lastMoveTimestamp
          ? game.lastMoveTimestamp.toMillis()
          : game.startedAt.toMillis();
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
      console.error("Timeout handler error:", error);
      throw error;
    }
  });

/**
 * Cloud Function: Update game ratings after completion
 * Calculates ELO changes and updates player ratings
 */
exports.updateGameRatings = functions
  .runWith({ timeoutSeconds: 30, memory: "256MB" })
  .firestore.document("games/{gameId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process when game transitions to completed
    if (before.status === "active" && after.status === "completed") {
      console.log(`Updating ratings for completed game ${context.params.gameId}`);

      try {
        const { whiteChange, blackChange } = calculateRatingChanges(
          after.whiteRating,
          after.blackRating,
          after.result
        );

        const whiteNewRating = after.whiteRating + whiteChange;
        const blackNewRating = after.blackRating + blackChange;

        const batch = db.batch();

        // Update game with rating changes
        batch.update(change.after.ref, {
          whiteRatingDelta: whiteChange,
          blackRatingDelta: blackChange,
          whiteNewRating: whiteNewRating,
          blackNewRating: blackNewRating,
        });

        // Update player ratings in users collection
        // (Implementation would depend on user document structure)

        await batch.commit();

        console.log(
          `Ratings updated: White ${after.whiteRating}→${whiteNewRating}, Black ${after.blackRating}→${blackNewRating}`
        );

        return null;
      } catch (error) {
        console.error("Rating update error:", error);
        throw error;
      }
    }

    return null;
  });

/**
 * Cloud Function: Cleanup expired queue entries
 * Runs hourly to remove stale matchmaking entries
 */
exports.cleanupExpiredQueue = functions
  .runWith({ timeoutSeconds: 300, memory: "256MB" })
  .pubsub.schedule("every 1 hours")
  .onRun(async (context) => {
    console.log("Cleaning up expired queue entries...");

    try {
      const now = admin.firestore.Timestamp.now();
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
        console.log(`Cleaned up ${cleaned} expired entries`);
      }

      return { cleaned };
    } catch (error) {
      console.error("Cleanup error:", error);
      throw error;
    }
  });

/**
 * Helper function: Convert time control string to milliseconds
 */
function timeControlMs(timeControl) {
  switch (timeControl) {
    case "3min":
      return 3 * 60 * 1000;
    case "5min":
      return 5 * 60 * 1000;
    case "10min":
      return 10 * 60 * 1000;
    default:
      return 5 * 60 * 1000;
  }
}

module.exports = {
  timeControlMs,
};
