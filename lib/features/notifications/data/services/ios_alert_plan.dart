import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/services/prayer_labels.dart';

enum IosSound {
  fajrClip('fajr_adhan.caf'),
  normalClip('normal_adhan.caf'),
  defaultSound(null),
  none(null);

  const IosSound(this.file);

  final String? file;

  bool get audible => this != none;
}

const iosMaxDays = 12;
const iosReminderIdBase = 200;
const _idsPerDay = 10;

bool isIosAlertId(int id) {
  final offset = id >= iosReminderIdBase ? id - iosReminderIdBase : id;
  return offset >= 0 && offset < iosMaxDays * _idsPerDay;
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

  bool get isReminder => id >= iosReminderIdBase;

  @override
  List<Object?> get props => [id, at, title, body, sound];
}

int iosDayCount(int requestsPerDay) =>
    requestsPerDay <= 0 ? 0 : min(iosMaxDays, 60 ~/ requestsPerDay);

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
  final arabic = localeCode == 'ar';

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
      final id = dayIndex * _idsPerDay + index;
      final name = prayerNameLabel(
        prayer,
        arabic: arabic,
        friday: date.weekday == DateTime.friday,
      );
      if (at.isAfter(now)) {
        dayRequests.add(
          IosAlertRequest(
            id: id,
            at: at,
            title: name,
            body: arabic ? 'حان موعد صلاة $name' : "It's time for $name prayer",
            sound: _adhanSound(prayer, alert.sound),
          ),
        );
      }
      if (alert.effectiveReminderMinutes case final minutes?) {
        final reminderAt = at.subtract(
          Duration(minutes: PrayerAlert.clampMinutes(minutes)),
        );
        if (reminderAt.isAfter(now)) {
          dayRequests.add(
            IosAlertRequest(
              id: iosReminderIdBase + id,
              at: reminderAt,
              title: arabic ? 'تذكير $name' : '$name reminder',
              body: arabic ? 'اقتربت صلاة $name' : '$name prayer is coming up',
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
