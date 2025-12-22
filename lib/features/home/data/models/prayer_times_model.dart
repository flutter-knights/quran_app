import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimesModel extends PrayerTimes {
  PrayerTimesModel({required super.timings, required super.date});

  factory PrayerTimesModel.fromJson(
    Map<String, dynamic> json, {
    String languageCode = 'ar',
  }) {
    final timings = json['data']['timings'];
    final date = json['data']['date']['hijri'];

    return PrayerTimesModel(
      timings: {
        PrayerName.fajr: timings['Fajr'],
        PrayerName.sunrise: timings['Sunrise'],
        PrayerName.dhuhr: timings['Dhuhr'],
        PrayerName.asr: timings['Asr'],
        PrayerName.maghrib: timings['Maghrib'],
        PrayerName.isha: timings['Isha'],
      },
      date: Date(
        month: date['month'][languageCode],
        day: date['day'],
        year: date['year'],
        weekDay: date['weekday'][languageCode],
      ),
    );
  }
}
