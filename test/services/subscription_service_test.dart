import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/subscription_service.dart';

void main() {
  group('SubscriptionService', () {
    group('Subscription Plans', () {
      test('free plan has zero price', () {
        expect(SubscriptionPlan.free.monthlyPrice, equals(0.0));
      });

      test('premium plan has correct price', () {
        expect(SubscriptionPlan.premium.monthlyPrice, equals(4.99));
      });

      test('premium+ plan has correct annual price', () {
        expect(SubscriptionPlan.premiumPlus.monthlyPrice, equals(2.92));
      });

      test('all plans have display names', () {
        expect(SubscriptionPlan.free.displayName, isNotEmpty);
        expect(SubscriptionPlan.premium.displayName, isNotEmpty);
        expect(SubscriptionPlan.premiumPlus.displayName, isNotEmpty);
      });
    });

    group('Premium Features', () {
      test('all features have display names', () {
        for (final feature in PremiumFeature.values) {
          expect(feature.displayName, isNotEmpty);
        }
      });

      test('free plan has no premium features', () {
        for (final feature in PremiumFeature.values) {
          expect(feature.isAvailableIn(SubscriptionPlan.free), isFalse);
        }
      });

      test('premium plan has most features except priority support', () {
        expect(
          PremiumFeature.unlimitedPuzzles
              .isAvailableIn(SubscriptionPlan.premium),
          isTrue,
        );
        expect(
          PremiumFeature.customThemes.isAvailableIn(SubscriptionPlan.premium),
          isTrue,
        );
        expect(
          PremiumFeature.noAds.isAvailableIn(SubscriptionPlan.premium),
          isTrue,
        );
        expect(
          PremiumFeature.prioritySupport
              .isAvailableIn(SubscriptionPlan.premium),
          isFalse,
        );
      });

      test('premium+ plan has all features', () {
        for (final feature in PremiumFeature.values) {
          expect(
            feature.isAvailableIn(SubscriptionPlan.premiumPlus),
            isTrue,
            reason: '${feature.displayName} should be available in Premium+',
          );
        }
      });
    });

    group('SubscriptionStatus', () {
      test('free user is not premium', () {
        final status = SubscriptionStatus(userId: 'user-1');
        expect(status.isPremium, isFalse);
      });

      test('premium user is premium', () {
        final status = SubscriptionStatus(
          userId: 'user-1',
          currentPlan: SubscriptionPlan.premium,
          isSubscribed: true,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
        );
        expect(status.isPremium, isTrue);
      });

      test('inactive subscription is not active', () {
        final status = SubscriptionStatus(
          userId: 'user-1',
          currentPlan: SubscriptionPlan.premium,
          isSubscribed: false,
        );
        expect(status.isActive, isFalse);
      });

      test('expired subscription is not active', () {
        final status = SubscriptionStatus(
          userId: 'user-1',
          currentPlan: SubscriptionPlan.premium,
          isSubscribed: true,
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(status.isActive, isFalse);
        expect(status.isExpired, isTrue);
      });

      test('active subscription is active', () {
        final status = SubscriptionStatus(
          userId: 'user-1',
          currentPlan: SubscriptionPlan.premium,
          isSubscribed: true,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
        );
        expect(status.isActive, isTrue);
      });

      test('converts to map correctly', () {
        final expiryDate = DateTime.now().add(const Duration(days: 30));
        final status = SubscriptionStatus(
          userId: 'user-1',
          currentPlan: SubscriptionPlan.premium,
          isSubscribed: true,
          expiryDate: expiryDate,
          transactionId: 'txn-123',
        );

        final map = status.toMap();
        expect(map['userId'], equals('user-1'));
        expect(map['plan'], equals('premium_monthly'));
        expect(map['isSubscribed'], isTrue);
        expect(map['transactionId'], equals('txn-123'));
      });

      test('creates from map correctly', () {
        final map = {
          'userId': 'user-1',
          'plan': 'premium_monthly',
          'isSubscribed': true,
          'transactionId': 'txn-123',
        };

        final status = SubscriptionStatus.fromMap(map);
        expect(status.userId, equals('user-1'));
        expect(status.currentPlan, equals(SubscriptionPlan.premium));
        expect(status.isSubscribed, isTrue);
        expect(status.transactionId, equals('txn-123'));
      });

      test('defaults to free plan when not specified', () {
        final map = {'userId': 'user-1'};
        final status = SubscriptionStatus.fromMap(map);
        expect(status.currentPlan, equals(SubscriptionPlan.free));
      });
    });
  });
}
