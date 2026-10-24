import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/puzzle.dart';
import '../services/season_challenge_service.dart';
import '../services/season_management_service.dart';
import '../services/rating_calculation_service.dart';
import '../services/battle_pass_service.dart';

// Puzzle provider for loading and tracking puzzle solving
class PuzzleService {
  PuzzleService(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Get daily puzzle challenge for today
  Future<DailyChallengeModel?> getDailyChallenge() async {
    try {
      final today =
          DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD format
      final doc =
          await _firestore.collection('daily_challenges').doc(today).get();

      if (doc.exists) {
        return DailyChallengeModel.fromJson({
          ...doc.data()!,
          'date': doc.id,
        });
      }
      return null;
    } catch (e) {
      print('Error fetching daily challenge: $e');
      return null;
    }
  }

  // Get puzzle by ID
  Future<PuzzleModel?> getPuzzleById(String puzzleId) async {
    try {
      final doc = await _firestore.collection('puzzles').doc(puzzleId).get();

      if (doc.exists) {
        return PuzzleModel.fromJson({
          ...doc.data()!,
          'id': doc.id,
        });
      }
      return null;
    } catch (e) {
      print('Error fetching puzzle: $e');
      return null;
    }
  }

  // Get puzzles by difficulty rating
  Future<List<PuzzleModel>> getPuzzlesByRating(int minRating, int maxRating,
      {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('puzzles')
          .where('rating', isGreaterThanOrEqualTo: minRating)
          .where('rating', isLessThanOrEqualTo: maxRating)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => PuzzleModel.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      print('Error fetching puzzles by rating: $e');
      return [];
    }
  }

  // Record puzzle attempt
  Future<void> recordPuzzleAttempt({
    required String puzzleId,
    required bool solved,
    required List<String> userMoves,
    required int puzzleRating,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      // Each attempt is its own doc (id includes a timestamp), so there's
      // nothing to increment on this doc itself - it always represents
      // exactly one attempt.
      final resultId =
          '${user.uid}_${puzzleId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('user_puzzle_results').doc(resultId).set({
        'userId': user.uid,
        'puzzleId': puzzleId,
        'solved': solved,
        'userMoves': userMoves,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the user's puzzle rating via a real Elo exchange against
      // the puzzle's own rating (solve = win, fail = loss), through
      // RatingCalculationService - the same tiered-K-factor engine
      // CPU/online chess games use (see UserModel.rating's doc comment).
      // Previously `averageRating` was a plain running average of every
      // puzzle *attempted* ((sum of ratings) / count), with no win/loss
      // semantics at all - it could only ever climb toward whatever
      // difficulty the player attempted regardless of whether they
      // solved it, and crucially only ever updated `if (solved)`, so a
      // failed attempt moved nothing (not even the rating down),
      // which is backwards for any real rating system. Renamed to
      // `puzzleRating` to make clear it's now an Elo rating, not an
      // average - puzzlesSolved/dailyStreak still only advance on an
      // actual solve.
      final userRef = _firestore.collection('users').doc(user.uid);
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final data = userDoc.data() ?? const <String, dynamic>{};

        final previousRating = (data['puzzleRating'] as num?)?.toInt() ?? 1500;
        final clampedPrevious = previousRating.clamp(
          RatingCalculationService.minRating,
          RatingCalculationService.maxRating,
        );
        final clampedPuzzleRating = puzzleRating.clamp(
          RatingCalculationService.minRating,
          RatingCalculationService.maxRating,
        );
        final newRating = RatingCalculationService.calculateNewRating(
          clampedPrevious,
          clampedPuzzleRating,
          solved ? 1.0 : 0.0,
        );

        final update = <String, dynamic>{'puzzleRating': newRating};

        if (solved) {
          final today = DateTime.now();
          final todayKey =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final lastSolvedDate = data['lastPuzzleSolvedDate'] as String?;
          final previousStreak = (data['dailyStreak'] as num?)?.toInt() ?? 0;

          int newStreak;
          if (lastSolvedDate == todayKey) {
            // Already solved a puzzle today - same streak, just a second
            // win on the same day.
            newStreak = previousStreak;
          } else if (lastSolvedDate != null &&
              today.difference(DateTime.parse(lastSolvedDate)).inDays == 1) {
            newStreak = previousStreak + 1;
          } else {
            newStreak = 1;
          }

          update['puzzlesSolved'] = FieldValue.increment(1);
          update['dailyStreak'] = newStreak;
          update['lastPuzzleSolvedDate'] = todayKey;
        }

        transaction.update(userRef, update);
      });

      if (solved) {
        // Best-effort: advance any active seasonal challenge tracking
        // puzzle solves - previously nothing in the app ever called into
        // SeasonChallengeService from a real puzzle solve, so no seasonal
        // challenge could progress through actual play.
        try {
          final season = await SeasonManagementService().getCurrentSeason();
          if (season != null) {
            await SeasonChallengeService().recordMetricProgress(
              playerId: user.uid,
              seasonId: season.seasonId,
              metric: GameplayMetric.solvePuzzles,
            );
            // Best-effort: same dead-wiring gap as the one just fixed for
            // CPU games - BattlePassService.addBattlePassExperience was
            // never called from anywhere, leaving every player's battle
            // pass level stuck at 1 forever.
            await BattlePassService().addBattlePassExperience(
              playerId: user.uid,
              seasonId: season.seasonId,
              experienceAmount: 15,
            );
          }
        } catch (_) {
          // Best-effort; don't block puzzle-solving on this.
        }
      }
    } catch (e) {
      print('Error recording puzzle attempt: $e');
      rethrow;
    }
  }

  // Record a finished Puzzle Rush run's score, keeping the user's best.
  // Transactional (like recordPuzzleAttempt's stat update above) since
  // "keep the higher of two values" can't be expressed as a
  // FieldValue.increment sentinel.
  Future<void> recordPuzzleRushScore(int score) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final previousBest =
            (userDoc.data()?['puzzleRushBestScore'] as num?)?.toInt() ?? 0;
        if (score > previousBest) {
          transaction.set(
            userRef,
            {'puzzleRushBestScore': score},
            SetOptions(merge: true),
          );
        }
      });
    } catch (e) {
      print('Error recording Puzzle Rush score: $e');
      rethrow;
    }
  }

  // Get user's puzzle statistics
  Future<Map<String, dynamic>> getUserPuzzleStats() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        return {
          'puzzlesSolved': userDoc.data()?['puzzlesSolved'] ?? 0,
          'dailyStreak': userDoc.data()?['dailyStreak'] ?? 0,
          'puzzleRating': userDoc.data()?['puzzleRating'] ?? 1500,
        };
      }
      return {'puzzlesSolved': 0, 'dailyStreak': 0, 'puzzleRating': 1500};
    } catch (e) {
      print('Error fetching puzzle stats: $e');
      return {'puzzlesSolved': 0, 'dailyStreak': 0, 'puzzleRating': 1500};
    }
  }
}

