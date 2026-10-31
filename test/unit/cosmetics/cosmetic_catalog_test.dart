import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/board_theme.dart';
import 'package:komovia_chess/src/models/cosmetic_catalog.dart';
import 'package:komovia_chess/src/models/piece_skin.dart';
import 'package:komovia_chess/src/providers/cosmetic_provider.dart';

void main() {
  group('ChessCosmeticCatalog', () {
    test('ids are unique per category and product ids are unique', () {
      final boardIds = BoardThemeCatalog.all.map((t) => t.id).toList();
      final pieceIds = PieceSkinCatalog.all.map((s) => s.id).toList();
      expect(boardIds.toSet().length, boardIds.length);
      expect(pieceIds.toSet().length, pieceIds.length);
      final products = ChessCosmeticCatalog.all
          .map((i) => i.iapProductId)
          .whereType<String>()
          .toList();
      expect(products.toSet().length, products.length);
      expect(ChessCosmeticCatalog.purchasableProductIds, {
        'chess_skin_board_walnut',
        'chess_skin_board_carrara',
        'chess_skin_board_tournament',
        'chess_skin_pieces_gold_onyx',
        'chess_skin_pieces_sapphire',
      });
    });

    test('free skins stay free for everyone (never paywall the basics)', () {
      for (final id in ['default', 'wooden', 'marble', 'green', 'slate']) {
        expect(
          BoardThemeCatalog.byId(id).cosmetic.isFreeForAll,
          isTrue,
          reason: id,
        );
      }
      for (final id in ['default', 'bold_outline', 'classic_ivory']) {
        expect(
          PieceSkinCatalog.byId(id).cosmetic.isFreeForAll,
          isTrue,
          reason: id,
        );
      }
    });

    test('ownership: free user owns only free skins', () {
      final owned = ChessCosmeticCatalog.all
          .where(
            (i) => i.isOwnedBy(
              hasActiveSubscription: false,
              purchasedProductIds: const {},
            ),
          )
          .map((i) => i.id)
          .toSet();
      expect(owned, {
        'default', 'wooden', 'marble', 'green', 'slate', // boards
        'bold_outline', 'classic_ivory', // pieces ('default' shared id)
      });
    });

    test('ownership: subscriber gets subscription skins but not IAP-only', () {
      bool owns(String id, String cat) => ChessCosmeticCatalog.all
          .firstWhere((i) => i.id == id && i.category == cat)
          .isOwnedBy(
            hasActiveSubscription: true,
            purchasedProductIds: const {},
          );
      expect(owns('forest', 'boardSkin'), isTrue);
      expect(owns('tournament', 'boardSkin'), isTrue);
      expect(owns('ebony', 'pieceSkin'), isTrue);
      expect(owns('sapphire', 'pieceSkin'), isTrue);
      expect(owns('walnut', 'boardSkin'), isFalse);
      expect(owns('gold_onyx', 'pieceSkin'), isFalse);
    });

    test('ownership: one-time purchase unlocks only that skin', () {
      final walnut = BoardThemeCatalog.walnut.cosmetic;
      final carrara = BoardThemeCatalog.carrara.cosmetic;
      const bought = {'chess_skin_board_walnut'};
      expect(
        walnut.isOwnedBy(
          hasActiveSubscription: false,
          purchasedProductIds: bought,
        ),
        isTrue,
      );
      expect(
        carrara.isOwnedBy(
          hasActiveSubscription: false,
          purchasedProductIds: bought,
        ),
        isFalse,
      );
    });
  });

  group('resolveBoardSkin', () {
    test('null / unknown id falls back to the default skin', () {
      expect(
        resolveBoardSkin(
          null,
          hasActiveSubscription: false,
          purchasedProductIds: const {},
        ).id,
        'default',
      );
      expect(
        resolveBoardSkin(
          'nope',
          hasActiveSubscription: false,
          purchasedProductIds: const {},
        ).id,
        'default',
      );
    });

    test('owned skin resolves, locked skin falls back', () {
      expect(
        resolveBoardSkin(
          'walnut',
          hasActiveSubscription: false,
          purchasedProductIds: const {'chess_skin_board_walnut'},
        ).id,
        'walnut',
      );
      expect(
        resolveBoardSkin(
          'walnut',
          hasActiveSubscription: true,
          purchasedProductIds: const {},
        ).id,
        'default',
      );
      // Lapsed subscription: subscription skin no longer applies.
      expect(
        resolveBoardSkin(
          'forest',
          hasActiveSubscription: false,
          purchasedProductIds: const {},
        ).id,
        'default',
      );
    });
  });

  group('PieceSkin readability invariant', () {
    for (final skin in PieceSkinCatalog.all) {
      test(
        '${skin.id}: white light/dark-outlined, black dark/light-outlined',
        () {
          final whiteFill =
              skin.whiteFill ?? BoardThemeCatalog.classic.whitePieceColor;
          final blackFill =
              skin.blackFill ?? BoardThemeCatalog.classic.blackPieceColor;
          expect(whiteFill.computeLuminance(), greaterThan(0.45));
          expect(blackFill.computeLuminance(), lessThan(0.1));
          expect(
            whiteFill.computeLuminance() - blackFill.computeLuminance(),
            greaterThan(0.45),
          );
          expect(skin.whiteOutline.computeLuminance(), lessThan(0.1));
          final blackOutlineOnBlack = Color.alphaBlend(
            skin.blackOutline,
            blackFill,
          );
          expect(blackOutlineOnBlack.computeLuminance(), greaterThan(0.25));
          expect(skin.whiteStrokeScale, greaterThan(0));
          expect(skin.blackStrokeScale, greaterThan(0));
        },
      );
    }
  });
}
