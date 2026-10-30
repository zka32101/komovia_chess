import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart' show computeFairPlaySignal, FairPlaySignal;
import '../models/game_analysis.dart';

/// Persists an engine-correlation "fair play" review signal for one
/// player's moves in one completed game, computed from the per-move
/// [GameAnalysis] ChessAnalysisService already produces (specifically
/// each MoveAnalysis.centipawnLoss, the same "how far from the engine's
/// best move was this" value GameAnalysisScreen already shows players).
///
/// This is a backend/moderator-only signal - see
/// `games/{gameId}/fair_play_signals/{uid}` in firestore.rules for the
/// access-control reasoning (admin-read-only; no moderator UI exists yet
/// in this app, so it's write-only from the client's perspective for
/// now). Nothing in this file (or the shared [computeFairPlaySignal] it
/// wraps) is ever shown to either player - see GameAnalysisScreen, which
/// never reads this data back.
class FairPlayService {
  FairPlayService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String gameId) =>
      _firestore
          .collection('games')
          .doc(gameId)
          .collection('fair_play_signals');

  /// Computes and saves [uid]'s [FairPlaySignal] for [gameId], derived
  /// from [analysis]'s moves for the side [isWhitePlayer] played. Safe to
  /// call more than once for the same (gameId, uid) - it overwrites that
  /// player's own doc for this game rather than accumulating duplicates.
  ///
  /// Best-effort: like WeaknessAnalysisService.recordGameAnalysis, a
  /// failure here (permission-denied, offline, etc.) is swallowed rather
  /// than surfaced, since this must never block or alter anything the
  /// two players actually see.
  Future<void> recordGameSignal({
    required String uid,
    required String gameId,
    required GameAnalysis analysis,
    required bool isWhitePlayer,
  }) async {
    try {
      final losses = analysis
          .movesBy(isWhitePlayer)
          .map((m) => m.centipawnLoss.toDouble())
          .toList();
      final signal = computeFairPlaySignal(losses);

      await _collection(gameId).doc(uid).set({
        'uid': uid,
        'gameId': gameId,
        'sampleSize': signal.sampleSize,
        'meanCentipawnLoss': signal.meanCentipawnLoss,
        'stdDevCentipawnLoss': signal.stdDevCentipawnLoss,
        'topMoveMatchRate': signal.topMoveMatchRate,
        'suspicionScore': signal.suspicionScore,
        'reviewRecommended': signal.reviewRecommended,
        'computedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording fair play signal: $e');
    }
  }
}
