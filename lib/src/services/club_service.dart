import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';

/// Create/browse/join/leave chess clubs, and read a club's member
/// leaderboard (sorted by each member's own `rating` field on
/// `users/{uid}`, the same rating CPU games already maintain).
class ClubService {
  ClubService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _collection = 'clubs';

  Future<Club> createClub({
    required String name,
    required String description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final docRef = _firestore.collection(_collection).doc();
    final club = Club(
      id: docRef.id,
      name: name,
      description: description,
      createdBy: user.uid,
      // The creator is always a member - matches
      // firestore.rules' create rule, which requires memberUids to be
      // exactly [creator] on the initial write.
      memberUids: [user.uid],
      createdAt: DateTime.now(),
    );
    await docRef.set(club.toJson());
    return club;
  }

  Future<Club?> getClub(String clubId) async {
    final doc = await _firestore.collection(_collection).doc(clubId).get();
    if (!doc.exists) return null;
    return Club.fromJson(doc.data()!);
  }

  /// Browse all clubs (newest first) - there's no per-club privacy model
  /// here, every club is publicly listable and joinable, same as this
  /// app's open-read leaderboard/ranking collections.
  Future<List<Club>> getAllClubs({int limit = 50}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => Club.fromJson(d.data())).toList();
  }

  /// Clubs the signed-in user is a member of.
  Future<List<Club>> getMyClubs() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await _firestore
        .collection(_collection)
        .where('memberUids', arrayContains: user.uid)
        .get();
    return snapshot.docs.map((d) => Club.fromJson(d.data())).toList();
  }

  Future<void> joinClub(String clubId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    await _firestore.collection(_collection).doc(clubId).update({
      'memberUids': FieldValue.arrayUnion([user.uid]),
    });
  }

  Future<void> leaveClub(String clubId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    await _firestore.collection(_collection).doc(clubId).update({
      'memberUids': FieldValue.arrayRemove([user.uid]),
    });
  }

  /// A club's members with their current rating, sorted highest-first -
  /// the club's own internal leaderboard. Firestore has no "fetch N docs
  /// by a list of ids, in one query" beyond a `whereIn` of up to 30 at a
  /// time, so a bigger club is paginated internally rather than failing
  /// outright.
  Future<List<ClubMember>> getClubMembers(List<String> memberUids) async {
    if (memberUids.isEmpty) return [];
    final members = <ClubMember>[];
    for (var i = 0; i < memberUids.length; i += 30) {
      final batch = memberUids.sublist(
        i,
        i + 30 > memberUids.length ? memberUids.length : i + 30,
      );
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      members.addAll(snapshot.docs.map((d) => ClubMember(
            uid: d.id,
            displayName: (d.data()['displayName'] as String?) ?? 'Player',
            rating: (d.data()['rating'] as num?)?.toInt() ?? 1500,
          )));
    }
    members.sort((a, b) => b.rating.compareTo(a.rating));
    return members;
  }
}
