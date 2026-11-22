import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/settings/presentation/pages/settings_page.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart';

import '../../../notifications/presentation/alerts_test_harness.dart';

void main() {
  late SettingsCubit settings;

  setUpAll(() => HydratedBloc.storage = MemStorage());
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
  });
  tearDown(() => settings.close());

  testWidgets('one notifications row with the enabled count in Arabic digits', (
    tester,
  ) async {
    settings.updatePrayerAlert(
      PrayerName.isha,
      const PrayerAlert(enabled: false),
    );
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      alertsApp(settings: settings, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('الأذان والتذكيرات'), findsOneWidget);
    expect(find.text('مفعّل لـ٤ صلوات'), findsOneWidget);
    expect(find.text('أوقات الصلاة المثبتة'), findsNothing);
  });

  testWidgets('the mushaf row reads العرض and opens the display sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      alertsApp(settings: settings, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-open-reading'));
    expect(
      find.descendant(of: row, matching: find.text('العرض')),
      findsOneWidget,
    );
    await tester.tap(find.text('العرض'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(DisplaySheet), findsOneWidget);
  });
}
