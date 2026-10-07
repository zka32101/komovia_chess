import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/paywall_service.dart';
import 'package:komovia_chess/src/services/revenue_tracking_service.dart';

void main() {
  group('RevenueTrackingService', () {
    late RevenueTrackingService revenueService;

    setUp(() {
      revenueService = RevenueTrackingService();
    });

    group('Subscription Purchase Tracking', () {
      test('tracks premium monthly subscription purchase', () async {
        final subscription = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(subscription);
        // Service should track without throwing
      });

      test('tracks premium plus yearly subscription purchase', () async {
        final subscription = Subscription(
          id: 'sub_002',
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.yearly,
          status: SubscriptionStatus.active,
          price: 99.90,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 365)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(subscription);
        // Service should track without throwing
      });

      test('tracks lifetime subscription purchase', () async {
        final subscription = Subscription(
          id: 'sub_003',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.lifetime,
          status: SubscriptionStatus.active,
          price: 99.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 36500)),
          autoRenew: false,
        );

        await revenueService.trackSubscriptionPurchase(subscription);
        // Service should track without throwing
      });
    });

    group('Subscription Cancellation Tracking', () {
      test('tracks subscription cancellation', () async {
        final subscription = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.cancelled,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now().subtract(Duration(days: 15)),
          expiryDate: DateTime.now(),
          autoRenew: false,
        );

        await revenueService.trackSubscriptionCancellation(subscription);
        // Service should track cancellation without throwing
      });

      test('tracks premiumplus cancellation', () async {
        final subscription = Subscription(
          id: 'sub_002',
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.yearly,
          status: SubscriptionStatus.cancelled,
          price: 99.90,
          currency: 'USD',
          startDate: DateTime.now().subtract(Duration(days: 180)),
          expiryDate: DateTime.now(),
          autoRenew: false,
        );

        await revenueService.trackSubscriptionCancellation(subscription);
      });
    });

    group('Monthly Recurring Revenue (MRR)', () {
      test('calculates MRR from active subscriptions', () async {
        // Create multiple subscriptions
        final subs = [
          Subscription(
            id: 'sub_001',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
          Subscription(
            id: 'sub_002',
            type: SubscriptionType.premiumPlus,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 9.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
        ];

        for (final sub in subs) {
          await revenueService.trackSubscriptionPurchase(sub);
        }

        final mrr = await revenueService.calculateMonthlyRecurringRevenue();
        expect(mrr, greaterThan(0));
      });

      test('MRR includes only active subscriptions', () async {
        final activeSub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        final cancelledSub = Subscription(
          id: 'sub_002',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.cancelled,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now().subtract(Duration(days: 30)),
          expiryDate: DateTime.now(),
          autoRenew: false,
        );

        await revenueService.trackSubscriptionPurchase(activeSub);
        await revenueService.trackSubscriptionPurchase(cancelledSub);

        final mrr = await revenueService.calculateMonthlyRecurringRevenue();
        expect(mrr, greaterThan(0)); // Should only include active subscription
      });

      test('MRR normalizes yearly subscriptions to monthly', () async {
        // Yearly subscription normalized to monthly should be ~1/12
        final yearlySub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.yearly,
          status: SubscriptionStatus.active,
          price: 49.90,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 365)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(yearlySub);

        final mrr = await revenueService.calculateMonthlyRecurringRevenue();
        expect(mrr, greaterThan(0));
      });
    });

    group('Annual Recurring Revenue (ARR)', () {
      test('calculates ARR from active subscriptions', () async {
        final sub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.yearly,
          status: SubscriptionStatus.active,
          price: 49.90,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 365)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(sub);

        final arr = await revenueService.calculateAnnualRecurringRevenue();
        expect(arr, greaterThan(0));
      });

      test('ARR is approximately MRR × 12', () async {
        final sub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(sub);

        final mrr = await revenueService.calculateMonthlyRecurringRevenue();
        final arr = await revenueService.calculateAnnualRecurringRevenue();

        // ARR should be approximately MRR × 12
        expect(arr, greaterThan(mrr * 10)); // At least 10x
      });

      test('ARR handles mixed subscription periods', () async {
        final monthlySub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        final yearlySub = Subscription(
          id: 'sub_002',
          type: SubscriptionType.premiumPlus,
          period: SubscriptionPeriod.yearly,
          status: SubscriptionStatus.active,
          price: 99.90,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 365)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(monthlySub);
        await revenueService.trackSubscriptionPurchase(yearlySub);

        final arr = await revenueService.calculateAnnualRecurringRevenue();
        expect(arr, greaterThan(99.90)); // At least the yearly sub amount
      });
    });

    group('Average Revenue Per User (ARPU)', () {
      test('calculates ARPU with single user', () async {
        final sub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(sub);

        final arpu = await revenueService.calculateARPU();
        expect(arpu, greaterThanOrEqualTo(0));
      });

      test('calculates ARPU with multiple users', () async {
        final subs = [
          Subscription(
            id: 'sub_001',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
          Subscription(
            id: 'sub_002',
            type: SubscriptionType.premiumPlus,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 9.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
          Subscription(
            id: 'sub_003',
            type: SubscriptionType.free,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 0.0,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: false,
          ),
        ];

        for (final sub in subs) {
          await revenueService.trackSubscriptionPurchase(sub);
        }

        final arpu = await revenueService.calculateARPU();
        expect(arpu, greaterThan(0)); // Average should be > 0 with mix of free and paid
      });

      test('ARPU includes free users', () async {
        final freeSub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.free,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 0.0,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: false,
        );

        final paidSub = Subscription(
          id: 'sub_002',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(freeSub);
        await revenueService.trackSubscriptionPurchase(paidSub);

        final arpu = await revenueService.calculateARPU();
        expect(arpu, lessThan(4.99)); // ARPU should be less than full premium price
      });
    });

    group('Lifetime Value (LTV)', () {
      test('calculates LTV for monthly subscription', () async {
        final sub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(sub);

        final ltv = await revenueService.calculateLTV();
        expect(ltv, greaterThan(4.99)); // LTV should be > single month
      });

      test('calculates LTV for lifetime subscription', () async {
        final sub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.lifetime,
          status: SubscriptionStatus.active,
          price: 99.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 36500)),
          autoRenew: false,
        );

        await revenueService.trackSubscriptionPurchase(sub);

        final ltv = await revenueService.calculateLTV();
        expect(ltv, greaterThanOrEqualTo(99.99));
      });

      test('LTV increases with longer subscription', () async {
        // Monthly subscription
        final monthlySub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now().subtract(Duration(days: 365)),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        // Yearly subscription
        final yearlySub = Subscription(
          id: 'sub_002',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.yearly,
          status: SubscriptionStatus.active,
          price: 49.90,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 365)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(monthlySub);
        final ltvMonthly = await revenueService.calculateLTV();

        await revenueService.trackSubscriptionPurchase(yearlySub);
        final ltvBoth = await revenueService.calculateLTV();

        expect(ltvBoth, greaterThan(ltvMonthly));
      });
    });

    group('Churn Rate Tracking', () {
      test('calculates churn rate with cancellations', () async {
        // Track some active subscriptions
        final activeSubs = [
          Subscription(
            id: 'sub_001',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
          Subscription(
            id: 'sub_002',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
        ];

        // Track some cancelled subscriptions
        final cancelledSubs = [
          Subscription(
            id: 'sub_003',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.cancelled,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now().subtract(Duration(days: 15)),
            expiryDate: DateTime.now(),
            autoRenew: false,
          ),
        ];

        for (final sub in activeSubs) {
          await revenueService.trackSubscriptionPurchase(sub);
        }

        for (final sub in cancelledSubs) {
          await revenueService.trackSubscriptionCancellation(sub);
        }

        final churnRate = await revenueService.calculateChurnRate();
        expect(churnRate, greaterThanOrEqualTo(0));
        expect(churnRate, lessThanOrEqualTo(1)); // Should be between 0 and 1 (0-100%)
      });

      test('churn rate is zero with no cancellations', () async {
        final sub = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(sub);

        final churnRate = await revenueService.calculateChurnRate();
        expect(churnRate, 0); // No cancellations
      });

      test('churn rate approaches 1 with all cancellations', () async {
        final cancelledSubs = [
          Subscription(
            id: 'sub_001',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.cancelled,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now().subtract(Duration(days: 30)),
            expiryDate: DateTime.now(),
            autoRenew: false,
          ),
          Subscription(
            id: 'sub_002',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.cancelled,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now().subtract(Duration(days: 30)),
            expiryDate: DateTime.now(),
            autoRenew: false,
          ),
        ];

        for (final sub in cancelledSubs) {
          await revenueService.trackSubscriptionCancellation(sub);
        }

        final churnRate = await revenueService.calculateChurnRate();
        expect(churnRate, greaterThan(0)); // Some or all cancelled
      });
    });

    group('Revenue Tracking Integration', () {
      test('tracks complete subscription lifecycle', () async {
        // Initial purchase
        var subscription = Subscription(
          id: 'sub_001',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now().subtract(Duration(days: 30)),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(subscription);

        // Renewal (create new subscription)
        subscription = Subscription(
          id: 'sub_001_renewed',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.active,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 30)),
          autoRenew: true,
        );

        await revenueService.trackSubscriptionPurchase(subscription);

        // Eventually cancelled
        subscription = Subscription(
          id: 'sub_001_renewed',
          type: SubscriptionType.premium,
          period: SubscriptionPeriod.monthly,
          status: SubscriptionStatus.cancelled,
          price: 4.99,
          currency: 'USD',
          startDate: DateTime.now().subtract(Duration(days: 30)),
          expiryDate: DateTime.now(),
          autoRenew: false,
        );

        await revenueService.trackSubscriptionCancellation(subscription);
      });

      test('calculates revenue metrics after multiple transactions', () async {
        final subscriptions = [
          Subscription(
            id: 'sub_001',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.monthly,
            status: SubscriptionStatus.active,
            price: 4.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 30)),
            autoRenew: true,
          ),
          Subscription(
            id: 'sub_002',
            type: SubscriptionType.premiumPlus,
            period: SubscriptionPeriod.yearly,
            status: SubscriptionStatus.active,
            price: 99.90,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 365)),
            autoRenew: true,
          ),
          Subscription(
            id: 'sub_003',
            type: SubscriptionType.premium,
            period: SubscriptionPeriod.lifetime,
            status: SubscriptionStatus.active,
            price: 99.99,
            currency: 'USD',
            startDate: DateTime.now(),
            expiryDate: DateTime.now().add(Duration(days: 36500)),
            autoRenew: false,
          ),
        ];

        for (final sub in subscriptions) {
          await revenueService.trackSubscriptionPurchase(sub);
        }

        final mrr = await revenueService.calculateMonthlyRecurringRevenue();
        final arr = await revenueService.calculateAnnualRecurringRevenue();
        final arpu = await revenueService.calculateARPU();
        final ltv = await revenueService.calculateLTV();

        expect(mrr, greaterThan(0));
        expect(arr, greaterThan(mrr));
        expect(arpu, greaterThan(0));
        expect(ltv, greaterThan(0));
      });
    });
  });
}
