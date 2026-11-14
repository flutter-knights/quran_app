import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimesModel extends PrayerTimes {
  PrayerTimesModel({
    required super.timings,
    required super.date,
    required super.key,
  });

  factory PrayerTimesModel.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'];
    final dateObj = json['date'];
    if (timings is! Map || dateObj is! Map) {
      throw const FormatException('Aladhan response missing timings/date');
    }
    final hijri = dateObj['hijri'];
    final gregorian = dateObj['gregorian'];
    if (hijri is! Map || gregorian is! Map || gregorian['date'] == null) {
      throw const FormatException('Aladhan response missing hijri/gregorian date');
    }
    const requiredKeys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final k in requiredKeys) {
      if (timings[k] == null) {
        throw FormatException('Aladhan response missing timing: $k');
      }
    }
    final date = hijri;
    final key = gregorian['date'];

    return PrayerTimesModel(
      timings: {
        PrayerName.fajr: timings['Fajr'].toString().removeTimeZone(),
        PrayerName.sunrise: timings['Sunrise'].toString().removeTimeZone(),
        PrayerName.dhuhr: timings['Dhuhr'].toString().removeTimeZone(),
        PrayerName.asr: timings['Asr'].toString().removeTimeZone(),
        PrayerName.maghrib: timings['Maghrib'].toString().removeTimeZone(),
        PrayerName.isha: timings['Isha'].toString().removeTimeZone(),
      },
      date: Date(
        month: date['month']['ar'],
        enMonth: date['month']['en'],
        day: date['day'],
        year: date['year'],
        weekDay: date['weekday']['ar'],
        enWeekDay: date['weekday']['en'],
        gregorianDate: key,
      ),
      key: key,
    );
  }
}
