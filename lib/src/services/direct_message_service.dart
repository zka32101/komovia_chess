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

    // Must be sorted the same way threadIdFor sorts them (and the same
    // way every previous write to this thread sorted them) - Firestore
    // rules' update guard requires
    // `request.resource.data.participantUids == resource.data.participantUids`,
    // an exact array comparison including order. Writing [fromUid, toUid]
    // in send order instead meant the thread's first reply (sent by the
    // other participant) always flipped the order relative to what was
    // already stored, so the merge-write was rejected with
    // permission-denied every time - the second person in any thread
    // could never actually reply.
    final participantUids = [fromUid, toUid]..sort();

    // A transaction (not a plain batch) because the sender's own
    // participantNames entry needs to stay fresh on every send while
    // never clobbering the recipient's entry with a possibly-stale name
    // the sender happens to have cached locally - that requires reading
    // the thread's current participantNames first. A prior version
    // unconditionally overwrote the whole map with {fromUid: ...,
    // toUid: ...} using whatever name the caller passed for each party,
    // so if the recipient had changed their display name since, every
    // message the sender sent before next seeing their fresh name kept
    // reverting it back to stale data in MessageThread.otherDisplayNameFor.
    await _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(threadRef);
      final existingNames =
          (existingSnapshot.data()?['participantNames'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {};

      // The thread document must be written BEFORE the message - the
      // messages/{messageId} create rule's threadParticipants() does
      // get(message_threads/{threadId}) to check the caller is a real
      // participant, and a transaction's rule evaluation for each write
      // only sees the effects of writes already applied earlier in that
      // same transaction. With the message written first (the previous
      // order here), the very first message of a brand-new thread always
      // saw a nonexistent thread doc - threadParticipants() returned null
      // and isParticipant(null) denied the whole transaction - so
      // starting a new conversation with someone never messaged before
      // failed with permission-denied every time; only replying in an
      // already-existing thread worked.
      transaction.set(
        threadRef,
        {
          'participantUids': participantUids,
          'participantNames': {
            ...existingNames,
            // Always refresh the sender's own entry - it's never stale,
            // since it's the sender's own current name.
            fromUid: fromDisplayName,
            // Bootstrap the recipient's entry only if the thread has
            // never recorded one at all (e.g. this is the very first
            // message) - once set, only the recipient's own sends ever
            // refresh it, so a stale cached name here can never clobber
            // a fresher one already on the thread.
            if (!existingNames.containsKey(toUid)) toUid: toDisplayName,
          },
          'lastMessage': trimmed,
          'lastMessageAt': Timestamp.fromDate(now),
          'lastSenderUid': fromUid,
          // A nested map, NOT the 'unreadCount.<toUid>' dot-path key this
          // used to be: dot notation is only interpreted as a field path by
          // update(), while set() (merge or not) stores it as a literal
          // top-level field literally named "unreadCount.<uid>". The real
          // unreadCount map was therefore never incremented (the unread
          // badge never moved), and firestore.rules' send branch - which
          // requires the recipient's unreadCount entry to rise by exactly 1
          // and only lists 'unreadCount' among the changeable keys -
          // rejected every reply in an already-existing thread. A merge
          // set deep-merges nested maps, so only toUid's entry is touched.
          'unreadCount': {toUid: FieldValue.increment(1)},
        },
        SetOptions(merge: true),
      );

      transaction.set(messageRef, {
        'fromUid': fromUid,
        'content': trimmed,
        'sentAt': Timestamp.fromDate(now),
      });
    });
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
