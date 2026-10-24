/**
 * Covers the fix for handleGameTimeout never recording wins/losses/
 * gamesPlayed/rating (or unlocking achievements) on the two
 * players' `users/{uid}` docs when a game ends by server-side timeout -
 * unlike every other way a game can end, which all route through the
 * Dart client's OnlineGameService._endGameWithResult.
 *
 * Uses a minimal hand-rolled fake Firestore (no real firebase-admin
 * connection needed) that understands just enough of the real API
 * surface this code touches: collection/doc chains, FieldValue.increment
 * sentinels applied on batch commit, and serverTimestamp as a sentinel
 * value.
 */

const INCREMENT = Symbol.for('increment');

function makeFakeFirestore(seedUsers) {
  const users = new Map(Object.entries(seedUsers));
  const userAchievements = new Map(); // uid -> Set(achievementId)
  const games = new Map();

  function applyIncrements(existing, patch) {
    const result = { ...existing };
    for (const [key, value] of Object.entries(patch)) {
      if (value && value.__type === INCREMENT) {
        result[key] = (result[key] || 0) + value.amount;
      } else if (value === 'SERVER_TIMESTAMP') {
        result[key] = new Date();
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  const db = {
    collection(name) {
      return {
        doc(id) {
          if (name === 'users') {
            return {
              id,
              async get() {
                const data = users.get(id);
                return { exists: !!data, data: () => data };
              },
              async update(patch) {
                users.set(id, applyIncrements(users.get(id) || {}, patch));
              },
            };
          }
          if (name === 'games') {
            return {
              id,
              async get() {
                const data = games.get(id);
                return { exists: !!data, data: () => data };
              },
              async update(patch) {
                games.set(id, applyIncrements(games.get(id) || {}, patch));
              },
            };
          }
          if (name === 'achievements' && id === 'user_achievements') {
            return {
              collection(uid) {
                return {
                  doc(achievementId) {
                    return {
                      async get() {
                        const set = userAchievements.get(uid) || new Set();
                        return { exists: set.has(achievementId) };
                      },
                      async set() {
                        const set = userAchievements.get(uid) || new Set();
                        set.add(achievementId);
                        userAchievements.set(uid, set);
                      },
                    };
                  },
                };
              },
            };
          }
          if (name === 'achievements' && id === 'definitions') {
            return {
              collection() {
                return { async get() { return { empty: true, docs: [] }; } };
              },
            };
          }
          throw new Error(`Unhandled fake collection/doc: ${name}/${id}`);
        },
      };
    },
    batch() {
      const ops = [];
      return {
        update(ref, patch) {
          ops.push({ ref, patch });
        },
        async commit() {
          for (const { ref, patch } of ops) {
            await ref.update(patch);
          }
        },
      };
    },
    // Enough of the real Transaction API (get/set, writes applied once
    // the callback resolves) for achievement-service.js's own
    // check-then-unlock transaction to run against - checkAndUnlockAchievements
    // is called by maybeUnlockAchievementsAfterTimeouts below.
    async runTransaction(updateFunction) {
      const ops = [];
      const tx = {
        async get(ref) { return ref.get(); },
        set(ref, data) { ops.push({ ref, data }); },
      };
      const result = await updateFunction(tx);
      for (const { ref, data } of ops) {
        await ref.set(data);
      }
      return result;
    },
  };

  return { db, users, userAchievements, games };
}

jest.mock('firebase-admin', () => {
  let fakeDb;
  return {
    __setFakeDb: (db) => { fakeDb = db; },
    firestore: Object.assign(
      () => fakeDb,
      {
        FieldValue: {
          increment: (amount) => ({ __type: Symbol.for('increment'), amount }),
          serverTimestamp: () => 'SERVER_TIMESTAMP',
        },
      },
    ),
  };
});

describe('handleGameTimeout stat recording', () => {
  let admin;
  let timeoutHandler;
  let fake;

  beforeEach(() => {
    jest.resetModules();
    admin = require('firebase-admin');
    fake = makeFakeFirestore({
      white_uid: { wins: 0, losses: 0, gamesPlayed: 0, rating: 1500 },
      black_uid: { wins: 4, losses: 1, gamesPlayed: 5, rating: 1600 },
    });
    admin.__setFakeDb(fake.db);
    timeoutHandler = require('./timeout-handler');
  });

  function baseGame() {
    return {
      whitePlayerId: 'white_uid',
      blackPlayerId: 'black_uid',
      whiteRating: 1500,
      blackRating: 1600,
    };
  }

  it('credits the non-timed-out player with a win and the timed-out player with a loss', async () => {
    const batch = fake.db.batch();
    const gameRef = fake.db.collection('games').doc('game_1');
    const game = baseGame();

    const { winnerId, loserId } = timeoutHandler.handleGameTimeout(
      batch, gameRef, game, 'white',
    );

    expect(winnerId).toBe('black_uid');
    expect(loserId).toBe('white_uid');

    await batch.commit();

    expect(fake.users.get('black_uid').wins).toBe(5);
    expect(fake.users.get('black_uid').gamesPlayed).toBe(6);
    expect(fake.users.get('white_uid').losses).toBe(1);
    expect(fake.users.get('white_uid').gamesPlayed).toBe(1);
  });

  it('updates rating for both players based on the computed rating change', async () => {
    const batch = fake.db.batch();
    const gameRef = fake.db.collection('games').doc('game_2');
    const game = baseGame();

    timeoutHandler.handleGameTimeout(batch, gameRef, game, 'black');
    await batch.commit();

    // White was favored on rating and won: small positive change.
    expect(fake.users.get('white_uid').rating).toBeGreaterThan(1500);
    expect(fake.users.get('black_uid').rating).toBeLessThan(1600);
  });

  it('unlocks first_win for a white player winning their first game via timeout', async () => {
    const batch = fake.db.batch();
    const gameRef = fake.db.collection('games').doc('game_3');
    const game = baseGame();

    const { winnerId } = timeoutHandler.handleGameTimeout(batch, gameRef, game, 'black');
    await batch.commit();

    expect(winnerId).toBe('white_uid');
    await timeoutHandler.maybeUnlockAchievementsAfterTimeouts([winnerId]);

    expect(fake.userAchievements.get('white_uid').has('first_win')).toBe(true);
  });

  it('never unlocks an achievement for the losing (timed-out) player', async () => {
    const batch = fake.db.batch();
    const gameRef = fake.db.collection('games').doc('game_4');
    const game = baseGame();

    const { loserId } = timeoutHandler.handleGameTimeout(batch, gameRef, game, 'white');
    await batch.commit();
    await timeoutHandler.maybeUnlockAchievementsAfterTimeouts([]);

    expect(fake.userAchievements.get(loserId)).toBeUndefined();
  });
});
