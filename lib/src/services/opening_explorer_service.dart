import 'package:cloud_firestore/cloud_firestore.dart';

/// A single match's move list and the signed-in player's own result
/// perspective ('win'/'loss'/'draw'), read straight off the raw
/// `match_history/{playerId}/matches/{matchId}` document - the `movesUci`
/// field isn't a declared field on `MatchRecord` (see
/// `MatchHistoryService.recordMatch`'s doc comment for why), so this
/// bypasses `MatchRecord.fromJson` entirely.
class OpeningGameMoves {
  OpeningGameMoves({required this.result, required this.moves});
  final String result; // 'win', 'loss', 'draw'
  final List<Map<String, String?>> moves; // [{'from','to','promotion'}, ...]
}

/// Aggregate stats for one candidate next move from a given position in
/// the opening explorer - how many of the player's own past games
/// continued with this move from here, and how those games turned out.
class OpeningMoveStat {
  OpeningMoveStat({
    required this.move,
    required this.games,
    required this.wins,
    required this.draws,
    required this.losses,
  });
  final String move; // e.g. 'e2e4'
  final int games;
  final int wins;
  final int draws;
  final int losses;

  double get winRate => games == 0 ? 0 : wins / games;
}

/// Builds personal (not global/masters-database) opening statistics from
/// the signed-in player's own completed games. A true cross-player
/// "millions of master games" explorer (lichess's Masters/Lichess-games
/// database style) isn't buildable here: firestore.rules' `games/{gameId}`
/// read rule only allows a completed game's own two participants to read
/// it, so there's no way for a client to query across every user's
/// finished games at all - that would need a new Cloud Function
/// aggregation job, a materially larger undertaking than this personal
/// variant.
class OpeningExplorerService {
  OpeningExplorerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// Fetches every one of [playerId]'s recorded matches that actually has
  /// a `movesUci` move list (games recorded before this feature existed,
  /// or any future match-recording path that doesn't pass `moves`, are
  /// silently skipped rather than treated as a data error).
  Future<List<OpeningGameMoves>> getUserOpeningGames(String playerId) async {
    final snapshot = await _firestore
        .collection('match_history')
        .doc(playerId)
        .collection('matches')
        .get();

    final games = <OpeningGameMoves>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawMoves = data['movesUci'] as List?;
      if (rawMoves == null) continue;

      final moves = rawMoves
          .cast<Map<String, dynamic>>()
          .map((m) => {
                'from': m['from'] as String?,
                'to': m['to'] as String?,
                'promotion': m['promotion'] as String?,
              })
          .toList();
      final result = data['result'] as String? ?? 'draw';
      games.add(OpeningGameMoves(result: result, moves: moves));
    }
    return games;
  }

  /// Candidate next moves from the position reached after [path] (a
  /// sequence of 'fromto' tokens, e.g. `['e2e4', 'e7e5']`), aggregated
  /// across every game in [games] whose own move list has [path] as a
  /// prefix. Sorted by game count descending, matching a real opening
  /// explorer's convention of showing the most-played continuations
  /// first.
  List<OpeningMoveStat> getCandidateMoves(
    List<OpeningGameMoves> games,
    List<String> path,
  ) {
    final byMove = <String, _MutableStat>{};

    for (final game in games) {
      if (game.moves.length <= path.length) continue;

      var matchesPath = true;
      for (var i = 0; i < path.length; i++) {
        final move = game.moves[i];
        if (_moveToken(move) != path[i]) {
          matchesPath = false;
          break;
        }
      }
      if (!matchesPath) continue;

      final nextMove = game.moves[path.length];
      final token = _moveToken(nextMove);
      final stat = byMove.putIfAbsent(token, () => _MutableStat());
      stat.games++;
      switch (game.result) {
        case 'win':
          stat.wins++;
          break;
        case 'loss':
          stat.losses++;
          break;
        default:
          stat.draws++;
      }
    }

    final result = byMove.entries
        .map((e) => OpeningMoveStat(
              move: e.key,
              games: e.value.games,
              wins: e.value.wins,
              draws: e.value.draws,
              losses: e.value.losses,
            ))
        .toList()
      ..sort((a, b) => b.games.compareTo(a.games));
    return result;
  }

  String _moveToken(Map<String, String?> move) {
    final from = move['from'] ?? '';
    final to = move['to'] ?? '';
    final promotion = move['promotion'];
    return promotion == null ? '$from$to' : '$from$to=$promotion';
  }
}

class _MutableStat {
  int games = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
}
