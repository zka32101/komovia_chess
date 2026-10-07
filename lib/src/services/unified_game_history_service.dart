import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;
import 'error_logging_service.dart';

/// Exception thrown for game history service errors
class GameHistoryException implements Exception {
  GameHistoryException(
    this.message, {
    this.code,
    this.originalError,
  });
  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() => message;
}

/// Unified service for managing game history
///
/// Consolidates:
/// - CPU play game history (single player vs AI)
/// - Multiplayer match history (online games)
/// - Performance statistics
/// - Rating history
///
/// Features:
/// - Comprehensive error logging
/// - Network resilience
/// - Pagination support
/// - Filtering and search
/// - CSV export
/// - Statistics aggregation
class UnifiedGameHistoryService {
  UnifiedGameHistoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger = Logger();

  /// Get current user ID
  String get _userId =>
      _auth.currentUser?.uid ??
      (throw GameHistoryException(
        'No user logged in',
        code: 'auth_required',
      ));

  // ============================================
  // MULTIPLAYER GAME HISTORY
  // ============================================

  /// Get paginated match history for current player
  ///
  /// Retrieves completed online games with pagination support
  /// Ordered by most recent first
  Future<List<Map<String, dynamic>>> getMatchHistory({
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      _logger.i('Fetching match history for user $_userId, limit: $limit');

      Query query = _firestore
          .collection('games')
          .where(
            Filter.or(
              Filter('whitePlayerId', isEqualTo: _userId),
              Filter('blackPlayerId', isEqualTo: _userId),
            ),
          )
          .where('status', isEqualTo: 'completed')
          .orderBy('endedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await _handleNetworkCall(
        () => query.get(),
        'Fetch match history',
      );

      final matches = snapshot.docs
          .map((doc) => {
                'gameId': doc.id,
                ...doc.data()! as Map<String, dynamic>,
              })
          .toList();

      _logger.d('Fetched ${matches.length} matches');
      return matches;
    } on GameHistoryException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        e,
        stackTrace,
        context: 'getMatchHistory',
        reason: 'Failed to fetch match history',
      );
      throw GameHistoryException(
        'Failed to fetch match history. Please try again.',
        originalError: e,
      );
    }
  }

  /// Stream live match history updates
  Stream<List<Map<String, dynamic>>> watchMatchHistory() => _firestore
          .collection('games')
          .where(
            Filter.or(
              Filter('whitePlayerId', isEqualTo: _userId),
              Filter('blackPlayerId', isEqualTo: _userId),
            ),
          )
          .where('status', isEqualTo: 'completed')
          .orderBy('endedAt', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {
                    'gameId': doc.id,
                    ...doc.data(),
                  })
              .toList())
          .handleError((e, stackTrace) async {
        await ErrorLoggingService.logError(
          e,
          stackTrace as StackTrace,
          context: 'watchMatchHistory',
          reason: 'Stream error while watching match history',
        );
        return [];
      });

  /// Filter games by multiple criteria
  ///
  /// Supports filtering by:
  /// - Date range
  /// - Opponent
  /// - Game result
  /// - Time control
  /// - Rating range
  Future<List<Map<String, dynamic>>> filterGames({
    DateTime? fromDate,
    DateTime? toDate,
    String? opponentId,
    String? result, // 'white_win', 'black_win', 'draw'
    String? timeControl,
    int? minRating,
    int? maxRating,
    int limit = 100,
  }) async {
    try {
      _logger.i('Filtering games with criteria');

      Query query = _firestore
          .collection('games')
          .where(
            Filter.or(
              Filter('whitePlayerId', isEqualTo: _userId),
              Filter('blackPlayerId', isEqualTo: _userId),
            ),
          )
          .where('status', isEqualTo: 'completed');

      // Apply filters
      if (fromDate != null) {
        query = query.where('endedAt', isGreaterThanOrEqualTo: fromDate);
      }
      if (toDate != null) {
        query = query.where('endedAt', isLessThanOrEqualTo: toDate);
      }
      if (result != null) {
        query = query.where('result', isEqualTo: result);
      }
      if (timeControl != null) {
        query = query.where('timeControl', isEqualTo: timeControl);
      }

      query = query.orderBy('endedAt', descending: true).limit(limit);

      final snapshot = await _handleNetworkCall(
        () => query.get(),
        'Filter games',
      );

      var games = snapshot.docs
          .map((doc) => {
                'gameId': doc.id,
                ...doc.data()! as Map<String, dynamic>,
              })
          .toList();

      // Post-filter on client side for rating range (Firestore limitation)
      if (minRating != null || maxRating != null) {
        games = games.where((game) {
          final isWhite = game['whitePlayerId'] == _userId;
          final playerRating =
              isWhite ? game['whiteRating'] : game['blackRating'];

          if (minRating != null && playerRating < minRating) return false;
          if (maxRating != null && playerRating > maxRating) return false;
          return true;
        }).toList();
      }

      _logger.d('Filtered to ${games.length} games');
      return games;
    } on GameHistoryException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        e,
        stackTrace,
        context: 'filterGames',
        reason: 'Failed to filter games',
      );
      throw GameHistoryException(
        'Failed to filter games. Please try again.',
        originalError: e,
      );
    }
  }

  /// Get head-to-head statistics against a specific opponent
  Future<Map<String, int>> getStatsVsOpponent(String opponentId) async {
    try {
      _logger.i('Getting stats vs opponent $opponentId');

      final snapshot = await _handleNetworkCall(
        () => _firestore
            .collection('games')
            .where(
              Filter.or(
                Filter.and(
                  Filter('whitePlayerId', isEqualTo: _userId),
                  Filter('blackPlayerId', isEqualTo: opponentId),
                ),
                Filter.and(
                  Filter('whitePlayerId', isEqualTo: opponentId),
                  Filter('blackPlayerId', isEqualTo: _userId),
                ),
              ),
            )
            .where('status', isEqualTo: 'completed')
            .get(),
        'Get opponent statistics',
      );

      int wins = 0;
      int losses = 0;
      int draws = 0;

      for (final doc in snapshot.docs) {
        final game = doc.data();
        final isWhite = game['whitePlayerId'] == _userId;
        final result = game['result'] as String?;

        if (result == 'white_win') {
          if (isWhite) {
            wins++;
          } else {
            losses++;
          }
        } else if (result == 'black_win') {
          if (isWhite) {
            losses++;
          } else {
            wins++;
          }
        } else if (result == 'draw') {
          draws++;
        }
      }

      _logger.d('Stats vs opponent: W:$wins L:$losses D:$draws');
      return {'wins': wins, 'losses': losses, 'draws': draws};
    } on GameHistoryException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        e,
        stackTrace,
        context: 'getStatsVsOpponent',
        reason: 'Failed to get opponent statistics',
      );
      throw GameHistoryException(
        'Failed to get opponent statistics.',
        originalError: e,
      );
    }
  }

  /// Get aggregated statistics for current player
  Future<Map<String, dynamic>> getPlayerStats() async {
    try {
      _logger.i('Calculating player statistics');

      final snapshot = await _handleNetworkCall(
        () => _firestore
            .collection('games')
            .where(
              Filter.or(
                Filter('whitePlayerId', isEqualTo: _userId),
                Filter('blackPlayerId', isEqualTo: _userId),
              ),
            )
            .where('status', isEqualTo: 'completed')
            .get(),
        'Calculate player statistics',
      );

      final int totalGames = snapshot.size;
      int wins = 0;
      int losses = 0;
      int draws = 0;
      int totalRatingGain = 0;

      for (final doc in snapshot.docs) {
        final game = doc.data();
        final isWhite = game['whitePlayerId'] == _userId;
        final result = game['result'] as String?;
        final ratingDelta = isWhite
            ? (game['whiteRatingAfter'] as int? ?? 0) -
                (game['whiteRatingBefore'] as int? ?? 0)
            : (game['blackRatingAfter'] as int? ?? 0) -
                (game['blackRatingBefore'] as int? ?? 0);

        if (result == 'white_win') {
          if (isWhite) {
            wins++;
          } else {
            losses++;
          }
        } else if (result == 'black_win') {
          if (isWhite) {
            losses++;
          } else {
            wins++;
          }
        } else if (result == 'draw') {
          draws++;
        }

        totalRatingGain += ratingDelta;
      }

      final stats = {
        'totalGames': totalGames,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'winRate': totalGames > 0
            ? (wins / totalGames * 100).toStringAsFixed(1)
            : '0.0',
        'totalRatingGain': totalRatingGain,
        'averageRatingGain': totalGames > 0
            ? (totalRatingGain / totalGames).toStringAsFixed(1)
            : '0.0',
      };

      _logger.d('Player stats: $stats');
      return stats;
    } on GameHistoryException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        e,
        stackTrace,
        context: 'getPlayerStats',
        reason: 'Failed to calculate player statistics',
      );
      throw GameHistoryException(
        'Failed to calculate player statistics.',
        originalError: e,
      );
    }
  }

  /// Export game history as CSV
  Future<String> exportAsCSV({int limit = 1000}) async {
    try {
      _logger.i('Exporting game history as CSV');

      final snapshot = await _handleNetworkCall(
        () => _firestore
            .collection('games')
            .where(
              Filter.or(
                Filter('whitePlayerId', isEqualTo: _userId),
                Filter('blackPlayerId', isEqualTo: _userId),
              ),
            )
            .where('status', isEqualTo: 'completed')
            .orderBy('endedAt', descending: true)
            .limit(limit)
            .get(),
        'Export game history',
      );

      final buffer = StringBuffer();
      buffer.writeln(
          'Date,Opponent,Color,Result,Rating Change,Time Control,Moves');

      for (final doc in snapshot.docs) {
        final game = doc.data();
        final isWhite = game['whitePlayerId'] == _userId;
        final opponentName =
            isWhite ? game['blackPlayerName'] : game['whitePlayerName'];
        final ratingBefore =
            isWhite ? game['whiteRatingBefore'] : game['blackRatingBefore'];
        final ratingAfter =
            isWhite ? game['whiteRatingAfter'] : game['blackRatingAfter'];
        final ratingChange =
            (ratingAfter as int? ?? 0) - (ratingBefore as int? ?? 0);
        final result = game['result'];
        final timeControl = game['timeControl'] ?? '-';
        final moves =
            game['moves'] != null ? (game['moves'] as List).length : 0;

        buffer.writeln(
          '${game['endedAt']},'
          '$opponentName,'
          '${isWhite ? 'White' : 'Black'},'
          '$result,'
          '${ratingChange > 0 ? '+' : ''}$ratingChange,'
          '$timeControl,'
          '$moves',
        );
      }

      _logger.i('Exported ${snapshot.size} games to CSV');
      return buffer.toString();
    } on GameHistoryException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        e,
        stackTrace,
        context: 'exportAsCSV',
        reason: 'Failed to export game history',
      );
      throw GameHistoryException(
        'Failed to export game history.',
        originalError: e,
      );
    }
  }

  /// Get rating history (ratings over time)
  Future<List<Map<String, dynamic>>> getRatingHistory() async {
    try {
      _logger.i('Fetching rating history for user $_userId');

      final snapshot = await _handleNetworkCall(
        () => _firestore
            .collection('users')
            .doc(_userId)
            .collection('rating_history')
            .orderBy('timestamp', descending: false)
            .limit(1000)
            .get(),
        'Fetch rating history',
      );

      final history = snapshot.docs
          .map((doc) => {
                'timestamp': doc['timestamp'],
                'rating': doc['rating'],
                'gameId': doc['gameId'],
                'delta': doc['delta'],
              })
          .toList();

      _logger.d('Fetched ${history.length} rating history entries');
      return history;
    } on GameHistoryException {
      rethrow;
    } catch (e, stackTrace) {
      await ErrorLoggingService.logError(
        e,
        stackTrace,
        context: 'getRatingHistory',
        reason: 'Failed to fetch rating history',
      );
      throw GameHistoryException(
        'Failed to fetch rating history.',
        originalError: e,
      );
    }
  }

  // ============================================
  // PRIVATE HELPERS
  // ============================================

  /// Handle network calls with error conversion
  Future<T> _handleNetworkCall<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } on SocketException catch (e) {
      throw GameHistoryException(
        'Network error: Unable to connect. Please check your internet connection.',
        code: 'network_error',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw GameHistoryException(
        'Connection timeout: The request took too long. Please try again.',
        code: 'timeout',
        originalError: e,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'network-error' || e.code == 'unavailable') {
        throw GameHistoryException(
          'Service unavailable: Please try again later.',
          code: e.code,
          originalError: e,
        );
      }
      rethrow;
    }
  }
}
