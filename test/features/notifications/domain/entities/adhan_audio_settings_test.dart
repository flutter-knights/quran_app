import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';

void main() {
  test('default settings expose fajr_adhan for fajr, normal_adhan elsewhere', () {
    final s = AdhanAudioSettings.defaults();
    expect(s.clipAssetByPrayer[PrayerName.fajr], 'fajr_adhan');
    expect(s.clipAssetByPrayer[PrayerName.dhuhr], 'normal_adhan');
    expect(s.volume, 1.0);
  });

  test('equality holds for identical settings', () {
    final a = AdhanAudioSettings.defaults();
    final b = AdhanAudioSettings.defaults();
    expect(a, b);
  });
}
