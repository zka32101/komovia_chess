/**
 * Seeds the `puzzles` and `daily_challenges` Firestore collections that
 * lib/src/providers/puzzle_provider.dart's PuzzleService reads from.
 *
 * Requires Application Default Credentials for the target Firebase project,
 * e.g.:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node scripts/seedPuzzles.js
 * or run after `gcloud auth application-default login` /
 * `firebase login` with the project selected via `firebase use <project>`.
 *
 * Usage: node scripts/seedPuzzles.js [--project <firebaseProjectId>]
 */
const admin = require("firebase-admin");
const puzzles = require("./puzzles-data.json");

const projectFlagIndex = process.argv.indexOf("--project");
const projectId =
  projectFlagIndex !== -1 ? process.argv[projectFlagIndex + 1] : undefined;

admin.initializeApp(projectId ? { projectId } : undefined);
const db = admin.firestore();

async function seedPuzzles() {
  const batch = db.batch();

  for (const puzzle of puzzles) {
    const ref = db.collection("puzzles").doc(puzzle.id);
    batch.set(ref, {
      fen: puzzle.fen,
      moves: puzzle.moves,
      rating: puzzle.rating,
      themes: puzzle.themes,
      handCount: puzzle.moves.length,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  const today = new Date().toISOString().split("T")[0];
  batch.set(db.collection("daily_challenges").doc(today), {
    theme: "Checkmate patterns",
    puzzleIds: puzzles.map((p) => p.id),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
  console.log(
    `Seeded ${puzzles.length} puzzles and today's (${today}) daily challenge.`
  );
}

seedPuzzles()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Failed to seed puzzles:", error);
    process.exit(1);
  });
