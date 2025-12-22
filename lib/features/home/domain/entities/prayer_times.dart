import 'package:quran_app/core/constants/prayers_list_constants.dart';

class PrayerTimes {
  final Map<PrayerName, String> timings;
  final Date date;

  const PrayerTimes({required this.timings, required this.date});
}

class Date {
  final String month;
  final String weekDay;
  final String year;
  final String day;
  Date({
    required this.month,
    required this.weekDay,
    required this.day,
    required this.year,
  });
}
