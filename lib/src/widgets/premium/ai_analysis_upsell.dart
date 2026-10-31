import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/premium_provider.dart';
import '../../services/feature_gating_service.dart';
import '../../services/paywall_service.dart' show PurchaseUnavailableException;

/// Starts the AI分析プラン purchase and reports the outcome via SnackBar.
/// Returns true when the purchase completed.
Future<bool> purchaseAiAnalysisPlan(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(paywallServiceProvider).purchaseAiAnalysisPlan();
    ref.invalidate(aiAnalysisPlanActiveProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.aiAnalysisPurchaseSuccess)),
    );
    return true;
  } on PurchaseUnavailableException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.aiAnalysisUnavailable)));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.aiAnalysisPurchaseFailed(e.toString()))),
    );
  }
  return false;
}

/// Upsell shown when the free daily AI-analysis quota is used up.
Future<void> showAiAnalysisUpsellDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (_) => const AiAnalysisUpsellDialog(),
    );

class AiAnalysisUpsellDialog extends ConsumerWidget {
  const AiAnalysisUpsellDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final limit = FeatureGatingService
        .DAILY_LIMITS[FeatureGatingService.AI_ANALYSIS_ACTION]!;
    return AlertDialog(
      title: Text(l10n.aiAnalysisLimitTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.aiAnalysisLimitMessage(limit)),
          const SizedBox(height: 12),
          Text(
            '${l10n.aiAnalysisPlanName} - ${l10n.aiAnalysisPlanPrice}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.aiAnalysisLater),
        ),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final ok = await purchaseAiAnalysisPlan(context, ref);
            if (ok) navigator.pop();
          },
          child: Text(l10n.aiAnalysisSubscribeButton),
        ),
      ],
    );
  }
}

/// Card for PremiumScreen offering the separate AI分析プラン.
class AiAnalysisPlanCard extends ConsumerWidget {
  const AiAnalysisPlanCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(aiAnalysisPlanActiveProvider).valueOrNull ?? false;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_graph),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aiAnalysisPlanName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(l10n.aiAnalysisPlanPrice),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.aiAnalysisPlanDescription),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: active
                  ? Text(
                      l10n.aiAnalysisPlanActive,
                      style: const TextStyle(color: Colors.green),
                    )
                  : FilledButton(
                      onPressed: () => purchaseAiAnalysisPlan(context, ref),
                      child: Text(l10n.aiAnalysisSubscribeButton),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
