import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/models/avatar_frames.dart';
import 'package:komovia_chess/src/models/user.dart';
import 'package:komovia_chess/src/widgets/avatar_picker.dart';

UserModel _user({
  int rating = 1200,
  int wins = 0,
  int gamesPlayed = 0,
  int puzzlesSolved = 0,
  int dailyStreak = 0,
  String? frameId,
  List<String> unlocked = const [],
}) => UserModel(
  uid: 'u1',
  email: 'u1@example.com',
  rating: rating,
  wins: wins,
  gamesPlayed: gamesPlayed,
  puzzlesSolved: puzzlesSolved,
  dailyStreak: dailyStreak,
  frameId: frameId,
  unlockedFrameIds: unlocked,
);

void main() {
  group('catalog', () {
    test('has 8-12 frames with unique ids spanning every tier', () {
      expect(kAvatarFrames.length, inInclusiveRange(8, 12));
      final ids = kAvatarFrames.map((r) => r.frame.id).toSet();
      expect(ids.length, kAvatarFrames.length);
      expect(
        kAvatarFrames.map((r) => r.frame.tier).toSet(),
        FrameTier.values.toSet(),
      );
    });

    test('avatarFrameById resolves known ids and rejects unknown', () {
      expect(avatarFrameById('first_win')?.frame.tier, FrameTier.bronze);
      expect(avatarFrameById('nope'), isNull);
      expect(avatarFrameById(null), isNull);
    });
  });

  group('unlock derivation', () {
    test('a brand-new user has nothing unlocked', () {
      expect(unlockedFrameIdsFor(_user()), isEmpty);
    });

    test('live frames follow current counters', () {
      final ids = unlockedFrameIdsFor(
        _user(wins: 1, gamesPlayed: 10, puzzlesSolved: 50),
      );
      expect(
        ids,
        containsAll(['first_win', 'games_10', 'first_puzzle', 'puzzles_50']),
      );
      expect(ids, isNot(contains('games_100')));
    });

    test('peak rating frame stays unlocked after rating drops', () {
      final dropped = _user(rating: 1350, unlocked: ['rating_1400']);
      expect(unlockedFrameIdsFor(dropped), contains('rating_1400'));
      expect(
        unlockedFrameIdsFor(_user(rating: 1350)),
        isNot(contains('rating_1400')),
      );
    });

    test('newlyEarnedPeakFrameIds only returns unpersisted peaks', () {
      final u = _user(rating: 1850, dailyStreak: 7, unlocked: ['rating_1400']);
      expect(
        newlyEarnedPeakFrameIds(u),
        unorderedEquals(['rating_1800', 'puzzle_streak_7']),
      );
    });

    test('peakFrameIdsForStats maps rating and streak', () {
      expect(
        peakFrameIdsForStats(rating: 2000),
        unorderedEquals(['rating_1400', 'rating_1800', 'rating_2000']),
      );
      expect(peakFrameIdsForStats(puzzleStreak: 6), isEmpty);
      expect(peakFrameIdsForStats(puzzleStreak: 7), ['puzzle_streak_7']);
    });

    test('resolveDisplayedFrame falls back to none when locked/unknown', () {
      expect(resolveDisplayedFrame(_user(frameId: 'first_win')), isNull);
      expect(resolveDisplayedFrame(_user(frameId: 'bogus', wins: 5)), isNull);
      expect(
        resolveDisplayedFrame(_user(frameId: 'first_win', wins: 1))?.id,
        'first_win',
      );
      expect(resolveDisplayedFrame(null), isNull);
    });
  });

  group('widgets', () {
    Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    testWidgets('AvatarEmoji renders a frame border only when given one', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const AvatarEmoji(avatarId: 'owl')));
      expect(
        find.byKey(const ValueKey('avatar-frame-first_win')),
        findsNothing,
      );
      await tester.pumpWidget(
        wrap(
          const AvatarEmoji(
            avatarId: 'owl',
            frame: AvatarFrame(id: 'first_win', name: 'First Win'),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('avatar-frame-first_win')),
        findsOneWidget,
      );
    });

    testWidgets('picker lists locked frames with requirement and returns '
        'an unlocked selection', (tester) async {
      AvatarPickerResult? result;
      final user = _user(wins: 1);
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAvatarPickerSheet(
                  context,
                  currentAvatarId: 'owl',
                  user: user,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final r in kAvatarFrames) {
        expect(
          find.byKey(ValueKey('frame-choice-${r.frame.id}')),
          findsOneWidget,
        );
      }
      expect(find.text('Locked: Reach rating 2000'), findsOneWidget);

      // Tapping a locked frame does nothing.
      final locked = find.byKey(const ValueKey('frame-choice-rating_2000'));
      await tester.ensureVisible(locked);
      await tester.tap(locked);
      final unlocked = find.byKey(const ValueKey('frame-choice-first_win'));
      await tester.ensureVisible(unlocked);
      await tester.tap(unlocked);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result?.avatarId, 'owl');
      expect(result?.frameId, 'first_win');
    });
  });

  group('lifetime-exclusive frame', () {
    test('is never earned from stats, only from persisted unlock', () {
      final r = avatarFrameById('eternal_laurel')!;
      expect(r.frame.lifetimeExclusive, isTrue);
      final maxed = _user(
        rating: 3000,
        wins: 9999,
        gamesPlayed: 9999,
        puzzlesSolved: 9999,
        dailyStreak: 999,
      );
      expect(unlockedFrameIdsFor(maxed), isNot(contains('eternal_laurel')));
      expect(newlyEarnedPeakFrameIds(maxed), isNot(contains('eternal_laurel')));
      expect(
        unlockedFrameIdsFor(_user(unlocked: const ['eternal_laurel'])),
        contains('eternal_laurel'),
      );
    });
  });
}

