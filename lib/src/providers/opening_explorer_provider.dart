import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/opening_explorer_service.dart';

final openingExplorerServiceProvider =
    Provider<OpeningExplorerService>((ref) => OpeningExplorerService());

/// Every one of [playerId]'s recorded matches that carries a move list -
/// see OpeningExplorerService's own doc comment for why this is a
/// personal (not global) opening explorer.
final userOpeningGamesProvider =
    FutureProvider.family<List<OpeningGameMoves>, String>((ref, playerId) {
  final service = ref.watch(openingExplorerServiceProvider);
  return service.getUserOpeningGames(playerId);
});
