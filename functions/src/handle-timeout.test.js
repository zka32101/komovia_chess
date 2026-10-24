/**
 * Integration-style coverage for the `handleTimeout` scheduled Cloud
 * Function (exports.handleTimeout in index.js) - specifically the fix
 * for it previously checking BOTH players' remaining time against the
 * same elapsed-since-last-move value regardless of whose turn it
 * actually was, and for it processing CPU games (which share the same
 * `games` collection but have no real server-side clock concept at
 * all - whitePlayerId/blackPlayerId are the literal strings
 * 'player'/'cpu', not real uids).
 */

const functionsTest = require('firebase-functions-test')();

const INCREMENT = Symbol.for('increment');

function fakeTimestamp(ms) {
  return { toMillis: () => ms };
}

function makeFakeFirestore(seedGames, seedUsers) {
  const games = new Map(Object.entries(seedGames));
  const users = new Map(Object.entries(seedUsers));

  function applySentinels(existing, patch) {
    const result = { ...existing };
    for (const [key, value] of Object.entries(patch)) {
      if (value && value.__type === INCREMENT) {
        result[key] = (result[key] || 0) + value.amount;
      } else if (value === 'SERVER_TIMESTAMP' || value === 'NOW_TIMESTAMP') {
        result[key] = fakeTimestamp(Date.now());
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  function collection(name) {
    return {
      doc(id) {
        return {
          id,
          async get() {
            const map = name === 'games' ? games : users;
            const data = map.get(id);
            return { exists: !!data, data: () => data };
          },
          async update(patch) {
            const map = name === 'games' ? games : users;
            map.set(id, applySentinels(map.get(id) || {}, patch));
          },
        };
      },
      where() {
        // Filters are ignored here - the one real query this file's
        // production code issues is `status == 'active'`, applied below
        // against the whole seeded set instead of re-implementing a
        // query engine.
        return this;
      },
      async get() {
        const docs = [...games.entries()]
          .filter(([, data]) => data.status === 'active')
          .map(([id, data]) => ({
            id,
            ref: db.collection('games').doc(id),
            data: () => data,
          }));
        return { docs, empty: docs.length === 0 };
      },
    };
  }

  const db = {
    collection,
    batch() {
      const ops = [];
      return {
        update(ref, patch) {
          ops.push({ ref, patch });
        },
        async commit() {
          for (const op of ops) await op.ref.update(op.patch);
        },
      };
    },
    // No real isolation/retry semantics (this fake is single-threaded and
    // synchronous between awaits) - just enough of the real Transaction
    // API (get/update, writes applied once the callback resolves) for
    // handleTimeout's per-game transaction to run against.
    async runTransaction(updateFunction) {
      const ops = [];
      const tx = {
        async get(ref) {
          return ref.get();
        },
        update(ref, patch) {
          ops.push({ ref, patch });
        },
      };
      const result = await updateFunction(tx);
      for (const op of ops) await op.ref.update(op.patch);
      return result;
    },
  };

  return { db, games, users };
}

jest.mock('firebase-admin', () => {
  let fakeDb;
  return {
    __setFakeDb: (db) => { fakeDb = db; },
    initializeApp: jest.fn(),
    firestore: Object.assign(
      () => fakeDb,
      {
        FieldValue: {
          increment: (amount) => ({ __type: Symbol.for('increment'), amount }),
          serverTimestamp: () => 'SERVER_TIMESTAMP',
          arrayUnion: (...items) => ({ __arrayUnion: true, items }),
        },
        Timestamp: { now: () => 'NOW_TIMESTAMP' },
      },
    ),
    database: () => ({ ref: () => ({ set: async () => {} }) }),
  };
});

function baseGame(overrides = {}) {
  return {
    status: 'active',
    type: 'online_pvp',
    whitePlayerId: 'white_uid',
    blackPlayerId: 'black_uid',
    whiteRating: 1500,
    blackRating: 1500,
    moves: [],
    whiteTimeRemainingMs: 5 * 60 * 1000,
    blackTimeRemainingMs: 5 * 60 * 1000,
    startedAt: fakeTimestamp(Date.now()),
    ...overrides,
  };
}

describe('handleTimeout', () => {
  let admin;
  let fake;
  let wrappedHandleTimeout;

  beforeEach(() => {
    jest.resetModules();
    admin = require('firebase-admin');
    fake = makeFakeFirestore(
      {},
      {
        white_uid: { wins: 0, losses: 0, gamesPlayed: 0, rating: 1500 },
        black_uid: { wins: 0, losses: 0, gamesPlayed: 0, rating: 1500 },
      },
    );
    admin.__setFakeDb(fake.db);

    // eslint-disable-next-line global-require
    const myFunctions = require('./index');
    wrappedHandleTimeout = functionsTest.wrap(myFunctions.handleTimeout);
  });

  afterAll(() => {
    functionsTest.cleanup();
  });

  it("ends the game for the side actually on move when only their clock has expired", async () => {
    // It's White's move (0 moves played, even count). White's clock has
    // expired; Black's has not been touched at all (as a real chess
    // clock works - it was never Black's turn).
    fake.games.set('game_1', baseGame({
      whiteTimeRemainingMs: 100,
      startedAt: fakeTimestamp(Date.now() - 10_000),
    }));

    await wrappedHandleTimeout();

    const game = fake.games.get('game_1');
    expect(game.status).toBe('completed');
    expect(game.result).toBe('black_win');
    expect(fake.users.get('black_uid').wins).toBe(1);
    expect(fake.users.get('white_uid').losses).toBe(1);
  });

  it("never times out the side who isn't on move, even if their stored remaining time is low", async () => {
    // One move played (odd count) - it's Black's move. Black's clock is
    // fine; White's is nearly zero, but it is NOT White's turn, so White
    // must never be flagged.
    fake.games.set('game_1', baseGame({
      moves: [{ from: 'e2', to: 'e4' }],
      whiteTimeRemainingMs: 10,
      blackTimeRemainingMs: 5 * 60 * 1000,
      startedAt: fakeTimestamp(Date.now() - 10_000),
    }));

    await wrappedHandleTimeout();

    const game = fake.games.get('game_1');
    expect(game.status).toBe('active');
  });

  it('does not touch an active game whose on-move side still has time left', async () => {
    fake.games.set('game_1', baseGame());

    await wrappedHandleTimeout();

    expect(fake.games.get('game_1').status).toBe('active');
  });

  it('never processes a CPU game, even if it looks timed out', async () => {
    fake.games.set('cpu_game', baseGame({
      type: 'cpu',
      whitePlayerId: 'player',
      blackPlayerId: 'cpu',
      whiteTimeRemainingMs: 1,
      startedAt: fakeTimestamp(Date.now() - 60_000),
    }));

    await wrappedHandleTimeout();

    expect(fake.games.get('cpu_game').status).toBe('active');
    // No garbage stat docs created for the literal 'player'/'cpu' ids.
    expect(fake.users.get('player')).toBeUndefined();
    expect(fake.users.get('cpu')).toBeUndefined();
  });

  it('does not double-credit a game that recordMove already concluded before the transaction commits', async () => {
    // Simulates the real race this fixes: the initial `.get()` scan (done
    // by makeFakeFirestore's collection().get() above) sees the game as
    // still "active" with White's clock expired, but by the time this
    // game's own transaction actually runs, recordMove's transaction has
    // already ended it some other way (checkmate). A shared batch would
    // have blindly re-applied the timeout result and incremented both
    // players' stats a second time on top of that.
    fake.games.set('game_1', baseGame({
      whiteTimeRemainingMs: 100,
      startedAt: fakeTimestamp(Date.now() - 10_000),
    }));
    const realGet = fake.db.collection('games').doc('game_1').get;
    fake.db.runTransaction = async (updateFunction) => {
      // Conclude the game via a different path right before this game's
      // transaction does its own fresh read.
      fake.games.set('game_1', {
        ...fake.games.get('game_1'),
        status: 'completed',
        result: 'white_win',
        resultReason: 'checkmate',
      });
      fake.users.set('white_uid', { ...fake.users.get('white_uid'), wins: 1 });
      const ops = [];
      const tx = {
        async get(ref) { return ref.get(); },
        update(ref, patch) { ops.push({ ref, patch }); },
      };
      const result = await updateFunction(tx);
      for (const op of ops) await op.ref.update(op.patch);
      return result;
    };
    void realGet;

    await wrappedHandleTimeout();

    const game = fake.games.get('game_1');
    expect(game.status).toBe('completed');
    expect(game.result).toBe('white_win');
    expect(game.resultReason).toBe('checkmate');
    // Not re-incremented by handleGameTimeout's own (would-be) black_win
    // write - White still has exactly the one win from checkmate, Black
    // never got a bogus loss credited on top of it.
    expect(fake.users.get('white_uid').wins).toBe(1);
    expect(fake.users.get('black_uid').losses).toBe(0);
  });
});
