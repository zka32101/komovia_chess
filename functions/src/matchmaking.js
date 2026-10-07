/**
 * Matchmaking algorithm for rating-based player pairing
 * 
 * Strategy:
 * 1. Expand rating ranges over time
 * 2. Prioritize by wait time and rating
 * 3. Balance strong/weak players
 * 4. Separate by time control
 */

/**
 * Find the best matches from queue entries
 * @param {Array} queueEntries - Players waiting in queue
 * @returns {Array} Matched pairs of players
 */
function matchPlayers(queueEntries) {
  const matches = [];
  const matched = new Set();
  
  // Group by time control
  const byTimeControl = groupByTimeControl(queueEntries);
  
  for (const [timeControl, players] of Object.entries(byTimeControl)) {
    // Try to match players in this time control group
    const groupMatches = matchGroup(players, matched);
    matches.push(...groupMatches);
  }
  
  return matches;
}

/**
 * Group queue entries by time control type
 */
function groupByTimeControl(queueEntries) {
  const groups = {};
  
  for (const entry of queueEntries) {
    const key = entry.timeControlType;
    if (!groups[key]) {
      groups[key] = [];
    }
    groups[key].push(entry);
  }
  
  return groups;
}

/**
 * Match players within a time control group
 */
function matchGroup(players, matched) {
  const matches = [];
  
  // Sort by wait time (longer wait = higher priority)
  const sorted = [...players].sort((a, b) => {
    const waitA = Date.now() - a.queuedAt.toMillis();
    const waitB = Date.now() - b.queuedAt.toMillis();
    return waitB - waitA;
  });
  
  for (let i = 0; i < sorted.length; i++) {
    if (matched.has(sorted[i].queueId)) {
      continue;
    }
    
    const player1 = sorted[i];
    const ratingRange = getRatingRange(player1);
    
    // Find best opponent
    let bestOpponent = null;
    let bestScore = -Infinity;
    
    for (let j = i + 1; j < sorted.length; j++) {
      if (matched.has(sorted[j].queueId)) {
        continue;
      }
      
      const player2 = sorted[j];
      
      // Check if player2 is in player1's rating range
      if (!ratingRange.contains(player2.currentRating)) {
        continue;
      }
      
      // Also check reverse: player1 in player2's range
      const player2Range = getRatingRange(player2);
      if (!player2Range.contains(player1.currentRating)) {
        continue;
      }
      
      // Calculate match quality score
      const score = calculateMatchScore(player1, player2);
      
      if (score > bestScore) {
        bestScore = score;
        bestOpponent = player2;
      }
    }
    
    // If found a good match, pair them
    if (bestOpponent && bestScore > 0) {
      // Assign colors
      const player1Color = getPlayerColor(player1);
      const player2Color = getPlayerColor(bestOpponent);
      
      matches.push({
        player1: { ...player1, color: player1Color },
        player2: { ...bestOpponent, color: player2Color },
        timeControlType: player1.timeControlType,
        matchScore: bestScore,
      });
      
      matched.add(player1.queueId);
      matched.add(bestOpponent.queueId);
    }
  }
  
  return matches;
}

/**
 * Get rating range based on wait time
 */
function getRatingRange(queueEntry) {
  const waitSeconds = Math.floor(
    (Date.now() - queueEntry.queuedAt.toMillis()) / 1000
  );
  
  let range = 50;
  if (waitSeconds >= 30) {
    range = 300;
  } else if (waitSeconds >= 20) {
    range = 200;
  } else if (waitSeconds >= 10) {
    range = 100;
  }
  
  return {
    min: queueEntry.currentRating - range,
    max: queueEntry.currentRating + range,
    contains(rating) {
      return rating >= this.min && rating <= this.max;
    },
  };
}

/**
 * Calculate match quality score
 * Higher score = better match
 */
function calculateMatchScore(player1, player2) {
  const ratingDiff = Math.abs(player1.currentRating - player2.currentRating);
  
  // Prefer close rating matches (within 100 points)
  if (ratingDiff <= 50) {
    return 100 - ratingDiff;
  }
  if (ratingDiff <= 100) {
    return 80 - (ratingDiff - 50) * 0.4;
  }
  if (ratingDiff <= 200) {
    return 60 - (ratingDiff - 100) * 0.2;
  }
  
  // Still acceptable but not preferred
  return Math.max(10, 40 - (ratingDiff - 200) * 0.1);
}

/**
 * Determine player color preference
 */
function getPlayerColor(player) {
  if (player.color === "random") {
    return Math.random() < 0.5 ? "white" : "black";
  }
  return player.color;
}

module.exports = {
  matchPlayers,
};
