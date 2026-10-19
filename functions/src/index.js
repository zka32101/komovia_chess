const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { applyMove, detectGameConclusion } = require("./game-validation");
const { computeGameEndUpdates } = require("./game-ending");
const {
  handleGameTimeout,
  maybeUnlockAchievementsAfterTimeouts,
  cleanupExpiredQueues,
} = require("./timeout-handler");

admin.initializeApp();

const db = admin.firestore();
const realtimeDb = admin.database();

// A scheduled `matchmakingWorker` Cloud Function used to live here,
// independently scanning `matchmaking_queue` for 'waiting' entries
// and matching them every 5 seconds via the same pure matchPlayers()
// (./matchmaking.js) the Dart client's own matching path uses.
// Removed: MatchmakingService.tryMatch (lib/src/services/
// matchmaking_service.dart) already does this client-side, polled by
// MatchmakingScreen - and does it *correctly*, atomically claiming
// both queue entries (flipping them to an intermediate 'matching'
// status inside a Firestore transaction, _claimPair) before either
// side creates a game. This worker had no such claim step: it took a
// plain get() snapshot, computed matches, then unconditionally wrote
// 'matched' + created a new `games` doc with a batch, never
// re-checking that either entry was still 'waiting' at commit time.
// Running both concurrently (which they were - this fired every 5s
// regardless of whether tryMatch's own polling had already claimed a
// pair) could create two separate games for the same two players,
// with the queue docs' matchedGameId ending up pointing at whichever
// system committed last - a genuine race, not a deliberate
// belt-and-suspenders safety net, since this worker was already
// documented as nonexistent in firestore.rules' own
// matchmaking_queue comment ("there's no Cloud Function to own this
// step") before this fix. matchPlayers()/matchmaking.js itself is
// kept (and still covered by matchmaking.test.js) since it's a pure
// pairing-selection function with its own value independent of which
// caller drives it; only this redundant, racing Cloud Function
// wrapper around it is removed.

/**
 * Cloud Function: Record player move
 * Validates move legality and updates game state
 */
