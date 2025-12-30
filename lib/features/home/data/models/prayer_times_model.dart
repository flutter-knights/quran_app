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
    final date = json['date']['hijri'];
    final key = json['date']['gregorian']['date'];

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
      ),
      key: key,
    );
  }
}
