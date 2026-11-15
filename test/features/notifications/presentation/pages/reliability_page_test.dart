import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/reliability_page.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../alerts_test_harness.dart';

class _MockReliability extends MockCubit<ReliabilityState>
    implements ReliabilityCubit {}

void main() {
  late SettingsCubit settings;
  late _MockReliability reliability;

  final ok = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
    scheduledUntil: DateTime(2026, 11, 21, 18, 19),
  );
  final worst = ok.copyWith(
    notificationsEnabled: false,
    channelBlocked: true,
    exactAlarmsAllowed: false,
    batteryUnrestricted: false,
    isXiaomi: true,
    clearScheduledUntil: true,
  );

  setUpAll(() async {
    HydratedBloc.storage = MemStorage();
    registerFallbackValue(SystemSettingsTarget.notifications);
    await loadAppFonts();
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    reliability = _MockReliability();
    when(() => reliability.openSettings(any())).thenAnswer((_) async {});
    when(() => reliability.load()).thenAnswer((_) async {});
  });
  tearDown(() => settings.close());

  Future<void> pump(
    WidgetTester tester,
    ReliabilityState state, {
    String locale = 'ar',
    Size size = const Size(400, 1600),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      reliability,
      const Stream<ReliabilityState>.empty(),
      initialState: state,
    );
    settings.updateSettings(isArabic: locale == 'ar');
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        locale: locale,
        home: BlocProvider<ReliabilityCubit>.value(
          value: reliability,
          child: const ReliabilityPage(),
        ),
      ),
    );
    settle
        ? await tester.pumpAndSettle()
        : await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a blocked notifications row asks for action and opens it', (
    tester,
  ) async {
    await pump(
      tester,
      ReliabilityLoaded(ok.copyWith(notificationsEnabled: false)),
    );
    expect(find.text('يحتاج إجراء'), findsOneWidget);
    expect(find.text('غير مسموحة'), findsOneWidget);
    expect(find.text('يعمل'), findsNWidgets(2));
    await tester.tap(find.text('فتح الإعداد'));
    verify(
      () => reliability.openSettings(SystemSettingsTarget.notifications),
    ).called(1);
  });

  testWidgets('a blocked channel alone reads as blocked', (tester) async {
    await pump(tester, ReliabilityLoaded(ok.copyWith(channelBlocked: true)));
    expect(find.text('غير مسموحة'), findsOneWidget);
    expect(find.text('فتح الإعداد'), findsOneWidget);
  });

  testWidgets('blocked exact alarms and battery open their own settings', (
    tester,
  ) async {
    await pump(
      tester,
      ReliabilityLoaded(
        ok.copyWith(exactAlarmsAllowed: false, batteryUnrestricted: false),
      ),
    );
    expect(find.text('مقيّد'), findsOneWidget);
    expect(
      find.text('قد يؤخّر النظام الأذان أو يوقفه. يلزم اختيار «بدون قيود».'),
      findsOneWidget,
    );
    await tester.tap(find.text('فتح الإعداد').first);
    await tester.tap(find.text('فتح الإعداد').last);
    verify(
      () => reliability.openSettings(SystemSettingsTarget.exactAlarm),
    ).called(1);
    verify(
      () => reliability.openSettings(SystemSettingsTarget.battery),
    ).called(1);
  });

  testWidgets('everything allowed shows no action and the scheduled date', (
    tester,
  ) async {
    await pump(tester, ReliabilityLoaded(ok));
    expect(find.text('يعمل'), findsNWidgets(3));
    expect(find.text('بدون قيود'), findsOneWidget);
    expect(find.text('فتح الإعداد'), findsNothing);
    expect(find.text('مجدولة حتى ٢١ نوفمبر'), findsOneWidget);
    expect(find.byType(TestAdhanButton), findsOneWidget);
  });

  testWidgets('nothing scheduled reads as not scheduled yet', (tester) async {
    await pump(
      tester,
      ReliabilityLoaded(ok.copyWith(clearScheduledUntil: true)),
    );
    expect(find.text('لا تنبيهات مجدولة بعد'), findsOneWidget);
  });

  testWidgets('non-Xiaomi hides the Xiaomi section', (tester) async {
    await pump(tester, ReliabilityLoaded(ok));
    expect(find.text('هواتف شاومي'), findsNothing);
    expect(find.text('تفعيل التشغيل التلقائي'), findsNothing);
  });

  testWidgets('Xiaomi rows confirm, then show the done badge', (tester) async {
    await pump(tester, ReliabilityLoaded(ok.copyWith(isXiaomi: true)));
    expect(find.text('هواتف شاومي'), findsOneWidget);
    expect(find.text('قفل التطبيق في التطبيقات الأخيرة'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'تمّ'), findsNWidgets(2));
    expect(find.widgetWithText(AppStatusBadge, 'تمّ'), findsNothing);
    expect(find.text('فتح الإعداد'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(TextButton, 'تمّ').first);
    await tester.pumpAndSettle();

    expect(settings.state.settingsModel.xiaomiAutostartConfirmed, isTrue);
    expect(settings.state.settingsModel.xiaomiBatteryConfirmed, isFalse);
    verify(() => reliability.load()).called(1);
    expect(find.widgetWithText(TextButton, 'تمّ'), findsOneWidget);
    expect(find.widgetWithText(AppStatusBadge, 'تمّ'), findsOneWidget);
    expect(find.text('فتح الإعداد'), findsNWidgets(2));

    await tester.tap(find.text('فتح الإعداد').first);
    verify(
      () => reliability.openSettings(SystemSettingsTarget.autostart),
    ).called(1);
    await tester.tap(find.widgetWithText(TextButton, 'تمّ'));
    await tester.pumpAndSettle();
    expect(settings.state.settingsModel.xiaomiBatteryConfirmed, isTrue);
    expect(find.widgetWithText(AppStatusBadge, 'تمّ'), findsNWidgets(2));
    await tester.tap(find.text('فتح الإعداد').last);
    verify(
      () => reliability.openSettings(SystemSettingsTarget.xiaomiBattery),
    ).called(1);
  });

  testWidgets('iOS shows only the notifications row and the test button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(
      tester,
      const ReliabilityLoaded(
        ReliabilityStatus.ios(notificationsEnabled: true),
      ),
    );
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('المنبهات الدقيقة'), findsNothing);
    expect(find.text('تحسين البطارية'), findsNothing);
    expect(find.text('لا تنبيهات مجدولة بعد'), findsNothing);
    expect(find.byType(TestAdhanButton), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('loading renders the rows as a skeleton', (tester) async {
    await pump(tester, const ReliabilityLoading(), settle: false);
    expect(find.byWidgetPredicate((w) => w is Skeletonizer), findsOneWidget);
    expect(find.text('فتح الإعداد'), findsNothing);
  });

  testWidgets('an unavailable status keeps only the test button', (
    tester,
  ) async {
    await pump(tester, const ReliabilityUnavailable());
    expect(find.text('الإشعارات'), findsNothing);
    expect(find.byType(TestAdhanButton), findsOneWidget);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets('smoke $locale: every row blocked on Xiaomi fits a phone', (
      tester,
    ) async {
      await pump(
        tester,
        ReliabilityLoaded(worst),
        locale: locale,
        size: const Size(360, 640),
      );
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.byType(TestAdhanButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
