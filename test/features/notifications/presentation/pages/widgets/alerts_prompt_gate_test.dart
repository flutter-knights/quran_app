import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_prompt_gate.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../alerts_test_harness.dart';

class _MockReliability extends MockCubit<ReliabilityState>
    implements ReliabilityCubit {}

void main() {
  late SettingsCubit settings;
  late _MockReliability reliability;

  const base = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
  );
  final ishaMiss = MissedAlert(
    prayer: PrayerName.isha,
    at: DateTime(2026, 11, 14, 18, 16),
  );
  final ishaMiss2 = MissedAlert(
    prayer: PrayerName.isha,
    at: DateTime(2026, 11, 15, 18, 19),
  );
  final asrLate = MissedAlert(
    prayer: PrayerName.asr,
    at: DateTime(2026, 11, 15, 14, 39),
  );
  final xiaomiMiss = base.copyWith(isXiaomi: true, missed: [ishaMiss]);

  const missedTitle = 'فاتك تنبيه العشاء';
  const missedBody =
      'أوقف النظام التطبيق في الخلفية غالبًا. إعدادان على هاتفك يمنعان تكرار ذلك.';
  const genericBody =
      'قد يكون النظام أوقف التطبيق أو أخّره. صفحة حالة التنبيهات تبيّن ما يلزم تغييره.';
  const upgradeTitle = 'تحسينات في تنبيهات الصلاة';
  const upgradeXiaomi = 'على هواتف شاومي يلزم إعدادان حتى لا يتوقف الأذان.';
  const upgradeSilent =
      'يتبع الأذان الآن وضع الهاتف الصامت. لتشغيله رغم الصامت: «يرن حتى في الوضع الصامت» لكل صلاة.';

  setUpAll(() async {
    HydratedBloc.storage = MemStorage();
    registerFallbackValue(base);
    await loadAppFonts();
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    settings.completeOnboarding();
    settings.setXiaomiAutostartConfirmed(true);
    settings.setXiaomiBatteryConfirmed(true);
    reliability = _MockReliability();
    when(() => reliability.ackMissed(any())).thenAnswer((_) async {});
    sl.registerFactory<ReliabilityCubit>(() => reliability);
  });
  tearDown(() async {
    await sl.unregister<ReliabilityCubit>();
    await settings.close();
  });

  Future<void> asUpgrader() async {
    final upgrader = settings.state.settingsModel.copyWith(
      hasCompletedOnboarding: true,
      alertsIntroSeen: false,
    );
    await settings.close();
    await HydratedBloc.storage.write('SettingsCubit', upgrader.toMap());
    settings = SettingsCubit();
  }

  Future<GoRouter> pump(
    WidgetTester tester,
    List<ReliabilityState> states, {
    String locale = 'ar',
    Stream<ReliabilityState>? stream,
    AlertsSyncCubit? alertsSync,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      reliability,
      stream ?? Stream.fromIterable(states),
      initialState: const ReliabilityLoading(),
    );
    settings.updateSettings(isArabic: locale == 'ar');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const AlertsPromptGate(child: Text('home-view')),
        ),
        GoRoute(
          path: AppRouter.notificationsPath,
          builder: (context, state) => const Text('notifications-page'),
        ),
        GoRoute(
          path: AppRouter.alertsReliabilityPath,
          builder: (context, state) => const Text('reliability-page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      alertsRouterApp(
        settings: settings,
        router: router,
        locale: locale,
        alertsSync: alertsSync,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a Xiaomi miss shows the missed sheet, acks it and clears the '
      'Xiaomi confirmations', (tester) async {
    await pump(tester, [ReliabilityLoaded(xiaomiMiss)]);
    expect(find.text('home-view'), findsOneWidget);
    expect(find.text(missedTitle), findsOneWidget);
    expect(find.text(missedBody), findsOneWidget);
    verify(() => reliability.ackMissed(xiaomiMiss)).called(1);
    expect(settings.state.settingsModel.xiaomiAutostartConfirmed, isFalse);
    expect(settings.state.settingsModel.xiaomiBatteryConfirmed, isFalse);
  });

  testWidgets('a miss elsewhere uses the generic body and keeps the flags', (
    tester,
  ) async {
    final status = base.copyWith(missed: [ishaMiss], late: [asrLate]);
    await pump(tester, [ReliabilityLoaded(status)]);
    expect(find.text(missedTitle), findsOneWidget);
    expect(find.text(genericBody), findsOneWidget);
    verify(() => reliability.ackMissed(status)).called(1);
    expect(settings.state.settingsModel.xiaomiAutostartConfirmed, isTrue);
    expect(settings.state.settingsModel.xiaomiBatteryConfirmed, isTrue);
  });

  testWidgets('a late delivery alone shows the late title', (tester) async {
    await pump(tester, [
      ReliabilityLoaded(base.copyWith(late: [asrLate])),
    ]);
    expect(find.text('تأخّر تنبيه العصر'), findsOneWidget);
  });

  testWidgets('an unseen intro shows the upgrade sheet first, then the '
      'pending miss', (tester) async {
    await asUpgrader();
    await pump(tester, [ReliabilityLoaded(xiaomiMiss)]);
    expect(find.text(upgradeTitle), findsOneWidget);
    expect(find.text(upgradeSilent), findsOneWidget);
    expect(find.text(upgradeXiaomi), findsOneWidget);
    expect(find.text(missedTitle), findsNothing);
    expect(settings.state.settingsModel.alertsIntroSeen, isTrue);
    verifyNever(() => reliability.ackMissed(any()));

    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
    expect(find.text(upgradeTitle), findsNothing);
    expect(find.text(missedTitle), findsOneWidget);
    verify(() => reliability.ackMissed(xiaomiMiss)).called(1);
  });

  testWidgets('a miss behind the upgrade sheet waits while review covers '
      'Home', (tester) async {
    await asUpgrader();
    final status = base.copyWith(missed: [ishaMiss]);
    final router = await pump(tester, [ReliabilityLoaded(status)]);
    await tester.tap(find.text('مراجعة الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('notifications-page'), findsOneWidget);
    verifyNever(() => reliability.ackMissed(any()));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(missedTitle), findsOneWidget);
    verify(() => reliability.ackMissed(status)).called(1);
  });

  testWidgets('the upgrade sheet leaves out the Xiaomi line elsewhere', (
    tester,
  ) async {
    await asUpgrader();
    await pump(tester, [const ReliabilityLoaded(base)]);
    expect(find.text(upgradeTitle), findsOneWidget);
    expect(find.text(upgradeXiaomi), findsNothing);
  });

  testWidgets('the upgrade sheet on iOS leaves out the silent-mode line', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await asUpgrader();
    await pump(tester, [
      const ReliabilityLoaded(
        ReliabilityStatus.ios(notificationsEnabled: true),
      ),
    ]);
    expect(find.text(upgradeTitle), findsOneWidget);
    expect(find.text(upgradeSilent), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a completed sync reloads the status', (tester) async {
    final sync = MockAlertsSync();
    whenListen(sync, Stream.value(DateTime(2026, 11, 15, 9)));
    when(() => reliability.load()).thenAnswer((_) async {});
    await pump(tester, [const ReliabilityLoaded(base)], alertsSync: sync);
    verify(() => reliability.load()).called(1);
  });

  testWidgets('a later reload shows nothing more', (tester) async {
    await pump(tester, [
      ReliabilityLoaded(xiaomiMiss),
      const ReliabilityLoading(),
      ReliabilityLoaded(xiaomiMiss),
    ]);
    expect(find.text(missedTitle), findsOneWidget);
    verify(() => reliability.ackMissed(any())).called(1);
  });

  testWidgets('a late delivery found while running shows the sheet', (
    tester,
  ) async {
    await pump(tester, [
      const ReliabilityLoaded(base),
      ReliabilityLoaded(base.copyWith(late: [asrLate])),
    ]);
    expect(find.text('تأخّر تنبيه العصر'), findsOneWidget);
    verify(() => reliability.ackMissed(any())).called(1);
  });

  testWidgets('an alert already shown is not shown again', (tester) async {
    final status = base.copyWith(late: [asrLate]);
    final states = StreamController<ReliabilityState>();
    addTearDown(states.close);
    await pump(tester, const [], stream: states.stream);
    states.add(ReliabilityLoaded(status));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
    states.add(ReliabilityLoaded(status.copyWith(batteryUnrestricted: false)));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    verify(() => reliability.ackMissed(any())).called(1);
  });

  testWidgets('a newer miss after the first is shown too', (tester) async {
    final states = StreamController<ReliabilityState>();
    addTearDown(states.close);
    await pump(tester, const [], stream: states.stream);
    states.add(ReliabilityLoaded(base.copyWith(late: [asrLate])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
    states.add(ReliabilityLoaded(base.copyWith(missed: [ishaMiss2])));
    await tester.pumpAndSettle();
    expect(find.text(missedTitle), findsOneWidget);
    verify(() => reliability.ackMissed(any())).called(2);
  });

  testWidgets('nothing shows while a route covers Home, then it shows on '
      'return', (tester) async {
    final states = StreamController<ReliabilityState>();
    addTearDown(states.close);
    final router = await pump(tester, const [], stream: states.stream);
    states.add(const ReliabilityLoaded(base));
    await tester.pumpAndSettle();
    router.push(AppRouter.notificationsPath);
    await tester.pumpAndSettle();
    states.add(ReliabilityLoaded(xiaomiMiss));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    verifyNever(() => reliability.ackMissed(any()));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(missedTitle), findsOneWidget);
    verify(() => reliability.ackMissed(xiaomiMiss)).called(1);
  });

  testWidgets('an unavailable status shows nothing and keeps the intro', (
    tester,
  ) async {
    await asUpgrader();
    await pump(tester, [const ReliabilityUnavailable()]);
    expect(find.byType(BottomSheet), findsNothing);
    expect(settings.state.settingsModel.alertsIntroSeen, isFalse);
  });

  testWidgets('nothing to report shows no sheet', (tester) async {
    await pump(tester, [const ReliabilityLoaded(base)]);
    expect(find.byType(BottomSheet), findsNothing);
    verifyNever(() => reliability.ackMissed(any()));
  });

  testWidgets('fix now opens the reliability page', (tester) async {
    await pump(tester, [ReliabilityLoaded(xiaomiMiss)]);
    await tester.tap(find.text('إصلاح الآن'));
    await tester.pumpAndSettle();
    expect(find.text('reliability-page'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('later closes the missed sheet', (tester) async {
    await pump(tester, [ReliabilityLoaded(xiaomiMiss)]);
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('home-view'), findsOneWidget);
  });

  testWidgets('review on Xiaomi opens the reliability page over the alerts '
      'page', (tester) async {
    await asUpgrader();
    final router = await pump(tester, [ReliabilityLoaded(xiaomiMiss)]);
    await tester.tap(find.text('مراجعة الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('reliability-page'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('notifications-page'), findsOneWidget);
  });

  testWidgets('review elsewhere opens the alerts page', (tester) async {
    await asUpgrader();
    await pump(tester, [const ReliabilityLoaded(base)]);
    await tester.tap(find.text('مراجعة الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('notifications-page'), findsOneWidget);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('smoke $locale: the upgrade sheet fits a phone', (
      tester,
    ) async {
      await asUpgrader();
      await pump(tester, [ReliabilityLoaded(xiaomiMiss)], locale: locale);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('smoke $locale: the missed sheet fits a phone', (tester) async {
      await pump(tester, [ReliabilityLoaded(xiaomiMiss)], locale: locale);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
