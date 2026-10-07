const { matchPlayers } = require('./matchmaking');

describe('Matchmaking Algorithm', () => {
  
  describe('matchPlayers', () => {
    it('should match two players with similar ratings', () => {
      const entries = [
        {
          queueId: '1',
          playerId: 'p1',
          playerName: 'Alice',
          currentRating: 1600,
          ratingRange: { min: 1550, max: 1650 },
          timeControlType: '5min',
          queuedAt: { toMillis: () => Date.now() - 6000 },
          color: 'random',
          priority: 16,
        },
        {
          queueId: '2',
          playerId: 'p2',
          playerName: 'Bob',
          currentRating: 1620,
          ratingRange: { min: 1570, max: 1670 },
          timeControlType: '5min',
          queuedAt: { toMillis: () => Date.now() - 5000 },
          color: 'random',
          priority: 16,
        },
      ];

      const matches = matchPlayers(entries);
      expect(matches.length).toBe(1);
      expect(matches[0].player1.playerId).toBe('p1');
      expect(matches[0].player2.playerId).toBe('p2');
    });

    it('should not match players outside rating range', () => {
      const entries = [
        {
          queueId: '1',
          playerId: 'p1',
          currentRating: 1600,
          ratingRange: { min: 1550, max: 1650 },
          timeControlType: '5min',
          queuedAt: { toMillis: () => Date.now() },
          color: 'random',
        },
        {
          queueId: '2',
          playerId: 'p2',
          currentRating: 2000, // Outside range
          ratingRange: { min: 1950, max: 2050 },
          timeControlType: '5min',
          queuedAt: { toMillis: () => Date.now() },
          color: 'random',
        },
      ];

      const matches = matchPlayers(entries);
      expect(matches.length).toBe(0);
    });

    it('should prioritize longer wait times', () => {
      const now = Date.now();
      const entries = [
        {
          queueId: '1',
          playerId: 'p1',
          currentRating: 1600,
          ratingRange: { min: 1550, max: 1650 },
          timeControlType: '5min',
          queuedAt: { toMillis: () => now - 20000 }, // Waited 20s
          color: 'random',
        },
        {
          queueId: '2',
          playerId: 'p2',
          currentRating: 1600,
          ratingRange: { min: 1550, max: 1650 },
          timeControlType: '5min',
          queuedAt: { toMillis: () => now - 5000 }, // Waited 5s
          color: 'random',
        },
      ];

      const matches = matchPlayers(entries);
      expect(matches.length).toBe(1);
      // Player 1 (longer wait) should be first
      expect(matches[0].player1.queueId).toBe('1');
    });

    it('should separate players by time control', () => {
      const entries = [
        {
          queueId: '1',
          playerId: 'p1',
          currentRating: 1600,
          ratingRange: { min: 1550, max: 1650 },
          timeControlType: '3min',
          queuedAt: { toMillis: () => Date.now() },
          color: 'random',
        },
        {
          queueId: '2',
          playerId: 'p2',
          currentRating: 1600,
          ratingRange: { min: 1550, max: 1650 },
          timeControlType: '5min', // Different time control
          queuedAt: { toMillis: () => Date.now() },
          color: 'random',
        },
      ];

      const matches = matchPlayers(entries);
      expect(matches.length).toBe(0);
    });
  });
});

describe('Rating Range Expansion', () => {
  it('should expand range based on wait time', () => {
    const now = Date.now();
    
    // Test at different wait times
    const test = (waitMs, expectedRange) => {
      const entry = {
        currentRating: 1600,
        queuedAt: { toMillis: () => now - waitMs },
      };
      // Would test getRatingRange function
    };

    // Ranges based on wait time:
    // 0-10s: ±50
    // 10-20s: ±100
    // 20-30s: ±200
    // 30+s: ±300
  });
});
