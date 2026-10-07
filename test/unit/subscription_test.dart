import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Subscription Tests', () {
    group('Feature Access', () {
      const freeFeatures = <String>[];
      const premiumFeatures = <String>[
        'unlimited_puzzles',
        'custom_board',
        'no_ads',
        'offline_play',
      ];
      const eliteFeatures = <String>[
        'unlimited_puzzles',
        'custom_board',
        'game_analysis',
        'no_ads',
        'offline_play',
        'cloud_sync',
        'opening_books',
        'endgame_tablebases',
      ];

      test('Free tier has no premium features', () {
        final hasFeature = (feature) => freeFeatures.contains(feature);

        expect(hasFeature('unlimited_puzzles'), false);
        expect(hasFeature('no_ads'), false);
      });

      test('Premium tier has premium features', () {
        final hasFeature = (feature) => premiumFeatures.contains(feature);

        expect(hasFeature('unlimited_puzzles'), true);
        expect(hasFeature('custom_board'), true);
        expect(hasFeature('no_ads'), true);
        expect(hasFeature('offline_play'), true);
        expect(hasFeature('game_analysis'), false);
      });

      test('Elite tier has all features', () {
        final hasFeature = (feature) => eliteFeatures.contains(feature);

        expect(hasFeature('unlimited_puzzles'), true);
        expect(hasFeature('game_analysis'), true);
        expect(hasFeature('cloud_sync'), true);
        expect(hasFeature('endgame_tablebases'), true);
      });
    });

    group('Subscription Status', () {
      bool isSubscriptionActive(String status, DateTime? expiresAt) {
        if (status != 'active') return false;
        if (expiresAt == null) return false;
        return expiresAt.isAfter(DateTime.now());
      }

      test('Active subscription before expiry', () {
        final futureDate = DateTime.now().add(Duration(days: 30));
        final isActive = isSubscriptionActive('active', futureDate);

        expect(isActive, true);
      });

      test('Expired subscription', () {
        final pastDate = DateTime.now().subtract(Duration(days: 1));
        final isActive = isSubscriptionActive('active', pastDate);

        expect(isActive, false);
      });

      test('Cancelled subscription', () {
        final futureDate = DateTime.now().add(Duration(days: 30));
        final isActive = isSubscriptionActive('cancelled', futureDate);

        expect(isActive, false);
      });
    });

    group('Days Remaining', () {
      int? daysRemaining(DateTime? expiresAt) {
        if (expiresAt == null) return null;
        return expiresAt.difference(DateTime.now()).inDays;
      }

      test('30 days remaining', () {
        final futureDate = DateTime.now().add(Duration(days: 30));
        final days = daysRemaining(futureDate);

        expect(days, 30);
      });

      test('0 days remaining (expires today)', () {
        final today = DateTime.now();
        final days = daysRemaining(today);

        expect(days, 0);
      });

      test('Negative days (already expired)', () {
        final pastDate = DateTime.now().subtract(Duration(days: 1));
        final days = daysRemaining(pastDate);

        expect(days, lessThan(0));
      });
    });

    group('Tier Pricing', () {
      Map<String, double> getTierPricing() {
        return {
          'free': 0.0,
          'premium_monthly': 4.99,
          'premium_annual': 39.99,
          'elite_monthly': 9.99,
        };
      }

      test('Free tier is \$0', () {
        final pricing = getTierPricing();
        expect(pricing['free'], 0.0);
      });

      test('Premium monthly is \$4.99', () {
        final pricing = getTierPricing();
        expect(pricing['premium_monthly'], 4.99);
      });

      test('Annual subscription saves money', () {
        final pricing = getTierPricing();
        final monthlyAnnual = 4.99 * 12;
        final annualPrice = pricing['premium_annual']!;

        expect(annualPrice, lessThan(monthlyAnnual));
      });
    });
  });
}
