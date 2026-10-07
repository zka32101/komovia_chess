import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/roadmap.dart';

/// Feature Roadmap Service
class FeatureRoadmapService {
  factory FeatureRoadmapService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      _instance._firestore = firestore;
    }
    return _instance;
  }

  FeatureRoadmapService._internal() : _firestore = FirebaseFirestore.instance;
  static final FeatureRoadmapService _instance =
      FeatureRoadmapService._internal();

  FirebaseFirestore _firestore;

  /// Create roadmap item
  Future<void> createRoadmapItem({
    required String title,
    required String description,
    required String category,
    required int priority,
    required DateTime targetDate,
    required String targetVersion,
    required int complexity,
  }) async {
    try {
      final item = RoadmapItem(
        id: _firestore.collection('roadmap').doc().id,
        title: title,
        description: description,
        category: category,
        priority: priority,
        status: RoadmapStatus.planned,
        targetDate: targetDate,
        targetVersion: targetVersion,
        complexity: complexity,
        createdDate: DateTime.now(),
        completedDate: null,
        relatedFeatureRequests: [],
      );

      await _firestore.collection('roadmap').doc(item.id).set(item.toJson());
    } catch (e) {
      print('Roadmap creation error: $e');
      rethrow;
    }
  }

  /// Update roadmap item status
  Future<void> updateRoadmapItemStatus(
      String itemId, RoadmapStatus status) async {
    try {
      final updateData = {'status': status.name};
      if (status == RoadmapStatus.completed) {
        updateData['completedDate'] = DateTime.now().toIso8601String();
      }

      await _firestore.collection('roadmap').doc(itemId).update(updateData);
    } catch (e) {
      print('Roadmap update error: $e');
      rethrow;
    }
  }

  /// Get roadmap items
  Future<List<RoadmapItem>> getRoadmapItems({int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection('roadmap')
          .orderBy('targetDate', descending: false)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => RoadmapItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching roadmap items: $e');
      return [];
    }
  }

  /// Get roadmap by priority
  Future<List<RoadmapItem>> getRoadmapByPriority() async {
    try {
      final querySnapshot = await _firestore
          .collection('roadmap')
          .orderBy('priority', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RoadmapItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching roadmap by priority: $e');
      return [];
    }
  }

  /// Get roadmap by timeline
  Future<List<RoadmapItem>> getRoadmapByTimeline() async {
    try {
      final querySnapshot = await _firestore
          .collection('roadmap')
          .orderBy('targetDate', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => RoadmapItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching roadmap by timeline: $e');
      return [];
    }
  }

  /// Get roadmap items by status
  Future<List<RoadmapItem>> getRoadmapByStatus(RoadmapStatus status) async {
    try {
      final querySnapshot = await _firestore
          .collection('roadmap')
          .where('status', isEqualTo: status.name)
          .get();

      return querySnapshot.docs
          .map((doc) => RoadmapItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching roadmap by status: $e');
      return [];
    }
  }

  /// Publish roadmap (make visible to users)
  Future<void> publishRoadmap() async {
    try {
      final items = await getRoadmapItems();
      await _firestore.collection('settings').doc('public_roadmap').set({
        'items': items.map((e) => e.toJson()).toList(),
        'publishedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error publishing roadmap: $e');
      rethrow;
    }
  }

  /// Get completion percentage
  Future<double> getCompletionPercentage() async {
    try {
      final allItems = await getRoadmapItems(limit: 1000);
      if (allItems.isEmpty) return 0.0;

      final completed = allItems
          .where((item) => item.status == RoadmapStatus.completed)
          .length;

      return (completed / allItems.length) * 100;
    } catch (e) {
      print('Error getting completion percentage: $e');
      return 0.0;
    }
  }
}
