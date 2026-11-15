import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../notifications/presentation/alerts_test_harness.dart';

class _MockReliability extends MockCubit<ReliabilityState>
    implements ReliabilityCubit {}

class _MockScheduler extends Mock implements PrayerNotificationScheduler {}

void main() {
  late SettingsCubit settings;
  late _MockReliability reliability;
  late _MockScheduler scheduler;

  const status = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
  );

  const alertsTitle = 'تنبيهات الصلاة';
  const exactTitle = 'المنبهات الدقيقة';
  final exactOpen = find.widgetWithText(OutlinedButton, 'فتح الإعداد');
  const xiaomiTitle = 'حتى لا يتوقف الأذان على هواتف شاومي';

  setUpAll(() async {
    HydratedBloc.storage = MemStorage();
    registerFallbackValue(SystemSettingsTarget.autostart);
    await loadAppFonts();
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    reliability = _MockReliability();
    when(() => reliability.load()).thenAnswer((_) async {});
    when(() => reliability.openSettings(any())).thenAnswer((_) async {});
    scheduler = _MockScheduler();
    when(
      () => scheduler.requestNotificationsPermission(),
    ).thenAnswer((_) async => true);
    sl.registerSingleton<PrayerNotificationScheduler>(scheduler);
  });
  tearDown(() async {
    await sl.unregister<PrayerNotificationScheduler>();
    await settings.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool xiaomi = false,
    String locale = 'ar',
    Stream<ReliabilityState> states = const Stream.empty(),
    ReliabilityStatus? initial,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      reliability,
      states,
      initialState: ReliabilityLoaded(
        initial ?? status.copyWith(isXiaomi: xiaomi),
      ),
    );
    settings.updateSettings(isArabic: locale == 'ar');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider<ReliabilityCubit>.value(
            value: reliability,
            child: const OnboardingPage(),
          ),
        ),
        GoRoute(
          path: AppRouter.homePath,
          builder: (context, state) => const Text('home-page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      alertsRouterApp(settings: settings, router: router, locale: locale),
    );
    await tester.pumpAndSettle();
  }

  Future<void> primary(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  Future<void> secondary(WidgetTester tester) async {
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
  }

  Future<void> toNotificationsStep(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await primary(tester);
    }
    await secondary(tester);
    expect(find.text('لا تفوتك صلاة'), findsOneWidget);
  }

  testWidgets('enabling notifications leads to the alerts step', (
    tester,
  ) async {
    await pump(tester);
    await toNotificationsStep(tester);
    await primary(tester);
    verify(() => scheduler.requestNotificationsPermission()).called(1);
    expect(find.text(alertsTitle), findsOneWidget);
    expect(find.text('home-page'), findsNothing);
  });

  testWidgets('not now on notifications also leads to the alerts step', (
    tester,
  ) async {
    await pump(tester);
    await toNotificationsStep(tester);
    await secondary(tester);
    expect(find.text(alertsTitle), findsOneWidget);
    verifyNever(() => scheduler.requestNotificationsPermission());
  });

  testWidgets('continue applies the choice and finishes off Xiaomi', (
    tester,
  ) async {
    await pump(tester);
    await toNotificationsStep(tester);
    await secondary(tester);
    await tester.tap(find.text('نغمة الإشعار'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('١٥ دقيقة'));
    await tester.tap(find.text('١٥ دقيقة'));
    await tester.pumpAndSettle();
    await primary(tester);
    final model = settings.state.settingsModel;
    final asr = model.prayerAlerts[PrayerName.asr]!;
    expect(
      (asr.enabled, asr.sound, asr.reminderEnabled, asr.reminderMinutes),
      (true, PrayerSound.tone, true, 15),
    );
    expect(model.hasCompletedOnboarding, isTrue);
    expect(model.alertsIntroSeen, isTrue);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('an untouched continue keeps the stored alerts', (tester) async {
    settings.updatePrayerAlert(
      PrayerName.isha,
      const PrayerAlert(enabled: false),
    );
    settings.updatePrayerAlert(
      PrayerName.fajr,
      const PrayerAlert(reminderEnabled: true, reminderMinutes: 20),
    );
    final before = settings.state.settingsModel.prayerAlerts;
    await pump(tester);
    await toNotificationsStep(tester);
    await secondary(tester);
    await primary(tester);
    expect(settings.state.settingsModel.prayerAlerts, before);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('later on the alerts step keeps the defaults and finishes', (
    tester,
  ) async {
    await pump(tester);
    await toNotificationsStep(tester);
    await secondary(tester);
    await tester.tap(find.text('بدون تنبيه'));
    await tester.pumpAndSettle();
    expect(find.text('لاحقًا'), findsOneWidget);
    await secondary(tester);
    final model = settings.state.settingsModel;
    expect(model.prayerAlerts.values.every((a) => a.enabled), isTrue);
    expect(model.hasCompletedOnboarding, isTrue);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('Xiaomi adds the checklist step, skip leaves the flags off', (
    tester,
  ) async {
    await pump(tester, xiaomi: true);
    await toNotificationsStep(tester);
    await secondary(tester);
    await primary(tester);
    expect(find.text(xiaomiTitle), findsOneWidget);
    expect(find.text('تخطٍّ'), findsOneWidget);
    await secondary(tester);
    final model = settings.state.settingsModel;
    expect(model.xiaomiAutostartConfirmed, isFalse);
    expect(model.xiaomiBatteryConfirmed, isFalse);
    expect(model.hasCompletedOnboarding, isTrue);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('the Xiaomi step confirms a setting and continue finishes', (
    tester,
  ) async {
    await pump(tester, xiaomi: true);
    await toNotificationsStep(tester);
    await secondary(tester);
    await secondary(tester);
    expect(find.text(xiaomiTitle), findsOneWidget);
    await tester.tap(find.text('فتح الإعداد').first);
    verify(
      () => reliability.openSettings(SystemSettingsTarget.autostart),
    ).called(1);
    await tester.tap(find.widgetWithText(TextButton, 'تمّ').first);
    await tester.pumpAndSettle();
    expect(settings.state.settingsModel.xiaomiAutostartConfirmed, isTrue);
    verify(() => reliability.load()).called(1);
    await primary(tester);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('going back from the Xiaomi step keeps the alerts choice', (
    tester,
  ) async {
    await pump(tester, xiaomi: true);
    await toNotificationsStep(tester);
    await secondary(tester);
    await tester.tap(find.text('نغمة الإشعار'));
    await tester.pumpAndSettle();
    await primary(tester);
    expect(find.text(xiaomiTitle), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    final radios = tester.widget<RadioGroup<PrayerSound?>>(
      find.byType(RadioGroup<PrayerSound?>),
    );
    expect(radios.groupValue, PrayerSound.tone);
  });

  testWidgets('a choice swiped past on Xiaomi still applies at the end', (
    tester,
  ) async {
    await pump(tester, xiaomi: true);
    await toNotificationsStep(tester);
    await secondary(tester);
    await tester.tap(find.text('نغمة الإشعار'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text(xiaomiTitle), findsOneWidget);
    await primary(tester);
    final alerts = settings.state.settingsModel.prayerAlerts.values;
    expect(alerts.every((a) => a.sound == PrayerSound.tone), isTrue);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('later on alerts keeps the defaults through the Xiaomi step', (
    tester,
  ) async {
    await pump(tester, xiaomi: true);
    await toNotificationsStep(tester);
    await secondary(tester);
    await tester.tap(find.text('نغمة الإشعار'));
    await tester.pumpAndSettle();
    await secondary(tester);
    expect(find.text(xiaomiTitle), findsOneWidget);
    await secondary(tester);
    final alerts = settings.state.settingsModel.prayerAlerts.values;
    expect(alerts.every((a) => a.sound == PrayerSound.adhan), isTrue);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('a later unavailable status keeps the Xiaomi step', (
    tester,
  ) async {
    final states = StreamController<ReliabilityState>();
    addTearDown(states.close);
    await pump(tester, xiaomi: true, states: states.stream);
    await toNotificationsStep(tester);
    await secondary(tester);
    await secondary(tester);
    expect(find.text(xiaomiTitle), findsOneWidget);
    states.add(const ReliabilityUnavailable());
    await tester.pumpAndSettle();
    expect(find.text(xiaomiTitle), findsOneWidget);
    await primary(tester);
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('the alerts step starts from the stored alerts', (tester) async {
    settings.applyAlertToAll(
      enabled: true,
      sound: PrayerSound.tone,
      reminderEnabled: true,
      reminderMinutes: 30,
    );
    await pump(tester);
    await toNotificationsStep(tester);
    await secondary(tester);
    final radios = tester.widget<RadioGroup<PrayerSound?>>(
      find.byType(RadioGroup<PrayerSound?>),
    );
    expect(radios.groupValue, PrayerSound.tone);
    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .singleWhere((c) => c.selected);
    expect((selected.label as Text).data, '٣٠ دقيقة');
  });

  testWidgets('denied exact alarms add a row that opens their setting', (
    tester,
  ) async {
    await pump(tester, initial: status.copyWith(exactAlarmsAllowed: false));
    await toNotificationsStep(tester);
    expect(find.text(exactTitle), findsOneWidget);
    await tester.tap(exactOpen);
    verify(
      () => reliability.openSettings(SystemSettingsTarget.exactAlarm),
    ).called(1);
    await primary(tester);
    expect(find.text(alertsTitle), findsOneWidget);
  });

  testWidgets('a grant on return keeps the row and shows it allowed', (
    tester,
  ) async {
    final states = StreamController<ReliabilityState>();
    addTearDown(states.close);
    await pump(
      tester,
      initial: status.copyWith(exactAlarmsAllowed: false),
      states: states.stream,
    );
    await toNotificationsStep(tester);
    states.add(const ReliabilityLoaded(status));
    await tester.pumpAndSettle();
    expect(find.text(exactTitle), findsOneWidget);
    expect(find.text('مسموحة'), findsOneWidget);
    expect(exactOpen, findsNothing);
    states.add(const ReliabilityUnavailable());
    await tester.pumpAndSettle();
    expect(find.text(exactTitle), findsOneWidget);
    expect(find.text('مسموحة'), findsOneWidget);
  });

  testWidgets('allowed exact alarms show no row', (tester) async {
    await pump(tester);
    await toNotificationsStep(tester);
    expect(find.text(exactTitle), findsNothing);
  });

  testWidgets('iOS shows no exact-alarm row', (tester) async {
    await pump(
      tester,
      initial: const ReliabilityStatus.ios(notificationsEnabled: true),
    );
    await toNotificationsStep(tester);
    expect(find.text(exactTitle), findsNothing);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('smoke $locale: the exact-alarm row fits a phone', (
      tester,
    ) async {
      await pump(
        tester,
        locale: locale,
        initial: status.copyWith(exactAlarmsAllowed: false),
      );
      for (var i = 0; i < 3; i++) {
        await primary(tester);
      }
      await secondary(tester);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in ['ar', 'en']) {
    testWidgets('smoke $locale: alerts and Xiaomi steps fit a phone', (
      tester,
    ) async {
      await pump(tester, xiaomi: true, locale: locale);
      for (var i = 0; i < 3; i++) {
        await primary(tester);
      }
      await secondary(tester);
      await secondary(tester);
      expect(find.byType(RadioGroup<PrayerSound?>), findsOneWidget);
      expect(tester.takeException(), isNull);
      await primary(tester);
      expect(find.byType(TextButton), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
