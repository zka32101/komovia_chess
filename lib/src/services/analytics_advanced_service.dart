import 'package:cloud_firestore/cloud_firestore.dart';

// Phase N: 高度な分析 & 統計
class AnalyticsAdvancedService {
  factory AnalyticsAdvancedService() => _instance;
  AnalyticsAdvancedService._internal();
  static final AnalyticsAdvancedService _instance =
      AnalyticsAdvancedService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getOpeningBookAnalysis(String ecoCode) async {
    final doc = await _firestore.collection('opening_book').doc(ecoCode).get();
    return doc.data() ?? {};
  }

  Future<Map<String, dynamic>> getPlayerAnalytics(String userId) async {
    final doc =
        await _firestore.collection('player_analytics').doc(userId).get();
    return doc.data() ?? {};
  }

  Future<void> recordMoveTime(
      String gameId, int moveNumber, int timeSpentMs) async {
    await _firestore
        .collection('move_times')
        .doc(gameId)
        .collection('moves')
        .doc('$moveNumber')
        .set({
      'moveNumber': moveNumber,
      'timeSpent': timeSpentMs,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getMoveTimesAnalysis(String userId) async {
    final snapshot = await _firestore
        .collection('move_times')
        .where('userId', isEqualTo: userId)
        .get();
    return {'movesAnalyzed': snapshot.size};
  }
}
