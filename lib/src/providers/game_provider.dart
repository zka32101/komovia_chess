import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../services/error_logging_service.dart';
import '../services/rating_calculation_service.dart';
import '../services/fen_calculator_service.dart';

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

// Get active games for current user
final activeGamesProvider = StreamProvider<List<GameModel>>((ref) async* {
  final firestore = ref.watch(firestoreProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    yield [];
    return;
  }

  try {
    await for (final snapshot in firestore
        .collection('games')
        .where('status', isEqualTo: 'active')
        .where(
          Filter.or(
            Filter('whitePlayerId', isEqualTo: user.uid),
            Filter('blackPlayerId', isEqualTo: user.uid),
          ),
        )
        .snapshots()) {
      final games = snapshot.docs
          .map((doc) => GameModel.fromJson({
                ...doc.data(),
                'gameId': doc.id,
              }))
          .toList();
      yield games;
    }
  } catch (e, stackTrace) {
    await ErrorLoggingService.logError(
      e,
      stackTrace,
      context: 'activeGamesProvider',
      reason: 'Failed to fetch active games from Firestore',
    );
    yield []; // Graceful fallback while error is logged
  }
});

// Get game history for current user
final gameHistoryProvider = StreamProvider<List<GameModel>>((ref) async* {
  final firestore = ref.watch(firestoreProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    yield [];
    return;
  }

  try {
    await for (final snapshot in firestore
        .collection('games')
        .where('status', isEqualTo: 'completed')
        .where(
          Filter.or(
            Filter('whitePlayerId', isEqualTo: user.uid),
            Filter('blackPlayerId', isEqualTo: user.uid),
          ),
        )
        .orderBy('endedAt', descending: true)
        .limit(50)
        .snapshots()) {
      final games = snapshot.docs
          .map((doc) => GameModel.fromJson({
                ...doc.data(),
                'gameId': doc.id,
              }))
          .toList();
      yield games;
    }
  } catch (e, stackTrace) {
    await ErrorLoggingService.logError(
      e,
      stackTrace,
      context: 'gameHistoryProvider',
      reason: 'Failed to fetch game history from Firestore',
    );
    yield []; // Graceful fallback while error is logged
  }
});

// Get specific game by ID
final gameByIdProvider =
    StreamProvider.family<GameModel?, String>((ref, gameId) async* {
  final firestore = ref.watch(firestoreProvider);

  try {
    await for (final snapshot
        in firestore.collection('games').doc(gameId).snapshots()) {
      if (snapshot.exists) {
        yield GameModel.fromJson({
          ...snapshot.data()!,
          'gameId': snapshot.id,
        });
      } else {
        yield null;
      }
    }
  } catch (e, stackTrace) {
    await ErrorLoggingService.logError(
      e,
      stackTrace,
      context: 'gameByIdProvider',
      reason: 'Failed to fetch game $gameId from Firestore',
    );
    yield null; // Graceful fallback while error is logged
  }
});

