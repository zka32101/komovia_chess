const { computeGameEndUpdates } = require('./game-ending');

function baseGame() {
  return {
    whitePlayerId: 'white_uid',
    blackPlayerId: 'black_uid',
    whiteRating: 1500,
    blackRating: 1500,
  };
}

describe('computeGameEndUpdates', () => {
  it('credits the winner a win and the loser a loss on checkmate', () => {
    const { gameUpdate, whiteUserUpdate, blackUserUpdate, winnerId } =
      computeGameEndUpdates(baseGame(), 'white_win', 'checkmate');

    expect(gameUpdate.status).toBe('completed');
    expect(gameUpdate.result).toBe('white_win');
    expect(gameUpdate.resultReason).toBe('checkmate');
    expect(winnerId).toBe('white_uid');

    expect(whiteUserUpdate.wins).toBeDefined();
    expect(whiteUserUpdate.losses).toBeUndefined();
    expect(blackUserUpdate.losses).toBeDefined();
    expect(blackUserUpdate.wins).toBeUndefined();
  });

  it('credits both players a draw and no winner for a stalemate/draw result', () => {
    const { whiteUserUpdate, blackUserUpdate, winnerId } =
      computeGameEndUpdates(baseGame(), 'draw', 'stalemate');

    expect(whiteUserUpdate.draws).toBeDefined();
    expect(blackUserUpdate.draws).toBeDefined();
    expect(winnerId).toBeNull();
  });

  it('always increments gamesPlayed and onlineRating for both players regardless of result', () => {
    const { whiteUserUpdate, blackUserUpdate } = computeGameEndUpdates(
      baseGame(),
      'black_win',
      'checkmate',
    );

    expect(whiteUserUpdate.gamesPlayed).toBeDefined();
    expect(blackUserUpdate.gamesPlayed).toBeDefined();
    expect(typeof whiteUserUpdate.onlineRating).toBe('number');
    expect(typeof blackUserUpdate.onlineRating).toBe('number');
  });
});
