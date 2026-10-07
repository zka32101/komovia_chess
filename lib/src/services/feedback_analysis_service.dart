import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for analyzing user feedback and sentiment
class FeedbackAnalysisService {
  FeedbackAnalysisService._();
  static final FeedbackAnalysisService _instance = FeedbackAnalysisService._();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sentiment thresholds
  static const double POSITIVE_THRESHOLD = 0.6;
  static const double NEGATIVE_THRESHOLD = 0.4;

  static FeedbackAnalysisService get instance => _instance;

  /// Analyze sentiment of feedback text
  Future<SentimentAnalysis> analyzeFeedbackSentiment(String text) async {
    try {
      final score = _calculateSentimentScore(text);
      final category = _categorizeText(text);

      return SentimentAnalysis(
        text: text,
        score: score,
        sentiment: _getSentimentLabel(score),
        category: category,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error analyzing sentiment: $e');
      return SentimentAnalysis(
        text: text,
        score: 0.5,
        sentiment: 'neutral',
        category: 'other',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Aggregate feedback for a period
  Future<FeedbackReport> aggregateFeedback(Duration period) async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(period),
      );

      final query = await _firestore
          .collection('beta_feedback')
          .where('timestamp', isGreaterThan: cutoff)
          .get();

      final feedbackItems = query.docs.map((doc) => doc.data()).toList();

      final sentiments = <String, int>{
        'positive': 0,
        'neutral': 0,
        'negative': 0,
      };

      final categories = <String, int>{};
      final issues = <FeedbackIssue>[];

      for (final feedback in feedbackItems) {
        final text = feedback['text'] as String? ?? '';
        final sentiment = _getSentimentLabel(_calculateSentimentScore(text));
        sentiments[sentiment] = (sentiments[sentiment] ?? 0) + 1;

        final category = _categorizeText(text);
        categories[category] = (categories[category] ?? 0) + 1;

        if (sentiment == 'negative') {
          issues.add(FeedbackIssue(
            text: text,
            category: category,
            severity: _estimateSeverity(text),
            affectedUsers: 1,
            priority: 0,
          ));
        }
      }

      // Prioritize issues
      _prioritizeIssues(issues);

      return FeedbackReport(
        period: period,
        totalFeedback: feedbackItems.length,
        sentimentDistribution: sentiments,
        categoryDistribution: categories,
        topIssues: issues.take(10).toList(),
        sentimentTrend: await _calculateSentimentTrend(period),
      );
    } catch (e) {
      debugPrint('Error aggregating feedback: $e');
      return FeedbackReport(
        period: period,
        totalFeedback: 0,
        sentimentDistribution: {'positive': 0, 'neutral': 0, 'negative': 0},
        categoryDistribution: {},
        topIssues: [],
        sentimentTrend: 0.5,
      );
    }
  }

  /// Calculate sentiment trend
  Future<double> _calculateSentimentTrend(Duration period) async {
    try {
      final halfPeriod = Duration(milliseconds: period.inMilliseconds ~/ 2);
      final cutoff1 = Timestamp.fromDate(
        DateTime.now().subtract(period),
      );
      final cutoff2 = Timestamp.fromDate(
        DateTime.now().subtract(halfPeriod),
      );

      // First half
      final query1 = await _firestore
          .collection('beta_feedback')
          .where('timestamp', isGreaterThan: cutoff1)
          .where('timestamp', isLessThan: cutoff2)
          .get();

      double trend1 = 0.5;
      if (query1.docs.isNotEmpty) {
        final scores = query1.docs.map((doc) {
          final text = doc['text'] as String? ?? '';
          return _calculateSentimentScore(text);
        }).toList();
        trend1 = scores.reduce((a, b) => a + b) / scores.length;
      }

      // Second half
      final query2 = await _firestore
          .collection('beta_feedback')
          .where('timestamp', isGreaterThan: cutoff2)
          .get();

      double trend2 = 0.5;
      if (query2.docs.isNotEmpty) {
        final scores = query2.docs.map((doc) {
          final text = doc['text'] as String? ?? '';
          return _calculateSentimentScore(text);
        }).toList();
        trend2 = scores.reduce((a, b) => a + b) / scores.length;
      }

      return (trend2 - trend1).clamp(-1.0, 1.0);
    } catch (e) {
      debugPrint('Error calculating trend: $e');
      return 0.0;
    }
  }

  /// Calculate sentiment score (0.0 = very negative, 1.0 = very positive)
  double _calculateSentimentScore(String text) {
    if (text.isEmpty) return 0.5;

    final lowerText = text.toLowerCase();

    // Positive indicators
    final positiveWords = [
      'great',
      'excellent',
      'amazing',
      'fantastic',
      'love',
      'best',
      'awesome',
      'perfect',
      'wonderful',
      'brilliant',
      'good',
      'nice',
      'excellent',
      'super',
      'fun',
      'enjoyed',
      'impressed'
    ];

    // Negative indicators
    final negativeWords = [
      'bad',
      'terrible',
      'horrible',
      'awful',
      'hate',
      'crash',
      'bug',
      'slow',
      'broken',
      'useless',
      'poor',
      'disappointing',
      'angry',
      'frustrated',
      'annoyed',
      'error',
      'problem',
      'issue'
    ];

    var score = 0.5;
    var count = 0;

    for (final word in positiveWords) {
      if (lowerText.contains(word)) {
        score += 0.1;
        count++;
      }
    }

    for (final word in negativeWords) {
      if (lowerText.contains(word)) {
        score -= 0.1;
        count++;
      }
    }

    // Boost by exclamation marks
    score += (text.split('!').length - 1) * 0.05;

    // Dampen by question marks
    score -= (text.split('?').length - 1) * 0.03;

    return score.clamp(0.0, 1.0);
  }

  /// Categorize feedback text
  String _categorizeText(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('crash') ||
        lowerText.contains('bug') ||
        lowerText.contains('error') ||
        lowerText.contains('broken')) {
      return 'bug_report';
    }

    if (lowerText.contains('feature') ||
        lowerText.contains('add') ||
        lowerText.contains('would like') ||
        lowerText.contains('suggest')) {
      return 'feature_request';
    }

    if (lowerText.contains('slow') ||
        lowerText.contains('lag') ||
        lowerText.contains('performance') ||
        lowerText.contains('battery')) {
      return 'performance';
    }

    if (lowerText.contains('ui') ||
        lowerText.contains('interface') ||
        lowerText.contains('design') ||
        lowerText.contains('layout')) {
      return 'ui_ux';
    }

    if (lowerText.contains('rating') ||
        lowerText.contains('star') ||
        lowerText.contains('review')) {
      return 'rating';
    }

    return 'other';
  }

