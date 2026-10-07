import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:async';

/// Manages real-time game synchronization with conflict detection
class RealtimeSyncService {
  RealtimeSyncService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _gamesCollection = 'games';
  static const String _syncStateSubcollection = 'syncState';
  static const int _syncTimeoutMs = 5000;
  static const int _maxRetries = 3;

  /// Record a tentative move locally with sync metadata
  Future<MoveSync> recordTentativeMove({
    required String gameId,
    required String playerId,
    required int moveNumber,
    required String from,
    required String to,
    required String updatedFen,
    String? promotion,
  }) async {
    try {
      final clientTimestamp = DateTime.now().millisecondsSinceEpoch;
      final moveSync = MoveSync(
        moveId: _generateMoveId(),
        gameId: gameId,
        playerId: playerId,
        moveNumber: moveNumber,
        from: from,
        to: to,
        promotion: promotion,
        fen: updatedFen,
        clientTimestamp: clientTimestamp,
        syncStatus: 'pending',
        retryCount: 0,
        createdAt: DateTime.now(),
      );

      _logger
          .d('Recorded tentative move: ${moveSync.moveId} from $from to $to');

      return moveSync;
    } catch (e, st) {
      _logger.e('Failed to record tentative move', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Confirm move to server with conflict detection
  Future<bool> confirmMove({
    required String gameId,
    required MoveSync moveSync,
    required String pgn,
  }) async {
    try {
      // Get current game state to detect conflicts
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found');
      }

      final gameData = gameDoc.data()!;
      final currentMoveCount = (gameData['moves'] as List?)?.length ?? 0;

      // Detect move order conflict
      if (moveSync.moveNumber != currentMoveCount) {
        _logger.w(
            'Move conflict detected: expected move #$currentMoveCount, got #${moveSync.moveNumber}');
        return false;
      }

      // Attempt to persist move with server timestamp
      await _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_syncStateSubcollection)
          .doc(moveSync.moveId)
          .set({
        'gameId': gameId,
        'playerId': moveSync.playerId,
        'moveNumber': moveSync.moveNumber,
        'from': moveSync.from,
        'to': moveSync.to,
        'promotion': moveSync.promotion,
        'fen': moveSync.fen,
        'clientTimestamp': moveSync.clientTimestamp,
        'serverTimestamp': FieldValue.serverTimestamp(),
        'syncStatus': 'confirmed',
        'createdAt': DateTime.now().toIso8601String(),
      });

      _logger.i('Move confirmed: ${moveSync.moveId}');
      return true;
    } catch (e, st) {
      _logger.e('Failed to confirm move', error: e, stackTrace: st);
      return false;
    }
  }

  /// Get pending moves for a game
  Future<List<MoveSync>> getPendingMoves(String gameId) async {
    try {
      final snapshot = await _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_syncStateSubcollection)
          .where('syncStatus', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) => MoveSync.fromJson(doc.data())).toList();
    } catch (e, st) {
      _logger.e('Failed to get pending moves', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Stream sync state for real-time updates
  Stream<GameSyncState> watchSyncState(String gameId) => _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_syncStateSubcollection)
          .snapshots()
          .map((snapshot) {
        final moves =
            snapshot.docs.map((doc) => MoveSync.fromJson(doc.data())).toList();

        final pendingCount =
            moves.where((m) => m.syncStatus == 'pending').length;
        final confirmedCount =
            moves.where((m) => m.syncStatus == 'confirmed').length;

        return GameSyncState(
          gameId: gameId,
          totalMoves: moves.length,
          pendingMoves: pendingCount,
          confirmedMoves: confirmedCount,
          lastSyncTimestamp: DateTime.now(),
          movesList: moves,
        );
      });

  /// Cleanup old sync records
  Future<void> cleanupOldSyncRecords(String gameId,
      {int retentionDays = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

      await _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_syncStateSubcollection)
          .where('createdAt', isLessThan: cutoffDate.toIso8601String())
          .get()
          .then((snapshot) async {
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      });

      _logger.i('Cleaned up sync records for game $gameId');
    } catch (e, st) {
      _logger.e('Failed to cleanup sync records', error: e, stackTrace: st);
    }
  }

  String _generateMoveId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
}

/// Data class for move synchronization state
class MoveSync {
  MoveSync({
    required this.moveId,
    required this.gameId,
    required this.playerId,
    required this.moveNumber,
    required this.from,
    required this.to,
    required this.fen,
    required this.clientTimestamp,
    required this.syncStatus,
    required this.retryCount,
    required this.createdAt,
    this.promotion,
  });

  factory MoveSync.fromJson(Map<String, dynamic> json) => MoveSync(
        moveId: json['moveId'] as String,
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        moveNumber: json['moveNumber'] as int,
        from: json['from'] as String,
        to: json['to'] as String,
        promotion: json['promotion'] as String?,
        fen: json['fen'] as String,
        clientTimestamp: json['clientTimestamp'] as int,
        syncStatus: json['syncStatus'] as String,
        retryCount: json['retryCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
  final String moveId;
  final String gameId;
  final String playerId;
  final int moveNumber;
  final String from;
  final String to;
  final String? promotion;
  final String fen;
  final int clientTimestamp;
  final String syncStatus; // pending, confirmed, failed
  final int retryCount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'moveId': moveId,
        'gameId': gameId,
        'playerId': playerId,
        'moveNumber': moveNumber,
        'from': from,
        'to': to,
        'promotion': promotion,
        'fen': fen,
        'clientTimestamp': clientTimestamp,
        'syncStatus': syncStatus,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Data class for game synchronization state
class GameSyncState {
  GameSyncState({
    required this.gameId,
    required this.totalMoves,
    required this.pendingMoves,
    required this.confirmedMoves,
    required this.lastSyncTimestamp,
    required this.movesList,
  });
  final String gameId;
  final int totalMoves;
  final int pendingMoves;
  final int confirmedMoves;
  final DateTime lastSyncTimestamp;
  final List<MoveSync> movesList;

  bool get isSynced => pendingMoves == 0;
  double get syncProgress => confirmedMoves / (totalMoves + 1);
}
