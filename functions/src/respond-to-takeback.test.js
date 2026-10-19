/**
 * Integration-style coverage for the `respondToTakeback` Cloud Function
 * (exports.respondToTakeback in index.js) - accepting a pending takeback
 * request actually undoes the last recorded move, recomputing
 * currentFen/pgn/moves server-side (the same fields firestore.rules locks
 * to the Admin SDK alone for online PvP games).
 */

const functionsTest = require('firebase-functions-test')();

function makeFakeFirestore(seedGames) {
  const games = new Map(Object.entries(seedGames));
  const moveSubdocs = new Map(); // gameId -> array of {id, moveNumber, ...}

  function gameDocRef(docId) {
    return {
      id: docId,
      async get() {
        const data = games.get(docId);
        return { exists: !!data, data: () => data };
      },
      async update(patch) {
        games.set(docId, { ...(games.get(docId) || {}), ...patch });
      },
      collection(subName) {
        if (subName !== 'moves') {
          throw new Error(`Unhandled fake subcollection: ${subName}`);
        }
        return {
          doc(moveId) {
            const id = moveId || `move_${Math.random().toString(36).slice(2)}`;
            return {
              async set(data) {
                const arr = moveSubdocs.get(docId) || [];
                arr.push({ id, ref: this, ...data });
                moveSubdocs.set(docId, arr);
              },
              async delete() {
                const arr = moveSubdocs.get(docId) || [];
                moveSubdocs.set(docId, arr.filter((d) => d.id !== id));
              },
            };
          },
          where(field, op, value) {
            if (field !== 'moveNumber' || op !== '==') {
              throw new Error(`Unhandled fake where: ${field} ${op}`);
            }
            return {
              async get() {
                const arr = moveSubdocs.get(docId) || [];
                const matches = arr.filter((d) => d.moveNumber === value);
                return {
                  docs: matches.map((d) => ({
                    ref: {
                      async delete() {
                        const current = moveSubdocs.get(docId) || [];
                        moveSubdocs.set(
                          docId,
                          current.filter((x) => x.id !== d.id),
                        );
                      },
                    },
                  })),
                };
              },
            };
          },
        };
      },
    };
  }

  const db = {
    collection(name) {
      if (name !== 'games') throw new Error(`Unhandled fake collection: ${name}`);
      return { doc: gameDocRef };
    },
    batch() {
      const ops = [];
      return {
        update(ref, patch) {
          ops.push({ type: 'update', ref, patch });
        },
        delete(ref) {
          ops.push({ type: 'delete', ref });
        },
        async commit() {
          for (const op of ops) {
            if (op.type === 'update') await op.ref.update(op.patch);
            else await op.ref.delete();
          }
        },
      };
    },
  };

  return { db, games, moveSubdocs };
}

jest.mock('firebase-admin', () => {
  let fakeDb;
  return {
    __setFakeDb: (db) => { fakeDb = db; },
    initializeApp: jest.fn(),
    firestore: Object.assign(() => fakeDb, {
      Timestamp: { now: () => 'NOW_TIMESTAMP' },
    }),
    database: () => ({ ref: () => ({ set: async () => {} }) }),
  };
});

function baseGame(overrides = {}) {
  return {
    status: 'active',
    whitePlayerId: 'white_uid',
    blackPlayerId: 'black_uid',
    whiteRating: 1500,
    blackRating: 1500,
    currentFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    pgn: '1. e4',
    moves: [{ moveNumber: 1, from: 'e2', to: 'e4', promotion: null, playerId: 'white_uid' }],
    takebackRequestedBy: 'white_uid',
    ...overrides,
  };
}

describe('respondToTakeback', () => {
  let admin;
  let fake;
  let wrapped;

  beforeEach(() => {
    jest.resetModules();
    admin = require('firebase-admin');
    fake = makeFakeFirestore({ game_1: baseGame() });
    admin.__setFakeDb(fake.db);

    // eslint-disable-next-line global-require
    const myFunctions = require('./index');
    wrapped = functionsTest.wrap(myFunctions.respondToTakeback);
  });

  afterAll(() => {
    functionsTest.cleanup();
  });

  function callAs(uid, data) {
    return wrapped(data, { auth: { uid } });
  }

  it('undoes the last move and clears the request when the non-requester accepts', async () => {
    const result = await callAs('black_uid', { gameId: 'game_1', playerId: 'black_uid' });

    expect(result.success).toBe(true);
    const game = fake.games.get('game_1');
    expect(game.currentFen).toBe(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );
    expect(game.moves).toEqual([]);
    expect(game.takebackRequestedBy).toBeNull();
    // recordMove computes the next mover's elapsed time from
    // lastMoveTimestamp - leaving it stale would double-charge the next
    // mover for the entire takeback-negotiation window too.
    expect(game.lastMoveTimestamp).toBe('NOW_TIMESTAMP');
  });

  it('deletes the undone move from the moves subcollection', async () => {
    fake.moveSubdocs.set('game_1', [{ id: 'm1', moveNumber: 1 }]);

    await callAs('black_uid', { gameId: 'game_1', playerId: 'black_uid' });

    expect(fake.moveSubdocs.get('game_1')).toEqual([]);
  });

  it('rejects the requester trying to accept their own takeback request', async () => {
    await expect(
      callAs('white_uid', { gameId: 'game_1', playerId: 'white_uid' }),
    ).rejects.toMatchObject({ code: 'permission-denied' });

    // Nothing changed.
    expect(fake.games.get('game_1').moves).toHaveLength(1);
  });

  it('rejects when no takeback request is pending', async () => {
    fake.games.set('game_1', baseGame({ takebackRequestedBy: null }));

    await expect(
      callAs('black_uid', { gameId: 'game_1', playerId: 'black_uid' }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('rejects a non-participant', async () => {
    await expect(
      callAs('stranger_uid', { gameId: 'game_1', playerId: 'stranger_uid' }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects once the game is no longer active', async () => {
    fake.games.set('game_1', baseGame({ status: 'completed' }));

    await expect(
      callAs('black_uid', { gameId: 'game_1', playerId: 'black_uid' }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('correctly replays multiple remaining moves after undoing only the last one', async () => {
    fake.games.set('game_1', baseGame({
      currentFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      pgn: '1. e4 e5',
      moves: [
        { moveNumber: 1, from: 'e2', to: 'e4', promotion: null, playerId: 'white_uid' },
        { moveNumber: 2, from: 'e7', to: 'e5', promotion: null, playerId: 'black_uid' },
      ],
      takebackRequestedBy: 'black_uid',
    }));

    const result = await callAs('white_uid', { gameId: 'game_1', playerId: 'white_uid' });

    expect(result.success).toBe(true);
    const game = fake.games.get('game_1');
    expect(game.moves).toHaveLength(1);
    expect(game.currentFen).toBe(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
  });
});
