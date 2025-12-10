class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final Date date;
  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
  });
}

class Date {
  final String month;
  final String weekDay;
  final String year;
  final int day;
  Date({
    required this.month,
    required this.weekDay,
    required this.day,
    required this.year,
  });
}
