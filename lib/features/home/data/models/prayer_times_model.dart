import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimesModel extends PrayerTimes {
  PrayerTimesModel({
    required super.fajr,
    required super.sunrise,
    required super.dhuhr,
    required super.asr,
    required super.maghrib,
    required super.isha,
    required super.date,
  });

  factory PrayerTimesModel.fromJson(
    Map<String, dynamic> json, {
    String languageCode = 'ar',
  }) {
    final timings = json['data']['timings'];
    final date = json['data']['date'];

    return PrayerTimesModel(
      fajr: timings['Fajr'],
      sunrise: timings['Sunrise'],

      dhuhr: timings['Dhuhr'],

      asr: timings['Asr'],
      maghrib: timings['Maghrib'],
      isha: timings['Isha'],
      date: Date(
        month: date['month'][languageCode],
        day: date['day'],
        year: date['year'],
        weekDay: date['weekday'][languageCode],
      ),
    );
  }
}
