import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/domain/usecases/preview_alert_sound.dart';
import 'package:quran_app/features/notifications/domain/usecases/stop_alert_preview.dart';
import 'package:quran_app/features/notifications/domain/usecases/watch_preview_ended.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/cubit/sound_preview_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/notifications_settings_page.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../alerts_test_harness.dart';

class _MockReliability extends MockCubit<ReliabilityState>
    implements ReliabilityCubit {}

class _MockToday extends MockCubit<TodayPrayerTimesState>
    implements TodayPrayerTimesCubit {}

class _MockPreview extends Mock implements PreviewAlertSound {}

class _MockStop extends Mock implements StopAlertPreview {}

class _MockWatchEnded extends Mock implements WatchPreviewEnded {}

void main() {
  late SettingsCubit settings;
  late _MockReliability reliability;
  late _MockToday today;

  final ok = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
    scheduledUntil: DateTime.now().add(const Duration(days: 6)),
  );

  setUpAll(() async {
    HydratedBloc.storage = MemStorage();
    registerFallbackValue(NoParams());
    registerFallbackValue(
      const PreviewAlertSoundParams(
        sound: PreviewSound.tone,
        prayer: PrayerName.fajr,
      ),
    );
    await loadAppFonts();
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    reliability = _MockReliability();
    today = _MockToday();
    final preview = _MockPreview();
    final stop = _MockStop();
    when(() => preview(any())).thenAnswer((_) async => const Right(unit));
    final watchEnded = _MockWatchEnded();
    when(() => stop(any())).thenAnswer((_) async => const Right(unit));
    when(() => watchEnded(any())).thenAnswer((_) => const Stream.empty());
    sl.registerFactory(() => SoundPreviewCubit(preview, stop, watchEnded));
  });
  tearDown(() async {
    await sl.unregister<SoundPreviewCubit>();
    await settings.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'ar',
    ReliabilityState? state,
    PrayerTimes? times,
    TodayPrayerTimesState? todayState,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      reliability,
      const Stream<ReliabilityState>.empty(),
      initialState: state ?? ReliabilityLoaded(ok),
    );
    whenListen(
      today,
      const Stream<TodayPrayerTimesState>.empty(),
      initialState:
          todayState ??
          (times == null
              ? const TodayPrayerTimesEmpty()
              : TodayPrayerTimesLoaded(times)),
    );
    settings.updateSettings(isArabic: locale == 'ar');
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        locale: locale,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ReliabilityCubit>.value(value: reliability),
            BlocProvider<TodayPrayerTimesCubit>.value(value: today),
          ],
          child: const NotificationsSettingsPage(),
        ),
      ),
    );
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  testWidgets('loading status renders as a skeleton', (tester) async {
    await pump(tester, state: const ReliabilityLoading(), settle: false);
    expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    expect(find.text('الفجر'), findsOneWidget);
  });

  testWidgets('Arabic page shows status, summaries, times and strip row', (
    tester,
  ) async {
    settings.updatePrayerAlert(
      PrayerName.fajr,
      const PrayerAlert(
        ringInSilent: true,
        reminderEnabled: true,
        reminderMinutes: 10,
      ),
    );
    settings.updatePrayerAlert(
      PrayerName.isha,
      const PrayerAlert(enabled: false),
    );
    settings.updatePrayerStripPinned(true);
    settings.updateStripStyle(const StripStyle());
    await pump(tester, times: cairoToday());
    expect(find.textContaining('التنبيهات تعمل، ومجدولة حتى '), findsOneWidget);
    expect(
      find.text('أذان الفجر، يرن في الوضع الصامت، تذكير قبل ١٠ دقائق'),
      findsOneWidget,
    );
    expect(find.text('٤:٥٠ ص'), findsOneWidget);
    expect(find.text('متوقف'), findsOneWidget);
    await scrollToEnd(tester);
    expect(find.text('مفعّل، عرض موسّع'), findsOneWidget);
    expect(find.text('تشغيل أذان تجريبي'), findsOneWidget);
    expect(find.text('تُختار الطريقة تلقائيًا حسب بلدك.'), findsOneWidget);
  });

  for (final state in const [
    TodayPrayerTimesLoading(),
    TodayPrayerTimesEmpty(),
  ]) {
    testWidgets('times are hidden while ${state.runtimeType}', (tester) async {
      await pump(tester, todayState: state);
      expect(find.text('٤:٥٠ ص'), findsNothing);
      expect(find.text('الفجر'), findsOneWidget);
    });
  }

  testWidgets('status rules map to their lines', (tester) async {
    await pump(
      tester,
      state: ReliabilityLoaded(ok.copyWith(notificationsEnabled: false)),
    );
    expect(find.text('الإشعارات غير مسموحة، فلن يصل الأذان'), findsOneWidget);
  });

  Finder checkIcon() => find.byWidgetPredicate(
    (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedCheckmarkCircle02,
  );

  testWidgets('unavailable status reads as on with a neutral icon', (
    tester,
  ) async {
    await pump(tester, state: const ReliabilityUnavailable());
    expect(find.text('التنبيهات تعمل'), findsOneWidget);
    expect(checkIcon(), findsNothing);
  });

  testWidgets('a resolved status without a date keeps the check icon', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(
      tester,
      state: const ReliabilityLoaded(
        ReliabilityStatus.ios(notificationsEnabled: true),
      ),
    );
    expect(find.text('التنبيهات تعمل'), findsOneWidget);
    expect(checkIcon(), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final state in const [ReliabilityUnavailable(), ReliabilityLoading()]) {
    testWidgets('every prayer off reads as off while ${state.runtimeType}', (
      tester,
    ) async {
      settings.applyAlertToAll(enabled: false);
      await pump(tester, state: state, settle: false);
      expect(find.text('متوقف لكل الصلوات'), findsOneWidget);
      expect(find.text('التنبيهات تعمل'), findsNothing);
      expect(checkIcon(), findsNothing);
    });
  }

  testWidgets('every prayer off reads as off for all prayers', (tester) async {
    settings.applyAlertToAll(enabled: false);
    await pump(tester);
    expect(find.text('متوقف لكل الصلوات'), findsOneWidget);
  });

  testWidgets('picking a method from its sheet writes it', (tester) async {
    await pump(tester);
    await tapAndSettle(tester, find.text('الطريقة'));
    await tester.tap(find.text('رابطة العالم الإسلامي').last);
    await tester.pumpAndSettle();
    expect(
      settings.state.settingsModel.calculationMethod,
      CalculationMethod.mwl,
    );
  });

  testWidgets('iOS shows the iPhone note and no strip row', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(
      tester,
      state: const ReliabilityLoaded(
        ReliabilityStatus.ios(notificationsEnabled: true),
      ),
    );
    await scrollToEnd(tester);
    expect(
      find.text('على iPhone يعمل مقطع قصير من الأذان، ويتبع زر الصامت.'),
      findsOneWidget,
    );
    expect(find.text('شريط أوقات الصلاة'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the strip row opens the strip settings route', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      reliability,
      const Stream<ReliabilityState>.empty(),
      initialState: ReliabilityLoaded(ok),
    );
    whenListen(
      today,
      const Stream<TodayPrayerTimesState>.empty(),
      initialState: const TodayPrayerTimesEmpty(),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<ReliabilityCubit>.value(value: reliability),
              BlocProvider<TodayPrayerTimesCubit>.value(value: today),
            ],
            child: const NotificationsSettingsPage(),
          ),
        ),
        GoRoute(
          path: AppRouter.prayerStripPath,
          builder: (context, state) => const Text('strip-page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      alertsRouterApp(settings: settings, router: router),
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('شريط أوقات الصلاة'));
    expect(find.text('strip-page'), findsOneWidget);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets(
      'smoke $locale: page, prayer sheet and sound picker fit a phone',
      (tester) async {
        for (final p in alertPrayers) {
          settings.updatePrayerAlert(
            p,
            const PrayerAlert(
              ringInSilent: true,
              reminderEnabled: true,
              reminderMinutes: 15,
            ),
          );
        }
        settings.updatePrayerStripPinned(true);
        await pump(tester, locale: locale, times: cairoToday());
        await scrollToEnd(tester);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tapAndSettle(
          tester,
          find.text(locale == 'ar' ? 'المغرب' : 'Maghrib'),
        );
        expect(find.byType(Slider), findsOneWidget);
        await tapAndSettle(
          tester,
          find.text(locale == 'ar' ? 'الصوت' : 'Sound'),
        );
        expect(find.byType(RadioListTile<PrayerSound>), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
