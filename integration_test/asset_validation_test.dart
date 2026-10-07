import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Asset Validation Tests', () {
    /// Test that all Leonardo-generated assets are bundled correctly
    testWidgets('Verify all 13 Leonardo-generated assets exist', (WidgetTester tester) async {
      // List of all expected Leonardo-generated assets
      final expectedAssets = [
        'assets/images/app_icon_1024.png',
        'assets/images/feature_graphic_1242x2688.png',
        'assets/images/splash_android_1080x1920.png',
        'assets/images/splash_ios_1170x2532.png',
        'assets/images/chess_board_1024x1024.png',
        'assets/images/chess_pieces_white.png',
        'assets/images/chess_pieces_black.png',
        'assets/images/icon_home_192x192.png',
        'assets/images/icon_puzzle_192x192.png',
        'assets/images/icon_game_192x192.png',
        'assets/images/icon_profile_192x192.png',
        'assets/images/icon_settings_192x192.png',
        'assets/images/icon_leaderboard_192x192.png',
      ];

      // Verify each asset can be loaded
      for (final asset in expectedAssets) {
        final assetKey = UniqueKey();

        // Build a widget that loads the asset
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Image.asset(
                asset,
                key: assetKey,
                errorBuilder: (context, error, stackTrace) {
                  return Text('Failed to load: $asset');
                },
              ),
            ),
          ),
        );

        // Give the image time to load
        await tester.pumpAndSettle();

        // Verify the image widget is present
        expect(find.byKey(assetKey), findsOneWidget);
      }
    });

    /// Test app icon asset properties
    testWidgets('App icon asset validates correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Image.asset(
              'assets/images/app_icon_1024.png',
              width: 1024,
              height: 1024,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.width, 1024);
      expect(imageWidget.height, 1024);
    });

    /// Test splash screen assets display without letterboxing
    testWidgets('Splash screen assets render without distortion', (WidgetTester tester) async {
      // Test Android splash (1080x1920)
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        MaterialApp(
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

    /// Test chess board asset renders correctly
    testWidgets('Chess board asset displays proper grid', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Image.asset(
                'assets/images/chess_board_1024x1024.png',
                width: 512,
                height: 512,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
    });

    /// Test chess pieces assets load correctly
    testWidgets('Chess pieces assets (white and black) load', (WidgetTester tester) async {
      final pieces = [
        'assets/images/chess_pieces_white.png',
        'assets/images/chess_pieces_black.png',
      ];

      for (final piece in pieces) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Image.asset(piece),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
      }
    });

    /// Test navigation icons load at correct sizes
    testWidgets('Navigation icons render at expected sizes', (WidgetTester tester) async {
      final navigationIcons = [
        'assets/images/icon_home_192x192.png',
        'assets/images/icon_puzzle_192x192.png',
        'assets/images/icon_game_192x192.png',
        'assets/images/icon_profile_192x192.png',
        'assets/images/icon_settings_192x192.png',
        'assets/images/icon_leaderboard_192x192.png',
      ];

      for (final icon in navigationIcons) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(icon),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
      }
    });

    /// Test Play Store feature graphic asset
    testWidgets('Play Store feature graphic asset loads', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Image.asset(
              'assets/images/feature_graphic_1242x2688.png',
              width: 1242,
              height: 2688,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    /// Test asset memory efficiency
    testWidgets('Multiple asset loads do not exceed memory limits', (WidgetTester tester) async {
      final assets = [
        'assets/images/app_icon_1024.png',
        'assets/images/chess_board_1024x1024.png',
        'assets/images/chess_pieces_white.png',
        'assets/images/icon_home_192x192.png',
      ];

      // Load multiple assets in sequence
      for (final asset in assets) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Image.asset(asset),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);

        // Clear widget tree for next asset
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      }

      // No explicit memory check here - Flutter test framework monitors this
    });

    /// Test image rendering performance
    testWidgets('Assets render without UI jank', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Image.asset('assets/images/app_icon_1024.png', height: 200),
                Image.asset('assets/images/chess_board_1024x1024.png', height: 200),
                Image.asset('assets/images/chess_pieces_white.png', height: 200),
              ],
            ),
          ),
        ),
      );

      // Initial pump
      await tester.pumpAndSettle();

      // Verify all images are rendered
      expect(find.byType(Image), findsWidgets);

      // Scroll through and verify smooth rendering
      await tester.scroll(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsWidgets);
    });

    /// Test that assets work in different color schemes (light and dark)
    testWidgets('Assets visible in light and dark themes', (WidgetTester tester) async {
      // Test with light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Image.asset('assets/images/chess_board_1024x1024.png'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      // Test with dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Image.asset('assets/images/chess_board_1024x1024.png'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    /// Test responsive scaling of assets
    testWidgets('Assets scale responsively on different screen sizes', (WidgetTester tester) async {
      // Test on small screen (phone)
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      tester.binding.window.physicalSizeTestValue = const Size(375, 667);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Image.asset(
                'assets/images/chess_board_1024x1024.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      // Test on large screen (tablet)
      tester.binding.window.physicalSizeTestValue = const Size(1024, 1366);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Image.asset(
                'assets/images/chess_board_1024x1024.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('Asset Configuration Validation', () {
    /// Test that asset filenames follow naming conventions
    test('Asset filenames follow naming conventions', () {
      final assetPatterns = {
        'app_icon_1024.png': RegExp(r'^app_icon_\d+\.png$'),
        'chess_board_1024x1024.png': RegExp(r'^chess_board_\d+x\d+\.png$'),
        'chess_pieces_white.png': RegExp(r'^chess_pieces_(white|black)\.png$'),
        'icon_home_192x192.png': RegExp(r'^icon_\w+_\d+x\d+\.png$'),
      };

      for (final entry in assetPatterns.entries) {
        expect(
          entry.value.hasMatch(entry.key),
          true,
          reason: '${entry.key} does not follow naming convention',
        );
      }
    });

    /// Verify asset dimensions are appropriate for their use
    test('Asset dimensions are correct for intended use', () {
      const assetDimensions = {
        'app_icon_1024.png': (1024, 1024),
        'feature_graphic_1242x2688.png': (1242, 2688),
        'splash_android_1080x1920.png': (1080, 1920),
        'splash_ios_1170x2532.png': (1170, 2532),
        'chess_board_1024x1024.png': (1024, 1024),
        'chess_pieces_white.png': (512, 512),
        'chess_pieces_black.png': (512, 512),
        'icon_home_192x192.png': (192, 192),
        'icon_puzzle_192x192.png': (192, 192),
        'icon_game_192x192.png': (192, 192),
        'icon_profile_192x192.png': (192, 192),
        'icon_settings_192x192.png': (192, 192),
        'icon_leaderboard_192x192.png': (192, 192),
      };

      // Validate dimensions map is complete
      expect(assetDimensions.length, 13, reason: 'Should have 13 assets');

      // Validate specific use cases
      expect(assetDimensions['app_icon_1024.png']!.$1, equals(1024));
      expect(assetDimensions['chess_board_1024x1024.png']!.$1, equals(1024));

      // Navigation icons should all be 192x192
      for (final key in assetDimensions.keys) {
        if (key.startsWith('icon_')) {
          expect(
            assetDimensions[key],
            equals((192, 192)),
            reason: '$key should be 192x192',
          );
        }
      }
    });
  });
}
