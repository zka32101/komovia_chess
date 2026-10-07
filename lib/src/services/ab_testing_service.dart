import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';

/// Service for A/B testing and feature flags
class ABTestingService {
  ABTestingService._();
  static final ABTestingService _instance = ABTestingService._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for experiments
  final Map<String, Experiment> _experimentCache = {};
  final Map<String, String> _userVariantCache = {};

  static ABTestingService get instance => _instance;

  /// Create a new A/B test experiment
  Future<Experiment> createExperiment({
    required String name,
    required String hypothesis,
    required List<String> variants,
    required Duration duration,
    required int sampleSize,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final experiment = Experiment(
        id: _generateId(),
        name: name,
        hypothesis: hypothesis,
        variants: variants,
        createdAt: DateTime.now(),
        endAt: DateTime.now().add(duration),
        sampleSize: sampleSize,
        metadata: metadata ?? {},
        status: 'active',
        results: {},
      );

      await _firestore
          .collection('ab_tests')
          .doc('experiments')
          .collection('list')
          .doc(experiment.id)
          .set(experiment.toJson());

      _experimentCache[experiment.id] = experiment;
      return experiment;
    } catch (e) {
      debugPrint('Error creating experiment: $e');
      rethrow;
    }
  }

  /// Get user's variant for experiment (consistent hashing)
  Future<String> getUserVariant(String userId, String experimentId) async {
    // Check cache first
    final cacheKey = '$userId:$experimentId';
    if (_userVariantCache.containsKey(cacheKey)) {
      return _userVariantCache[cacheKey]!;
    }

    try {
      final doc = await _firestore
          .collection('ab_tests')
          .doc('user_assignments')
          .collection('assignments')
          .doc(cacheKey)
          .get();

      if (doc.exists) {
        final variant = doc['variant'] as String;
        _userVariantCache[cacheKey] = variant;
        return variant;
      }

      // Create new assignment using consistent hashing
      final experiment =
          _experimentCache[experimentId] ?? await _getExperiment(experimentId);

      final variant = _assignVariant(userId, experimentId, experiment.variants);

      await _firestore
          .collection('ab_tests')
          .doc('user_assignments')
          .collection('assignments')
          .doc(cacheKey)
          .set({
        'userId': userId,
        'experimentId': experimentId,
        'variant': variant,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      _userVariantCache[cacheKey] = variant;
      return variant;
    } catch (e) {
      debugPrint('Error getting user variant: $e');
      // Fallback: try to get experiment and return first variant
      try {
        final experiment = await _getExperiment(experimentId);
        return experiment.variants.isNotEmpty
            ? experiment.variants.first
            : 'control';
      } catch (_) {
        // Final fallback to 'control' variant
        return 'control';
      }
    }
  }

  /// Get variant-specific value
  Future<T?> getVariantValue<T>(String key, String experimentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final variant = await getUserVariant(userId, experimentId);

      final doc = await _firestore
          .collection('ab_tests')
          .doc('variants')
          .collection(experimentId)
          .doc(variant)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return data[key] as T?;
    } catch (e) {
      debugPrint('Error getting variant value: $e');
      return null;
    }
  }

  /// Track user action in experiment
  Future<void> trackExperimentAction(
    String experimentId,
    String action, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final variant = await getUserVariant(userId, experimentId);

      await _firestore
          .collection('ab_tests')
          .doc('events')
          .collection('tracking')
          .add({
        'experimentId': experimentId,
        'variant': variant,
        'userId': userId,
        'action': action,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error tracking experiment action: $e');
    }
  }

  /// End experiment and analyze results
  Future<ExperimentResults> analyzeResults(String experimentId) async {
    try {
      // Fetch all events for experiment
      final query = await _firestore
          .collection('ab_tests')
          .doc('events')
          .collection('tracking')
          .where('experimentId', isEqualTo: experimentId)
          .get();

      final experiment =
          _experimentCache[experimentId] ?? await _getExperiment(experimentId);

      final events = query.docs.map((doc) => doc.data()).toList();
      final variantStats = _calculateVariantStats(events, experiment.variants);
      final winner = _determineWinner(variantStats, experiment.variants);
      final confidenceLevel = _calculateConfidence(variantStats);

      return ExperimentResults(
        experimentId: experimentId,
        variantStats: variantStats,
        winner: winner,
        confidenceLevel: confidenceLevel,
        sampleSize: events.length,
        recommendedAction: _getRecommendedAction(winner, confidenceLevel),
      );
    } catch (e) {
      debugPrint('Error analyzing results: $e');
      rethrow;
    }
  }

  /// Assign variant using consistent hashing
  String _assignVariant(
      String userId, String experimentId, List<String> variants) {
    final salt = '$experimentId:${variants.join(':')}';
    final hash = _consistentHash(userId, salt);
    return variants[hash % variants.length];
  }

  /// Consistent hash function
  int _consistentHash(String input, String salt) {
    final combined = '$input:$salt';
    final bytes = utf8.encode(combined);
    int hash = 5381;
    for (final int byte in bytes) {
      hash = ((hash << 5) + hash) + byte;
    }
    return hash.abs();
  }

  /// Calculate stats per variant
  Map<String, VariantStats> _calculateVariantStats(
    List<Map<String, dynamic>> events,
    List<String> variants,
  ) {
    final stats = <String, VariantStats>{};

    for (final variant in variants) {
      final variantEvents =
          events.where((e) => e['variant'] == variant).toList();
      final uniqueUsers = variantEvents.map((e) => e['userId']).toSet();

      stats[variant] = VariantStats(
        variant: variant,
        sampleSize: uniqueUsers.length,
        conversions:
            variantEvents.where((e) => e['action'] == 'convert').length,
        engagementScore: variantEvents
                .where((e) => e['action'] == 'engage')
                .length
                .toDouble() /
            (uniqueUsers.isNotEmpty ? uniqueUsers.length : 1),
      );
    }

    return stats;
  }

  /// Determine statistical winner
  String? _determineWinner(
      Map<String, VariantStats> stats, List<String> variants) {
    if (stats.isEmpty) return null;

    VariantStats? best;
    for (final variant in variants) {
      final stat = stats[variant];
      if (stat != null &&
          (best == null || stat.conversionRate > best.conversionRate)) {
        best = stat;
      }
    }

    return best?.variant;
  }

  /// Calculate statistical confidence
  double _calculateConfidence(Map<String, VariantStats> stats) {
    if (stats.length < 2) return 0;

    // Simplified chi-square test approximation
    final variants = stats.values.toList();
    final control = variants.first;
    final treatment = variants.length > 1 ? variants[1] : control;

    if (control.sampleSize == 0 || treatment.sampleSize == 0) return 0;

    final p1 = control.conversionRate;
    final p2 = treatment.conversionRate;
    final pooled = (control.conversions + treatment.conversions).toDouble() /
        (control.sampleSize + treatment.sampleSize);

    final se = sqrt(pooled *
        (1 - pooled) *
        (1 / control.sampleSize + 1 / treatment.sampleSize));
    if (se == 0) return 0;

    final z = ((p1 - p2) / se).abs();

    // Convert z-score to confidence (simplified)
    if (z > 1.96) return 0.95; // 95% confidence
    if (z > 1.645) return 0.90; // 90% confidence
    return (z / 1.96).clamp(0.0, 0.90);
  }

  /// Get recommended action
  String _getRecommendedAction(String? winner, double confidence) {
    if (winner == null) return 'continue_testing';
    if (confidence >= 0.95) return 'rollout_winner';
    if (confidence >= 0.80) return 'expand_sample';
    return 'continue_testing';
  }

  /// Internal helper to get experiment from cache or Firestore
  Future<Experiment> _getExperiment(String experimentId) async {
    if (_experimentCache.containsKey(experimentId)) {
      return _experimentCache[experimentId]!;
    }

    final doc = await _firestore
        .collection('ab_tests')
        .doc('experiments')
        .collection('list')
        .doc(experimentId)
        .get();

    if (!doc.exists) throw Exception('Experiment not found');

    final experiment = Experiment.fromJson(doc.data()!);
    _experimentCache[experimentId] = experiment;
    return experiment;
  }

  /// Generate unique ID
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}

/// Experiment data class
class Experiment {
  Experiment({
    required this.id,
    required this.name,
    required this.hypothesis,
    required this.variants,
    required this.createdAt,
    required this.endAt,
    required this.sampleSize,
    required this.metadata,
    required this.status,
    required this.results,
  });

  factory Experiment.fromJson(Map<String, dynamic> json) => Experiment(
        id: json['id'] as String,
        name: json['name'] as String,
        hypothesis: json['hypothesis'] as String,
        variants: List<String>.from(json['variants'] as List),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        endAt: (json['endAt'] as Timestamp).toDate(),
        sampleSize: json['sampleSize'] as int,
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
        status: json['status'] as String,
        results: json['results'] as Map<String, dynamic>? ?? {},
      );
  final String id;
  final String name;
  final String hypothesis;
  final List<String> variants;
  final DateTime createdAt;
  final DateTime endAt;
  final int sampleSize;
  final Map<String, dynamic> metadata;
  final String status;
  final Map<String, dynamic> results;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hypothesis': hypothesis,
        'variants': variants,
        'createdAt': Timestamp.fromDate(createdAt),
        'endAt': Timestamp.fromDate(endAt),
        'sampleSize': sampleSize,
        'metadata': metadata,
        'status': status,
        'results': results,
      };
}

/// Variant statistics
class VariantStats {
  VariantStats({
    required this.variant,
    required this.sampleSize,
    required this.conversions,
    required this.engagementScore,
  });
  final String variant;
  final int sampleSize;
  final int conversions;
  final double engagementScore;

  double get conversionRate => sampleSize > 0 ? conversions / sampleSize : 0.0;
}

/// Experiment results
class ExperimentResults {
  ExperimentResults({
    required this.experimentId,
    required this.variantStats,
    required this.winner,
    required this.confidenceLevel,
    required this.sampleSize,
    required this.recommendedAction,
  });
  final String experimentId;
  final Map<String, VariantStats> variantStats;
  final String? winner;
  final double confidenceLevel;
  final int sampleSize;
  final String recommendedAction;
}
