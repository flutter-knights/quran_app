import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  Future<int?> openAndReturn(WidgetTester tester, String input) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await PageJumpSheet.show(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), input);
    await tester.tap(find.byKey(const ValueKey('page-jump-go')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('returns the entered page number', (tester) async {
    expect(await openAndReturn(tester, '42'), 42);
  });

  testWidgets('clamps above 604 to 604', (tester) async {
    expect(await openAndReturn(tester, '999'), 604);
  });

  testWidgets('ignores non-numeric / empty input (returns null)', (tester) async {
    expect(await openAndReturn(tester, 'abc'), isNull);
  });
}
