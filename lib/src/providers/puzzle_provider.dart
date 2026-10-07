import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/puzzle.dart';

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
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final resultId =
          '${user.uid}_${puzzleId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('user_puzzle_results').doc(resultId).set({
        'userId': user.uid,
        'puzzleId': puzzleId,
        'solved': solved,
        'userMoves': userMoves,
        'timestamp': FieldValue.serverTimestamp(),
        'attempts': 1, // Will be incremented per attempt
      });

      // Update user's total puzzles solved
      if (solved) {
        await _firestore.collection('users').doc(user.uid).update({
          'puzzlesSolved': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error recording puzzle attempt: $e');
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
          'averageRating': userDoc.data()?['averageRating'] ?? 1600,
        };
      }
      return {'puzzlesSolved': 0, 'dailyStreak': 0, 'averageRating': 1600};
    } catch (e) {
      print('Error fetching puzzle stats: $e');
      return {'puzzlesSolved': 0, 'dailyStreak': 0, 'averageRating': 1600};
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

// Track user's puzzle statistics
final userPuzzleStatsProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    yield {'puzzlesSolved': 0, 'dailyStreak': 0, 'averageRating': 1600};
    return;
  }

  try {
    await for (final snapshot
        in firestore.collection('users').doc(user.uid).snapshots()) {
      if (snapshot.exists) {
        yield {
          'puzzlesSolved': snapshot.data()?['puzzlesSolved'] ?? 0,
          'dailyStreak': snapshot.data()?['dailyStreak'] ?? 0,
          'averageRating': snapshot.data()?['averageRating'] ?? 1600,
        };
      }
    }
  } catch (e) {
    yield {'puzzlesSolved': 0, 'dailyStreak': 0, 'averageRating': 1600};
  }
});
