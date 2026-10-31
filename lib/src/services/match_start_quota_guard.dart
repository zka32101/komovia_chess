/// Consumes one free-tier daily online-game slot exactly once per
/// matchmaking attempt, and only once a match has actually been confirmed
/// and a game created.
///
/// Previously `MatchmakingScreen` consumed the slot as soon as the player
/// joined the queue, so cancelling, timing out, or simply never finding an
/// opponent still used up one of the day's free games.
class MatchStartQuotaGuard {
  MatchStartQuotaGuard(this._consume);

  final Future<void> Function() _consume;
  final Set<String> _consumedGameIds = {};

  /// Call when a queue entry reports a created game. Repeated calls for the
  /// same game (e.g. widget rebuilds from the queue stream) are ignored.
  Future<void> onMatchStarted(String gameId) async {
    if (!_consumedGameIds.add(gameId)) return;
    try {
      await _consume();
    } catch (_) {
      // Best-effort: a tracking failure must never block the game itself.
    }
  }

  bool hasConsumedFor(String gameId) => _consumedGameIds.contains(gameId);
}
