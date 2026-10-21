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
  opening('最初から', null),
  midgame(
    '中盤から',
    'r1bq1rk1/ppp2ppp/2n2n2/2bpp3/2B1P3/3P1N2/PPP2PPP/RNBQ1RK1 w - - 0 8',
  ),
  endgame(
    '終盤から',
    '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1',
  );

  const CpuStartingPosition(this.displayName, this.fen);

  /// Shown to the player when picking a starting position.
  final String displayName;

  /// null for the standard starting array.
  final String? fen;
}
