import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/pages/prayer_strip_settings_page.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/strip_preview.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../alerts_test_harness.dart';

class _MockToday extends MockCubit<PrayerTimes?>
    implements TodayPrayerTimesCubit {}

void main() {
  late SettingsCubit cubit;
  late _MockToday today;

  setUpAll(() async {
    HydratedBloc.storage = MemStorage();
    await loadAppFonts();
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    cubit = SettingsCubit();
    today = _MockToday();
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
    PrayerTimes? times,
    bool noTimes = false,
    bool settle = true,
  }) async {
    phone(tester);
    cubit.updateSettings(isArabic: locale == 'ar');
    cubit.updatePrayerStripPinned(pinned);
    cubit.updateStripStyle(style);
    whenListen(
      today,
      const Stream<PrayerTimes?>.empty(),
      initialState: noTimes ? null : times ?? cairoToday(),
    );
    await tester.pumpWidget(
      alertsApp(
        settings: cubit,
        locale: locale,
        home: BlocProvider<TodayPrayerTimesCubit>.value(
          value: today,
          child: const PrayerStripSettingsPage(),
        ),
      ),
    );
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 100));
  }

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

    testWidgets('the preview is a skeleton until today\'s times load', (
      tester,
    ) async {
      await pumpPage(tester, noTimes: true, settle: false);
      expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    });

    for (final locale in ['ar', 'en']) {
      testWidgets('smoke $locale: page and option sheets fit a phone', (
        tester,
      ) async {
        cubit.updateSettings(isFormat12Hours: true);
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
    PrayerStripState day({String locale = 'ar', bool friday = false}) =>
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
      PrayerStripState? state,
      String locale = 'ar',
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
              day: state ?? day(locale: locale),
              style: style,
              expanded: expanded,
              palette: ColorPalette.neutralLight,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
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
        state: day(locale: 'en', friday: true),
      );
      expect(find.text("Jumu'ah"), findsOneWidget);
      expect(find.text('04:59'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
