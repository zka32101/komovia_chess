import 'package:flutter/foundation.dart';

/// Launch phase
enum LaunchPhase {
  preAlpha,
  alpha,
  beta,
  betaExpanded,
  softLaunch,
  fullLaunch,
  postLaunch,
}

/// Launch checklist item
class LaunchChecklistItem {
  LaunchChecklistItem({
    required this.title,
    required this.description,
    required this.phase,
    this.isCompleted = false,
    this.notes,
    DateTime? createdAt,
  })  : id = 'LCI_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();
  final String id;
  final String title;
  final String description;
  final LaunchPhase phase;
  bool isCompleted;
  String? notes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'phase': phase.toString().split('.').last,
        'isCompleted': isCompleted,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  String toString() => '$title${isCompleted ? ' ✓' : ' ○'}';
}

/// Launch checklist
class LaunchChecklist {
  factory LaunchChecklist() => _instance;

  LaunchChecklist._internal() {
    _initializeChecklist();
  }
  static final LaunchChecklist _instance = LaunchChecklist._internal();

  final _items = <LaunchChecklistItem>[];
  LaunchPhase _currentPhase = LaunchPhase.preAlpha;

  /// Initialize launch checklist
  void _initializeChecklist() {
    // Pre-Alpha Phase
    _addItem('Concept Approved', 'Product and design reviewed and approved',
        LaunchPhase.preAlpha);
    _addItem('Core Features Complete', 'All core game features implemented',
        LaunchPhase.preAlpha);
    _addItem('Basic Testing', 'Internal testing on core features complete',
        LaunchPhase.preAlpha);

    // Alpha Phase
    _addItem('Full Feature Set', 'All features implemented and integrated',
        LaunchPhase.alpha);
    _addItem('Alpha Testing', 'Comprehensive internal testing completed',
        LaunchPhase.alpha);
    _addItem('Bug Fixes', 'Critical and high priority bugs resolved',
        LaunchPhase.alpha);
    _addItem('Performance Baseline', 'Performance benchmarks established',
        LaunchPhase.alpha);

    // Beta Phase
    _addItem('Beta Build Released', 'Beta version released to select testers',
        LaunchPhase.beta);
    _addItem('Feedback Collected', 'User feedback from beta testers collected',
        LaunchPhase.beta);
    _addItem('Localization Complete', 'App localized for target markets',
        LaunchPhase.beta);
    _addItem('Analytics Integration', 'Analytics fully configured and tested',
        LaunchPhase.beta);

    // Beta Expanded Phase
    _addItem('Expanded Beta', 'Beta expanded to larger user group',
        LaunchPhase.betaExpanded);
    _addItem('Stability Testing', 'Stability and crash rate monitoring',
        LaunchPhase.betaExpanded);
    _addItem('Load Testing', 'Server and infrastructure load tested',
        LaunchPhase.betaExpanded);
    _addItem('Security Review', 'Security review and penetration testing',
        LaunchPhase.betaExpanded);

    // Soft Launch Phase
    _addItem('Soft Launch Markets', 'Release in selected markets first',
        LaunchPhase.softLaunch);
    _addItem('Soft Launch Monitoring', 'Monitor soft launch metrics',
        LaunchPhase.softLaunch);
    _addItem('Issue Resolution', 'Address issues discovered in soft launch',
        LaunchPhase.softLaunch);
    _addItem('Readiness Sign-Off', 'Team sign-off for full launch',
        LaunchPhase.softLaunch);

    // Full Launch Phase
    _addItem('Global Rollout', 'Release in all target markets',
        LaunchPhase.fullLaunch);
    _addItem('Marketing Campaign', 'Launch marketing campaign',
        LaunchPhase.fullLaunch);
    _addItem('Press Release', 'Issue press release and media coverage',
        LaunchPhase.fullLaunch);
    _addItem('Launch Monitoring', 'Real-time monitoring during launch',
        LaunchPhase.fullLaunch);

    // Post-Launch Phase
    _addItem('Performance Monitoring', 'Continuous performance monitoring',
        LaunchPhase.postLaunch);
    _addItem(
        'User Support', 'Launch user support team', LaunchPhase.postLaunch);
    _addItem('Analytics Review', 'Daily analytics review and optimization',
        LaunchPhase.postLaunch);
    _addItem('Roadmap Planning', 'Plan features for next release',
        LaunchPhase.postLaunch);

    debugPrint('[LaunchChecklist] Initialized with ${_items.length} items');
  }

