import 'package:cloud_firestore/cloud_firestore.dart';

class GameSharingService {
  factory GameSharingService() => _instance;

  GameSharingService._internal();
  static final GameSharingService _instance = GameSharingService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SharedGameLink> createShareableLink(String gameId) async {
    try {
      final shortCode = _generateShortCode();
      final expiresAt = DateTime.now().add(const Duration(days: 30));

      await _firestore
          .collection('shared_games')
          .doc('links')
          .collection('active')
          .doc(shortCode)
          .set({
        'gameId': gameId,
        'shortCode': shortCode,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return SharedGameLink(
        gameId: gameId,
        shortCode: shortCode,
        fullUrl: 'https://chesstacticsmaster.app/game/$shortCode',
        expiresAt: expiresAt,
        isPublic: true,
      );
    } catch (e) {
      print('Error creating shareable link: $e');
      rethrow;
    }
  }

  Future<void> shareGameWithFriends(
      String gameId, List<String> friendIds) async {
    try {
      for (final friendId in friendIds) {
        await _firestore
            .collection('shared_games')
            .doc('friend_shares')
            .collection(friendId)
            .add({
          'gameId': gameId,
          'sharedAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      print('Error sharing game with friends: $e');
    }
  }

  Future<List<SharedGame>> getPublicGames(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('shared_games')
          .doc('games')
          .collection('public')
          .orderBy('sharedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SharedGame.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching public games: $e');
      return [];
    }
  }

  Future<String> generateEmbedCode(String gameId) async {
    final embedCode = '''
<iframe 
  src="https://chesstacticsmaster.app/embed/game/$gameId" 
  width="600" 
  height="400" 
  frameborder="0"
></iframe>
''';
    return embedCode;
  }

  Future<GameViewerData> getGameViewerData(String gameId) async {
    try {
      final gameDoc = await _firestore
          .collection('shared_games')
          .doc('games')
          .collection('all')
          .doc(gameId)
          .get();

      final commentsSnapshot = await _firestore
          .collection('shared_games')
          .doc('comments')
          .collection(gameId)
          .orderBy('createdAt', descending: false)
          .get();

      return GameViewerData(
        gameId: gameId,
        pgn: gameDoc['pgn'] ?? '',
        analysis: gameDoc['analysis'],
        comments: commentsSnapshot.docs
            .map((doc) => GameComment.fromJson(doc.data()))
            .toList(),
        viewCount: gameDoc['viewCount'] ?? 0,
        sharedAt: gameDoc['sharedAt'] != null
            ? (gameDoc['sharedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      print('Error fetching game viewer data: $e');
      rethrow;
    }
  }

  String _generateShortCode() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String result = '';
    for (int i = 0; i < 8; i++) {
      result +=
          chars[(DateTime.now().millisecondsSinceEpoch + i) % chars.length];
    }
    return result;
  }
}

class SharedGame {
  SharedGame({
    required this.gameId,
    required this.sharedBy,
    required this.title,
    required this.pgn,
    required this.tags,
    required this.viewCount,
    required this.sharedAt,
    this.analysis,
  });

  factory SharedGame.fromJson(Map<String, dynamic> json) => SharedGame(
        gameId: json['gameId'] ?? '',
        sharedBy: json['sharedBy'] ?? '',
        title: json['title'] ?? '',
        pgn: json['pgn'] ?? '',
        analysis: json['analysis'],
        tags: List<String>.from(json['tags'] ?? []),
        viewCount: json['viewCount'] ?? 0,
        sharedAt: json['sharedAt'] != null
            ? (json['sharedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String gameId;
  final String sharedBy;
  final String title;
  final String pgn;
  final List<dynamic>? analysis;
  final List<String> tags;
  final int viewCount;
  final DateTime sharedAt;
}

class SharedGameLink {
  SharedGameLink({
    required this.gameId,
    required this.shortCode,
    required this.fullUrl,
    required this.expiresAt,
    required this.isPublic,
  });
  final String gameId;
  final String shortCode;
  final String fullUrl;
  final DateTime expiresAt;
  final bool isPublic;
}

class GameComment {
  GameComment({
    required this.commentId,
    required this.userId,
    required this.username,
    required this.content,
    required this.moveNumber,
    required this.createdAt,
    required this.likes,
  });

  factory GameComment.fromJson(Map<String, dynamic> json) => GameComment(
        commentId: json['commentId'] ?? '',
        userId: json['userId'] ?? '',
        username: json['username'] ?? '',
        content: json['content'] ?? '',
        moveNumber: json['moveNumber'] ?? 0,
        createdAt: json['createdAt'] != null
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        likes: List<String>.from(json['likes'] ?? []),
      );
  final String commentId;
  final String userId;
  final String username;
  final String content;
  final int moveNumber;
  final DateTime createdAt;
  final List<String> likes;
}

class GameViewerData {
  GameViewerData({
    required this.gameId,
    required this.pgn,
    required this.comments,
    required this.viewCount,
    required this.sharedAt,
    this.analysis,
  });
  final String gameId;
  final String pgn;
  final dynamic analysis;
  final List<GameComment> comments;
  final int viewCount;
  final DateTime sharedAt;
}