  /// Get sentiment label
  String _getSentimentLabel(double score) {
    if (score >= POSITIVE_THRESHOLD) return 'positive';
    if (score <= NEGATIVE_THRESHOLD) return 'negative';
    return 'neutral';
  }

  /// Estimate severity from text
  String _estimateSeverity(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('crash') ||
        lowerText.contains('completely broken')) {
      return 'critical';
    }

    if (lowerText.contains('bug') || lowerText.contains('error')) {
      return 'high';
    }

    if (lowerText.contains('slow') || lowerText.contains('annoying')) {
      return 'medium';
    }

    return 'low';
  }

  /// Prioritize issues by impact and severity
  void _prioritizeIssues(List<FeedbackIssue> issues) {
    final severityScores = {
      'critical': 100,
      'high': 50,
      'medium': 25,
      'low': 10,
    };

    for (final issue in issues) {
      issue.priority =
          (severityScores[issue.severity] ?? 0) + (issue.affectedUsers * 5);
    }

    issues.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Store sentiment analysis result
  Future<void> storeSentimentAnalysis(SentimentAnalysis analysis) async {
    try {
      await _firestore
          .collection('monitoring')
          .doc('sentiment_analysis')
          .collection('results')
          .add({
        'text': analysis.text,
        'score': analysis.score,
        'sentiment': analysis.sentiment,
        'category': analysis.category,
        'timestamp': Timestamp.fromDate(analysis.timestamp),
      });
    } catch (e) {
      debugPrint('Error storing sentiment analysis: $e');
    }
  }
}

/// Sentiment analysis result
class SentimentAnalysis {
  SentimentAnalysis({
    required this.text,
    required this.score,
    required this.sentiment,
    required this.category,
    required this.timestamp,
  });
  final String text;
  final double score;
  final String sentiment;
  final String category;
  final DateTime timestamp;
}

/// Feedback report
class FeedbackReport {
  FeedbackReport({
    required this.period,
    required this.totalFeedback,
    required this.sentimentDistribution,
    required this.categoryDistribution,
    required this.topIssues,
    required this.sentimentTrend,
  });
  final Duration period;
  final int totalFeedback;
  final Map<String, int> sentimentDistribution;
  final Map<String, int> categoryDistribution;
  final List<FeedbackIssue> topIssues;
  final double sentimentTrend;

  double get positiveRatio => totalFeedback > 0
      ? (sentimentDistribution['positive'] ?? 0) / totalFeedback
      : 0.0;

  double get negativeRatio => totalFeedback > 0
      ? (sentimentDistribution['negative'] ?? 0) / totalFeedback
      : 0.0;
}

/// Feedback issue
class FeedbackIssue {
  FeedbackIssue({
    required this.text,
    required this.category,
    required this.severity,
    required this.affectedUsers,
    required this.priority,
  });
  final String text;
  final String category;
  final String severity;
  int affectedUsers;
  int priority;
}
