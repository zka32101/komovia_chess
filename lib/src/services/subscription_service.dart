import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription.dart';

/// Subscription Service for RevenueCat integration
class SubscriptionService {
  SubscriptionService(this._firestore);
  final FirebaseFirestore _firestore;

  /// Get user subscription
  Future<UserSubscription?> getUserSubscription(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .get();
      if (!doc.exists) return null;

      return UserSubscription.fromJson(doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  /// Watch user subscription
  Stream<UserSubscription?> watchUserSubscription(String userId) => _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return UserSubscription.fromJson(doc.data()!);
      });

  /// Update subscription after purchase
  Future<void> updateSubscription({
    required String userId,
    required SubscriptionTier tier,
    required DateTime expiresAt,
    required bool autoRenewing,
    required String transactionId,
  }) async {
    try {
      final subscription = UserSubscription(
        userId: userId,
        currentTier: tier,
        status: SubscriptionStatus.active,
        expiresAt: expiresAt,
        autoRenewing: autoRenewing,
        sandbox: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .set(subscription.toJson());

      // Store purchase record
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc(transactionId)
          .set({
        'transaction_id': transactionId,
        'tier': tier.identifier,
        'purchased_at': DateTime.now(),
        'expires_at': expiresAt,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .update({
        'status': SubscriptionStatus.cancelled.name,
        'updated_at': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Check if feature is accessible
  Future<bool> hasAccessToFeature({
    required String userId,
    required PremiumFeature feature,
  }) async {
    try {
      final subscription = await getUserSubscription(userId);

      if (subscription == null || !subscription.isActive) {
        return false;
      }

      // Define feature access by tier
      const freeFeatures = <PremiumFeature>[];

      const premiumFeatures = <PremiumFeature>[
        PremiumFeature.unlimitedPuzzles,
        PremiumFeature.customBoard,
        PremiumFeature.noAds,
        PremiumFeature.offlinePlay,
      ];

      const eliteFeatures = <PremiumFeature>[
        PremiumFeature.unlimitedPuzzles,
        PremiumFeature.customBoard,
        PremiumFeature.gameAnalysis,
        PremiumFeature.noAds,
        PremiumFeature.offlinePlay,
        PremiumFeature.cloudSync,
        PremiumFeature.openingBooks,
        PremiumFeature.endgameTablebases,
      ];

      switch (subscription.currentTier) {
        case SubscriptionTier.free:
          return freeFeatures.contains(feature);
        case SubscriptionTier.premium:
          return premiumFeatures.contains(feature);
        case SubscriptionTier.elite:
          return eliteFeatures.contains(feature);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get available offerings
  Future<List<SubscriptionOffering>> getOfferings() async {
    try {
      // In a real app, this would come from RevenueCat
      return [
        const SubscriptionOffering(
          tier: SubscriptionTier.premium,
          packageId: 'premium_monthly',
          price: 4.99,
          currency: 'USD',
          displayPrice: r'$4.99',
          period: '1mo',
          features: [
            PremiumFeature.unlimitedPuzzles,
            PremiumFeature.customBoard,
            PremiumFeature.noAds,
            PremiumFeature.offlinePlay,
          ],
          isMostPopular: true,
        ),
        const SubscriptionOffering(
          tier: SubscriptionTier.premium,
          packageId: 'premium_annual',
          price: 39.99,
          currency: 'USD',
          displayPrice: r'$39.99',
          period: '1y',
          features: [
            PremiumFeature.unlimitedPuzzles,
            PremiumFeature.customBoard,
            PremiumFeature.noAds,
            PremiumFeature.offlinePlay,
          ],
          isMostPopular: false,
        ),
        const SubscriptionOffering(
          tier: SubscriptionTier.elite,
          packageId: 'elite_monthly',
          price: 9.99,
          currency: 'USD',
          displayPrice: r'$9.99',
          period: '1mo',
          features: [
            PremiumFeature.unlimitedPuzzles,
            PremiumFeature.customBoard,
            PremiumFeature.gameAnalysis,
            PremiumFeature.noAds,
            PremiumFeature.offlinePlay,
            PremiumFeature.cloudSync,
            PremiumFeature.openingBooks,
            PremiumFeature.endgameTablebases,
          ],
          isMostPopular: false,
        ),
      ];
    } catch (e) {
      rethrow;
    }
  }

  /// Get purchase history
  Future<List<PurchaseRecord>> getPurchaseHistory(String userId) async {
    try {
      final docs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .orderBy('purchased_at', descending: true)
          .get();

      return docs.docs
          .map((doc) => PurchaseRecord.fromJson(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases(String userId) async {
    try {
      // In a real app, this would sync with RevenueCat
      // For now, just refetch subscription status
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('current')
          .get();

      if (!doc.exists) {
        // Set to free tier if no subscription found
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('subscription')
            .doc('current')
            .set({
          'user_id': userId,
          'current_tier': SubscriptionTier.free.identifier,
          'status': SubscriptionStatus.active.name,
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}
