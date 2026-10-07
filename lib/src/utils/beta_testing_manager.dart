import 'package:flutter/foundation.dart';

/// Beta tester profile
class BetaTester {
  BetaTester({
    required this.email,
    required this.name,
    required this.deviceInfo,
    String? id,
    DateTime? invitedAt,
  })  : id = id ?? 'BT_${DateTime.now().millisecondsSinceEpoch}',
        isActive = false,
        invitedAt = invitedAt ?? DateTime.now();
  final String id;
  final String email;
  final String name;
  final String deviceInfo;
  bool isActive;
  final DateTime invitedAt;
  DateTime? acceptedAt;
  final List<String> feedback = [];
  int bugsReported = 0;
  int bugsFixed = 0;

  void acceptInvitation() {
    isActive = true;
    acceptedAt = DateTime.now();
  }

  void addFeedback(String message) {
    feedback.add(message);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'deviceInfo': deviceInfo,
        'isActive': isActive,
        'invitedAt': invitedAt.toIso8601String(),
        'acceptedAt': acceptedAt?.toIso8601String(),
        'feedbackCount': feedback.length,
        'bugsReported': bugsReported,
        'bugsFixed': bugsFixed,
      };

  @override
  String toString() => 'BetaTester($name - ${isActive ? "Active" : "Pending"})';
}

/// Beta testing session
class BetaTestingSession {
  BetaTestingSession({
    required this.versionTested,
    String? id,
    DateTime? startDate,
  })  : id = id ?? 'BTS_${DateTime.now().millisecondsSinceEpoch}',
        startDate = startDate ?? DateTime.now();
  final String id;
  final String versionTested;
  final DateTime startDate;
  DateTime? endDate;
  final List<BetaTester> testers = [];
  int totalBugsReported = 0;
  int totalBugsFixed = 0;
  double averageFeedbackScore = 0;

  void addTester(BetaTester tester) {
    testers.add(tester);
  }

  void endSession() {
    endDate = DateTime.now();
    _calculateMetrics();
  }

  void _calculateMetrics() {
    totalBugsReported = testers.fold<int>(0, (sum, t) => sum + t.bugsReported);
    totalBugsFixed = testers.fold<int>(0, (sum, t) => sum + t.bugsFixed);

    if (testers.isNotEmpty) {
      final totalFeedback =
          testers.fold<int>(0, (sum, t) => sum + t.feedback.length);
      averageFeedbackScore = totalFeedback / testers.length;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionTested': versionTested,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'testerCount': testers.length,
        'totalBugsReported': totalBugsReported,
        'totalBugsFixed': totalBugsFixed,
        'averageFeedbackScore': averageFeedbackScore,
      };

  @override
  String toString() =>
      'BetaTestingSession(v$versionTested with ${testers.length} testers)';
}

/// Beta testing manager
class BetaTestingManager {
  factory BetaTestingManager() => _instance;

  BetaTestingManager._internal();
  static final BetaTestingManager _instance = BetaTestingManager._internal();

  final _testers = <BetaTester>[];
  final _sessions = <BetaTestingSession>[];

  /// Add beta tester
  BetaTester addBetaTester({
    required String email,
    required String name,
    required String deviceInfo,
  }) {
    final tester = BetaTester(
      email: email,
      name: name,
      deviceInfo: deviceInfo,
    );

    _testers.add(tester);
    debugPrint('[BetaTestingManager] Beta tester added: $name');
    return tester;
  }

  /// Accept tester invitation
  void acceptTesterInvitation(String testerId) {
    final tester = _testers.firstWhere(
      (t) => t.id == testerId,
      orElse: () => null as dynamic,
    );

    tester.acceptInvitation();
    debugPrint(
        '[BetaTestingManager] Tester accepted invitation: ${tester.email}');
  }

  /// Report bug from tester
  void reportBug(String testerId, String description) {
    final tester = _testers.firstWhere(
      (t) => t.id == testerId,
      orElse: () => null as dynamic,
    );

    tester.bugsReported++;
    tester.addFeedback(description);
    debugPrint('[BetaTestingManager] Bug reported by ${tester.name}');
  }

  /// Mark bug as fixed
  void markBugFixed(String testerId) {
    final tester = _testers.firstWhere(
      (t) => t.id == testerId,
      orElse: () => null as dynamic,
    );

    tester.bugsFixed++;
  }

  /// Start beta testing session
  BetaTestingSession startBetaSession(String versionTested) {
    final session = BetaTestingSession(versionTested: versionTested);
    _sessions.add(session);

    for (final tester in _testers.where((t) => t.isActive)) {
      session.addTester(tester);
    }

    debugPrint('[BetaTestingManager] Beta session started for v$versionTested');
    return session;
  }

  /// End beta session
  void endBetaSession(String sessionId) {
    final session = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => null as dynamic,
    );

    session.endSession();
    debugPrint(
        '[BetaTestingManager] Beta session ended: ${session.versionTested}');
  }

  /// Get all testers
  List<BetaTester> getAllTesters() => List.unmodifiable(_testers);

  /// Get active testers
  List<BetaTester> getActiveTesters() =>
      _testers.where((t) => t.isActive).toList();

  /// Get all sessions
  List<BetaTestingSession> getAllSessions() => List.unmodifiable(_sessions);

  /// Generate beta report
  String generateBetaReport() {
    final buffer = StringBuffer();
    final activeTesterCount = getActiveTesters().length;
    final totalBugsReported =
        _testers.fold<int>(0, (sum, t) => sum + t.bugsReported);

    buffer.writeln('''
╔══════════════════════════════════════════════════════════════════╗
║                 BETA TESTING REPORT                             ║
╠══════════════════════════════════════════════════════════════════╣
║ Total Testers: ${_testers.length.toString().padRight(50)}║
║ Active Testers: ${activeTesterCount.toString().padRight(48)}║
║ Total Bugs Reported: ${totalBugsReported.toString().padRight(42)}║
║ Sessions: ${_sessions.length.toString().padRight(54)}║
╠══════════════════════════════════════════════════════════════════╣
║ TESTERS:
    ''');

    for (final tester in _testers) {
      final status = tester.isActive ? '✓' : '○';
      buffer.writeln(
          '║ $status ${tester.name.padRight(30)}: ${tester.bugsReported} bugs, ${tester.feedback.length} feedback');
    }

    buffer.writeln('''
╠══════════════════════════════════════════════════════════════════╣
║ SESSIONS:
    ''');

    for (final session in _sessions) {
      buffer.writeln(
          '║ v${session.versionTested.padRight(25)}: ${session.testers.length} testers, ${session.totalBugsReported} bugs');
    }

    buffer.writeln(
        '╚══════════════════════════════════════════════════════════════════╝');
    return buffer.toString();
  }

  /// Clear all data
  void clear() {
    _testers.clear();
    _sessions.clear();
  }
}