// Game service for creating and managing games
class GameService {
  GameService(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<GameModel> createGame({
    required String opponentId,
    required String timeControl,
    required String gameType,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      // Get current user data for initial ratings
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final opponentDoc =
          await _firestore.collection('users').doc(opponentId).get();

      if (!currentUserDoc.exists || !opponentDoc.exists) {
        throw Exception('User or opponent not found');
      }

      final currentUserData = currentUserDoc.data()!;
      final opponentData = opponentDoc.data()!;

      final whitePlayerId = currentUser.uid;
      final blackPlayerId = opponentId;
      final whiteRating =
          (currentUserData['onlineRating'] as num? ?? 1600).toInt();
      final blackRating =
          (opponentData['onlineRating'] as num? ?? 1600).toInt();

      // Parse time control to milliseconds
      final timeControlMs = _parseTimeControl(timeControl);

      // Create game document
      final gameData = {
        'type': gameType,
        'status': 'active',
        'whitePlayerId': whitePlayerId,
        'blackPlayerId': blackPlayerId,
        'whitePlayerName': currentUserData['displayName'] ?? 'Player 1',
        'blackPlayerName': opponentData['displayName'] ?? 'Player 2',
        'whiteRating': whiteRating,
        'blackRating': blackRating,
        'currentFen':
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': [],
        'pgn': '',
        'timeControl': timeControl,
        'timeControlMs': timeControlMs,
        'whiteTimeRemainingMs': timeControlMs,
        'blackTimeRemainingMs': timeControlMs,
        'result': null,
        'resultReason': null,
        'abandonedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
      };

      final gameRef = await _firestore.collection('games').add(gameData);

      return GameModel.fromJson({
        ...gameData,
        'gameId': gameRef.id,
        'createdAt': DateTime.now(),
        'startedAt': DateTime.now(),
      });
    } catch (e) {
      print('Error creating game: $e');
      rethrow;
    }
  }

  Future<void> makeMove({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) throw Exception('Game not found');

      final gameData = gameDoc.data()!;
      final currentMoves =
          List<Map<String, dynamic>>.from(gameData['moves'] ?? []);

      // Validate it's the current player's turn
      final isWhiteToMove = currentMoves.length % 2 == 0;
      final isCurrentUserWhite = gameData['whitePlayerId'] == currentUser.uid;

      if (isWhiteToMove != isCurrentUserWhite) {
        throw Exception('Not your turn');
      }

      // Create move record
      final moveRecord = {
        'from': from,
        'to': to,
        'promotion': promotion,
        'timestamp': FieldValue.serverTimestamp(),
        'playerId': currentUser.uid,
      };

      currentMoves.add(moveRecord);

      // Compute the resulting FEN via FenCalculatorService (validates legality)
      String newFen;
      try {
        newFen = FenCalculatorService.calculateNewFen(
          gameData['currentFen'] as String,
          from,
          to,
          promotion: promotion,
        );
      } catch (e) {
        throw Exception('Failed to calculate position: $e');
      }

      // Update game with new move and FEN
      await gameRef.update({
        'moves': currentMoves,
        'currentFen': newFen,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error making move: $e');
      rethrow;
    }
  }

  Future<void> resignGame(String gameId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) throw Exception('Game not found');

      final gameData = gameDoc.data()!;
      final whitePlayerId = gameData['whitePlayerId'] as String;

      // Determine result based on who resigned
      final isCurrentUserWhite = currentUser.uid == whitePlayerId;
      final result = isCurrentUserWhite ? 'black_win' : 'white_win';

      await gameRef.update({
        'status': 'completed',
        'result': result,
        'resultReason': 'resignation',
        'abandonedBy': currentUser.uid,
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Update user ratings with ELO calculation
      await _updateUserRatings(gameId, result);
    } catch (e) {
      print('Error resigning game: $e');
      rethrow;
    }
  }

  Future<void> offerDraw(String gameId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    try {
      final gameRef = _firestore.collection('games').doc(gameId);

      await gameRef.update({
        'drawOfferBy': currentUser.uid,
        'drawOfferAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error offering draw: $e');
      rethrow;
    }
  }

  // Helper method to parse time control string
  int _parseTimeControl(String timeControl) {
    // Formats: "10min", "5min", "3min", "1h", "30s"
    final value =
        int.tryParse(timeControl.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;

    if (timeControl.contains('h')) {
      return value * 60 * 60 * 1000; // Convert hours to milliseconds
    } else if (timeControl.contains('min')) {
      return value * 60 * 1000; // Convert minutes to milliseconds
    } else if (timeControl.contains('s')) {
      return value * 1000; // Convert seconds to milliseconds
    }

    return value * 60 * 1000; // Default to minutes
  }

  // Helper method to update user ratings after game completion
  Future<void> _updateUserRatings(String gameId, String result) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();

      if (!gameDoc.exists) return;

      final gameData = gameDoc.data()!;
      final whitePlayerId = gameData['whitePlayerId'] as String;
      final blackPlayerId = gameData['blackPlayerId'] as String;
      final whiteRating = gameData['whiteRating'] as int;
      final blackRating = gameData['blackRating'] as int;

      // Calculate new ratings using ELO system
      final ratingDeltas =
          RatingCalculationService.calculateBothPlayersRatingDelta(
        whiteRating,
        blackRating,
        result,
      );

      final whiteRatingDelta = ratingDeltas['whiteRatingDelta'] ?? 0;
      final blackRatingDelta = ratingDeltas['blackRatingDelta'] ?? 0;

      final newWhiteRating = whiteRating + whiteRatingDelta;
      final newBlackRating = blackRating + blackRatingDelta;

      // Update game document with rating information
      await _firestore.collection('games').doc(gameId).update({
        'ratingUpdated': true,
        'whiteRatingBefore': whiteRating,
        'whiteRatingAfter': newWhiteRating,
        'whiteRatingDelta': whiteRatingDelta,
        'blackRatingBefore': blackRating,
        'blackRatingAfter': newBlackRating,
        'blackRatingDelta': blackRatingDelta,
        'ratingCalculatedAt': FieldValue.serverTimestamp(),
      });

      // Update user rating documents for both players
      await _firestore.collection('users').doc(whitePlayerId).update({
        'onlineRating': newWhiteRating,
        'lastGameRatingDelta': whiteRatingDelta,
        'lastGameRatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(blackPlayerId).update({
        'onlineRating': newBlackRating,
        'lastGameRatingDelta': blackRatingDelta,
        'lastGameRatedAt': FieldValue.serverTimestamp(),
      });

      print(
          'Rating updated - White: $whiteRating→$newWhiteRating (${whiteRatingDelta > 0 ? '+' : ''}$whiteRatingDelta), '
          'Black: $blackRating→$newBlackRating (${blackRatingDelta > 0 ? '+' : ''}$blackRatingDelta)');
    } catch (e) {
      print('Error updating ratings: $e');
      rethrow;
    }
  }
}

final gameServiceProvider = Provider((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = FirebaseAuth.instance;
  return GameService(firestore, auth);
});
