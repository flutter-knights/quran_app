import 'package:quran_app/core/constants/prayers_list_constants.dart';

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
