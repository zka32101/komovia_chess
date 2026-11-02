import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';
import '../services/paywall_service.dart';
import '../services/feature_gating_service.dart';
import '../services/ai_analysis_gate.dart';
import '../utils/entitlement_adapter.dart';

/// User subscription state
class UserSubscription {
  UserSubscription({
    required this.tier,
    required this.isActive,
    this.expiryDate,
    this.isLifetime = false,
  });
  final String tier; // 'free', 'pro', 'premium'
  final DateTime? expiryDate;
  final bool isActive;

  /// True only for a one-time lifetime purchase (never for monthly/annual).
  final bool isLifetime;

  /// Whether lifetime-exclusive perks (komovia_core
  /// `CosmeticItem.includedWithLifetime`) apply.
  bool get isLifetimePurchaser => isLifetime && isActive;

  bool get isPro => tier == 'pro' && isActive;
  bool get isPremium => tier == 'premium' && isActive;
  bool get isFree => !isActive || tier == 'free';
}

// Get paywall service. Also kicks off PaywallService.initialize() the
// first time this provider is read (memoized, so once per app run) -
// nothing called it before, so the purchase stream listener that
// persists entitlement/completes purchases was never actually attached.
final paywallServiceProvider = Provider((ref) {
  final service = PaywallService.instance;
  service.initialize();
  return service;
});

// Get user's current subscription
final userSubscriptionProvider = FutureProvider<UserSubscription>((ref) async {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final user = auth.currentUser;

  if (user == null) {
    return UserSubscription(tier: 'free', isActive: false);
  }

  try {
    final doc = await firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      return UserSubscription(tier: 'free', isActive: false);
    }

    final data = doc.data()!;
    final tier = data['subscriptionTier'] as String? ?? 'free';
    final expiryTimestamp = data['subscriptionExpiry'] as Timestamp?;
    final expiryDate = expiryTimestamp?.toDate();

    // Check if this is a lifetime subscription (no expiry date and tier is not free)
    final isLifetime =
        data['isLifetime'] as bool? ?? (expiryDate == null && tier != 'free');

    // Active if: not free tier AND (lifetime OR expiry date is in the future)
    final isActive = tier != 'free' &&
        (isLifetime || (expiryDate?.isAfter(DateTime.now()) ?? false));

    return UserSubscription(
      tier: tier,
      expiryDate: expiryDate,
      isActive: isActive,
      isLifetime: isLifetime,
    );
  } catch (e) {
    debugPrint('Error fetching subscription: $e');
    return UserSubscription(tier: 'free', isActive: false);
  }
});

// This app's subscription status as a komovia_core Entitlement,
// game-agnostic and shared with komovia_go/komovia_shogi's own read
// paths.
final userEntitlementProvider = FutureProvider<Entitlement>((ref) async {
  final subscription = await ref.watch(userSubscriptionProvider.future);
  return subscription.toEntitlement();
});

// Check if specific premium feature is available
final premiumFeatureProvider =
    FutureProvider.family<bool, String>((ref, feature) async {
  final subscription = await ref.watch(userSubscriptionProvider.future);

  final premiumFeatures = {
    'unlimited_puzzles': subscription.isPro || subscription.isPremium,
    'unlimited_games': subscription.isPro || subscription.isPremium,
    'advanced_analysis': subscription.isPro || subscription.isPremium,
    'custom_board_themes': subscription.isPro || subscription.isPremium,
    'ai_lessons': subscription.isPremium,
    'personalized_training': subscription.isPremium,
    'offline_mode': subscription.isPremium,
    'priority_support': subscription.isPremium,
  };

  return premiumFeatures[feature] ?? false;
});

// Check if user can perform action with remaining attempts
final remainingAttemptsProvider =
    FutureProvider.family<int, String>((ref, action) async {
  final subscription = await ref.watch(userSubscriptionProvider.future);

  if (subscription.isPro || subscription.isPremium) {
    return 999; // Unlimited
  }

  // Free tier daily limits
  final limits = {
    'daily_puzzles': 3,
    'daily_games': 10,
  };

  return limits[action] ?? 0;
});

// Trigger paywall/subscription screen
final triggerPaywallProvider = StateProvider<String?>((ref) {
  return null; // Set to reason for showing paywall
});

// Feature gating service provider
final featureGatingServiceProvider =
    Provider((ref) => FeatureGatingService.instance);

// Check if user can perform action (with daily limits)
final canPerformActionProvider =
    FutureProvider.family<bool, String>((ref, action) async {
  final subscription = await ref.watch(userSubscriptionProvider.future);
  final featureGatingService = ref.watch(featureGatingServiceProvider);

  return featureGatingService.canPerformAction(action, subscription.tier);
});

// Get remaining daily attempts (tracks usage)
final remainingDailyUsageProvider =
    FutureProvider.family<int, String>((ref, action) async {
  final subscription = await ref.watch(userSubscriptionProvider.future);
  final featureGatingService = ref.watch(featureGatingServiceProvider);

  return featureGatingService.getRemainingDailyAttempts(
      action, subscription.tier);
});

// Track action usage
final trackActionUsageProvider =
    FutureProvider.family<void, String>((ref, action) async {
  final subscription = await ref.watch(userSubscriptionProvider.future);
  final featureGatingService = ref.watch(featureGatingServiceProvider);

  await featureGatingService.trackActionUsage(action, subscription.tier);
});

/// Whether the signed-in user's separate AI分析プラン (see
/// PaywallService.aiAnalysisPlanMonthlyProductId) is currently active -
/// read from users/{uid}.aiAnalysisPlanExpiry, independent of
/// subscriptionTier.
final aiAnalysisPlanActiveProvider = FutureProvider<bool>((ref) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final expiry = (doc.data()?['aiAnalysisPlanExpiry'] as Timestamp?)?.toDate();
    return expiry?.isAfter(DateTime.now()) ?? false;
  } catch (e) {
    debugPrint('Error fetching AI analysis plan: $e');
    return false;
  }
});

/// Real wiring of [AiAnalysisGate]. The quota is always evaluated with the
/// 'free' tier argument: pro/premium don't include unlimited AI analysis -
/// only the separate AI分析プラン does.
final aiAnalysisGateProvider = Provider<AiAnalysisGate>((ref) {
  final gating = ref.watch(featureGatingServiceProvider);
  return AiAnalysisGate(
    hasAiAnalysisPlan: () => ref.read(aiAnalysisPlanActiveProvider.future),
    remainingFreeAnalyses: () => gating.getRemainingDailyAttempts(
        FeatureGatingService.AI_ANALYSIS_ACTION, 'free'),
    consumeFreeAnalysis: () => gating.trackActionUsage(
        FeatureGatingService.AI_ANALYSIS_ACTION, 'free'),
  );
});
