import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reader_foot.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

Widget _host({
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  VoidCallback? onListen,
  VoidCallback? onMenu,
  double scale = 1,
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
          child: ReaderFoot(
            colors: MushafPaper.cream.colors,
            onPrevious: onPrevious,
            onNext: onNext,
            onListen: onListen,
            onMenu: onMenu ?? () {},
          ),
        ),
      ],
    ),
  ),
);

void _noop() {}

void main() {
  testWidgets('shows the four controls with their labels', (tester) async {
    await tester.pumpWidget(
      _host(onPrevious: _noop, onNext: _noop, onListen: _noop),
    );
    for (final key in [
      'foot-previous',
      'foot-listen',
      'foot-menu',
      'foot-next',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.text('استماع'), findsOneWidget);
    expect(find.text('القائمة'), findsOneWidget);
    expect(find.byTooltip('الصفحة السابقة'), findsOneWidget);
    expect(find.byTooltip('الصفحة التالية'), findsOneWidget);
  });

  testWidgets('each control calls its callback', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      _host(
        onPrevious: () => taps.add('previous'),
        onNext: () => taps.add('next'),
        onListen: () => taps.add('listen'),
        onMenu: () => taps.add('menu'),
      ),
    );
    for (final key in [
      'foot-previous',
      'foot-listen',
      'foot-menu',
      'foot-next',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
    }
    expect(taps, ['previous', 'listen', 'menu', 'next']);
  });

  testWidgets('null callbacks disable previous and listen', (tester) async {
    await tester.pumpWidget(_host(onNext: _noop));
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('foot-previous')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const ValueKey('foot-listen')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('both pills are at least 56 px tall', (tester) async {
    await tester.pumpWidget(_host(onListen: _noop));
    for (final key in ['foot-listen', 'foot-menu']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(56),
      );
    }
  });

  testWidgets('fits at 2x text', (tester) async {
    await tester.pumpWidget(_host(onListen: _noop, scale: 2));
    expect(tester.getSize(find.byType(ReaderFoot)).height, 64);
    expect(tester.takeException(), isNull);
  });
}
