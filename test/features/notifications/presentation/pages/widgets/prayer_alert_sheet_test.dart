import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/prayer_alert_sheet.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../alerts_test_harness.dart';

class _MockToday extends MockCubit<PrayerTimes?>
    implements TodayPrayerTimesCubit {}

void main() {
  late SettingsCubit settings;
  late _MockToday today;

  setUpAll(() => HydratedBloc.storage = MemStorage());
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    today = _MockToday();
    whenListen(
      today,
      const Stream<PrayerTimes?>.empty(),
      initialState: cairoToday(),
    );
  });
  tearDown(() => settings.close());

  Future<void> open(WidgetTester tester, PrayerAlert alert) async {
    settings.updatePrayerAlert(PrayerName.fajr, alert);
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        home: BlocProvider<TodayPrayerTimesCubit>.value(
          value: today,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    PrayerAlertSheet.show(context, PrayerName.fajr),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  SwitchListTile switchTitled(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title));

  PrayerAlert fajr() =>
      settings.state.settingsModel.prayerAlerts[PrayerName.fajr]!;

  testWidgets('alert off makes the reminder inert and shows the reason', (
    tester,
  ) async {
    await open(tester, const PrayerAlert(enabled: false));
    expect(switchTitled(tester, 'تذكير قبل الصلاة').onChanged, isNull);
    expect(
      find.text('يتوقف التذكير مع إيقاف تنبيه وقت الصلاة.'),
      findsOneWidget,
    );
    expect(switchTitled(tester, 'يرن حتى في الوضع الصامت').onChanged, isNull);
  });

  testWidgets('a tone makes ring in silent inert and keeps its value', (
    tester,
  ) async {
    await open(
      tester,
      const PrayerAlert(sound: PrayerSound.tone, ringInSilent: true),
    );
    final ring = switchTitled(tester, 'يرن حتى في الوضع الصامت');
    expect(ring.onChanged, isNull);
    expect(ring.value, isTrue);
  });

  testWidgets('toggling the alert switch writes enabled to the cubit', (
    tester,
  ) async {
    await open(tester, const PrayerAlert(enabled: false));
    await tester.tap(find.text('تنبيه وقت الصلاة'));
    await tester.pumpAndSettle();
    expect(fajr().enabled, isTrue);
    expect(switchTitled(tester, 'تذكير قبل الصلاة').onChanged, isNotNull);
  });

  testWidgets(
    'header shows the prayer and its time, the sound row the Fajr adhan',
    (tester) async {
      await open(tester, const PrayerAlert(reminderEnabled: true));
      expect(find.text('الفجر'), findsOneWidget);
      expect(find.text('٤:٥٠ ص'), findsOneWidget);
      expect(find.text('أذان الفجر'), findsOneWidget);
      expect(find.text('يصلك ٤:٤٠ ص'), findsOneWidget);
    },
  );

  testWidgets('a chip commits the reminder minutes', (tester) async {
    await open(tester, const PrayerAlert(reminderEnabled: true));
    await tester.ensureVisible(find.text('١٥ دقيقة'));
    await tester.tap(find.text('١٥ دقيقة'));
    await tester.pumpAndSettle();
    expect(fajr().reminderMinutes, 15);
  });

  testWidgets('iOS hides ring in silent and shows the iOS note', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await open(tester, const PrayerAlert());
    expect(
      find.widgetWithText(SwitchListTile, 'يرن حتى في الوضع الصامت'),
      findsNothing,
    );
    expect(
      find.text('يعمل الصوت مقطعًا قصيرًا، ويتبع زر الصامت في الهاتف.'),
      findsOneWidget,
    );
    expect(find.text('مقطع من أذان الفجر'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
