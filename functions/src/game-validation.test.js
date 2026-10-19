const { applyMove, detectGameConclusion, replayMoves } = require('./game-validation');

const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

describe('applyMove', () => {
  it('accepts a legal opening move and recomputes the FEN itself', () => {
    const { legal, chess } = applyMove(START_FEN, 'e2', 'e4');
    expect(legal).toBe(true);
    expect(chess.fen()).toBe(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
  });

  it('rejects an illegal move', () => {
    const { legal, chess } = applyMove(START_FEN, 'e2', 'e5');
    expect(legal).toBe(false);
    // The server never trusts a client-supplied FEN after a rejected
    // move - there is nothing to recompute from.
    expect(chess).not.toBeNull();
  });

  it('rejects moving a piece that was never there', () => {
    const { legal } = applyMove(START_FEN, 'e4', 'e5');
    expect(legal).toBe(false);
  });

  it('rejects an unparsable FEN entirely', () => {
    const { legal, chess } = applyMove('not a real fen', 'e2', 'e4');
    expect(legal).toBe(false);
    expect(chess).toBeNull();
  });

  it('defaults an unspecified pawn promotion to queen', () => {
    // Previously this app's online board never let a player choose a
    // promotion piece (online_game_screen.dart always passes
    // `promotion: null`) - without this fallback no pawn could ever
    // legally reach the back rank in a real game.
    const { legal, moveResult } = applyMove(
      '8/P7/8/8/8/8/8/k6K w - - 0 1',
      'a7',
      'a8',
    );
    expect(legal).toBe(true);
    expect(moveResult.promotion).toBe('q');
  });

  it('honors an explicit promotion piece when one is given', () => {
    const { legal, moveResult } = applyMove(
      '8/P7/8/8/8/8/8/k6K w - - 0 1',
      'a7',
      'a8',
      'r',
    );
    expect(legal).toBe(true);
    expect(moveResult.promotion).toBe('r');
  });
});

describe('detectGameConclusion', () => {
  it('reports no conclusion mid-game', () => {
    const { chess } = applyMove(START_FEN, 'e2', 'e4');
    expect(detectGameConclusion(chess)).toEqual({
      concluded: false,
      result: null,
      reason: null,
    });
  });

  it("detects fool's mate as black_win by checkmate", () => {
    let state = applyMove(START_FEN, 'f2', 'f3');
    state = applyMove(state.chess.fen(), 'e7', 'e5');
    state = applyMove(state.chess.fen(), 'g2', 'g4');
    state = applyMove(state.chess.fen(), 'd8', 'h4');

    expect(state.legal).toBe(true);
    expect(detectGameConclusion(state.chess)).toEqual({
      concluded: true,
      result: 'black_win',
      reason: 'checkmate',
    });
  });

  it('detects stalemate as a draw', () => {
    // Black king has no legal moves and is not in check.
    const { Chess } = require('chess.js');
    const chess = new Chess('k7/8/1Q6/8/8/8/8/7K b - - 0 1');
    expect(detectGameConclusion(chess)).toEqual({
      concluded: true,
      result: 'draw',
      reason: 'stalemate',
    });
  });

  it('detects insufficient material as a draw', () => {
    const { Chess } = require('chess.js');
    const chess = new Chess('8/8/8/4k3/8/8/4K3/8 w - - 0 1');
    expect(detectGameConclusion(chess)).toEqual({
      concluded: true,
      result: 'draw',
      reason: 'insufficient_material',
    });
  });
});

describe('replayMoves', () => {
  it('reproduces the same position applyMove would reach move-by-move', () => {
    const chess = replayMoves([
      { from: 'e2', to: 'e4' },
      { from: 'e7', to: 'e5' },
    ]);
    expect(chess.fen()).toBe(
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    );
  });

  it('returns the standard starting position for an empty move list', () => {
    const chess = replayMoves([]);
    expect(chess.fen()).toBe(START_FEN);
  });

  it('skips sentinel/pass entries with no from/to', () => {
    const chess = replayMoves([
      { from: 'e2', to: 'e4' },
      { from: '', to: '' },
    ]);
    expect(chess.fen()).toBe(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
  });
});
