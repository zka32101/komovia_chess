import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/paywall_service.dart';

void main() {
  group('PaywallService product ids', () {
    test('each tier has a monthly and an annual product', () {
      expect(PaywallService.productIdFor('pro', BillingPeriod.monthly),
          'chess_pro_monthly');
      expect(PaywallService.productIdFor('pro', BillingPeriod.annual),
          'chess_pro_annual');
      expect(PaywallService.productIdFor('premium', BillingPeriod.monthly),
          'chess_premium_monthly');
      expect(PaywallService.productIdFor('premium', BillingPeriod.annual),
          'chess_premium_annual');
      expect(PaywallService.productIdFor('free', BillingPeriod.monthly),
          isNull);
      expect(PaywallService.allSubscriptionProductIds, hasLength(4));
    });

    test('reverse lookup resolves tier and period', () {
      final plan = PaywallService.planForProductId('chess_premium_annual');
      expect(plan?.tier, 'premium');
      expect(plan?.period, BillingPeriod.annual);
      expect(PaywallService.planForProductId('chess_ai_analysis_monthly'),
          isNull);
    });
  });

  group('Fallback prices', () {
    test('pro/premium unified at 300/month, 2400/year', () {
      expect(PaywallService.fallbackPriceYenByPeriod[BillingPeriod.monthly],
          300);
      expect(PaywallService.fallbackPriceYenByPeriod[BillingPeriod.annual],
          2400);
    });

    test('AI analysis plan is 990/month', () {
      expect(PaywallService.aiAnalysisPlanMonthlyFallbackPriceYen, 990);
    });

    test('entitlement length follows billing period', () {
      expect(BillingPeriod.monthly.entitlementLength.inDays, 30);
      expect(BillingPeriod.annual.entitlementLength.inDays, 365);
    });
  });
}
