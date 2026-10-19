/**
 * Integration-style coverage for the `recordMove` Cloud Function
 * (exports.recordMove in index.js) - the orchestration layer around
 * game-validation.js's applyMove/detectGameConclusion and
 * game-ending.js's computeGameEndUpdates. Exercises the real onCall
 * handler via firebase-functions-test's wrap(), against a minimal
 * hand-rolled fake Firestore/Realtime Database (no real Firebase admin
 * connection needed), the same style as timeout-handler.test.js.
 */

const functionsTest = require('firebase-functions-test')();

const INCREMENT = Symbol.for('increment');

function makeFakeFirestore(seedGames, seedUsers) {
  const games = new Map(Object.entries(seedGames));
  const users = new Map(Object.entries(seedUsers));
  const moveSubdocs = new Map(); // gameId -> array of written move records

  function applySentinels(existing, patch) {
    const result = { ...existing };
    for (const [key, value] of Object.entries(patch)) {
      if (value && value.__type === INCREMENT) {
        result[key] = (result[key] || 0) + value.amount;
      } else if (value === 'SERVER_TIMESTAMP' || value === 'NOW_TIMESTAMP') {
        result[key] = new Date();
      } else if (value && value.__arrayUnion) {
        result[key] = [...(result[key] || []), ...value.items];
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  function collection(name) {
    return {
      doc(id) {
        const docId = id || `auto_${Math.random().toString(36).slice(2)}`;
        if (name === 'games') {
          return {
            id: docId,
            async get() {
              const data = games.get(docId);
              return { exists: !!data, data: () => data };
            },
            async update(patch) {
              games.set(docId, applySentinels(games.get(docId) || {}, patch));
            },
            collection(subName) {
              if (subName !== 'moves') {
                throw new Error(`Unhandled fake subcollection: ${subName}`);
              }
              return {
                doc(moveId) {
                  const id2 = moveId || `move_${Math.random().toString(36).slice(2)}`;
                  return {
                    async set(data) {
                      const arr = moveSubdocs.get(docId) || [];
                      arr.push({ id: id2, ...data });
                      moveSubdocs.set(docId, arr);
                    },
                  };
                },
              };
            },
          };
        }
        if (name === 'users') {
          return {
            id: docId,
            async get() {
              const data = users.get(docId);
              return { exists: !!data, data: () => data };
            },
            async update(patch) {
              users.set(docId, applySentinels(users.get(docId) || {}, patch));
            },
          };
        }
        throw new Error(`Unhandled fake collection: ${name}`);
      },
    };
  }

  const db = {
    collection,
    batch() {
      const ops = [];
      return {
        update(ref, patch) {
          ops.push({ type: 'update', ref, patch });
        },
        set(ref, data) {
          ops.push({ type: 'set', ref, data });
        },
        async commit() {
          for (const op of ops) {
            if (op.type === 'update') await op.ref.update(op.patch);
            else await op.ref.set(op.data);
          }
        },
      };
    },
  };

  return { db, games, users, moveSubdocs };
}

jest.mock('firebase-admin', () => {
  let fakeDb;
  let fakeRealtimeRefs = [];
  return {
    __setFakeDb: (db) => { fakeDb = db; },
    __getRealtimeWrites: () => fakeRealtimeRefs,
    initializeApp: jest.fn(),
    firestore: Object.assign(
      () => fakeDb,
      {
        FieldValue: {
          increment: (amount) => ({ __type: Symbol.for('increment'), amount }),
          serverTimestamp: () => 'SERVER_TIMESTAMP',
          arrayUnion: (...items) => ({ __arrayUnion: true, items }),
        },
        Timestamp: {
          now: () => 'NOW_TIMESTAMP',
        },
      },
    ),
    database: () => ({
      ref: (path) => ({
        set: async (data) => { fakeRealtimeRefs.push({ path, data }); },
      }),
    }),
  };
});

describe('recordMove', () => {
  let admin;
  let fake;
  let wrappedRecordMove;

  beforeEach(() => {
    jest.resetModules();
    admin = require('firebase-admin');
    fake = makeFakeFirestore(
      {
        game_1: {
          status: 'active',
          whitePlayerId: 'white_uid',
          blackPlayerId: 'black_uid',
          whiteRating: 1500,
          blackRating: 1500,
          currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          pgn: '',
          moves: [],
        },
      },
      {
        white_uid: { wins: 0, losses: 0, draws: 0, gamesPlayed: 0, onlineRating: 1500 },
        black_uid: { wins: 0, losses: 0, draws: 0, gamesPlayed: 0, onlineRating: 1500 },
      },
    );
    admin.__setFakeDb(fake.db);

    // eslint-disable-next-line global-require
    const myFunctions = require('./index');
    wrappedRecordMove = functionsTest.wrap(myFunctions.recordMove);
  });

  afterAll(() => {
    functionsTest.cleanup();
  });

  function callAs(uid, data) {
    return wrappedRecordMove(data, { auth: { uid } });
  }

  it('rejects an unauthenticated call', async () => {
    await expect(
      wrappedRecordMove(
        { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' },
        { auth: null },
      ),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('rejects when the caller uid does not match playerId', async () => {
    await expect(
      callAs('white_uid', {
        gameId: 'game_1',
        from: 'e2',
        to: 'e4',
        playerId: 'black_uid',
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it("rejects a move on the opponent's turn", async () => {
    await expect(
      callAs('black_uid', {
        gameId: 'game_1',
        from: 'e7',
        to: 'e5',
        playerId: 'black_uid',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('rejects an illegal move and never mutates the game doc', async () => {
    await expect(
      callAs('white_uid', {
        gameId: 'game_1',
        from: 'e2',
        to: 'e5',
        playerId: 'white_uid',
      }),
    ).rejects.toMatchObject({ code: 'invalid-argument' });

    expect(fake.games.get('game_1').currentFen).toBe(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );
  });

  it('applies a legal move, recomputing FEN/PGN server-side regardless of client input', async () => {
    const result = await callAs('white_uid', {
      gameId: 'game_1',
      from: 'e2',
      to: 'e4',
      playerId: 'white_uid',
    });

    expect(result.success).toBe(true);
    expect(result.concluded).toBe(false);
    expect(fake.games.get('game_1').currentFen).toBe(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
    expect(fake.games.get('game_1').moves).toHaveLength(1);
    expect(fake.moveSubdocs.get('game_1')).toHaveLength(1);

    // Mid-game: no stats recorded yet.
    expect(fake.users.get('white_uid').gamesPlayed).toBe(0);
  });

  it("ends the game and credits stats on fool's mate checkmate", async () => {
    // Play out fool's mate move by move through the real handler.
    await callAs('white_uid', { gameId: 'game_1', from: 'f2', to: 'f3', playerId: 'white_uid' });
    await callAs('black_uid', { gameId: 'game_1', from: 'e7', to: 'e5', playerId: 'black_uid' });
    await callAs('white_uid', { gameId: 'game_1', from: 'g2', to: 'g4', playerId: 'white_uid' });
    const result = await callAs('black_uid', { gameId: 'game_1', from: 'd8', to: 'h4', playerId: 'black_uid' });

    expect(result.concluded).toBe(true);
    expect(result.result).toBe('black_win');

    const game = fake.games.get('game_1');
    expect(game.status).toBe('completed');
    expect(game.resultReason).toBe('checkmate');

    expect(fake.users.get('black_uid').wins).toBe(1);
    expect(fake.users.get('black_uid').gamesPlayed).toBe(1);
    expect(fake.users.get('white_uid').losses).toBe(1);
    expect(fake.users.get('white_uid').gamesPlayed).toBe(1);
  });

  it('rejects any move once the game is no longer active', async () => {
    fake.games.set('game_1', { ...fake.games.get('game_1'), status: 'completed' });

    await expect(
      callAs('white_uid', { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' }),
    ).rejects.toThrow(/not active|failed-precondition/i);
  });
});
