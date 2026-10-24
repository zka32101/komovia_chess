import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_analysis.dart';
import '../models/weakness_profile.dart';

/// Persists and aggregates per-game weakness summaries (mistake/blunder
/// counts by game phase), computed from the per-move [GameAnalysis]
/// ChessAnalysisService already produces for GameAnalysisScreen. That
/// analysis was previously ephemeral - computed fresh every time a
/// player opened the screen for one specific game, never saved - so
/// there was no way to see which phase of the game a player struggled
/// with across their games as a whole, and nothing linked that signal
/// back to this app's own tactics/opening/strategy lesson content.
class WeaknessAnalysisService {
  WeaknessAnalysisService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('weakness_analysis');

  /// Saves one game's phase-by-phase mistake counts for [uid], derived
  /// from an already-computed [analysis]. Safe to call more than once
  /// for the same [gameId] (e.g. re-opening the analysis screen) - it
  /// just overwrites that game's own doc rather than double-counting.
  Future<void> recordGameAnalysis({
    required String uid,
    required String gameId,
    required GameAnalysis analysis,
    required bool isWhitePlayer,
  }) async {
    try {
      final summary = GameWeaknessSummary.fromGameAnalysis(
        gameId: gameId,
        analysis: analysis,
        isWhitePlayer: isWhitePlayer,
      );
      await _collection(uid).doc(gameId).set(summary.toJson());
    } catch (e) {
      // Best-effort - a failed save shouldn't block the player from
      // seeing their just-computed analysis for this one game.
      debugPrint('Error recording weakness analysis: $e');
    }
  }

  /// Aggregates every analyzed game's phase stats for [uid] into one
  /// [WeaknessProfile]. Capped to the most recent 200 analyzed games
  /// (ordered by analyzedAt) so a very active player's read doesn't grow
  /// unbounded - recent play matters more than a years-old game anyway.
  Future<WeaknessProfile> getWeaknessProfile(String uid) async {
    try {
      final snapshot = await _collection(uid)
          .orderBy('analyzedAt', descending: true)
          .limit(200)
          .get();

      if (snapshot.docs.isEmpty) return WeaknessProfile.empty;

      final byPhase = <GamePhase, PhaseStats>{
        for (final phase in GamePhase.values) phase: const PhaseStats(),
      };
      for (final doc in snapshot.docs) {
        final summary = GameWeaknessSummary.fromJson(doc.id, doc.data());
        for (final phase in GamePhase.values) {
          byPhase[phase] = byPhase[phase]! + summary.byPhase[phase]!;
        }
      }

      return WeaknessProfile(byPhase: byPhase, gamesAnalyzed: snapshot.docs.length);
    } catch (e) {
      debugPrint('Error fetching weakness profile: $e');
      return WeaknessProfile.empty;
    }
  }
}