  /// Add item
  void _addItem(String title, String description, LaunchPhase phase) {
    _items.add(
      LaunchChecklistItem(
        title: title,
        description: description,
        phase: phase,
      ),
    );
  }

  /// Set current phase
  void setCurrentPhase(LaunchPhase phase) {
    _currentPhase = phase;
    debugPrint(
        '[LaunchChecklist] Current phase: ${phase.toString().split('.').last}');
  }

  /// Get current phase
  LaunchPhase getCurrentPhase() => _currentPhase;

  /// Mark item completed
  void markItemCompleted(String itemId, {String? notes}) {
    final item = _items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => null as dynamic,
    );

    item.isCompleted = true;
    item.notes = notes;
  }

  /// Get items by phase
  List<LaunchChecklistItem> getItemsByPhase(LaunchPhase phase) =>
      _items.where((i) => i.phase == phase).toList();

  /// Get current phase items
  List<LaunchChecklistItem> getCurrentPhaseItems() =>
      getItemsByPhase(_currentPhase);

  /// Get completion percentage for phase
  double getPhaseCompletion(LaunchPhase phase) {
    final phaseItems = getItemsByPhase(phase);
    if (phaseItems.isEmpty) return 0;

    final completed = phaseItems.where((i) => i.isCompleted).length;
    return (completed / phaseItems.length) * 100;
  }

  /// Check if phase is complete
  bool isPhaseComplete(LaunchPhase phase) => getPhaseCompletion(phase) == 100.0;

  /// Get overall completion
  double getOverallCompletion() {
    if (_items.isEmpty) return 0;
    final completed = _items.where((i) => i.isCompleted).length;
    return (completed / _items.length) * 100;
  }

  /// Check if ready for next phase
  bool isReadyForNextPhase() => isPhaseComplete(_currentPhase);

  /// Advance to next phase
  bool advanceToNextPhase() {
    if (!isReadyForNextPhase()) {
      return false;
    }

    const phases = LaunchPhase.values;
    final currentIndex = phases.indexOf(_currentPhase);

    if (currentIndex < phases.length - 1) {
      _currentPhase = phases[currentIndex + 1];
      debugPrint(
          '[LaunchChecklist] Advanced to ${_currentPhase.toString().split('.').last}');
      return true;
    }

    return false;
  }

  /// Get all items
  List<LaunchChecklistItem> getAllItems() => List.unmodifiable(_items);

  /// Generate launch report
  String generateReport() {
    final buffer = StringBuffer();
    final overall = getOverallCompletion();

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                    LAUNCH CHECKLIST                             ║
╠══════════════════════════════════════════════════════════════════╣
║ Current Phase: ${_currentPhase.toString().split('.').last.toUpperCase().padRight(43)}║
║ Overall Completion: ${overall.toStringAsFixed(1)}%${' '.padRight(37)}║
║ Total Items: ${_items.length.toString().padRight(50)}║
╠══════════════════════════════════════════════════════════════════╣
║ PHASE BREAKDOWN:
    ''');

    for (final phase in LaunchPhase.values) {
      final completion = getPhaseCompletion(phase).toStringAsFixed(1);
      final isComplete = isPhaseComplete(phase) ? '✓' : '○';
      buffer.writeln(
          '║ $isComplete ${phase.toString().split('.').last.padRight(18)}: $completion%${' '.padRight(28)}║');

      for (final item in getItemsByPhase(phase)) {
        final itemStatus = item.isCompleted ? '  ✓' : '  ○';
        buffer.writeln('║$itemStatus ${item.title.padRight(56)}║');
      }
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ STATUS: ${(_currentPhase == LaunchPhase.postLaunch ? '✓ LAUNCHED' : '⏳ IN PROGRESS').padRight(49)}║
╚══════════════════════════════════════════════════════════════════╝
    ''');

    return buffer.toString();
  }

  /// Clear all data
  void clear() {
    for (final item in _items) {
      item.isCompleted = false;
      item.notes = null;
    }
    _currentPhase = LaunchPhase.preAlpha;
  }
}
