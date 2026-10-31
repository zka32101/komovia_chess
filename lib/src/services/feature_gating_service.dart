import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing feature gates and daily action limits
class FeatureGatingService {
  FeatureGatingService._();
  static final FeatureGatingService _instance = FeatureGatingService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Feature availability
  static const Map<String, Set<String>> FEATURE_TIERS = {
    'unlimited_puzzles': {'pro', 'premium'},
    'unlimited_games': {'pro', 'premium'},
    'advanced_analysis': {'pro', 'premium'},
    'ai_lessons': {'premium'},
    'personalized_training': {'premium'},
    'offline_mode': {'premium'},
    'priority_support': {'premium'},
  };

  // Free tier daily limits. Keys match the action-name vocabulary
  // premium_provider.dart's remainingAttemptsProvider/canPerformActionProvider
  // callers pass ('daily_puzzles'/'daily_games') - these previously read
  // 'puzzles'/'games', which no real caller would ever pass, so every
  // lookup below silently fell through to `?? 0` (zero daily attempts
  // for free-tier users, instead of the intended 3/2).
  static const Map<String, int> DAILY_LIMITS = {
    'daily_puzzles': 3,
    'daily_games': 10,
    // AI post-game analysis (GameAnalysisScreen / OneTapWeaknessButton).
    // Unlike the two keys above, this quota is NOT lifted by the
    // 'pro'/'premium' tiers: unlimited AI analysis is sold as its own
    // separate product (the AI分析プラン - see AiAnalysisGate), so callers
    // always evaluate this key with the 'free' tier argument and bypass it
    // entirely only when that separate plan is active.
    AI_ANALYSIS_ACTION: 3,
  };

  /// Daily-quota key for AI post-game analysis.
  static const String AI_ANALYSIS_ACTION = 'ai_analysis';

  static FeatureGatingService get instance => _instance;

  /// Check if user has access to a premium feature
  Future<bool> hasFeatureAccess(
      String featureName, String subscriptionTier) async {
    if (subscriptionTier == 'free') {
      // An unrecognized featureName (e.g. a typo) has no entry in
      // FEATURE_TIERS at all, so the lookup is null - previously that
      // fell through `?? true`, silently granting free-tier access to
      // whatever was asked for instead of failing closed like every
      // other unrecognized case here does.
      return FEATURE_TIERS[featureName]?.isEmpty ?? false;
    }
    return FEATURE_TIERS[featureName]?.contains(subscriptionTier) ?? false;
  }

  /// Get user's remaining daily attempts for an action
  Future<int> getRemainingDailyAttempts(
      String action, String subscriptionTier) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    // Pro and Premium tiers have unlimited access
    if (subscriptionTier != 'free') {
      return 999;
    }

    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_limits')
          .doc(dateKey)
          .get();

      if (!doc.exists) {
        return DAILY_LIMITS[action] ?? 0;
      }

      final usedCount = (doc.data()?['${action}_used'] as int?) ?? 0;
      final limit = DAILY_LIMITS[action] ?? 0;
      final remaining = (limit - usedCount).clamp(0, limit);

      return remaining;
    } catch (e) {
      print('Error getting remaining attempts: $e');
      return 0;
    }
  }

  /// Track an action usage for daily limits
  Future<void> trackActionUsage(String action, String subscriptionTier) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Only track for free tier
    if (subscriptionTier != 'free') {
      return;
    }

    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_limits')
          .doc(dateKey)
          .set(
        {'${action}_used': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error tracking action usage: $e');
    }
  }

  /// Check if user can perform action
  Future<bool> canPerformAction(String action, String subscriptionTier) async {
    final remaining = await getRemainingDailyAttempts(action, subscriptionTier);
    return remaining > 0;
  }

  /// Get premium feature description
  String getFeatureDescription(String featureName) {
    const descriptions = {
      'unlimited_puzzles': 'Solve unlimited tactical puzzles',
      'unlimited_games': 'Play unlimited online matches',
      'advanced_analysis': 'Get detailed game analysis and improvements',
      'ai_lessons': 'Access AI-powered personalized lessons',
      'personalized_training': 'Create custom training plans',
      'offline_mode': 'Play and solve puzzles offline',
      'priority_support': 'Priority customer support access',
    };
    return descriptions[featureName] ?? '';
  }

  /// Reset daily limits (for testing or admin)
  Future<void> resetDailyLimits(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_limits')
          .doc(dateKey)
          .delete();
    } catch (e) {
      print('Error resetting daily limits: $e');
    }
  }
}
