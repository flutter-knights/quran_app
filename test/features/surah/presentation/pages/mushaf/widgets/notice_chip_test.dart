import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/notice_chip.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

Widget _host({
  required VoidCallback onTap,
  String? actionLabel,
  VoidCallback? onAction,
}) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('ar'), Locale('en')],
  locale: const Locale('ar'),
  home: Scaffold(
    body: Center(
      child: NoticeChip(
        label: 'العودة إلى صفحة ٥',
        onTap: onTap,
        colors: MushafPaper.cream.colors,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    ),
  ),
);

void main() {
  testWidgets('shows the label and calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(onTap: () => taps++));
    expect(find.text('العودة إلى صفحة ٥'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notice-chip')));
    expect(taps, 1);
  });

  testWidgets('the action button calls onAction and not onTap', (tester) async {
    var taps = 0;
    var actions = 0;
    await tester.pumpWidget(
      _host(
        onTap: () => taps++,
        actionLabel: 'فهمت',
        onAction: () => actions++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('notice-action')));
    expect(actions, 1);
    expect(taps, 0);
  });

  testWidgets('is at least 48 px tall', (tester) async {
    await tester.pumpWidget(_host(onTap: () {}));
    expect(
      tester.getSize(find.byKey(const ValueKey('notice-chip'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('is a live region', (tester) async {
    await tester.pumpWidget(_host(onTap: () {}));
    final semantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(NoticeChip),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });
}
