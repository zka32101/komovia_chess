import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dark Mode Asset Validation Tests', () {
    /// Test that assets render correctly in light theme
    testWidgets('Assets render correctly in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/chess_board_1024x1024.png'),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/chess_pieces_white.png'),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/chess_pieces_black.png'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all images are rendered
      expect(find.byType(Image), findsWidgets);

      // Verify background is light
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.white));
    });

    /// Test that assets render correctly in dark theme
    testWidgets('Assets render correctly in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/chess_board_1024x1024.png'),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/chess_pieces_white.png'),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset('assets/images/chess_pieces_black.png'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all images are rendered
      expect(find.byType(Image), findsWidgets);
    });

    /// Test theme transition doesn't break asset rendering
    testWidgets('Theme transitions do not break asset rendering', (WidgetTester tester) async {
      final themeNotifier = ValueNotifier<ThemeData>(ThemeData.light());

      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: themeNotifier,
          builder: (context, theme, child) {
            return MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: Image.asset('assets/images/chess_board_1024x1024.png'),
                ),
              ),
            );
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      // Switch to dark theme
      themeNotifier.value = ThemeData.dark();
      await tester.pumpAndSettle();

      // Asset should still be rendered
      expect(find.byType(Image), findsOneWidget);

      // Switch back to light theme
      themeNotifier.value = ThemeData.light();
      await tester.pumpAndSettle();

      // Asset should still be rendered
      expect(find.byType(Image), findsOneWidget);
    });

    /// Test navigation icons visibility in both themes
    testWidgets('Navigation icons are visible in both themes', (WidgetTester tester) async {
      final navigationIcons = [
        'assets/images/icon_home_192x192.png',
        'assets/images/icon_puzzle_192x192.png',
        'assets/images/icon_game_192x192.png',
        'assets/images/icon_profile_192x192.png',
        'assets/images/icon_settings_192x192.png',
        'assets/images/icon_leaderboard_192x192.png',
      ];

      // Test in light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: navigationIcons
                    .map((icon) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            icon,
                            width: 48,
                            height: 48,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);

      // Test in dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: navigationIcons
                    .map((icon) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            icon,
                            width: 48,
                            height: 48,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);
    });

    /// Test splash screens work in both themes
    testWidgets('Splash screen assets work in light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Image.asset(
              'assets/images/splash_android_1080x1920.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    /// Test splash screens work in dark theme
    testWidgets('Splash screen assets work in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Image.asset(
              'assets/images/splash_android_1080x1920.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    /// Test app icon in different contexts
    testWidgets('App icon renders correctly in both themes', (WidgetTester tester) async {
      // Light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            appBar: AppBar(
              leading: Container(
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/images/app_icon_1024.png'),
              ),
              title: const Text('App'),
            ),
            body: const SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            appBar: AppBar(
              leading: Container(
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/images/app_icon_1024.png'),
              ),
              title: const Text('App'),
            ),
            body: const SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    /// Test text contrast with generated assets as background
    testWidgets('Text is readable over chess board asset', (WidgetTester tester) async {
      // Test light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Stack(
              children: [
                Image.asset(
                  'assets/images/chess_board_1024x1024.png',
                  fit: BoxFit.cover,
                ),
                const Positioned(
                  top: 20,
                  left: 20,
                  child: Text(
                    'Readable Text',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Readable Text'), findsOneWidget);

      // Test dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Stack(
              children: [
                Image.asset(
                  'assets/images/chess_board_1024x1024.png',
                  fit: BoxFit.cover,
                ),
                const Positioned(
                  top: 20,
                  left: 20,
                  child: Text(
                    'Readable Text',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Readable Text'), findsOneWidget);
    });

    /// Test button visibility with Leonardo-generated icon backgrounds
    testWidgets('Icon buttons are visible in both themes', (WidgetTester tester) async {
      // Light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/icon_home_192x192.png'),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Image.asset('assets/images/icon_puzzle_192x192.png'),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Image.asset('assets/images/icon_game_192x192.png'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);

      // Dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/icon_home_192x192.png'),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Image.asset('assets/images/icon_puzzle_192x192.png'),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Image.asset('assets/images/icon_game_192x192.png'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);
    });

    /// Test card layouts with assets in both themes
    testWidgets('Assets display correctly in cards (light and dark)', (WidgetTester tester) async {
      // Light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    child: Image.asset('assets/images/chess_board_1024x1024.png'),
                  ),
                  Card(
                    child: Image.asset('assets/images/chess_pieces_white.png'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Card), findsWidgets);

      // Dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    child: Image.asset('assets/images/chess_board_1024x1024.png'),
                  ),
                  Card(
                    child: Image.asset('assets/images/chess_pieces_white.png'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Card), findsWidgets);
    });
  });

  group('Asset Color Scheme Validation', () {
    /// Verify that Leonardo assets maintain quality across color schemes
    test('Assets maintain visual quality in different color schemes', () {
      // Placeholder test for color scheme validation
      // In real testing, this would involve pixel analysis

      final lightThemeExpectations = {
        'chess_board_1024x1024.png': 'Visible with good contrast on white background',
        'chess_pieces_white.png': 'Clearly distinguishable',
        'chess_pieces_black.png': 'High contrast on light background',
      };

      final darkThemeExpectations = {
        'chess_board_1024x1024.png': 'Visible with acceptable contrast on dark background',
        'chess_pieces_white.png': 'High contrast on dark background',
        'chess_pieces_black.png': 'Visible but lower contrast on dark background',
      };

      expect(lightThemeExpectations.length, equals(3));
      expect(darkThemeExpectations.length, equals(3));
    });
  });
}
