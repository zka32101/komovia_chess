import 'package:cloud_firestore/cloud_firestore.dart';

/// 進行中（未終局）のCPU対局のスナップショット。中断・再開機能専用。
///
/// komovia_go/komovia_shogiの`ActiveAiGame`/`ActiveShogiGame`と同じ設計
/// — 1ユーザーにつき同時に進行中のCPU対局は1つのみという前提で、
/// FirestoreのドキュメントIDは常に`uid`そのもの。
///
/// 盤面の最終FENだけではなく、指し手の履歴そのもの（UCI文字列のリスト）
/// を保存する — `zka32101/kouki-shogi`の`game_screen.dart`
/// `_saveGameSnapshot`/`_restoreGameSnapshot`が、クラッシュ復旧用に
/// 棋譜全体をJSONで保存し初期局面から打ち直して盤面を再構成している
/// のと同じ考え方（komovia_shogiのKIF棋譜保存とも同種）。これにより
/// 再開後も「待った」が通常の対局と同じだけ遡れる — 最終FENのみを
/// 保存する設計では、再開直後は「待った」できる手が一つも無い状態に
/// なってしまう。
class ActiveCpuGame {
  final String uid;

  /// 指し手の履歴。各要素はUCI形式（例: "e2e4"、プロモーションありなら
  /// "e7e8q"）— `chess_lib.Move.fromAlgebraic`/`toAlgebraic`/`promotion`
  /// から組み立てたもので、`CpuGameNotifier.makeAIMove`が
  /// `_chess.makeMoveUCI`へ渡す形式と同じ。[startingFen]からこの順で
  /// 打ち直すことで盤面を再構成する。
  final List<String> moveUcis;
  final String difficultyName;
  final bool playerIsWhite;

  /// 対局がカスタム開始局面（終盤練習など）から始まった場合のFEN。
  /// 通常の初形から始まった対局ではnull。
  final String? startingFen;
  final DateTime startTime;
  final DateTime? updatedAt;

  /// クイック対局（AIの着手を短い持ち時間で打ち切るモード）中だったか
  /// どうか。再開時も同じ体験になるよう復元する。
  final bool quickGame;

  ActiveCpuGame({
    required this.uid,
    required this.moveUcis,
    required this.difficultyName,
    required this.playerIsWhite,
    this.startingFen,
    required this.startTime,
    this.updatedAt,
    this.quickGame = false,
  });

  factory ActiveCpuGame.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawMoves = data['moveUcis'] as List<dynamic>?;
    return ActiveCpuGame(
      uid: doc.id,
      moveUcis: rawMoves != null
          ? rawMoves.map((m) => m as String).toList()
          : const [],
      difficultyName: data['difficultyName'] as String? ?? 'medium',
      playerIsWhite: data['playerIsWhite'] as bool? ?? true,
      startingFen: data['startingFen'] as String?,
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      quickGame: data['quickGame'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moveUcis': moveUcis,
      'difficultyName': difficultyName,
      'playerIsWhite': playerIsWhite,
      'startingFen': startingFen,
      'startTime': Timestamp.fromDate(startTime),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
      'quickGame': quickGame,
    };
  }
}
