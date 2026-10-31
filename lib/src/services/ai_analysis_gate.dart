/// Outcome of asking whether the user may run one AI post-game analysis.
enum AiAnalysisAccess {
  /// The AI分析プラン is active - unlimited, nothing consumed.
  unlimited,

  /// Allowed by the free daily quota; one slot has been consumed.
  quota,

  /// Free daily quota exhausted and no AI分析プラン - show the upsell.
  blocked,
}

/// Gate for this app's AI post-game analysis (ChessAnalysisService's
/// move-by-move evaluation, MoveCommentaryService commentary and
/// WeaknessAnalysisService aggregation), checked at the two user-facing
/// triggers: GameAnalysisScreen and OneTapWeaknessButton.
///
/// Order: (1) an active AI分析プラン allows unconditionally; (2) otherwise
/// FeatureGatingService's existing daily-quota pattern
/// (users/{uid}/daily_limits/{yyyy-MM-dd}, key
/// [FeatureGatingService.AI_ANALYSIS_ACTION], 3/day, resets at local
/// midnight) is checked and consumed; (3) otherwise blocked.
///
/// The three dependencies are injected so the decision logic is unit
/// testable without Firebase - see aiAnalysisGateProvider for the real
/// wiring.
class AiAnalysisGate {
  AiAnalysisGate({
    required this.hasAiAnalysisPlan,
    required this.remainingFreeAnalyses,
    required this.consumeFreeAnalysis,
  });

  final Future<bool> Function() hasAiAnalysisPlan;
  final Future<int> Function() remainingFreeAnalyses;
  final Future<void> Function() consumeFreeAnalysis;

  Future<AiAnalysisAccess> tryAcquire() async {
    if (await hasAiAnalysisPlan()) return AiAnalysisAccess.unlimited;
    if (await remainingFreeAnalyses() <= 0) return AiAnalysisAccess.blocked;
    await consumeFreeAnalysis();
    return AiAnalysisAccess.quota;
  }
}