// Riverpod Providers
final puzzleServiceProvider = Provider((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  return PuzzleService(firestore, auth);
});

// Get daily challenge
final dailyChallengeProvider =
    FutureProvider<DailyChallengeModel?>((ref) async {
  final puzzleService = ref.watch(puzzleServiceProvider);
  return puzzleService.getDailyChallenge();
});

// Get specific puzzle
final puzzleByIdProvider =
    FutureProvider.family<PuzzleModel?, String>((ref, puzzleId) async {
  final puzzleService = ref.watch(puzzleServiceProvider);
  return puzzleService.getPuzzleById(puzzleId);
});

// Get puzzles by rating range
final puzzlesByRatingProvider =
    FutureProvider.family<List<PuzzleModel>, ({int minRating, int maxRating})>(
  (ref, params) async {
    final puzzleService = ref.watch(puzzleServiceProvider);
    return puzzleService.getPuzzlesByRating(params.minRating, params.maxRating);
  },
);

// The signed-in user's best-ever Puzzle Rush score (0 if never played).
final puzzleRushBestScoreProvider = StreamProvider<int>((ref) async* {
  final firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    yield 0;
    return;
  }

  try {
    await for (final snapshot
        in firestore.collection('users').doc(user.uid).snapshots()) {
      yield (snapshot.data()?['puzzleRushBestScore'] as num?)?.toInt() ?? 0;
    }
  } catch (e) {
    yield 0;
  }
});

// Any user's puzzle rating by uid - unlike userPuzzleStatsProvider (which
// only ever reads the signed-in user's own doc), for showing e.g. a
// friend's or opponent's puzzle rating on their profile.
final puzzleRatingProvider =
    FutureProvider.family<int, String>((ref, uid) async {
  final firestore = FirebaseFirestore.instance;
  try {
    final doc = await firestore.collection('users').doc(uid).get();
    return (doc.data()?['puzzleRating'] as num?)?.toInt() ?? 1500;
  } catch (e) {
    return 1500;
  }
});

// Track user's puzzle statistics
final userPuzzleStatsProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    yield {'puzzlesSolved': 0, 'dailyStreak': 0, 'puzzleRating': 1500};
    return;
  }

  try {
    await for (final snapshot
        in firestore.collection('users').doc(user.uid).snapshots()) {
      if (snapshot.exists) {
        yield {
          'puzzlesSolved': snapshot.data()?['puzzlesSolved'] ?? 0,
          'dailyStreak': snapshot.data()?['dailyStreak'] ?? 0,
          'puzzleRating': snapshot.data()?['puzzleRating'] ?? 1500,
        };
      }
    }
  } catch (e) {
    yield {'puzzlesSolved': 0, 'dailyStreak': 0, 'puzzleRating': 1500};
  }
});
