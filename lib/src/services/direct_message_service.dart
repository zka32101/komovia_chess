import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';
import 'firestore_time.dart';

/// `MessageThread`/`DirectMessage` have no storage dependency (see
/// komovia_core's own doc comments) — converting to/from Firestore's
/// `DocumentSnapshot`/`Timestamp` is this service's own responsibility,
/// the same split every other komovia_core-backed service in this app
/// (`friend_service.dart`, `tournament_service.dart`) already uses.
MessageThread _threadFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return MessageThread.fromJson({
    ...data,
    'id': doc.id,
    'lastMessageAt': isoFromTimestamp(data['lastMessageAt']),
  });
}

DirectMessage _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return DirectMessage.fromJson({
    ...data,
    'id': doc.id,
    'sentAt': isoFromTimestamp(data['sentAt']),
  });
}

/// 1対1のフレンド間メッセージング。他のkomoviaファミリー（komovia_go）と
/// 同じFirestoreスキーマ・衝突回避方式を使う。
class DirectMessageService {
  DirectMessageService(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection('message_threads');

  /// 2者のuidをソートして連結した決定的なthreadId。どちらが先に送信して
  /// もスレッドが重複して作られない。
  static String threadIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    // FriendService.blockFriend mirrors a block onto both sides' own
    // `friends` entries, so checking only the sender's own (readable)
    // entry is enough to catch a block placed by either party.
    final relationship = await _firestore
        .collection('users')
        .doc(fromUid)
        .collection('friends')
        .doc(toUid)
        .get();
    if (relationship.data()?['status'] == 'blocked') {
      debugPrint('sendMessage refused: $fromUid/$toUid have a blocked relationship');
      return;
    }

    final threadId = threadIdFor(fromUid, toUid);
    final threadRef = _threads.doc(threadId);
    final messageRef = threadRef.collection('messages').doc();

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.set(messageRef, {
      'fromUid': fromUid,
      'content': trimmed,
      'sentAt': Timestamp.fromDate(now),
    });

    batch.set(
      threadRef,
      {
        'participantUids': [fromUid, toUid],
        'participantNames': {fromUid: fromDisplayName, toUid: toDisplayName},
        'lastMessage': trimmed,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastSenderUid': fromUid,
        'unreadCount.$toUid': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Stream<List<MessageThread>> watchThreadsForUser(String uid) {
    return _threads
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_threadFromDoc).toList());
  }

  Stream<List<DirectMessage>> watchMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_messageFromDoc).toList());
  }

  /// [uid]がこのスレッドを開いた際に未読数をリセットする。一度もメッセ
  /// ージを送っていない相手を開いた場合でも呼ばれるため、スレッドがまだ
  /// 存在しないケースは何もせず戻る（setでmerge書き込みすると、メッセー
  /// ジが無いのに空のスレッドが作られ、受信箱に空の会話が表示されてしま
  /// う）。
  Future<void> markThreadRead({required String threadId, required String uid}) async {
    final ref = _threads.doc(threadId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    await ref.update({'unreadCount.$uid': 0});
  }
}
