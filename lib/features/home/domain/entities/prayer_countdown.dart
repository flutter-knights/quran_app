import 'package:quran_app/core/constants/prayer_name.dart';

class PrayerCountdown {
  final PrayerName currentPrayer;
  final PrayerName nextPrayer;
  final Duration remainingTime;

  PrayerCountdown({
    required this.currentPrayer,
    required this.nextPrayer,
    required this.remainingTime,
  });
}
