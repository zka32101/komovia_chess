/// Curated practice starting positions for CPU games (CPUGameSelectionScreen),
/// letting a game begin from a representative midgame/endgame position
/// instead of always the standard starting array.
///
/// These are illustrative sample positions, not real recorded games - unlike
/// `JosekiScreen`/`OpeningExplorerScreen`, there's no existing in-app source
/// of real midgame/endgame positions to draw from (the app's own curated
/// `kifuLibrary` content is admin-only/`allow write: if false`, and nothing
/// seeds it with per-move data an endgame/midgame slice could be cut from).
/// A deeper version of this feature could instead cut a starting FEN out of
/// a `KifuLibrary` game at a chosen move - left for a later pass.
enum CpuStartingPosition {
  opening(
    '最初から',
    null,
    'Play a full game from the standard starting position.',
  ),
  midgame(
    '中盤から',
    'r1bq1rk1/ppp2ppp/2n2n2/2bpp3/2B1P3/3P1N2/PPP2PPP/RNBQ1RK1 w - - 0 8',
    'Jump into a representative middlegame position - practice tactics '
        'and planning without replaying an opening first.',
  ),
  endgame(
    '終盤から',
    '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1',
    'Start from a king-and-pawn endgame - practice converting a won '
        'endgame or defending a tough one.',
  );

  const CpuStartingPosition(this.displayName, this.fen, this.description);

  /// Shown to the player when picking a starting position.
  final String displayName;

  /// null for the standard starting array.
  final String? fen;

  /// Shown under the picker once this position is selected, so a
  /// player unfamiliar with "中盤から"/"終盤から" understands what
  /// they're actually choosing - previously the short card labels were
  /// the only explanation this feature got anywhere in the app.
  final String description;
}
