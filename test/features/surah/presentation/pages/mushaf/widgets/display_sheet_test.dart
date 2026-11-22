import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/leaf_tap_action.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../notifications/presentation/alerts_test_harness.dart'
    show loadAppFonts;

class _MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override
  dynamic read(String key) => _m[key];
  @override
  Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => HydratedBloc.storage = _MemStorage());

  Future<void> pumpSheet(
    WidgetTester tester,
    SettingsCubit cubit,
    String locale,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: DisplaySheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('paper swatches are named', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'ar');
    for (final name in [
      'كريمي',
      'سيبيا',
      'أخضر',
      'أبيض',
      'ليلي',
      'ليلي أزرق',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }

    await pumpSheet(tester, cubit, 'en');
    expect(find.text('White'), findsOneWidget);
  });

  testWidgets('the selected swatch is announced as selected', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'en');
    final handle = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cream')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sepia')),
        isNot(isSemantics(isSelected: true)),
      );
    } finally {
      handle.dispose();
    }
  });

  for (final locale in ['en', 'ar']) {
    testWidgets(
      'swatch captions are not truncated on a 360dp phone ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cubit = SettingsCubit();
        addTearDown(cubit.close);
        await loadAppFonts();
        await pumpSheet(tester, cubit, locale);

        for (final p in MushafPaper.values) {
          final caption = find.descendant(
            of: find.byKey(ValueKey('reading-paper-${p.name}')),
            matching: find.byType(Text),
          );
          expect(
            tester.renderObject<RenderParagraph>(caption).didExceedMaxLines,
            isFalse,
            reason: '${p.name} ($locale)',
          );
        }
      },
    );
  }

  testWidgets('tapping the night swatch updates the paper setting', (
    tester,
  ) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'en');

    await tester.tap(find.byKey(const ValueKey('reading-paper-night')));
    await tester.pump();
    expect(cubit.state.settingsModel.mushafPaper, MushafPaper.night);
  });

  testWidgets('tapping the Scroll segment updates the reading mode', (
    tester,
  ) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'en');

    expect(cubit.state.settingsModel.readingMode, MushafReadingMode.page);
    await tester.tap(find.text('Scroll'));
    await tester.pump();
    expect(cubit.state.settingsModel.readingMode, MushafReadingMode.scroll);
  });

  testWidgets('dragging brightness fades the sheet body, restores on end', (
    tester,
  ) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'en');

    AnimatedOpacity body() => tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('reading-sheet-body')),
    );
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('reading-brightness-slider')),
    );

    expect(body().opacity, 1.0);

    slider.onChangeStart!(0.8);
    await tester.pump();
    expect(body().opacity, lessThan(0.5));

    slider.onChanged!(0.6); // still updates the live brightness
    await tester.pump();
    expect(cubit.state.settingsModel.pageBrightness, 0.6);

    slider.onChangeEnd!(0.6);
    await tester.pump();
    expect(body().opacity, 1.0);
  });

  testWidgets('the brightness slider starts at the 0.6 floor', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'en');
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('reading-brightness-slider')),
    );
    expect(slider.min, Settings.minPageBrightness);
  });

  testWidgets('the keep-screen-on switch updates the setting', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'en');
    expect(cubit.state.settingsModel.keepScreenOn, isTrue);
    await tester.tap(find.byKey(const ValueKey('display-keep-awake')));
    await tester.pump();
    expect(cubit.state.settingsModel.keepScreenOn, isFalse);
    await tester.tap(find.byKey(const ValueKey('display-keep-awake')));
    await tester.pump();
    expect(cubit.state.settingsModel.keepScreenOn, isTrue);
  });

  testWidgets('done closes the sheet and is at least 48 by 48', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => DisplaySheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final done = find.byKey(const ValueKey('display-done'));
    expect(done, findsOneWidget);
    final size = tester.getSize(done);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(done, findsNothing);
  });

  testWidgets(
    'paper tiles draw a mini page and show a name of at least 14 px',
    (tester) async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await pumpSheet(tester, cubit, 'en');
      for (final p in MushafPaper.values) {
        final tile = find.byKey(ValueKey('reading-paper-${p.name}'));
        final paint = find.descendant(
          of: tile,
          matching: find.byType(CustomPaint),
        );
        expect(paint, findsOneWidget, reason: p.name);
        expect(
          tester.renderObject(paint),
          paints
            ..rect(color: p.colors.background)
            ..rect(color: p.colors.accent)
            ..line(color: p.colors.ink)
            ..line(color: p.colors.ink),
          reason: p.name,
        );
        final text = tester.widget<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        );
        expect(text.style!.fontSize, TS.medium14.fontSize, reason: p.name);
      }
    },
  );

  testWidgets('the title reads العرض and the sections are named', (
    tester,
  ) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'ar');
    for (final label in [
      'العرض',
      'لون الورق',
      'السطوع',
      'طريقة القراءة',
      'عند الضغط على الآية',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the tap-action selector starts on المعنى', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'ar');
    final toggle = tester.widget<AppSegmentedSelector<LeafTapAction>>(
      find.byKey(const ValueKey('tap-action-toggle')),
    );
    expect(toggle.selected, LeafTapAction.meaning);
    expect(find.text('المعنى'), findsOneWidget);
  });

  testWidgets('the tap-action selector stores الخيارات', (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await pumpSheet(tester, cubit, 'ar');
    await tester.ensureVisible(find.text('الخيارات'));
    await tester.tap(find.text('الخيارات'));
    await tester.pump();
    expect(cubit.state.settingsModel.tapAction, LeafTapAction.options);
    final toggle = tester.widget<AppSegmentedSelector<LeafTapAction>>(
      find.byKey(const ValueKey('tap-action-toggle')),
    );
    expect(toggle.selected, LeafTapAction.options);
  });
}
