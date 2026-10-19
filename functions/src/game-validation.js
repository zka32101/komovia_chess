/**
 * Game state validation and update logic
 *
 * Previously this module's validateMove only checked that `from`/`to`
 * were well-formed square strings (never real chess legality - the
 * module's own old comments said "In production, integrate chess.js"),
 * and detectGameConclusion always returned `concluded: false` - the
 * server never actually validated a move or detected checkmate/
 * stalemate/draws. Nothing in lib/ ever called the Cloud Function that
 * used this module anyway (recordMove, in index.js), so chess moves
 * were written straight to Firestore by the client with no server-side
 * check at all: any participant could set their game's `currentFen` to
 * an arbitrary (even illegal) position.
 *
 * Now backed by the real chess.js engine. applyMove is the single
 * source of truth for "is this move legal, and what does the position
 * look like afterward" - the server recomputes FEN/PGN/conclusion
 * itself rather than trusting whatever the client sends.
 */

const { Chess } = require("chess.js");

/**
 * Attempts to play [from]->[to] (optionally promoting to [promotion])
 * against [currentFen]. If the move is only illegal because it's an
 * unspecified pawn promotion, retries once promoting to queen - this
 * app's online board never actually lets a player pick a promotion
 * piece (see online_game_screen.dart's `_submitMove`, which always
 * passes `promotion: null`), so without this fallback no pawn could
 * ever legally reach the back rank in a real game.
 *
 * @returns {{legal: boolean, chess: Chess|null, moveResult: object|null}}
 */
function applyMove(currentFen, from, to, promotion) {
  let chess;
  try {
    chess = new Chess(currentFen);
  } catch (e) {
    return { legal: false, chess: null, moveResult: null };
  }

  const tryMove = (opts) => {
    try {
      return chess.move(opts);
    } catch (e) {
      return null;
    }
  };

  let moveResult = tryMove(promotion ? { from, to, promotion } : { from, to });
  if (!moveResult && !promotion) {
    moveResult = tryMove({ from, to, promotion: "q" });
  }

  return { legal: !!moveResult, chess, moveResult };
}

/**
 * Inspects [chess] (already reflecting the move just applied) for a
 * game-ending condition.
 * @returns {{concluded: boolean, result: string|null, reason: string|null}}
 */
function detectGameConclusion(chess) {
  if (!chess.isGameOver()) {
    return { concluded: false, result: null, reason: null };
  }

  if (chess.isCheckmate()) {
    // chess.turn() is the side TO MOVE, who is the side in checkmate -
    // the other color just delivered it and won.
    const result = chess.turn() === "w" ? "black_win" : "white_win";
    return { concluded: true, result, reason: "checkmate" };
  }
  if (chess.isStalemate()) {
    return { concluded: true, result: "draw", reason: "stalemate" };
  }
  if (chess.isThreefoldRepetition()) {
    return { concluded: true, result: "draw", reason: "threefold_repetition" };
  }
  if (chess.isInsufficientMaterial()) {
    return { concluded: true, result: "draw", reason: "insufficient_material" };
  }
  // Any other isGameOver() case left standing is the 50-move rule.
  return { concluded: true, result: "draw", reason: "fifty_move_rule" };
}

/**
 * Replays [moves] (an array of {from, to, promotion}) from the standard
 * starting position and returns the resulting Chess instance - used by
 * `respondToTakeback` (index.js) to recompute currentFen/pgn after
 * dropping the last move, the same "replay from scratch" approach
 * applyMove already relies on for a single move.
 * @returns {Chess}
 */
function replayMoves(moves) {
  const chess = new Chess();
  for (const m of moves) {
    if (!m.from || !m.to) continue; // pass/sentinel moves, if any
    try {
      chess.move(
        m.promotion ? { from: m.from, to: m.to, promotion: m.promotion } : { from: m.from, to: m.to }
      );
    } catch (e) {
      // Already-recorded moves came from applyMove, so this should never
      // actually be illegal - skip rather than abort the whole replay.
    }
  }
  return chess;
}

module.exports = {
  applyMove,
  detectGameConclusion,
  replayMoves,
};
