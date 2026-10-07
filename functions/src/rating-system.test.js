const {
  calculateRatingChanges,
  getExpectedScore,
  K_FACTOR,
  D_CONSTANT,
} = require('./rating-system');

describe('ELO Rating System', () => {
  
  describe('getExpectedScore', () => {
    it('should return 0.5 for equal ratings', () => {
      const expected = getExpectedScore(1600, 1600);
      expect(expected).toBeCloseTo(0.5, 1);
    });

    it('should favor higher rated player', () => {
      const expected1600 = getExpectedScore(1600, 1400);
      const expected1400 = getExpectedScore(1400, 1600);
      
      expect(expected1600).toBeGreaterThan(expected1400);
      expect(expected1600).toBeCloseTo(1 - expected1400, 2);
    });

    it('should calculate correct expected score for 200 rating difference', () => {
      const expected = getExpectedScore(1600, 1400);
      // For 200 point difference: E = 1 / (1 + 10^(200/400)) ≈ 0.76
      expect(expected).toBeCloseTo(0.76, 1);
    });
  });

  describe('calculateRatingChanges', () => {
    it('should calculate rating change for white win', () => {
      const result = calculateRatingChanges(1600, 1400, 'white_win');
      
      // White is favored, win gives small gain
      expect(result.whiteChange).toBeGreaterThan(0);
      expect(result.whiteChange).toBeLessThan(15);
      
      // Black loses to stronger opponent
      expect(result.blackChange).toBeLessThan(0);
      expect(result.blackChange).toBeGreaterThan(-25);
    });

    it('should reward upset win for weaker player', () => {
      const result = calculateRatingChanges(1600, 1400, 'black_win');
      
      // Black gets big bonus for upset win
      expect(result.blackChange).toBeGreaterThan(20);
      
      // White loses more for upset loss
      expect(result.whiteChange).toBeLessThan(-20);
    });

    it('should calculate rating change for draw', () => {
      const result = calculateRatingChanges(1600, 1400, 'draw');
      
      // White loses rating points (underperforms expectation)
      expect(result.whiteChange).toBeLessThan(0);
      
      // Black gains rating points (overperforms expectation)
      expect(result.blackChange).toBeGreaterThan(0);
    });

    it('should maintain sum-zero property', () => {
      // Rating changes should be approximately zero-sum
      const result = calculateRatingChanges(1600, 1400, 'white_win');
      const total = result.whiteChange + result.blackChange;
      
      // Allow small rounding error
      expect(Math.abs(total)).toBeLessThanOrEqual(1);
    });

    it('should handle equal ratings correctly', () => {
      const result = calculateRatingChanges(1600, 1600, 'white_win');
      
      // Both have 50% expected score
      // Winner gains K/2, loser loses K/2
      expect(result.whiteChange).toBeCloseTo(16, 0);
      expect(result.blackChange).toBeCloseTo(-16, 0);
    });

    it('should match historical ELO data', () => {
      // Known ELO calculation examples
      
      // Example 1: 1600 vs 1400, 1600 wins
      const result1 = calculateRatingChanges(1600, 1400, 'white_win');
      expect(result1.whiteChange).toBeCloseTo(8, 0);
      expect(result1.blackChange).toBeCloseTo(-8, 0);
      
      // Example 2: 1600 vs 1400, 1400 wins (upset)
      const result2 = calculateRatingChanges(1600, 1400, 'black_win');
      expect(result2.whiteChange).toBeCloseTo(-24, 0);
      expect(result2.blackChange).toBeCloseTo(24, 0);
    });
  });

  describe('Rating System Parameters', () => {
    it('should use correct K-factor', () => {
      expect(K_FACTOR).toBe(32);
    });

    it('should use correct D-constant', () => {
      expect(D_CONSTANT).toBe(400);
    });

    it('should follow standard chess rating system', () => {
      // ELO formula: ΔR = K × (S - E)
      // With K=32 and D=400, these are standard chess values
      
      const changes = calculateRatingChanges(1600, 1400, 'white_win');
      const expected = getExpectedScore(1600, 1400);
      const expectedChange = Math.round(K_FACTOR * (1.0 - expected));
      
      expect(changes.whiteChange).toBe(expectedChange);
    });
  });

  describe('Win Probability Calculations', () => {
    it('should calculate win probability for different rating gaps', () => {
      // 100 point gap: ~64% for higher rated
      const exp100 = getExpectedScore(1650, 1550);
      expect(exp100).toBeGreaterThan(0.6);
      expect(exp100).toBeLessThan(0.7);
      
      // 200 point gap: ~76% for higher rated
      const exp200 = getExpectedScore(1700, 1500);
      expect(exp200).toBeGreaterThan(0.7);
      expect(exp200).toBeLessThan(0.8);
      
      // 300 point gap: ~85% for higher rated
      const exp300 = getExpectedScore(1750, 1450);
      expect(exp300).toBeGreaterThan(0.8);
      expect(exp300).toBeLessThan(0.9);
    });
  });
});
