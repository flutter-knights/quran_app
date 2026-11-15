import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/services/prayer_labels.dart';

void main() {
  test('names every alert prayer in Arabic and English', () {
    expect(
      [for (final p in alertPrayers) prayerNameLabel(p, arabic: true)],
      ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'],
    );
    expect(
      [for (final p in alertPrayers) prayerNameLabel(p, arabic: false)],
      ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'],
    );
  });

  test('Dhuhr on a Friday reads as Jumuah', () {
    expect(
      prayerNameLabel(PrayerName.dhuhr, arabic: true, friday: true),
      'الجمعة',
    );
    expect(
      prayerNameLabel(PrayerName.dhuhr, arabic: false, friday: true),
      "Jumu'ah",
    );
  });

  test('Friday renames only Dhuhr', () {
    expect(prayerNameLabel(PrayerName.asr, arabic: false, friday: true), 'Asr');
  });
}
