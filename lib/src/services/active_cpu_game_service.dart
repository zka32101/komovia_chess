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
    final ref = _collection.doc(uid);
    // 対局画面から戻った直後は、直前の save/clear がまだサーバーに届いて
    // いない。キャッシュには未送信の書き込みも反映されているので、まず
    // キャッシュを読む（キャッシュに無いときだけサーバーへ）。
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await ref.get(const GetOptions(source: Source.cache));
    } catch (_) {
      doc = await ref.get();
    }
    if (!doc.exists) return null;
    return ActiveCpuGame.fromFirestore(doc);
  }

  Future<void> clear(String uid) {
    return _collection.doc(uid).delete();
  }
}
