/**
 * Server-side mirror of lib/src/services/achievement_service.dart's
 * checkAndUnlockAchievements, so a game ended by the server-side timeout
 * handler (handleGameTimeout) unlocks achievements exactly like a game
 * ended through the Dart app (resign/draw/abandonment) does. Only the
 * two win-count-based definitions are relevant here (a timeout always
 * resolves to a win/loss, never a puzzle solve) but all bootstrap
 * definitions are mirrored for consistency with the Dart service.
 */

const admin = require("firebase-admin");

const BOOTSTRAP_DEFINITIONS = [
  { achievementId: "first_win", targetValue: 1, metric: "wins" },
  { achievementId: "five_wins", targetValue: 5, metric: "wins" },
  { achievementId: "puzzle_master", targetValue: 20, metric: "puzzlesSolved" },
];

async function getAllAchievementDefinitions(db) {
  try {
    const snapshot = await db
      .collection("achievements")
      .doc("definitions")
      .collection("all")
      .get();

    if (snapshot.empty) {
      return BOOTSTRAP_DEFINITIONS;
    }

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      const targetValue = (data.condition && data.condition.targetValue) || 0;
      // Mirrors AchievementService._calculateCurrentProgress's switch: only
      // these two metrics map to a condition this handler can ever satisfy.
      const metric = data.achievementId === "puzzle_master"
        ? "puzzlesSolved"
        : "wins";
      return {
        achievementId: data.achievementId,
        targetValue,
        metric,
      };
    });
  } catch (error) {
    console.error("Error fetching achievement definitions:", error);
    return BOOTSTRAP_DEFINITIONS;
  }
}

/**
 * Checks every achievement definition against [userId]'s current stats and
 * unlocks any newly-satisfied one. Best-effort: swallows its own errors so
 * it never blocks the batch commit it's called alongside.
 */
async function checkAndUnlockAchievements(db, userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const data = userDoc.data() || {};
    const wins = Number(data.wins) || 0;
    const puzzlesSolved = Number(data.puzzlesSolved) || 0;

    const definitions = await getAllAchievementDefinitions(db);

    for (const def of definitions) {
      if (!def.targetValue || def.targetValue <= 0) continue;

      const currentValue = def.metric === "puzzlesSolved" ? puzzlesSolved : wins;
      if (currentValue < def.targetValue) continue;

      const unlockRef = db
        .collection("achievements")
        .doc("user_achievements")
        .collection(userId)
        .doc(def.achievementId);

      const unlockDoc = await unlockRef.get();
      if (unlockDoc.exists) continue;

      await unlockRef.set({
        userId,
        achievementId: def.achievementId,
        unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        progressPercentage: 100,
      });
    }
  } catch (error) {
    console.error(`Error checking achievements for ${userId}:`, error);
  }
}

module.exports = {
  checkAndUnlockAchievements,
  getAllAchievementDefinitions,
};
