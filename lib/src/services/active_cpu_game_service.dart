import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/active_cpu_game.dart';

/// 進行中CPU対局のFirestore CRUD（komovia_go/komovia_shogiの
/// `ActiveAiGameService`/`ActiveShogiGameService`と同じ役割）。ドキュメント
/// IDは常に`uid`なので、「進行中の対局があるか」の判定は一覧クエリなしで
/// 単純な`doc(uid).get()`だけで済む。
class ActiveCpuGameService {
  ActiveCpuGameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('active_cpu_games');

  Future<void> save(ActiveCpuGame game) {
    return _collection.doc(game.uid).set(game.toFirestore());
  }

  Future<ActiveCpuGame?> getActive(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return ActiveCpuGame.fromFirestore(doc);
  }

  Future<void> clear(String uid) {
    return _collection.doc(uid).delete();
  }
}
