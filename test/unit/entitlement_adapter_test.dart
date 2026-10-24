import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_chess/src/providers/premium_provider.dart';
import 'package:komovia_chess/src/utils/entitlement_adapter.dart';

void main() {
  group('UserSubscriptionEntitlement.toEntitlement', () {
    test('inactive/free subscription maps to an inactive entitlement', () {
      final entitlement =
          UserSubscription(tier: 'free', isActive: false).toEntitlement();
      expect(entitlement.isActive, isFalse);
      expect(entitlement.plan, isNull);
      expect(entitlement.isCurrentlyActive(), isFalse);
    });

    test('active monthly tier with an expiry maps to SubscriptionPlan.monthly',
        () {
      final expiry = DateTime(2099, 1, 1);
      final entitlement = UserSubscription(
        tier: 'pro',
        isActive: true,
        expiryDate: expiry,
      ).toEntitlement();
      expect(entitlement.isActive, isTrue);
      expect(entitlement.plan, SubscriptionPlan.monthly);
      expect(entitlement.expiresAt, expiry);
      expect(entitlement.isLifetime, isFalse);
      expect(entitlement.isCurrentlyActive(now: DateTime(2026)), isTrue);
    });

    test('active subscription with no expiry maps to SubscriptionPlan.lifetime',
        () {
      final entitlement = UserSubscription(
        tier: 'premium',
        isActive: true,
      ).toEntitlement();
      expect(entitlement.plan, SubscriptionPlan.lifetime);
      expect(entitlement.isLifetime, isTrue);
      expect(entitlement.isCurrentlyActive(now: DateTime(2099)), isTrue);
    });

    test('an expired-but-flagged-inactive subscription has no plan', () {
      // userSubscriptionProvider already re-derives isActive from the
      // expiry date before this adapter runs (see premium_provider.dart),
      // so a past expiry should already have flipped isActive to false.
      final entitlement = UserSubscription(
        tier: 'pro',
        isActive: false,
        expiryDate: DateTime(2000, 1, 1),
      ).toEntitlement();
      expect(entitlement.plan, isNull);
      expect(entitlement.isCurrentlyActive(), isFalse);
    });
  });
}