exports.recordMove = functions
  .runWith({ timeoutSeconds: 30, memory: "256MB" })
  .https.onCall(async (data, context) => {
    const { gameId, from, to, promotion, playerId } = data;

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

      // How long the player on move has actually been thinking, measured
      // server-side - this is also the only place whiteTimeRemainingMs/
      // blackTimeRemainingMs ever get decremented (see below), since
      // nothing in lib/ ever calls OnlineGameService.updateTimeRemaining
      // at all (confirmed via grep: zero callers of
      // OnlineGameNotifier.updateTimeRemaining anywhere in the app).
      // Before this fix, both fields stayed frozen at the game's initial
      // time-control allotment for the whole game.
      const lastMoveMs = game.lastMoveTimestamp
        ? game.lastMoveTimestamp.toMillis()
        : game.startedAt.toMillis();
      const elapsedMs = Date.now() - lastMoveMs;
      const onMoveRemainingField = isWhiteTurn
        ? "whiteTimeRemainingMs"
        : "blackTimeRemainingMs";
      const onMoveRemainingMs =
        (game[onMoveRemainingField] || 0) - elapsedMs;

      // The player on move already ran out of time before this move
      // arrived - end the game as a timeout now rather than silently
      // recording a late move. This closes the same loophole as the
      // per-minute handleTimeout cron, just immediately instead of
      // waiting up to a minute.
      if (onMoveRemainingMs <= 0) {
        const result = isWhiteTurn ? "black_win" : "white_win";
        const { gameUpdate, whiteUserUpdate, blackUserUpdate, winnerId } =
          computeGameEndUpdates(game, result, "timeout");

        const timeoutBatch = db.batch();
        timeoutBatch.update(gameRef, gameUpdate);
        timeoutBatch.update(
          db.collection("users").doc(game.whitePlayerId),
          whiteUserUpdate
        );
        timeoutBatch.update(
          db.collection("users").doc(game.blackPlayerId),
          blackUserUpdate
        );
        await timeoutBatch.commit();
        if (winnerId) {
          await maybeUnlockAchievementsAfterTimeouts([winnerId]);
        }

        throw new functions.https.HttpsError(
          "failed-precondition",
          "Time expired"
        );
      }

      // Validate AND apply the move server-side via chess.js - the
      // resulting FEN/PGN are computed here, never trusted from the
      // client (previously the client's own `fen`/`pgn` were written
      // straight through, so any participant could set their game's
      // board to an arbitrary, even illegal, position).
      const { legal, chess, moveResult } = applyMove(
        game.currentFen,
        from,
        to,
        promotion
      );
      if (!legal) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Illegal move"
        );
      }

      const nowTs = admin.firestore.Timestamp.now();
      const moveRecord = {
        moveNumber: moveCount + 1,
        from,
        to,
        promotion: moveResult.promotion || null,
        timestamp: nowTs,
        playerId,
      };

      const updates = {
        currentFen: chess.fen(),
        pgn: chess.pgn(),
        moves: admin.firestore.FieldValue.arrayUnion([moveRecord]),
        lastMoveTimestamp: nowTs,
        [onMoveRemainingField]: onMoveRemainingMs,
        [isWhitePlayer
          ? "whiteLastActivityTimestamp"
          : "blackLastActivityTimestamp"]: nowTs,
      };

      // Record the move in the `moves` subcollection too, matching what
      // OnlineGameService.recordMove (Dart) used to write directly -
      // gameMoveProvider/getGameMoves still reads this subcollection for
      // the move-history list.
      const moveSubDocRef = gameRef.collection("moves").doc();

      // Detect checkmate/stalemate/draw now that the move has been
      // applied. Previously nothing server-side (and nothing
      // client-side either - online_game_screen.dart's `in_checkmate`
      // check only ever played a sound) ever actually ended a PvP game
      // on checkmate: the game doc just sat at status "active" forever
      // until someone manually resigned or timed out.
      const conclusion = detectGameConclusion(chess);
      if (conclusion.concluded) {
        const { gameUpdate, whiteUserUpdate, blackUserUpdate, winnerId } =
          computeGameEndUpdates(game, conclusion.result, conclusion.reason);
        Object.assign(updates, gameUpdate);

        const batch = db.batch();
        batch.update(gameRef, updates);
        batch.set(moveSubDocRef, moveRecord);
        batch.update(db.collection("users").doc(game.whitePlayerId), whiteUserUpdate);
        batch.update(db.collection("users").doc(game.blackPlayerId), blackUserUpdate);
        await batch.commit();

        // Previously a server-detected checkmate/stalemate (the most
        // common way an online PvP game actually ends) credited stats
        // correctly but never unlocked an achievement for the winner -
        // only resign/draw/abandon/timeout (which route through the
        // Dart client's _endGameWithResult) and the handleTimeout cron
        // did this. maybeUnlockAchievementsAfterTimeouts isn't actually
        // timeout-specific internally; it just runs the same
        // best-effort achievement check for each winner id given.
        if (winnerId) {
          await maybeUnlockAchievementsAfterTimeouts([winnerId]);
        }
      } else {
        const batch = db.batch();
        batch.update(gameRef, updates);
        batch.set(moveSubDocRef, moveRecord);
        await batch.commit();
      }

      // Sync to Realtime DB
      await realtimeDb.ref(`games/${gameId}/lastMove`).set({
        from,
        to,
        fen: chess.fen(),
        playerId,
        timestamp: Date.now(),
      });

      console.log(`Move recorded in game ${gameId}: ${from}${to}`);

      return {
        success: true,
        message: "Move recorded successfully",
        concluded: conclusion.concluded,
        result: conclusion.result,
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
      const winnerIds = [];

      for (const doc of snapshot.docs) {
        const game = doc.data();

        // CPU games (cpu_game_provider.dart) share this same `games`
        // collection and also start with status "active", but they're
        // played entirely on the user's own device with no server-side
        // clock concept at all - whitePlayerId/blackPlayerId are the
        // literal strings 'player'/'cpu', not real uids, so ending one
        // here would try to credit wins/losses to nonexistent
        // `users/player` and `users/cpu` documents.
        if (game.type === "cpu") continue;

        const now = Date.now();

        // Calculate actual time remaining
        const lastMoveTime = game.lastMoveTimestamp
          ? game.lastMoveTimestamp.toMillis()
          : game.startedAt.toMillis();
        const elapsedMs = now - lastMoveTime;

        // Only the player currently on move has a clock running - a real
        // chess clock never ticks for the side waiting on their
        // opponent. Previously this checked BOTH players' remaining time
        // against the same elapsed-since-last-move value unconditionally,
        // so once a game's time-control duration had passed since any
        // move at all, White was always flagged first (and `continue`d
        // past), regardless of whose turn it actually was - and since
        // neither field was ever decremented in the first place (see
        // recordMove), this was the only timeout signal that existed.
        const moveCount = game.moves ? game.moves.length : 0;
        const isWhiteTurn = moveCount % 2 === 0;
        const onMoveRemainingMs = isWhiteTurn
          ? game.whiteTimeRemainingMs
          : game.blackTimeRemainingMs;

        if (onMoveRemainingMs - elapsedMs <= 0) {
          const { winnerId } = handleGameTimeout(
            batch,
            doc.ref,
            game,
            isWhiteTurn ? "white" : "black"
          );
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
      console.error("Timeout handler error:", error);
      throw error;
    }
  });

