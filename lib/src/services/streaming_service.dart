import 'package:cloud_firestore/cloud_firestore.dart';

class StreamingService {
  factory StreamingService() => _instance;
  StreamingService._internal();
  static final StreamingService _instance = StreamingService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> linkTwitchAccount(String userId, String twitchUsername) async {
    await _firestore.collection('streaming').doc(userId).set({
      'twitchUsername': twitchUsername,
      'twitchLinked': true,
      'linkedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> linkYoutubeChannel(
      String userId, String youtubeChannelId) async {
    await _firestore.collection('streaming').doc(userId).set({
      'youtubeChannelId': youtubeChannelId,
      'youtubeLinked': true,
      'linkedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<LiveStream>> getLiveStreams() async {
    final snapshot = await _firestore
        .collection('streams')
        .where('isLive', isEqualTo: true)
        .get();
    return snapshot.docs.map((d) => LiveStream.fromJson(d.data())).toList();
  }

  Future<void> startStream(
      String userId, String title, String description) async {
    await _firestore.collection('streams').add({
      'userId': userId,
      'title': title,
      'description': description,
      'isLive': true,
      'viewerCount': 0,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endStream(String streamId) async {
    await _firestore.collection('streams').doc(streamId).update({
      'isLive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<VideoContent>> getVideoTutorials(int limit) async {
    final snapshot = await _firestore
        .collection('video_content')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => VideoContent.fromJson(d.data())).toList();
  }

  Future<String> generateVideoFromLesson(String lessonId) async {
    final lesson =
        await _firestore.collection('chess_lessons').doc(lessonId).get();
    final videoId = _firestore.collection('video_content').doc().id;

    await _firestore.collection('video_content').doc(videoId).set({
      'lessonId': lessonId,
      'title': lesson['title'] ?? 'Chess Lesson',
      'description': lesson['description'] ?? '',
      'videoUrl': 'https://videos.chesstacticsmaster.app/$videoId',
      'thumbnailUrl': 'https://thumbnails.chesstacticsmaster.app/$videoId.jpg',
      'duration': 300,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return videoId;
  }

  Future<void> recordViewerInteraction(
      String streamId, String userId, String actionType) async {
    await _firestore
        .collection('stream_interactions')
        .doc(streamId)
        .collection('interactions')
        .add({
      'userId': userId,
      'actionType': actionType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getStreamAnalytics(String streamId) async {
    final interactions = await _firestore
        .collection('stream_interactions')
        .doc(streamId)
        .collection('interactions')
        .get();

    return {
      'totalInteractions': interactions.size,
      'chatMessages':
          interactions.docs.where((d) => d['actionType'] == 'chat').length,
      'likes': interactions.docs.where((d) => d['actionType'] == 'like').length,
    };
  }
}

class LiveStream {
  LiveStream({
    required this.streamId,
    required this.userId,
    required this.title,
    required this.description,
    required this.viewerCount,
    required this.startedAt,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) => LiveStream(
        streamId: json['streamId'] ?? '',
        userId: json['userId'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        viewerCount: json['viewerCount'] ?? 0,
        startedAt: (json['startedAt'] as Timestamp).toDate(),
      );
  final String streamId;
  final String userId;
  final String title;
  final String description;
  final int viewerCount;
  final DateTime startedAt;
}

class VideoContent {
  VideoContent({
    required this.videoId,
    required this.lessonId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.createdAt,
  });

  factory VideoContent.fromJson(Map<String, dynamic> json) => VideoContent(
        videoId: json.toString(),
        lessonId: json['lessonId'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        videoUrl: json['videoUrl'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        duration: json['duration'] ?? 0,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );
  final String videoId;
  final String lessonId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final int duration;
  final DateTime createdAt;
}
