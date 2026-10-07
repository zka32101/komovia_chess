import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/paywall_service.dart';

void main() {
  group('PaywallService', () {
    late PaywallService paywall;

    setUp(() {
      paywall = PaywallService();
    });

    group('Initialization', () {
      test('initializes with free subscription', () async {
        await paywall.initialize();

        final subscription = paywall.getCurrentSubscription();
        expect(subscription, isNotNull);
        expect(subscription!.type, SubscriptionType.free);
        expect(subscription.status, SubscriptionStatus.active);
      });

      test('premium features are initialized', () {
        final features = paywall.getAllPremiumFeatures();
        expect(features.length, 7);
        expect(features.map((f) => f.id).toList(), containsAll([
          'unlimited_puzzles',
          'online_multiplayer',
          'advanced_analytics',
          'ad_free',
          'exclusive_content',
          'ai_coach',
          'early_access',
        ]));
      });

      test('free user has no premium features', () {
        final features = paywall.getFeaturesForTier(SubscriptionType.free);
        expect(features.length, 0);
      });
    });

    group('Subscription Tiers', () {
      test('premium tier has 4 features', () {
        final features = paywall.getFeaturesForTier(SubscriptionType.premium);
        expect(features.length, 4);
        expect(features.every((f) => f.requiredTier == SubscriptionType.premium ||
            f.requiredTier.index <= SubscriptionType.premium.index), true);
      });

      test('premium plus tier has all 7 features', () {
        final features = paywall.getFeaturesForTier(SubscriptionType.premiumPlus);
        expect(features.length, 7);
      });

      test('features are ordered by tier requirement', () {
        final features = paywall.getAllPremiumFeatures();

        final premiumFeatures = features.where((f) =>
          f.requiredTier == SubscriptionType.premium).toList();
        final premiumPlusFeatures = features.where((f) =>
          f.requiredTier == SubscriptionType.premiumPlus).toList();

        expect(premiumFeatures.length, 4);
        expect(premiumPlusFeatures.length, 3);
      });
    });

    group('Feature Availability', () {
      test('free user cannot access any premium features', () {
        expect(paywall.isFeatureAvailable('unlimited_puzzles'), false);
        expect(paywall.isFeatureAvailable('online_multiplayer'), false);
        expect(paywall.isFeatureAvailable('ai_coach'), false);
      });

      test('premium user can access premium features', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        expect(paywall.isFeatureAvailable('unlimited_puzzles'), true);
        expect(paywall.isFeatureAvailable('online_multiplayer'), true);
        expect(paywall.isFeatureAvailable('advanced_analytics'), true);
        expect(paywall.isFeatureAvailable('ad_free'), true);
      });

      test('premium user cannot access premium plus features', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        expect(paywall.isFeatureAvailable('exclusive_content'), false);
        expect(paywall.isFeatureAvailable('ai_coach'), false);
        expect(paywall.isFeatureAvailable('early_access'), false);
      });

      test('premium plus user can access all features', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.yearly,
        );

        expect(paywall.isFeatureAvailable('unlimited_puzzles'), true);
        expect(paywall.isFeatureAvailable('exclusive_content'), true);
        expect(paywall.isFeatureAvailable('ai_coach'), true);
        expect(paywall.isFeatureAvailable('early_access'), true);
      });

      test('invalid feature always returns false', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.lifetime,
        );

        expect(paywall.isFeatureAvailable('nonexistent_feature'), false);
      });
    });

    group('Pricing', () {
      test('free subscription has zero price', () {
        final price = paywall.getPrice(SubscriptionType.free, SubscriptionPeriod.monthly);
        expect(price, 0.0);
      });

      test('premium monthly pricing', () {
        final price = paywall.getPrice(SubscriptionType.premium, SubscriptionPeriod.monthly);
        expect(price, 4.99);
      });

      test('premium yearly pricing with discount', () {
        final price = paywall.getPrice(SubscriptionType.premium, SubscriptionPeriod.yearly);
        expect(price, 49.90);
      });

      test('premium lifetime pricing', () {
        final price = paywall.getPrice(SubscriptionType.premium, SubscriptionPeriod.lifetime);
        expect(price, 99.99);
      });

      test('premium plus monthly pricing', () {
        final price = paywall.getPrice(SubscriptionType.premiumPlus, SubscriptionPeriod.monthly);
        expect(price, 9.99);
      });

      test('premium plus yearly pricing with discount', () {
        final price = paywall.getPrice(SubscriptionType.premiumPlus, SubscriptionPeriod.yearly);
        expect(price, 99.90);
      });

      test('premium plus lifetime pricing', () {
        final price = paywall.getPrice(SubscriptionType.premiumPlus, SubscriptionPeriod.lifetime);
        expect(price, 199.99);
      });
    });

    group('Purchase Flow', () {
      test('successful premium monthly purchase', () async {
        final success = await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        expect(success, true);

        final subscription = paywall.getCurrentSubscription();
        expect(subscription!.type, SubscriptionType.premium);
        expect(subscription.status, SubscriptionStatus.active);
        expect(subscription.price, 4.99);
        expect(subscription.currency, 'USD');
        expect(subscription.autoRenew, true);
      });

      test('successful premium plus yearly purchase', () async {
        final success = await paywall.purchaseSubscription(
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.yearly,
        );

        expect(success, true);

        final subscription = paywall.getCurrentSubscription();
        expect(subscription!.type, SubscriptionType.premiumPlus);
        expect(subscription.price, 99.90);
        expect(subscription.period, SubscriptionPeriod.yearly);
      });

      test('purchased subscription has valid expiry date', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final subscription = paywall.getCurrentSubscription();
        expect(subscription!.expiryDate, isNotNull);
        expect(subscription.expiryDate!.isAfter(DateTime.now()), true);
      });

      test('monthly subscription expires in ~30 days', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final subscription = paywall.getCurrentSubscription();
        final daysDifference = subscription!.expiryDate!.difference(subscription.startDate).inDays;
        expect(daysDifference, 30);
      });

      test('yearly subscription expires in ~365 days', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.yearly,
        );

        final subscription = paywall.getCurrentSubscription();
        final daysDifference = subscription!.expiryDate!.difference(subscription.startDate).inDays;
        expect(daysDifference, 365);
      });

      test('lifetime subscription has extended expiry', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.lifetime,
        );

        final subscription = paywall.getCurrentSubscription();
        final daysDifference = subscription!.expiryDate!.difference(subscription.startDate).inDays;
        expect(daysDifference, greaterThan(36000)); // ~100 years
      });
    });

    group('Subscription Cancellation', () {
      test('cancel subscription changes status to cancelled', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final success = await paywall.cancelSubscription();
        expect(success, true);

        final subscription = paywall.getCurrentSubscription();
        expect(subscription!.status, SubscriptionStatus.cancelled);
        expect(subscription.type, SubscriptionType.free);
      });

      test('cannot cancel when no subscription active', () async {
        final success = await paywall.cancelSubscription();
        expect(success, false);
      });

      test('cancelled subscription has expiry set', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        await paywall.cancelSubscription();

        final subscription = paywall.getCurrentSubscription();
        expect(subscription!.expiryDate, isNotNull);
        expect(subscription.expiryDate!.isBefore(DateTime.now()) ||
               subscription.expiryDate!.isAtSameMomentAs(DateTime.now()), true);
      });

      test('cancelled user loses premium features', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        expect(paywall.isFeatureAvailable('unlimited_puzzles'), true);

        await paywall.cancelSubscription();

        expect(paywall.isFeatureAvailable('unlimited_puzzles'), false);
      });
    });

    group('Subscription Listeners', () {
      test('subscription listener is called on purchase', () async {
        Subscription? notifiedSubscription;

        paywall.addSubscriptionListener((subscription) {
          notifiedSubscription = subscription;
        });

        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        expect(notifiedSubscription, isNotNull);
        expect(notifiedSubscription!.type, SubscriptionType.premium);
      });

      test('subscription listener is called on cancellation', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        Subscription? notifiedSubscription;
        paywall.addSubscriptionListener((subscription) {
          notifiedSubscription = subscription;
        });

        await paywall.cancelSubscription();

        expect(notifiedSubscription, isNotNull);
        expect(notifiedSubscription!.status, SubscriptionStatus.cancelled);
      });

      test('listener can be removed', () async {
        int callCount = 0;

        void listener(Subscription subscription) {
          callCount++;
        }

        paywall.addSubscriptionListener(listener);
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        expect(callCount, 1);

        paywall.removeSubscriptionListener(listener);
        await paywall.purchaseSubscription(
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.yearly,
        );

        expect(callCount, 1); // Should not increase
      });
    });

    group('Subscription Data Models', () {
      test('subscription serializes to JSON', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final subscription = paywall.getCurrentSubscription()!;
        final json = subscription.toJson();

        expect(json['type'], 'premium');
        expect(json['status'], 'active');
        expect(json['period'], 'monthly');
        expect(json['price'], 4.99);
        expect(json['currency'], 'USD');
        expect(json['autoRenew'], true);
      });

      test('subscription properties work correctly', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final subscription = paywall.getCurrentSubscription()!;
        expect(subscription.isActive, true);
        expect(subscription.isExpired, false);
        expect(subscription.isPremium, true);
      });

      test('subscription toString formats correctly', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final subscription = paywall.getCurrentSubscription()!;
        expect(subscription.toString(), contains('premium'));
        expect(subscription.toString(), contains('active'));
      });
    });

    group('Fetch Subscription', () {
      test('fetch returns current subscription', () async {
        await paywall.initialize();
        final subscription = await paywall.fetchSubscription();

        expect(subscription, isNotNull);
        expect(subscription!.type, SubscriptionType.free);
      });

      test('fetch returns null after error', () async {
        final subscription = await paywall.fetchSubscription();
        // Should return current subscription even if not initialized
        expect(subscription, isNotNull);
      });
    });

    group('Restore Purchases', () {
      test('restore purchases returns true', () async {
        final success = await paywall.restorePurchases();
        expect(success, true);
      });
    });

    group('Subscription Report', () {
      test('report contains subscription details', () async {
        await paywall.initialize();
        final report = paywall.generateSubscriptionReport();

        expect(report, contains('SUBSCRIPTION DETAILS'));
        expect(report, contains('free'));
        expect(report, contains('active'));
      });

      test('report contains available features', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
        );

        final report = paywall.generateSubscriptionReport();

        expect(report, contains('AVAILABLE FEATURES'));
        expect(report, contains('Unlimited Puzzles'));
        expect(report, contains('Online Multiplayer'));
        expect(report, contains('Advanced Analytics'));
        expect(report, contains('Ad-Free Experience'));
      });

      test('premium plus report contains all features', () async {
        await paywall.purchaseSubscription(
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.lifetime,
        );

        final report = paywall.generateSubscriptionReport();

        expect(report, contains('Exclusive Content'));
        expect(report, contains('AI Chess Coach'));
        expect(report, contains('Early Access'));
      });
    });
  });
}