/**
 * Cloud Function: Update game ratings after completion
 * Calculates ELO changes and updates player ratings
 */
// There used to be an `updateGameRatings` Firestore onUpdate trigger
// here, firing on every games/{gameId} transition to "completed" to
// recompute ELO deltas. It never actually did the one thing its own
// comment said it should ("Update player ratings in users collection -
// Implementation would depend on user document structure" - no such
// write existed) and was pure redundant work: every real way a game
// ends - resign/draw/abandonment/forfeit (OnlineGameService.
// _endGameWithResult, Dart), a server-detected checkmate/stalemate
// (recordMove's conclusion branch, via game-ending.js), and a timeout
// (handleGameTimeout) - already computes the same deltas and writes
// both the game doc AND both players' users/{uid} docs correctly on
// its own. Removed rather than "finished", since finishing it would
// have meant a second, independent path writing the same stats -  a
// real risk of double-crediting if the two ever drifted.

/**
 * Cloud Function: Cleanup expired queue entries
 * Runs hourly to remove stale matchmaking entries
 *
 * Delegates to timeout-handler.js's cleanupExpiredQueues, which was
 * previously imported but never actually called here - this function
 * duplicated the exact same query/batch-delete logic inline instead.
 */
exports.cleanupExpiredQueue = functions
  .runWith({ timeoutSeconds: 300, memory: "256MB" })
  .pubsub.schedule("every 1 hours")
  .onRun(async (context) => {
    console.log("Cleaning up expired queue entries...");
    return cleanupExpiredQueues();
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

// NOT `module.exports = {...}` - that would silently replace every
// `exports.XXX = ...` Cloud Function assignment above (matchmakingWorker,
// recordMove, handleTimeout, updateGameRatings, cleanupExpiredQueue) with
// just this one helper, meaning `firebase deploy --only functions` would
// never actually deploy any of them. Confirmed via this file's own
// `exports.recordMove` becoming `undefined` once required - this was a
// pre-existing bug that made every Cloud Function in this file dead on
// deploy, discovered while testing the fixed `recordMove`.
exports.timeControlMs = timeControlMs;
