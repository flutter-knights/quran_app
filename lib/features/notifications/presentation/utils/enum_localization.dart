import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/generated/l10n.dart';

String prayerLabel(BuildContext context, PrayerName p) {
  final s = S.of(context);
  return switch (p) {
    PrayerName.fajr => s.fajr,
    PrayerName.sunrise => s.sunrise,
    PrayerName.dhuhr => s.dhuhr,
    PrayerName.asr => s.asr,
    PrayerName.maghrib => s.maghrib,
    PrayerName.isha => s.isha,
  };
}

String prayerSoundLabel(
  PendingS s,
  PrayerSound sound, {
  required PrayerName prayer,
  required bool ios,
}) {
  final fajr = prayer == PrayerName.fajr;
  return switch (sound) {
    PrayerSound.adhan when ios =>
      fajr ? s.alerts_sound_fajrAdhanClip : s.alerts_sound_adhanClip,
    PrayerSound.adhan => fajr ? s.alerts_sound_fajrAdhan : s.alerts_sound_adhan,
    PrayerSound.tone => s.alerts_sound_tone,
    PrayerSound.vibrate when ios => s.alerts_sound_silent,
    PrayerSound.vibrate => s.alerts_sound_vibrate,
    PrayerSound.silent => s.alerts_sound_silent,
  };
}

String reminderSoundLabel(PendingS s, ReminderSound sound, {bool ios = false}) {
  return switch (sound) {
    ReminderSound.tone => s.alerts_sound_tone,
    ReminderSound.vibrate when ios => s.alerts_sound_silent,
    ReminderSound.vibrate => s.alerts_sound_vibrate,
    ReminderSound.silent => s.alerts_sound_silent,
  };
}

String minutesLabel(PendingS s, int minutes, String localeCode) =>
    s.alerts_minutes(minutes).toIndicNumerals(localeCode);

String enabledCountLabel(PendingS s, int count, String localeCode) =>
    s.alerts_enabledCount(count).toIndicNumerals(localeCode);

String alertSummary(
  PendingS s,
  PrayerAlert a, {
  required PrayerName prayer,
  required bool ios,
  required String localeCode,
}) {
  if (!a.enabled) return s.alerts_summary_off;
  final reminder = a.effectiveReminderMinutes;
  return [
    prayerSoundLabel(s, a.sound, prayer: prayer, ios: ios),
    if (!ios && a.sound == PrayerSound.adhan && a.ringInSilent)
      s.alerts_summary_ringsInSilent,
    if (reminder != null)
      s.alerts_summary_reminder(minutesLabel(s, reminder, localeCode)),
  ].join(localeCode == 'ar' ? '، ' : ', ');
}

List<List<dynamic>> prayerAlertIcon(PrayerAlert a) {
  if (!a.enabled || a.sound == PrayerSound.silent) {
    return HugeIcons.strokeRoundedNotificationOff01;
  }
  return a.sound == PrayerSound.adhan
      ? HugeIcons.strokeRoundedVolumeHigh
      : HugeIcons.strokeRoundedNotification01;
}

final _hhmm = RegExp(r'^(\d{1,2}):(\d{2})(?!\d)');

String? prayerTimeLabel(
  String? hhmm, {
  required bool use24Hour,
  required String localeCode,
  int minutesBefore = 0,
}) {
  final match = _hhmm.firstMatch(hhmm?.trim() ?? '');
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  final time = DateTime(
    2000,
    1,
    1,
    hour,
    minute,
  ).subtract(Duration(minutes: minutesBefore));
  return DateFormat(
    use24Hour ? 'HH:mm' : 'h:mm a',
    localeCode,
  ).format(time).toIndicNumerals(localeCode);
}

String alertsDateLabel(DateTime date, String localeCode) =>
    DateFormat('d MMMM', localeCode).format(date).toIndicNumerals(localeCode);

String stripHighlightLabel(PendingS s, StripHighlight h) => switch (h) {
  StripHighlight.app => s.strip_color_app,
  StripHighlight.darkGreen => s.strip_color_darkGreen,
  StripHighlight.emerald => s.strip_color_emerald,
  StripHighlight.blue => s.strip_color_blue,
  StripHighlight.indigo => s.strip_color_indigo,
  StripHighlight.maroon => s.strip_color_maroon,
  StripHighlight.bronze => s.strip_color_bronze,
};

String stripBackgroundLabel(PendingS s, StripBackground b) => switch (b) {
  StripBackground.auto => s.strip_bg_auto,
  StripBackground.mint => s.strip_bg_mint,
  StripBackground.sand => s.strip_bg_sand,
  StripBackground.sky => s.strip_bg_sky,
  StripBackground.rose => s.strip_bg_rose,
};

String stripShapeLabel(PendingS s, StripShape shape) => switch (shape) {
  StripShape.none => s.strip_shape_none,
  StripShape.rounded => s.strip_shape_rounded,
  StripShape.pill => s.strip_shape_pill,
  StripShape.outline => s.strip_shape_outline,
};
