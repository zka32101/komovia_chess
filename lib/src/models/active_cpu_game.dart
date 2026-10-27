import 'package:cloud_firestore/cloud_firestore.dart';

/// 進行中（未終局）のCPU対局のスナップショット。中断・再開機能専用。
///
/// komovia_go/komovia_shogiの`ActiveAiGame`/`ActiveShogiGame`と同じ設計
/// — 1ユーザーにつき同時に進行中のCPU対局は1つのみという前提で、
/// FirestoreのドキュメントIDは常に`uid`そのもの。チェスは`chess`パッケージ
/// が標準でFEN（現在の盤面）のエクスポート/読み込みをサポートしている
/// ため、将棋のKIF棋譜のような独自の指し手再生は不要 — 現在のFENだけ
/// あれば盤面をそのまま復元できる。ただし指し手の履歴そのもの
/// （`chess_lib.Move`のリスト）はFENからは復元できないため、再開直後は
/// 「待った」の対象になる手がまだ無い状態になる（将棋版の、ハンディ
/// キャップ付き対局での「待った」の制約と同種のトレードオフ）。
class ActiveCpuGame {
  final String uid;
  final String fen;
  final String difficultyName;
  final bool playerIsWhite;

  /// 対局がカスタム開始局面（終盤練習など）から始まった場合のFEN。
  /// 通常の初形から始まった対局ではnull。
  final String? startingFen;
  final DateTime startTime;
  final DateTime? updatedAt;

  ActiveCpuGame({
    required this.uid,
    required this.fen,
    required this.difficultyName,
    required this.playerIsWhite,
    this.startingFen,
    required this.startTime,
    this.updatedAt,
  });

  factory ActiveCpuGame.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ActiveCpuGame(
      uid: doc.id,
      fen: data['fen'] as String? ?? '',
      difficultyName: data['difficultyName'] as String? ?? 'medium',
      playerIsWhite: data['playerIsWhite'] as bool? ?? true,
      startingFen: data['startingFen'] as String?,
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fen': fen,
      'difficultyName': difficultyName,
      'playerIsWhite': playerIsWhite,
      'startingFen': startingFen,
      'startTime': Timestamp.fromDate(startTime),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}
