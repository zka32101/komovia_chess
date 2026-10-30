import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/widgets/avatar_picker.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  group('AvatarEmoji', () {
    testWidgets('renders the default preset for a null avatarId '
        '(every pre-existing user)', (tester) async {
      await tester.pumpWidget(wrap(const AvatarEmoji(avatarId: null)));
      expect(find.text(defaultAvatarIcon.emoji), findsOneWidget);
    });

    testWidgets('renders the default preset for an empty-string avatarId',
        (tester) async {
      await tester.pumpWidget(wrap(const AvatarEmoji(avatarId: '')));
      expect(find.text(defaultAvatarIcon.emoji), findsOneWidget);
    });

    testWidgets('renders the default preset for an unrecognized avatarId '
        'rather than crashing', (tester) async {
      await tester.pumpWidget(
        wrap(const AvatarEmoji(avatarId: 'does-not-exist')),
      );
      expect(find.text(defaultAvatarIcon.emoji), findsOneWidget);
    });

    testWidgets('renders the matching preset emoji for a real avatarId',
        (tester) async {
      await tester.pumpWidget(wrap(const AvatarEmoji(avatarId: 'owl')));
      expect(find.text('🦉'), findsOneWidget);
    });
  });

  group('showAvatarPickerSheet', () {
    testWidgets('shows every preset from kAvatarIcons', (tester) async {
      late Future<String?> result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                result = showAvatarPickerSheet(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final icon in kAvatarIcons) {
        expect(find.text(icon.emoji), findsOneWidget);
      }
      // Drain the still-open sheet's Future so the test doesn't leave a
      // pending route behind.
      unawaited(result);
    });

    testWidgets('tapping a preset then Save resolves with its id',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await showAvatarPickerSheet(
                  context,
                  currentAvatarId: 'fox',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🦉')); // owl
      await tester.pumpAndSettle();

      // The sheet's own "Save" button - the default (en) locale's text
      // for avatarPickerSaveButton, same convention other widget tests in
      // this suite use for localized button labels.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(selected, 'owl');
    });

    testWidgets('dismissing without a selection resolves with null',
        (tester) async {
      String? selected = 'not-yet-resolved';
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await showAvatarPickerSheet(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap outside the sheet to dismiss it (modal barrier).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(selected, isNull);
    });
  });
}
