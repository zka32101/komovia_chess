import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/ai_analysis_gate.dart';
import 'package:komovia_chess/src/services/feature_gating_service.dart';

void main() {
  group('FeatureGatingService ai_analysis quota', () {
    test('free daily limit is 3', () {
      expect(FeatureGatingService.AI_ANALYSIS_ACTION, 'ai_analysis');
      expect(
        FeatureGatingService
            .DAILY_LIMITS[FeatureGatingService.AI_ANALYSIS_ACTION],
        3,
      );
    });
  });

  group('AiAnalysisGate', () {
    AiAnalysisGate gate({
      required bool plan,
      required int Function() remaining,
      required void Function() consume,
    }) =>
        AiAnalysisGate(
          hasAiAnalysisPlan: () async => plan,
          remainingFreeAnalyses: () async => remaining(),
          consumeFreeAnalysis: () async => consume(),
        );

    test('AI分析プラン holder is unlimited and consumes nothing', () async {
      var consumed = 0;
      final g = gate(plan: true, remaining: () => 0, consume: () => consumed++);
      for (var i = 0; i < 10; i++) {
        expect(await g.tryAcquire(), AiAnalysisAccess.unlimited);
      }
      expect(consumed, 0);
    });

    test('free user gets 3 per day then is blocked', () async {
      var used = 0;
      final g = gate(
        plan: false,
        remaining: () => (3 - used).clamp(0, 3),
        consume: () => used++,
      );
      expect(await g.tryAcquire(), AiAnalysisAccess.quota);
      expect(await g.tryAcquire(), AiAnalysisAccess.quota);
      expect(await g.tryAcquire(), AiAnalysisAccess.quota);
      expect(await g.tryAcquire(), AiAnalysisAccess.blocked);
      expect(used, 3);
    });

    test('blocked does not consume', () async {
      var consumed = 0;
      final g = gate(plan: false, remaining: () => 0, consume: () => consumed++);
      expect(await g.tryAcquire(), AiAnalysisAccess.blocked);
      expect(consumed, 0);
    });
  });
}
