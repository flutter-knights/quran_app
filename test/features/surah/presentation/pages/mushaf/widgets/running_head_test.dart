import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/running_head.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

Widget _host({
  String surahName = 'آل عمران',
  int page = 50,
  int juz = 3,
  int hizb = 5,
  double scale = 1,
  VoidCallback? onBack,
  VoidCallback? onOpenMenu,
}) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('ar'), Locale('en')],
  locale: const Locale('ar'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Column(
      children: [
        SizedBox(
          width: 360,
          child: RunningHead(
            surahName: surahName,
            page: page,
            juz: juz,
            hizb: hizb,
            colors: MushafPaper.cream.colors,
            onBack: onBack ?? () {},
            onOpenMenu: onOpenMenu ?? () {},
          ),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('prints the surah, the page and the juz and hizb', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text('آل عمران'), findsOneWidget);
    expect(find.text('٥٠'), findsOneWidget);
    expect(find.text('الجزء ٣، الحزب ٥'), findsOneWidget);
  });

  testWidgets('back calls onBack', (tester) async {
    var backs = 0;
    await tester.pumpWidget(_host(onBack: () => backs++));
    await tester.tap(find.byKey(const ValueKey('head-back')));
    expect(backs, 1);
  });

  testWidgets('the surah and the juz each open the menu', (tester) async {
    var opens = 0;
    await tester.pumpWidget(_host(onOpenMenu: () => opens++));
    await tester.tap(find.byKey(const ValueKey('head-surah')));
    await tester.tap(find.byKey(const ValueKey('head-juz')));
    expect(opens, 2);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('is 64 px tall at ${scale}x text', (tester) async {
      await tester.pumpWidget(_host(scale: scale));
      expect(tester.getSize(find.byType(RunningHead)).height, 64);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long labels stay on one line at 2x text', (tester) async {
    await tester.pumpWidget(
      _host(surahName: 'الأحزاب', juz: 30, hizb: 60, scale: 2),
    );
    expect(tester.takeException(), isNull);
    for (final key in ['head-surah', 'head-juz']) {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, 1);
    }
  });
}
