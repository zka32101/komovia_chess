import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/models/board_theme.dart';
import 'package:komovia_chess/src/models/piece_skin.dart';
import 'package:komovia_chess/src/models/user.dart';
import 'package:komovia_chess/src/providers/auth_provider.dart';
import 'package:komovia_chess/src/providers/board_theme_provider.dart';
import 'package:komovia_chess/src/providers/cosmetic_provider.dart';
import 'package:komovia_chess/src/providers/premium_provider.dart';
import 'package:komovia_chess/src/providers/user_preferences_provider.dart';
import 'package:komovia_chess/src/screens/settings/cosmetic_shop_screen.dart';
import 'package:komovia_chess/src/widgets/game_board.dart';
import 'package:chess/chess.dart' as chess_lib;

List<Override> _overrides({
  required UserModel? user,
  bool subscribed = false,
  String legacyBoardStyle = 'default',
  Map<String, String> prices = const {},
  List<String>? purchased,
  List<Map<String, String?>>? equipped,
}) => [
  currentUserProvider.overrideWith((ref) => Stream.value(user)),
  userSubscriptionProvider.overrideWith(
    (ref) async => UserSubscription(
      tier: subscribed ? 'pro' : 'free',
      isActive: subscribed,
    ),
  ),
  userPreferencesProvider.overrideWith(
    (ref) async => UserPreferences(userId: 'u1', boardStyle: legacyBoardStyle),
  ),
  cosmeticPricesProvider.overrideWith((ref) async => prices),
  purchaseCosmeticProvider.overrideWithValue((id) async => purchased?.add(id)),
  equipCosmeticProvider.overrideWithValue(
    ({boardSkinId, pieceSkinId}) async =>
        equipped?.add({'board': boardSkinId, 'piece': pieceSkinId}),
  ),
];

Future<void> _pumpShop(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CosmeticShopScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inCard(String key, Finder f) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  const user = UserModel(uid: 'u1', email: 'a@b.c');

  testWidgets(
    'free user: free equipped/equippable, sub-only locked, IAP buyable',
    (tester) async {
      await _pumpShop(
        tester,
        _overrides(
          user: user,
          prices: const {'chess_skin_board_walnut': '¥300'},
        ),
      );

      expect(
        _inCard('board-skin-default', find.text('Equipped')),
        findsOneWidget,
      );
      expect(_inCard('board-skin-slate', find.text('Equip')), findsOneWidget);
      expect(
        _inCard('board-skin-forest', find.text('Subscribe to unlock')),
        findsOneWidget,
      );
      expect(
        _inCard('board-skin-forest', find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(
        _inCard('board-skin-walnut', find.text('Buy ¥300')),
        findsOneWidget,
      );
      // Tournament is both: not subscribed -> purchasable.
      expect(
        _inCard('board-skin-tournament', find.text('Buy')),
        findsOneWidget,
      );
    },
  );

  testWidgets('subscriber + purchased walnut: both owned and equippable', (
    tester,
  ) async {
    await _pumpShop(
      tester,
      _overrides(
        user: const UserModel(
          uid: 'u1',
          email: 'a@b.c',
          boardSkinId: 'walnut',
          purchasedCosmeticProductIds: ['chess_skin_board_walnut'],
        ),
        subscribed: true,
      ),
    );
    expect(_inCard('board-skin-walnut', find.text('Equipped')), findsOneWidget);
    expect(_inCard('board-skin-forest', find.text('Equip')), findsOneWidget);
    expect(_inCard('board-skin-carrara', find.text('Buy')), findsOneWidget);
  });

  testWidgets('Buy calls the purchase flow with the product id', (
    tester,
  ) async {
    final purchased = <String>[];
    await _pumpShop(tester, _overrides(user: user, purchased: purchased));
    await tester.tap(_inCard('board-skin-carrara', find.text('Buy')));
    await tester.pumpAndSettle();
    expect(purchased, ['chess_skin_board_carrara']);
  });

  testWidgets('Equip persists the board/piece skin id', (tester) async {
    final equipped = <Map<String, String?>>[];
    await _pumpShop(tester, _overrides(user: user, equipped: equipped));
    await tester.tap(_inCard('board-skin-slate', find.text('Equip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pieces'));
    await tester.pumpAndSettle();
    await tester.tap(_inCard('piece-skin-bold_outline', find.text('Equip')));
    await tester.pumpAndSettle();
    expect(equipped, [
      {'board': 'slate', 'piece': null},
      {'board': null, 'piece': 'bold_outline'},
    ]);
  });

  group('selected skin read-back', () {
    ProviderContainer container(List<Override> o) {
      final c = ProviderContainer(overrides: o);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle(ProviderContainer c) async {
      await c.read(currentUserProvider.future);
      await c.read(userSubscriptionProvider.future);
      await c.read(userPreferencesProvider.future);
    }

    test('user.boardSkinId/pieceSkinId resolve to the catalog skins', () async {
      final c = container(
        _overrides(
          user: const UserModel(
            uid: 'u1',
            email: 'a@b.c',
            boardSkinId: 'carrara',
            pieceSkinId: 'gold_onyx',
            purchasedCosmeticProductIds: [
              'chess_skin_board_carrara',
              'chess_skin_pieces_gold_onyx',
            ],
          ),
        ),
      );
      await settle(c);
      expect(c.read(selectedBoardThemeProvider).id, 'carrara');
      expect(c.read(selectedPieceSkinProvider).id, 'gold_onyx');
    });

    test('no selection -> default; legacy boardStyle still honored', () async {
      var c = container(_overrides(user: user));
      await settle(c);
      expect(c.read(selectedBoardThemeProvider).id, 'default');
      expect(c.read(selectedPieceSkinProvider).id, 'default');

      c = container(_overrides(user: user, legacyBoardStyle: 'marble'));
      await settle(c);
      expect(c.read(selectedBoardThemeProvider).id, 'marble');
    });

    test('unowned selection falls back to default', () async {
      final c = container(
        _overrides(
          user: const UserModel(
            uid: 'u1',
            email: 'a@b.c',
            boardSkinId: 'walnut',
            pieceSkinId: 'ebony',
          ),
        ),
      );
      await settle(c);
      expect(c.read(selectedBoardThemeProvider).id, 'default');
      expect(c.read(selectedPieceSkinProvider).id, 'default');
    });
  });

  testWidgets('GameBoard renders the board texture and piece skin', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GameBoard(
              gameState: chess_lib.Chess(),
              theme: BoardThemeCatalog.walnut,
              pieceSkin: PieceSkinCatalog.goldOnyx,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('board-skin-texture')), findsOneWidget);
    final glyphTexts = tester
        .widgetList<Text>(find.text('♚'))
        .map((t) => t.style?.color)
        .whereType<Color>()
        .toSet();
    expect(glyphTexts, contains(PieceSkinCatalog.goldOnyx.whiteFill));
    expect(glyphTexts, contains(PieceSkinCatalog.goldOnyx.blackFill));
  });
}
