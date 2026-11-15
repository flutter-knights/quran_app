import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/usecases/schedule_test_adhan.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../alerts_test_harness.dart';

class _MockReliability extends MockCubit<ReliabilityState>
    implements ReliabilityCubit {}

class _MockSchedule extends Mock implements ScheduleTestAdhan {}

void main() {
  late SettingsCubit settings;
  late _MockReliability reliability;
  late _MockSchedule schedule;

  const ok = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
  );

  setUpAll(() {
    HydratedBloc.storage = MemStorage();
    registerFallbackValue(
      const ScheduleTestAdhanParams(alert: PrayerAlert(), localeCode: 'ar'),
    );
  });
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    reliability = _MockReliability();
    schedule = _MockSchedule();
    when(() => schedule(any())).thenAnswer((_) async => const Right(unit));
    sl.registerSingleton<ScheduleTestAdhan>(schedule);
  });
  tearDown(() async {
    await sl.unregister<ScheduleTestAdhan>();
    await settings.close();
  });

  Future<void> pump(WidgetTester tester, ReliabilityState state) async {
    whenListen(
      reliability,
      const Stream<ReliabilityState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        home: BlocProvider<ReliabilityCubit>.value(
          value: reliability,
          child: const Scaffold(body: TestAdhanButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'blocked status shows the blocked snackbar and schedules nothing',
    (tester) async {
      await pump(
        tester,
        ReliabilityLoaded(ok.copyWith(notificationsEnabled: false)),
      );
      await tester.tap(find.text('تشغيل أذان تجريبي'));
      await tester.pumpAndSettle();
      expect(
        find.text('لن يعمل الأذان: الإشعارات أو المنبهات الدقيقة غير مسموحة.'),
        findsOneWidget,
      );
      verifyNever(() => schedule(any()));
    },
  );

  testWidgets(
    'ok status schedules with the Dhuhr alert and shows the caption',
    (tester) async {
      settings.updatePrayerAlert(
        PrayerName.dhuhr,
        const PrayerAlert(sound: PrayerSound.tone),
      );
      await pump(tester, const ReliabilityLoaded(ok));
      await tester.tap(find.text('تشغيل أذان تجريبي'));
      await tester.pumpAndSettle();
      final p =
          verify(() => schedule(captureAny())).captured.single
              as ScheduleTestAdhanParams;
      expect(p.alert.sound, PrayerSound.tone);
      expect(p.localeCode, 'ar');
      expect(
        find.text('يصل بعد ثوانٍ إذا كانت الإشعارات مسموحة.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a status still loading does not block the test', (tester) async {
    await pump(tester, const ReliabilityLoading());
    await tester.tap(find.text('تشغيل أذان تجريبي'));
    await tester.pumpAndSettle();
    verify(() => schedule(any())).called(1);
  });
}
