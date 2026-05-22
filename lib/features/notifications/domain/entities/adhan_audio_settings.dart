import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';

class AdhanAudioSettings extends Equatable {
  final Map<PrayerName, String> clipAssetByPrayer;
  final double volume;

  const AdhanAudioSettings({
    required this.clipAssetByPrayer,
    this.volume = 1.0,
  });

  factory AdhanAudioSettings.defaults() => const AdhanAudioSettings(
        clipAssetByPrayer: {
          PrayerName.fajr: 'fajr_adhan',
          PrayerName.sunrise: 'normal_adhan',
          PrayerName.dhuhr: 'normal_adhan',
          PrayerName.asr: 'normal_adhan',
          PrayerName.maghrib: 'normal_adhan',
          PrayerName.isha: 'normal_adhan',
        },
      );

  @override
  List<Object?> get props => [clipAssetByPrayer, volume];
}
