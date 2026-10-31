import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/widgets/premium/ai_analysis_upsell.dart';

void main() {
  Widget host(Locale locale) => ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAiAnalysisUpsellDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('upsell dialog shows limit, plan, price and actions (ja)',
      (tester) async {
    await tester.pumpWidget(host(const Locale('ja')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('本日の無料AI分析を使い切りました'), findsOneWidget);
    expect(find.textContaining('1日3回まで'), findsOneWidget);
    expect(find.textContaining('AI分析プラン - 月額 ¥990'), findsOneWidget);
    expect(find.text('AI分析プランに加入する'), findsOneWidget);

    await tester.tap(find.text('あとで'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('upsell dialog is localized (en)', (tester) async {
    await tester.pumpWidget(host(const Locale('en')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Daily free AI analyses used up'), findsOneWidget);
    expect(find.text('Subscribe to AI Analysis Plan'), findsOneWidget);
  });
}
