import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';

Future<PendingS> pendingFor(WidgetTester tester, String locale) async {
  late PendingS result;
  await tester.pumpWidget(
    Localizations(
      locale: Locale(locale),
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Builder(
        builder: (context) {
          result = PendingS.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  testWidgets('alertSummary renders Arabic-Indic digits', (tester) async {
    final s = await pendingFor(tester, 'ar');
    expect(
      alertSummary(
        s,
        const PrayerAlert(reminderEnabled: true, reminderMinutes: 10),
        prayer: PrayerName.fajr,
        ios: false,
        localeCode: 'ar',
      ),
      'أذان الفجر، تذكير قبل ١٠ دقائق',
    );
    expect(
      alertSummary(
        s,
        const PrayerAlert(enabled: false, reminderEnabled: true),
        prayer: PrayerName.asr,
        ios: false,
        localeCode: 'ar',
      ),
      'متوقف',
    );
  });

  testWidgets('alertSummary in English with ring in silent', (tester) async {
    final s = await pendingFor(tester, 'en');
    expect(
      alertSummary(
        s,
        const PrayerAlert(
          ringInSilent: true,
          reminderEnabled: true,
          reminderMinutes: 1,
        ),
        prayer: PrayerName.dhuhr,
        ios: false,
        localeCode: 'en',
      ),
      'Adhan, rings in silent mode, reminder 1 minute before',
    );
    expect(
      alertSummary(
        s,
        const PrayerAlert(ringInSilent: true),
        prayer: PrayerName.dhuhr,
        ios: true,
        localeCode: 'en',
      ),
      'Adhan clip',
    );
  });

  testWidgets('ring in silent is not mentioned for a tone', (tester) async {
    final s = await pendingFor(tester, 'ar');
    expect(
      alertSummary(
        s,
        const PrayerAlert(sound: PrayerSound.tone, ringInSilent: true),
        prayer: PrayerName.asr,
        ios: false,
        localeCode: 'ar',
      ),
      'نغمة الإشعار',
    );
  });

  testWidgets('settings row subtitle uses Arabic digits', (tester) async {
    expect(
      enabledCountLabel(await pendingFor(tester, 'ar'), 4, 'ar'),
      'مفعّل لـ٤ صلوات',
    );
  });

  testWidgets('sound labels follow prayer and platform', (tester) async {
    final s = await pendingFor(tester, 'ar');
    expect(
      prayerSoundLabel(
        s,
        PrayerSound.adhan,
        prayer: PrayerName.fajr,
        ios: false,
      ),
      'أذان الفجر',
    );
    expect(
      prayerSoundLabel(
        s,
        PrayerSound.adhan,
        prayer: PrayerName.isha,
        ios: false,
      ),
      'الأذان',
    );
    expect(
      prayerSoundLabel(
        s,
        PrayerSound.adhan,
        prayer: PrayerName.fajr,
        ios: true,
      ),
      'مقطع من أذان الفجر',
    );
    expect(
      prayerSoundLabel(
        s,
        PrayerSound.vibrate,
        prayer: PrayerName.asr,
        ios: true,
      ),
      'بدون صوت',
    );
    expect(reminderSoundLabel(s, ReminderSound.vibrate), 'اهتزاز فقط');
    expect(reminderSoundLabel(s, ReminderSound.vibrate, ios: true), 'بدون صوت');
    expect(minutesLabel(s, 15, 'ar'), '١٥ دقيقة');
  });

  test('prayerAlertIcon maps sound and state', () {
    expect(
      prayerAlertIcon(const PrayerAlert()),
      HugeIcons.strokeRoundedVolumeHigh,
    );
    expect(
      prayerAlertIcon(const PrayerAlert(sound: PrayerSound.tone)),
      HugeIcons.strokeRoundedNotification01,
    );
    expect(
      prayerAlertIcon(const PrayerAlert(sound: PrayerSound.vibrate)),
      HugeIcons.strokeRoundedNotification01,
    );
    expect(
      prayerAlertIcon(const PrayerAlert(sound: PrayerSound.silent)),
      HugeIcons.strokeRoundedNotificationOff01,
    );
    expect(
      prayerAlertIcon(const PrayerAlert(enabled: false)),
      HugeIcons.strokeRoundedNotificationOff01,
    );
  });

  test('prayerTimeLabel formats 12 and 24 hours with locale digits', () {
    expect(
      prayerTimeLabel('04:50', use24Hour: false, localeCode: 'ar'),
      '٤:٥٠ ص',
    );
    expect(
      prayerTimeLabel('14:38', use24Hour: true, localeCode: 'ar'),
      '١٤:٣٨',
    );
    expect(
      prayerTimeLabel('14:38', use24Hour: false, localeCode: 'en'),
      '2:38 PM',
    );
    expect(
      prayerTimeLabel('04:50 (EET)', use24Hour: true, localeCode: 'en'),
      '04:50',
    );
    expect(
      prayerTimeLabel(
        '04:50',
        use24Hour: false,
        localeCode: 'ar',
        minutesBefore: 10,
      ),
      '٤:٤٠ ص',
    );
  });

  test('prayerTimeLabel hides malformed times', () {
    for (final bad in [null, '', '25:00', '5:7x', '12:61']) {
      expect(
        prayerTimeLabel(bad, use24Hour: true, localeCode: 'en'),
        isNull,
        reason: '$bad',
      );
    }
  });

  test('alertsDateLabel reads day and month with locale digits', () {
    expect(alertsDateLabel(DateTime(2026, 11, 22), 'ar'), '٢٢ نوفمبر');
    expect(alertsDateLabel(DateTime(2026, 11, 22), 'en'), '22 November');
  });
}
