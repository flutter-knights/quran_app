import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/android_sdk_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/prayer_strip_settings_page.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/strip_preview.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../alerts_test_harness.dart';

class _MockToday extends MockCubit<TodayPrayerTimesState>
    implements TodayPrayerTimesCubit {}

class _MockSdk extends MockCubit<int?> implements AndroidSdkCubit {}

void main() {
  late SettingsCubit cubit;
  late _MockToday today;
  late _MockSdk sdk;

  setUpAll(() async {
    HydratedBloc.storage = MemStorage();
    await loadAppFonts();
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    cubit = SettingsCubit();
    today = _MockToday();
    sdk = _MockSdk();
  });
  tearDown(() async {
    await cubit.close();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    bool pinned = true,
    StripStyle style = const StripStyle(),
    String locale = 'ar',
    TodayPrayerTimesState? todayState,
    int? sdkInt,
    DateTime Function()? now,
    bool settle = true,
    AlertsSyncCubit? alertsSync,
  }) async {
    phone(tester);
    cubit.updateSettings(isArabic: locale == 'ar');
    cubit.updatePrayerStripPinned(pinned);
    cubit.updateStripStyle(style);
    whenListen(
      today,
      const Stream<TodayPrayerTimesState>.empty(),
      initialState: todayState ?? TodayPrayerTimesLoaded(cairoToday()),
    );
    whenListen(sdk, const Stream<int?>.empty(), initialState: sdkInt);
    await tester.pumpWidget(
      alertsApp(
        settings: cubit,
        locale: locale,
        alertsSync: alertsSync,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TodayPrayerTimesCubit>.value(value: today),
            BlocProvider<AndroidSdkCubit>.value(value: sdk),
          ],
          child: now == null
              ? const PrayerStripSettingsPage()
              : PrayerStripSettingsPage(now: now),
        ),
      ),
    );
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 100));
  }

  BoxDecoration cellBox(WidgetTester tester, String label) =>
      tester
              .widget<DecoratedBox>(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  AppSettingsTile tile(WidgetTester tester, String title) =>
      tester.widget(find.widgetWithText(AppSettingsTile, title));

  SwitchListTile switchRow(WidgetTester tester, String title) =>
      tester.widget(find.widgetWithText(SwitchListTile, title));

  AppSegmentedSelector<bool> toggle(WidgetTester tester) =>
      tester.widget(find.byType(AppSegmentedSelector<bool>));

  group('page', () {
    testWidgets('strip off makes the other rows inert', (tester) async {
      await pumpPage(tester, pinned: false);
      expect(switchRow(tester, 'إظهار الشريط').onChanged, isNotNull);
      expect(switchRow(tester, 'استخدام عرض موسّع').onChanged, isNull);
      expect(switchRow(tester, 'إظهار العدّاد').onChanged, isNull);
      for (final title in ['لون التمييز', 'لون الخلفية', 'شكل التمييز']) {
        expect(tile(tester, title).enabled, isFalse, reason: title);
      }
    });

    testWidgets('the show switch writes the pinned flag', (tester) async {
      await pumpPage(tester, pinned: false);
      await tapVisible(tester, find.text('إظهار الشريط'));
      expect(cubit.state.settingsModel.isPrayerStripPinned, isTrue);
      expect(tile(tester, 'لون التمييز').enabled, isTrue);
    });

    testWidgets('expanded on opens the preview on the expanded view', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(toggle(tester).selected, isTrue);
      expect(find.text('التالية'), findsOneWidget);
      await tapVisible(tester, find.text('مطويّ'));
      expect(toggle(tester).selected, isFalse);
      expect(find.text('التالية'), findsNothing);
    });

    testWidgets('expanded off fixes the preview toggle to collapsed', (
      tester,
    ) async {
      await pumpPage(tester, style: const StripStyle(expanded: false));
      expect(toggle(tester).selected, isFalse);
      expect(toggle(tester).enabled, isFalse);
      await tester.tap(find.text('موسّع'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(toggle(tester).selected, isFalse);
    });

    testWidgets('the expanded switch writes the style', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('استخدام عرض موسّع'));
      expect(cubit.state.settingsModel.stripStyle.expanded, isFalse);
      expect(toggle(tester).selected, isFalse);
    });

    testWidgets('countdown switch shows the digits note', (tester) async {
      await pumpPage(tester);
      expect(find.text('أرقام العدّاد تتبع لغة الهاتف'), findsOneWidget);
      expect(find.textContaining(' بعد · '), findsOneWidget);
      await tapVisible(tester, find.text('إظهار العدّاد'));
      expect(cubit.state.settingsModel.stripStyle.showCountdown, isFalse);
      expect(find.textContaining(' بعد · '), findsNothing);
    });

    testWidgets('picking a highlight writes the style', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('لون التمييز'));
      await tapVisible(tester, find.text('عنابي'));
      expect(
        cubit.state.settingsModel.stripStyle.highlight,
        StripHighlight.maroon,
      );
      expect(find.text('عنابي'), findsOneWidget);
    });

    testWidgets('picking a background and a shape writes the style', (
      tester,
    ) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('لون الخلفية'));
      await tapVisible(tester, find.text('رملي'));
      await tapVisible(tester, find.text('شكل التمييز'));
      await tapVisible(tester, find.text('إطار'));
      final style = cubit.state.settingsModel.stripStyle;
      expect(style.background, StripBackground.sand);
      expect(style.shape, StripShape.outline);
      expect(style.highlight, StripHighlight.app);
    });

    testWidgets('the preview is a skeleton while today\'s times load', (
      tester,
    ) async {
      await pumpPage(
        tester,
        todayState: const TodayPrayerTimesLoading(),
        settle: false,
      );
      expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    });

    testWidgets('no cached times shows a static sample, not a skeleton', (
      tester,
    ) async {
      await pumpPage(tester, todayState: const TodayPrayerTimesEmpty());
      expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsNothing);
      expect(find.text('الفجر'), findsOneWidget);
      expect(find.text('٠٤:٥٠ ص'), findsOneWidget);
    });

    testWidgets('the preview follows the 24-hour setting like the strip', (
      tester,
    ) async {
      cubit.updateSettings(isFormat12Hours: true);
      await pumpPage(tester);
      expect(find.text('١٨:١٩'), findsOneWidget);
      expect(find.text('٠٦:١٩ م'), findsNothing);
    });

    testWidgets('below API 31 the next cell is a flat filled rectangle', (
      tester,
    ) async {
      await pumpPage(
        tester,
        sdkInt: 30,
        now: () => DateTime(2026, 11, 15, 16, 30),
        style: const StripStyle(
          highlight: StripHighlight.maroon,
          shape: StripShape.outline,
        ),
      );
      final box = cellBox(tester, 'المغرب');
      expect(box.color, const Color(0xFF9A3B3B));
      expect(box.border, isNull);
      expect(box.borderRadius, isNull);
    });

    testWidgets('API 31 keeps the outline stroke', (tester) async {
      await pumpPage(
        tester,
        sdkInt: 31,
        now: () => DateTime(2026, 11, 15, 16, 30),
        style: const StripStyle(
          highlight: StripHighlight.maroon,
          shape: StripShape.outline,
        ),
      );
      final box = cellBox(tester, 'المغرب');
      expect(box.color, isNull);
      expect(box.border, isNotNull);
    });

    testWidgets('the preview advances once a minute', (tester) async {
      var now = DateTime(2026, 11, 15, 16, 58, 30);
      await pumpPage(tester, now: () => now);
      expect(cellBox(tester, 'المغرب').color, isNotNull);
      expect(cellBox(tester, 'العشاء').color, isNull);
      expect(find.textContaining('المغرب بعد · ٠٠:٣٠'), findsOneWidget);
      now = DateTime(2026, 11, 15, 16, 59, 30);
      await tester.pump(const Duration(seconds: 59));
      expect(cellBox(tester, 'المغرب').color, isNotNull);
      await tester.pump(const Duration(seconds: 1));
      expect(cellBox(tester, 'المغرب').color, isNull);
      expect(cellBox(tester, 'العشاء').color, isNotNull);
      expect(find.textContaining('العشاء بعد · ١:١٩:٣٠'), findsOneWidget);
    });

    for (final locale in ['ar', 'en']) {
      testWidgets('smoke $locale: page and option sheets fit a phone', (
        tester,
      ) async {
        await pumpPage(
          tester,
          locale: locale,
          style: const StripStyle(
            highlight: StripHighlight.indigo,
            background: StripBackground.mint,
            shape: StripShape.pill,
          ),
        );
        final ar = locale == 'ar';
        if (ar) {
          final ascii = find.byWidgetPredicate(
            (w) => w is Text && RegExp('[0-9]').hasMatch(w.data ?? ''),
          );
          expect(ascii, findsNothing);
        }
        await tapVisible(tester, find.text(ar ? 'مطويّ' : 'Collapsed'));
        for (final (title, option) in [
          (ar ? 'لون التمييز' : 'Highlight colour', ar ? 'برونزي' : 'Bronze'),
          (ar ? 'لون الخلفية' : 'Background colour', ar ? 'وردي' : 'Rose'),
          (ar ? 'شكل التمييز' : 'Highlight shape', ar ? 'بدون' : 'None'),
        ]) {
          await tapVisible(tester, find.text(title));
          await tapVisible(tester, find.text(option));
        }
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            ar
                ? 'يلوّن مساحة الأوقات فقط، ويبقى رأس الإشعار بلون النظام.'
                : 'Colours only the times area; the notification header keeps the system colour.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('StripPreview', () {
    PrayerStripState stripFor({String locale = 'ar', bool friday = false}) =>
        PrayerStripStateBuilder.build(
          prayerTimes: cairoToday(),
          nextPrayer: PrayerName.maghrib,
          localeCode: locale,
          isFriday: friday,
          use24Hour: false,
          nextInLabel: (p) => locale == 'ar' ? '$p بعد' : '$p in',
        );

    Future<void> pumpPreview(
      WidgetTester tester,
      StripStyle style, {
      bool expanded = false,
      bool night = false,
      PrayerStripState? strip,
      String locale = 'ar',
      bool tintable = true,
    }) async {
      phone(tester);
      tester.platformDispatcher.platformBrightnessTestValue = night
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        alertsApp(
          settings: cubit,
          locale: locale,
          home: Scaffold(
            body: StripPreview(
              strip: strip ?? stripFor(locale: locale),
              style: style,
              expanded: expanded,
              palette: ColorPalette.neutralLight,
              now: DateTime(2026, 11, 15, 16, 30),
              tintable: tintable,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color? ink(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    testWidgets('rounded fill uses the day swatch and pill text', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        const StripStyle(highlight: StripHighlight.maroon),
      );
      final box = cellBox(tester, 'المغرب');
      expect(box.color, const Color(0xFF9A3B3B));
      expect(box.borderRadius, BorderRadius.circular(8));
      expect(ink(tester, 'المغرب'), const Color(0xFFFFFFFF));
      expect(ink(tester, '٠٤:٥٩'), const Color(0xFFFFFFFF));
      expect(ink(tester, 'الفجر'), const Color(0x6F000000));
      expect(ink(tester, 'العشاء'), const Color(0xDE000000));
      expect(cellBox(tester, 'الفجر').color, isNull);
    });

    testWidgets('a dark system shade uses the night swatch', (tester) async {
      await pumpPreview(
        tester,
        const StripStyle(highlight: StripHighlight.maroon),
        night: true,
      );
      expect(cellBox(tester, 'المغرب').color, const Color(0xFFE7A3A3));
      expect(ink(tester, 'المغرب'), const Color(0xFF121413));
      expect(ink(tester, 'الفجر'), const Color(0x7FF8F9F8));
    });

    testWidgets('outline strokes the cell and colours the text', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        const StripStyle(
          highlight: StripHighlight.darkGreen,
          shape: StripShape.outline,
        ),
      );
      final box = cellBox(tester, 'المغرب');
      expect(box.color, isNull);
      expect(
        box.border,
        Border.all(color: const Color(0xFF4A7C6A), width: 1.5),
      );
      expect(ink(tester, 'المغرب'), const Color(0xFF406C5C));
    });

    testWidgets('pill rounds fully and none colours text only', (tester) async {
      await pumpPreview(tester, const StripStyle(shape: StripShape.pill));
      expect(
        cellBox(tester, 'المغرب').borderRadius,
        BorderRadius.circular(999),
      );
      await pumpPreview(
        tester,
        const StripStyle(
          highlight: StripHighlight.emerald,
          shape: StripShape.none,
        ),
      );
      expect(cellBox(tester, 'المغرب').color, isNull);
      expect(cellBox(tester, 'المغرب').border, isNull);
      expect(ink(tester, 'المغرب'), const Color(0xFF1C7151));
    });

    testWidgets('a background fills the times area and darkens the date', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        const StripStyle(background: StripBackground.sand),
        expanded: true,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).color == const Color(0xFFF3ECDD),
        ),
        findsOneWidget,
      );
      expect(ink(tester, 'الأحد · ٥ جمادى الآخرة'), const Color(0xA8000000));
    });

    testWidgets('expanded shows the date, full times and the next tag', (
      tester,
    ) async {
      await pumpPreview(tester, const StripStyle(), expanded: true);
      expect(find.text('الأحد · ٥ جمادى الآخرة'), findsOneWidget);
      expect(find.text('٠٤:٥٩ م'), findsOneWidget);
      expect(find.text('التالية'), findsOneWidget);
      expect(ink(tester, 'التالية'), const Color(0xFFFFFFFF));
    });

    testWidgets('countdown shows the next label in the header', (tester) async {
      await pumpPreview(tester, const StripStyle());
      expect(find.textContaining('الفرقان · المغرب بعد · '), findsOneWidget);
      await pumpPreview(tester, const StripStyle(showCountdown: false));
      expect(find.text('الفرقان'), findsOneWidget);
      expect(find.textContaining('المغرب بعد'), findsNothing);
    });

    testWidgets('English Friday fits the compact cells', (tester) async {
      await pumpPreview(
        tester,
        const StripStyle(),
        locale: 'en',
        strip: stripFor(locale: 'en', friday: true),
      );
      expect(find.text("Jumu'ah"), findsOneWidget);
      expect(find.text('04:59'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below API 31 every filled shape is a plain rectangle', (
      tester,
    ) async {
      for (final shape in [
        StripShape.rounded,
        StripShape.pill,
        StripShape.outline,
      ]) {
        await pumpPreview(
          tester,
          StripStyle(highlight: StripHighlight.blue, shape: shape),
          tintable: false,
        );
        final box = cellBox(tester, 'المغرب');
        expect(box.color, const Color(0xFF2F5F98), reason: shape.name);
        expect(box.borderRadius, isNull, reason: shape.name);
        expect(box.border, isNull, reason: shape.name);
        expect(ink(tester, 'المغرب'), const Color(0xFFFFFFFF));
      }
      await pumpPreview(
        tester,
        const StripStyle(
          highlight: StripHighlight.blue,
          shape: StripShape.none,
        ),
        tintable: false,
      );
      expect(cellBox(tester, 'المغرب').color, isNull);
      expect(ink(tester, 'المغرب'), const Color(0xFF2F5F98));
    });

    testWidgets('below API 31 the background is a square fill', (tester) async {
      await pumpPreview(
        tester,
        const StripStyle(background: StripBackground.sky),
        tintable: false,
      );
      final fill = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).color == const Color(0xFFE3ECF5),
        ),
      );
      expect((fill.decoration as BoxDecoration).borderRadius, isNull);
    });

    testWidgets('the countdown reads like the phone chronometer', (
      tester,
    ) async {
      await pumpPreview(tester, const StripStyle());
      expect(find.text('الفرقان · المغرب بعد · ٢٩:٠٠'), findsOneWidget);
    });
  });

  testWidgets('a completed sync reloads today\'s times', (tester) async {
    final sync = MockAlertsSync();
    whenListen(sync, Stream.value(DateTime(2026, 11, 15, 9)));
    when(() => today.load()).thenAnswer((_) async {});
    await pumpPage(tester, alertsSync: sync);
    verify(() => today.load()).called(1);
  });
}
