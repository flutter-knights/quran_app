import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';

enum IosSound {
  fajrClip('fajr_adhan.caf'),
  normalClip('normal_adhan.caf'),
  defaultSound(null),
  none(null);

  const IosSound(this.file);

  final String? file;

  bool get audible => this != none;
}

class IosAlertRequest extends Equatable {
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final IosSound sound;

  const IosAlertRequest({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.sound,
  });

  @override
  List<Object?> get props => [id, at, title, body, sound];
}

const _reminderIdBase = 200;

int iosDayCount(int requestsPerDay) =>
    requestsPerDay <= 0 ? 0 : min(12, 60 ~/ requestsPerDay);

List<IosAlertRequest> planIosAlerts({
  required List<PrayerTimes> days,
  required Map<PrayerName, PrayerAlert> alerts,
  required String localeCode,
  required DateTime now,
}) {
  final active = [
    for (final (index, prayer) in alertPrayers.indexed)
      if (alerts[prayer] case final alert? when alert.enabled)
        (index, prayer, alert),
  ];
  final requestsPerDay =
      active.length +
      active.where((e) => e.$3.effectiveReminderMinutes != null).length;
  final dayCount = iosDayCount(requestsPerDay);
  final copy = localeCode == 'ar' ? _arabic : _english;

  final byDate = <DateTime, PrayerTimes>{};
  for (final day in days) {
    final date = _parseDate(day.date.gregorianDate);
    if (date != null) byDate.putIfAbsent(date, () => day);
  }
  final dates = byDate.keys.toList()..sort();

  final requests = <IosAlertRequest>[];
  var dayIndex = 0;
  for (final date in dates) {
    if (dayIndex >= dayCount) break;
    final timings = byDate[date]!.timings;
    final dayRequests = <IosAlertRequest>[];
    for (final (index, prayer, alert) in active) {
      final at = _timeOn(date, timings[prayer]);
      if (at == null) continue;
      final id = dayIndex * 10 + index;
      if (at.isAfter(now)) {
        dayRequests.add(
          IosAlertRequest(
            id: id,
            at: at,
            title: copy.names[prayer]!,
            body: copy.adhanBodies[prayer]!,
            sound: _adhanSound(prayer, alert.sound),
          ),
        );
      }
      if (alert.effectiveReminderMinutes case final minutes?) {
        final reminderAt = at.subtract(Duration(minutes: minutes));
        if (reminderAt.isAfter(now)) {
          dayRequests.add(
            IosAlertRequest(
              id: _reminderIdBase + id,
              at: reminderAt,
              title: copy.reminderTitles[prayer]!,
              body: copy.reminderBodies[prayer]!,
              sound: alert.reminderSound == ReminderSound.tone
                  ? IosSound.defaultSound
                  : IosSound.none,
            ),
          );
        }
      }
    }
    if (dayRequests.isEmpty) continue;
    requests.addAll(dayRequests);
    dayIndex++;
  }
  return requests;
}

IosSound _adhanSound(PrayerName prayer, PrayerSound sound) => switch (sound) {
  PrayerSound.adhan when prayer == PrayerName.fajr => IosSound.fajrClip,
  PrayerSound.adhan => IosSound.normalClip,
  PrayerSound.tone => IosSound.defaultSound,
  PrayerSound.vibrate || PrayerSound.silent => IosSound.none,
};

DateTime? _parseDate(String ddMMyyyy) {
  final parts = ddMMyyyy.split('-');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  final date = DateTime(year, month, day);
  if (date.day != day || date.month != month) return null;
  return date;
}

DateTime? _timeOn(DateTime date, String? hhmm) {
  final parts = hhmm?.split(':');
  if (parts == null || parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

typedef _Copy = ({
  Map<PrayerName, String> names,
  Map<PrayerName, String> adhanBodies,
  Map<PrayerName, String> reminderTitles,
  Map<PrayerName, String> reminderBodies,
});

const _Copy _arabic = (
  names: {
    PrayerName.fajr: 'الفجر',
    PrayerName.dhuhr: 'الظهر',
    PrayerName.asr: 'العصر',
    PrayerName.maghrib: 'المغرب',
    PrayerName.isha: 'العشاء',
  },
  adhanBodies: {
    PrayerName.fajr: 'حان موعد صلاة الفجر',
    PrayerName.dhuhr: 'حان موعد صلاة الظهر',
    PrayerName.asr: 'حان موعد صلاة العصر',
    PrayerName.maghrib: 'حان موعد صلاة المغرب',
    PrayerName.isha: 'حان موعد صلاة العشاء',
  },
  reminderTitles: {
    PrayerName.fajr: 'تذكير الفجر',
    PrayerName.dhuhr: 'تذكير الظهر',
    PrayerName.asr: 'تذكير العصر',
    PrayerName.maghrib: 'تذكير المغرب',
    PrayerName.isha: 'تذكير العشاء',
  },
  reminderBodies: {
    PrayerName.fajr: 'اقتربت صلاة الفجر',
    PrayerName.dhuhr: 'اقتربت صلاة الظهر',
    PrayerName.asr: 'اقتربت صلاة العصر',
    PrayerName.maghrib: 'اقتربت صلاة المغرب',
    PrayerName.isha: 'اقتربت صلاة العشاء',
  },
);

const _Copy _english = (
  names: {
    PrayerName.fajr: 'Fajr',
    PrayerName.dhuhr: 'Dhuhr',
    PrayerName.asr: 'Asr',
    PrayerName.maghrib: 'Maghrib',
    PrayerName.isha: 'Isha',
  },
  adhanBodies: {
    PrayerName.fajr: "It's time for Fajr prayer",
    PrayerName.dhuhr: "It's time for Dhuhr prayer",
    PrayerName.asr: "It's time for Asr prayer",
    PrayerName.maghrib: "It's time for Maghrib prayer",
    PrayerName.isha: "It's time for Isha prayer",
  },
  reminderTitles: {
    PrayerName.fajr: 'Fajr reminder',
    PrayerName.dhuhr: 'Dhuhr reminder',
    PrayerName.asr: 'Asr reminder',
    PrayerName.maghrib: 'Maghrib reminder',
    PrayerName.isha: 'Isha reminder',
  },
  reminderBodies: {
    PrayerName.fajr: 'Fajr prayer is coming up',
    PrayerName.dhuhr: 'Dhuhr prayer is coming up',
    PrayerName.asr: 'Asr prayer is coming up',
    PrayerName.maghrib: 'Maghrib prayer is coming up',
    PrayerName.isha: 'Isha prayer is coming up',
  },
);
