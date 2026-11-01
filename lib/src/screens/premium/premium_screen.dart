import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription.dart' show PremiumFeature;
import '../../providers/premium_provider.dart';
import '../../services/paywall_service.dart'
    show BillingPeriod, PaywallService, PurchaseUnavailableException;
import '../../utils/animations.dart';
import '../../widgets/premium/ai_analysis_upsell.dart';

/// A purchasable premium plan (mirrors the tiers [UserSubscription] supports)
class _PremiumPlan {
  const _PremiumPlan({
    required this.tier,
    required this.displayName,
  });
  final String tier;
  final String displayName;
}

const _proPlan = _PremiumPlan(tier: 'pro', displayName: 'Pro');
const _premiumPlan = _PremiumPlan(tier: 'premium', displayName: 'Premium');

/// Formats a yen amount with thousands separators, e.g. 2400 -> "¥2,400".
String _formatYen(int yen) {
  final digits = yen.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '¥$buf';
}

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _isLoading = false;
  BillingPeriod _period = BillingPeriod.monthly;

  Future<void> _handlePurchase(_PremiumPlan plan) async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(paywallServiceProvider);
      await service.purchaseSubscription(plan.tier, period: _period);

      if (mounted) {
        ref.invalidate(userSubscriptionProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${plan.displayName} purchase successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PurchaseUnavailableException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionStatus = ref.watch(userSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Features'),
        centerTitle: true,
        elevation: 0,
      ),
      body: subscriptionStatus.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
        data: (status) => SingleChildScrollView(
          child: Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '♟️ Upgrade to Premium',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unlock all features and enhance your chess experience',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    if (status.isPro || status.isPremium)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'Currently on ${status.isPremium ? _premiumPlan.displayName : _proPlan.displayName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Separately purchasable AI分析プラン (independent of Pro/Premium).
              const SizedBox(height: 16),
              const AiAnalysisPlanCard(),

              // Features section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Features',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...PremiumFeature.values.asMap().entries.map((entry) {
                      final index = entry.key;
                      final feature = entry.value;
                      return SlideInAnimation(
                        direction: SlideDirection.left,
                        delay: Duration(milliseconds: index * 80),
                        child: _buildFeatureItem(feature),
                      );
                    }),
                  ],
                ),
              ),

              // Pricing section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Plan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<BillingPeriod>(
                      segments: const [
                        ButtonSegment(
                          value: BillingPeriod.monthly,
                          label: Text('Monthly'),
                        ),
                        ButtonSegment(
                          value: BillingPeriod.annual,
                          label: Text('Annual'),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) =>
                          setState(() => _period = s.first),
                    ),
                    const SizedBox(height: 16),
                    _buildPricingCard(
                      plan: _proPlan,
                      isSelected: status.tier == _proPlan.tier,
                      onTap: () => _handlePurchase(_proPlan),
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),
                    _buildPricingCard(
                      plan: _premiumPlan,
                      isSelected: status.tier == _premiumPlan.tier,
                      onTap: () => _handlePurchase(_premiumPlan),
                      isLoading: _isLoading,
                      isPopular: true,
                    ),
                  ],
                ),
              ),

              // Info section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade300,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Subscription Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Renews automatically on your billing date\n'
                        '• Cancel anytime from settings\n'
                        '• 7-day free trial on first subscription\n'
                        '• Prices may vary by region',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Restore button
              if (!status.isPremium)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: TextButton(
                    onPressed: () async {
                      try {
                        final service = ref.read(paywallServiceProvider);
                        await service.restorePurchases();
                        ref.invalidate(userSubscriptionProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Purchases restored'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Restore failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Restore Purchases'),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(PremiumFeature feature) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildPricingCard({
    required _PremiumPlan plan,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLoading,
    bool isPopular = false,
  }) =>
      Stack(
        children: [
          if (isPopular)
            Positioned(
              top: -12,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isPopular ? Colors.blue.withOpacity(0.05) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatYen(
                          PaywallService.fallbackPriceYenByPeriod[_period]!,
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _period == BillingPeriod.annual ? '/year' : '/month',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : onTap,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isSelected ? 'Current Plan' : 'Subscribe Now',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
