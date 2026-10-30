import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/screens/auth/login_screen.dart';

Future<void> _pump(WidgetTester tester, TargetPlatform platform) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('ja'));

  testWidgets('Android: Google だけを出し、Apple は出さない', (tester) async {
    await _pump(tester, TargetPlatform.android);

    expect(find.text(l10n.loginSignInWithGoogleButton), findsOneWidget);
    expect(find.text(l10n.loginSignInWithAppleButton), findsNothing);
  });

  testWidgets('iOS: Google と Apple の両方を出す', (tester) async {
    await _pump(tester, TargetPlatform.iOS);

    expect(find.text(l10n.loginSignInWithGoogleButton), findsOneWidget);
    expect(find.text(l10n.loginSignInWithAppleButton), findsOneWidget);
  });

  testWidgets('メール/パスワードの入力欄・新規登録・パスワード再設定は無い',
      (tester) async {
    await _pump(tester, TargetPlatform.android);

    expect(find.byType(TextField), findsNothing);
    expect(find.text(l10n.loginSignUpButton), findsNothing);
    expect(find.text(l10n.loginForgotPasswordButton), findsNothing);
    // 「ログイン」はタイトルと同じ文言なので、ボタン(FilledButton)の有無で見る。
    expect(find.byType(FilledButton), findsNothing);
  });
}
