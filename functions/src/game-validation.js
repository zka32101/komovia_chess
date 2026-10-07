/**
 * Game state validation and update logic
 * 
 * Handles:
 * - Move legality validation
 * - Game state transitions
 * - Draw agreement logic
 * - Game conclusion detection
 */

/**
 * Validate if a move is legal
 * In production, integrate chess.js or similar
 */
function validateMove(currentFen, from, to) {
  // Basic validation
  if (!from || !to || typeof from !== "string" || typeof to !== "string") {
    return false;
  }
  
  // Format validation: e2, e4, etc.
  const moveRegex = /^[a-h][1-8]$/;
  if (!moveRegex.test(from) || !moveRegex.test(to)) {
    return false;
  }
  
  // Prevent moving to same square
  if (from === to) {
    return false;
  }
  
  // In production:
  // const chess = new Chess(currentFen);
  // const moves = chess.moves({ square: from, verbose: true });
  // return moves.some(m => m.to === to);
  
  return true;
}

/**
 * Handle game conclusion detection
 * Detects checkmate, stalemate, threefold repetition, etc.
 */
function detectGameConclusion(fen, moves) {
  // Would use chess.js to detect:
  // - Checkmate
  // - Stalemate
  // - Threefold repetition
  // - Fifty-move rule
  // - Insufficient material
  
  return {
    concluded: false,
    result: null, // 'white_win', 'black_win', 'draw'
    reason: null, // 'checkmate', 'stalemate', 'threefold', etc.
  };
}

/**
 * Handle draw agreement
 */
async function processDrawAgreement(db, gameRef, game) {
  // In production: track draw proposals and agreements
  // Only end game when both players agree
  
  await gameRef.update({
    status: "completed",
    endedAt: admin.firestore.FieldValue.serverTimestamp(),
    result: "draw",
    resultReason: "draw_agreement",
  });
}

/**
 * Update game state after valid move
 */
async function updateGameState(db, gameRef, game, moveData) {
  const updates = {
    currentFen: moveData.fen,
    pgn: moveData.pgn,
    moves: admin.firestore.FieldValue.arrayUnion([moveData.move]),
    lastMoveTimestamp: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  // Update activity timestamp
  if (moveData.playerId === game.whitePlayerId) {
    updates.whiteLastActivityTimestamp =
      admin.firestore.FieldValue.serverTimestamp();
  } else {
    updates.blackLastActivityTimestamp =
      admin.firestore.FieldValue.serverTimestamp();
  }
  
  // Check for game conclusion
  const conclusion = detectGameConclusion(moveData.fen, game.moves || []);
  if (conclusion.concluded) {
    updates.status = "completed";
    updates.endedAt = admin.firestore.FieldValue.serverTimestamp();
    updates.result = conclusion.result;
    updates.resultReason = conclusion.reason;
  }
  
  await gameRef.update(updates);
  
  return conclusion;
}

module.exports = {
  validateMove,
  detectGameConclusion,
  processDrawAgreement,
  updateGameState,
};
