import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import 'dart:math';

/// Custom finder for chess-specific widgets
class ChessWidgetFinders {
  /// Find the chess board widget
  static Finder findChessBoardWidget() {
    return find.byType(CustomPaint).first;
  }

  /// Find game status badge
  static Finder findGameStatusBadge(String status) {
    return find.byWidgetPredicate((widget) =>
        widget is Chip && (widget.label as Text?)?.data?.contains(status) ??
        false);
  }

  /// Find game card by opponent name
  static Finder findGameCard(String opponentName) {
    return find.byWidgetPredicate((widget) =>
        widget is Card &&
        find
            .descendant(
                of: find.byWidget(widget), matching: find.text(opponentName))
            .evaluate()
            .isNotEmpty);
  }

  /// Find rating display widget
  static Finder findRatingWidget() {
    return find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').contains('Rating'));
  }

  /// Find loading indicator
  static Finder findLoadingIndicator() {
    return find.byType(CircularProgressIndicator);
  }

  /// Find error message
  static Finder findErrorMessage() {
    return find.byWidgetPredicate((widget) =>
        widget is Text && (widget.data ?? '').toLowerCase().contains('error'));
  }
}

/// Extension methods for WidgetTester
extension WidgetTesterX on WidgetTester {
  /// Pump and settle with custom timeout
  Future<void> pumpAndSettleWithTimeout(
      {Duration timeout = const Duration(seconds: 2)}) async {
    return pumpAndSettle(timeout);
  }

  /// Type text into the first TextField
  Future<void> typeTextInTextField(String text) async {
    await enterText(find.byType(TextField).first, text);
    await pump();
  }

  /// Tap a button by text label
  Future<void> tapButtonWithText(String text) async {
    await tap(find.text(text));
    await pumpAndSettle();
  }

  /// Tap a button by icon
  Future<void> tapButtonWithIcon(IconData icon) async {
    await tap(find.byIcon(icon));
    await pumpAndSettle();
  }

  /// Find and tap a widget
  Future<void> tapWidget(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  /// Scroll to find a widget
  Future<void> scrollToFind(Finder finder,
      {Axis scrollDirection = Axis.vertical}) async {
    while (!finder.evaluate().isNotEmpty) {
      if (scrollDirection == Axis.vertical) {
        await scroll(find.byType(SingleChildScrollView).first, 0, -300);
      } else {
        await scroll(find.byType(SingleChildScrollView).first, -300, 0);
      }
      await pump();
    }
  }

  /// Verify text exists
  void verifyTextExists(String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Verify text does not exist
  void verifyTextNotExists(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Verify widget count
  void verifyWidgetCount(Finder finder, int count) {
    expect(finder, findsNWidgets(count));
  }

  /// Wait for widget to appear
  Future<void> waitForWidget(Finder finder) async {
    int attempts = 0;
    while (!finder.evaluate().isNotEmpty && attempts < 30) {
      await pump(Duration(milliseconds: 100));
      attempts++;
    }
  }

  /// Get rendered text from widget
  String getRenderedText(Finder finder) {
    return (finder.evaluate().single.widget as Text).data ?? '';
  }
}

/// Mock data generator for tests
class MockDataGenerator {
  static final Random _random = Random();

  /// Generate mock online game
  static OnlineGame mockGame({
    String? id,
    String status = 'active',
    String? whitePlayerId,
    String? blackPlayerId,
    String? pgn,
  }) {
    return OnlineGame(
      id: id ?? 'game_${DateTime.now().millisecondsSinceEpoch}',
      whitePlayerId: whitePlayerId ?? 'white_${_random.nextInt(10000)}',
      whitePlayerName: 'White Player',
      whiteRating: 1600 + _random.nextInt(400),
      blackPlayerId: blackPlayerId ?? 'black_${_random.nextInt(10000)}',
      blackPlayerName: 'Black Player',
      blackRating: 1650 + _random.nextInt(400),
      status: status,
      pgn: pgn ?? 'e4 c5 Nf3 d6 d4 cxd4 Nxd4',
      result: status == 'completed'
          ? ['1-0', '0-1', '1/2-1/2'][_random.nextInt(3)]
          : null,
      createdAt: DateTime.now().subtract(Duration(hours: _random.nextInt(24))),
      updatedAt: DateTime.now(),
      timeControl: '5+3',
    );
  }

  /// Generate multiple mock games
  static List<OnlineGame> mockGames(int count, {String status = 'active'}) {
    return List.generate(count, (_) => mockGame(status: status));
  }

  /// Generate mock user
  static Map<String, dynamic> mockUser({
    String? uid,
    String? email,
    int rating = 1600,
    String? displayName,
  }) {
    return {
      'uid': uid ?? 'user_${_random.nextInt(100000)}',
      'email': email ?? 'user${_random.nextInt(10000)}@example.com',
      'displayName': displayName ?? 'Test Player ${_random.nextInt(1000)}',
      'rating': rating,
      'totalGames': _random.nextInt(500),
      'wins': _random.nextInt(250),
      'losses': _random.nextInt(250),
      'draws': _random.nextInt(100),
      'createdAt':
          DateTime.now().subtract(Duration(days: _random.nextInt(365))),
    };
  }

  /// Generate mock rating data
  static List<Map<String, dynamic>> mockRatingHistory({
    int days = 30,
    int startingRating = 1600,
  }) {
    final history = <Map<String, dynamic>>[];
    var currentRating = startingRating;

    for (int i = 0; i < days; i++) {
      currentRating += _random.nextInt(50) - 25; // ±25 rating change
      history.add({
        'date': DateTime.now().subtract(Duration(days: days - i)),
        'rating': currentRating,
      });
    }

    return history;
  }
}

/// Test app wrapper with Material3 theme
Widget createTestApp({
  required Widget child,
  ThemeData? theme,
}) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
    theme: theme ?? ThemeData(useMaterial3: true),
    localizationsDelegates: const [],
  );
}

/// Test scenario builder
class TestScenario {
  final String name;
  final List<OnlineGame> games;
  final Map<String, dynamic>? currentUser;
  final Map<String, dynamic> errors;
  final bool isLoading;

