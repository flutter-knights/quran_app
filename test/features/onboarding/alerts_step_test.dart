import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/alerts_step.dart';
import 'package:quran_app/features/onboarding/presentation/utils/apply_alerts_choice.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../notifications/presentation/alerts_test_harness.dart';

void main() {
  late SettingsCubit settings;
  late List<AlertsChoice> changes;

  setUpAll(() => HydratedBloc.storage = MemStorage());
  setUp(() async {
    await HydratedBloc.storage.clear();
    settings = SettingsCubit();
    changes = [];
  });
  tearDown(() => settings.close());

  Future<void> pump(WidgetTester tester, AlertsChoice initial) async {
    var choice = initial;
    await tester.pumpWidget(
      alertsApp(
        settings: settings,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AlertsStep(
              choice: choice,
              onChanged: (c) {
                changes.add(c);
                setState(() => choice = c);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<ChoiceChip> chips(WidgetTester tester) =>
      tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();

  testWidgets('defaults to adhan with no reminder selected', (tester) async {
    await pump(tester, const AlertsChoice(sound: PrayerSound.adhan));
    final selected = chips(tester).where((c) => c.selected).toList();
    expect(selected, hasLength(1));
    expect((selected.single.label as Text).data, 'بدون');
    expect(chips(tester), hasLength(5));
  });

  testWidgets('no alert makes the reminder chips inert', (tester) async {
    await pump(tester, const AlertsChoice(sound: PrayerSound.adhan));
    await tester.tap(find.text('بدون تنبيه'));
    await tester.pumpAndSettle();
    expect(changes.last, const AlertsChoice(sound: null));
    expect(chips(tester).every((c) => c.onSelected == null), isTrue);
  });

  testWidgets('tone then 15 minutes reports both', (tester) async {
    await pump(tester, const AlertsChoice(sound: PrayerSound.adhan));
    await tester.tap(find.text('نغمة الإشعار'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('١٥ دقيقة'));
    await tester.pumpAndSettle();
    expect(
      changes.last,
      const AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 15),
    );
    expect(
      chips(tester).singleWhere((c) => c.selected).label,
      isA<Text>().having((t) => t.data, 'label', '١٥ دقيقة'),
    );
  });

  testWidgets('the shown choice follows the one passed in', (tester) async {
    await pump(
      tester,
      const AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 30),
    );
    final radios = tester.widget<RadioGroup<PrayerSound?>>(
      find.byType(RadioGroup<PrayerSound?>),
    );
    expect(radios.groupValue, PrayerSound.tone);
    expect(
      chips(tester).singleWhere((c) => c.selected).label,
      isA<Text>().having((t) => t.data, 'label', '٣٠ دقيقة'),
    );
  });

  Switch switchFor(WidgetTester tester, String label) => tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
      matching: find.byType(Switch),
    ),
  );

  testWidgets('Android shows ring in silent and strip switches, both off', (
    tester,
  ) async {
    await pump(tester, const AlertsChoice(sound: PrayerSound.adhan));
    expect(switchFor(tester, 'يرن حتى في الوضع الصامت').value, isFalse);
    expect(switchFor(tester, 'شريط أوقات الصلاة').value, isFalse);
  });

  testWidgets('toggling the switches reports them', (tester) async {
    await pump(tester, const AlertsChoice(sound: PrayerSound.adhan));
    await tester.tap(find.text('يرن حتى في الوضع الصامت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شريط أوقات الصلاة'));
    await tester.pumpAndSettle();
    expect(
      changes.last,
      const AlertsChoice(
        sound: PrayerSound.adhan,
        ringInSilent: true,
        stripPinned: true,
      ),
    );
  });

  testWidgets('ring in silent is inert unless the sound is adhan', (
    tester,
  ) async {
    await pump(
      tester,
      const AlertsChoice(sound: PrayerSound.adhan, ringInSilent: true),
    );
    await tester.tap(find.text('نغمة الإشعار'));
    await tester.pumpAndSettle();
    final ring = switchFor(tester, 'يرن حتى في الوضع الصامت');
    expect(ring.onChanged, isNull);
    expect(ring.value, isFalse);
    expect(changes.last.ringInSilent, isTrue);
    expect(switchFor(tester, 'شريط أوقات الصلاة').onChanged, isNotNull);
  });

  testWidgets('iOS shows neither switch', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(tester, const AlertsChoice(sound: PrayerSound.adhan));
    expect(find.byType(Switch), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
