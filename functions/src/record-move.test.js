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

/** A minimal stand-in for admin.firestore.Timestamp good enough for toMillis(). */
function fakeTimestamp(ms) {
  return { toMillis: () => ms };
}

function makeFakeFirestore(seedGames, seedUsers) {
  const games = new Map(Object.entries(seedGames));
  const users = new Map(Object.entries(seedUsers));
  const moveSubdocs = new Map(); // gameId -> array of written move records
  const achievementUnlocks = new Map(); // uid -> Set(achievementId)

  function applySentinels(existing, patch) {
    const result = { ...existing };
    for (const [key, value] of Object.entries(patch)) {
      if (value && value.__type === INCREMENT) {
        result[key] = (result[key] || 0) + value.amount;
      } else if (value === 'SERVER_TIMESTAMP' || value === 'NOW_TIMESTAMP') {
        // A real admin.firestore.Timestamp exposes toMillis() - production
        // code (recordMove's own clock-decrement logic) calls that on
        // whatever lastMoveTimestamp was stored by a previous move, so a
        // plain Date here would break every move after the first.
        result[key] = fakeTimestamp(Date.now());
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
        if (name === 'achievements') {
          if (docId === 'definitions') {
            return {
              collection() {
                // Empty on purpose - falls back to achievement-service.js's
                // own BOOTSTRAP_DEFINITIONS (first_win/five_wins/puzzle_master).
                return { async get() { return { empty: true, docs: [] }; } };
              },
            };
          }
          if (docId === 'user_achievements') {
            return {
              collection(uid) {
                return {
                  doc(achievementId) {
                    return {
                      async get() {
                        const set = achievementUnlocks.get(uid) || new Set();
                        return { exists: set.has(achievementId) };
                      },
                      async set() {
                        const set = achievementUnlocks.get(uid) || new Set();
                        set.add(achievementId);
                        achievementUnlocks.set(uid, set);
                      },
                    };
                  },
                };
              },
            };
          }
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
    // Real Firestore transactions re-run the whole callback on a
    // contended read, retrying it against the state the FIRST writer
    // just committed. This fake doesn't simulate actual contention (no
    // test here exercises concurrent calls), but still gives
    // recordMove's transaction.get/update/set calls a working
    // same-process implementation - real behavior for a single
    // non-contended call.
    async runTransaction(updateFunction) {
      const transaction = {
        async get(ref) {
          return ref.get();
        },
        update(ref, patch) {
          ref.update(patch);
        },
        set(ref, data) {
          ref.set(data);
        },
      };
      return updateFunction(transaction);
    },
  };

  return { db, games, users, moveSubdocs, achievementUnlocks };
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
          startedAt: fakeTimestamp(Date.now()),
          whiteTimeRemainingMs: 5 * 60 * 1000,
          blackTimeRemainingMs: 5 * 60 * 1000,
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
    // Regression check for arrayUnion's variadic signature: each entry in
    // `moves` must be the move record itself, not a one-element array
    // wrapping it (admin.firestore.FieldValue.arrayUnion(...elements) is
    // variadic, unlike the Dart client SDK's List-taking overload).
    expect(fake.games.get('game_1').moves[0]).toMatchObject({
      from: 'e2',
      to: 'e4',
      playerId: 'white_uid',
    });
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

    // Previously a server-detected checkmate credited stats but never
    // unlocked an achievement for the winner - only resign/draw/abandon/
    // timeout did, since those route through the Dart client's
    // _endGameWithResult (or, for a real timeout, the handleTimeout
    // cron). first_win's target (1 win) is now satisfied by this game.
    expect(fake.achievementUnlocks.get('black_uid')?.has('first_win')).toBe(true);
    expect(fake.achievementUnlocks.get('white_uid')).toBeUndefined();
  });

  it('never double-records a move resubmitted while the first commit is still in flight', async () => {
    // Simulates the race a non-transactional get()-then-commit() would
    // lose: two calls for the SAME move (a client retry, or a
    // double-tap) racing each other. Delays the fake transaction's own
    // get() so the second call's read starts before the first call's
    // write has landed, then releases the first write - a real
    // Firestore transaction would instead force the second call to
    // retry against the first call's already-committed state, which is
    // exactly what this regression test is asserting still happens
    // with the fake's (non-contending, in-process) runTransaction.
    let firstGetStarted = false;
    let releaseFirstGet;
    const firstGetGate = new Promise((resolve) => {
      releaseFirstGet = resolve;
    });
    const originalRunTransaction = fake.db.runTransaction;
    let callIndex = 0;
    fake.db.runTransaction = async (updateFunction) => {
      const myIndex = callIndex;
      callIndex += 1;
      if (myIndex === 0) {
        firstGetStarted = true;
      } else {
        // Second call: wait until the first call's write has actually
        // committed before this one reads, so its own moveCount check
        // sees the post-first-move state (as a real serialized
        // transaction retry would) rather than racing it.
        await firstGetGate;
      }
      const result = await originalRunTransaction(updateFunction);
      if (myIndex === 0) {
        releaseFirstGet();
      }
      return result;
    };

    const callA = callAs('white_uid', { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' });
    // Give the first call's runTransaction a chance to start before
    // firing the resubmission.
    await new Promise((resolve) => setImmediate(resolve));
    expect(firstGetStarted).toBe(true);
    const callB = callAs('white_uid', { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' });

    const resultA = await callA;
    await expect(callB).rejects.toMatchObject({ code: 'failed-precondition' });

    expect(resultA.success).toBe(true);
    const game = fake.games.get('game_1');
    expect(game.moves).toHaveLength(1);
    expect(game.currentFen).toBe(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
  });

  it('rejects any move once the game is no longer active', async () => {
    fake.games.set('game_1', { ...fake.games.get('game_1'), status: 'completed' });

    await expect(
      callAs('white_uid', { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' }),
    ).rejects.toThrow(/not active|failed-precondition/i);
  });

  describe('clock handling', () => {
    it("decrements only the mover's own remaining time, leaving the opponent's untouched", async () => {
      fake.games.set('game_1', {
        ...fake.games.get('game_1'),
        startedAt: fakeTimestamp(Date.now() - 10_000), // white thought for 10s
      });

      await callAs('white_uid', { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' });

      const game = fake.games.get('game_1');
      expect(game.whiteTimeRemainingMs).toBeLessThanOrEqual(5 * 60 * 1000 - 10_000);
      expect(game.blackTimeRemainingMs).toBe(5 * 60 * 1000);
    });

    it('ends the game as a timeout (not a move) once the mover is already out of time', async () => {
      fake.games.set('game_1', {
        ...fake.games.get('game_1'),
        // White's clock already expired before this move attempt arrived.
        whiteTimeRemainingMs: 1000,
        startedAt: fakeTimestamp(Date.now() - 5000),
      });

      await expect(
        callAs('white_uid', { gameId: 'game_1', from: 'e2', to: 'e4', playerId: 'white_uid' }),
      ).rejects.toMatchObject({ code: 'failed-precondition' });

      const game = fake.games.get('game_1');
      expect(game.status).toBe('completed');
      expect(game.resultReason).toBe('timeout');
      expect(game.result).toBe('black_win');
      expect(fake.users.get('black_uid').wins).toBe(1);
      expect(fake.users.get('white_uid').losses).toBe(1);
      expect(fake.achievementUnlocks.get('black_uid')?.has('first_win')).toBe(true);
      // No chess move was ever actually applied.
      expect(game.currentFen).toBe(
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
    });

    it("never charges elapsed time against the side who isn't on move", async () => {
      // Black's clock is nearly expired, but it's White's move - a stale
      // elapsed-time read should never end the game on Black's behalf.
      fake.games.set('game_1', {
        ...fake.games.get('game_1'),
        blackTimeRemainingMs: 500,
        startedAt: fakeTimestamp(Date.now() - 10_000),
      });

      const result = await callAs('white_uid', {
        gameId: 'game_1',
        from: 'e2',
        to: 'e4',
        playerId: 'white_uid',
      });

      expect(result.success).toBe(true);
      expect(fake.games.get('game_1').status).toBe('active');
      expect(fake.games.get('game_1').blackTimeRemainingMs).toBe(500);
    });
  });
});