  TestScenario({
    required this.name,
    this.games = const [],
    this.currentUser,
    this.errors = const {},
    this.isLoading = false,
  });

  /// Scenario with no games
  static TestScenario noGames() => TestScenario(
        name: 'No Active Games',
        games: [],
        currentUser: MockDataGenerator.mockUser(),
      );

  /// Scenario with one active game
  static TestScenario singleGame() => TestScenario(
        name: 'Single Active Game',
        games: [MockDataGenerator.mockGame(status: 'active')],
        currentUser: MockDataGenerator.mockUser(),
      );

  /// Scenario with multiple active games
  static TestScenario multipleGames({int count = 3}) => TestScenario(
        name: 'Multiple Active Games',
        games: MockDataGenerator.mockGames(count, status: 'active'),
        currentUser: MockDataGenerator.mockUser(),
      );

  /// Scenario with mixed game statuses
  static TestScenario mixedGameStatus() => TestScenario(
        name: 'Mixed Game Status',
        games: [
          ...MockDataGenerator.mockGames(2, status: 'active'),
          ...MockDataGenerator.mockGames(3, status: 'completed'),
        ],
        currentUser: MockDataGenerator.mockUser(),
      );

  /// Scenario with loading state
  static TestScenario loading() => TestScenario(
        name: 'Loading State',
        games: [],
        isLoading: true,
      );

  /// Scenario with network error
  static TestScenario networkError() => TestScenario(
        name: 'Network Error',
        games: [],
        errors: {'error': 'Network connection failed'},
      );

  /// Scenario with no user (logged out)
  static TestScenario notLoggedIn() => TestScenario(
        name: 'Not Logged In',
        games: [],
        currentUser: null,
      );

  /// Scenario with null opponent data
  static TestScenario nullOpponentData() => TestScenario(
        name: 'Null Opponent Data',
        games: [
          OnlineGame(
            id: 'test_game',
            whitePlayerId: 'white_1',
            whitePlayerName: 'Known Player',
            whiteRating: 1600,
            blackPlayerId: null,
            blackPlayerName: null,
            blackRating: null,
            status: 'active',
            pgn: 'e4',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            timeControl: '5+3',
          ),
        ],
      );
}

/// Performance measurement helper
class PerformanceMeasure {
  final String label;
  late Stopwatch _stopwatch;
  Duration? _duration;

  PerformanceMeasure(this.label) {
    _stopwatch = Stopwatch()..start();
  }

  void stop() {
    _stopwatch.stop();
    _duration = _stopwatch.elapsed;
  }

  Duration get duration => _duration ?? Duration.zero;

  bool isUnderLimit(Duration limit) => duration < limit;

  @override
  String toString() => '$label: ${duration.inMilliseconds}ms';
}

/// Widget tree debugger
class WidgetTreeDebugger {
  static void printWidgetTree(WidgetTester tester) {
    debugPrint('=== Widget Tree ===');
    debugPrint(tester.binding.window.physicalSize.toString());
    debugPrint('===================');
  }

  static void printFindersState(Map<String, Finder> finders) {
    debugPrint('=== Finder States ===');
    finders.forEach((label, finder) {
      final count = finder.evaluate().length;
      debugPrint('$label: found $count widget(s)');
    });
    debugPrint('=====================');
  }
}
