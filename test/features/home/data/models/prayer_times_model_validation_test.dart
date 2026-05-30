import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/home/data/models/prayer_times_model.dart';

void main() {
  test('throws FormatException when timings missing', () {
    expect(() => PrayerTimesModel.fromJson({'date': {}}),
        throwsA(isA<FormatException>()));
  });

  test('throws FormatException when a prayer timing key is missing', () {
    final json = {
      'timings': {'Fajr': '05:00 (UTC)'}, // missing the rest
      'date': {
        'hijri': {
          'month': {'ar': 'x', 'en': 'x'},
          'weekday': {'ar': 'x', 'en': 'x'},
          'day': '1', 'year': '1447',
        },
        'gregorian': {'date': '30-05-2026'},
      },
    };
    expect(() => PrayerTimesModel.fromJson(json),
        throwsA(isA<FormatException>()));
  });

  test('parses a well-formed payload', () {
    final json = {
      'timings': {
        'Fajr': '05:00 (UTC)', 'Sunrise': '06:00 (UTC)', 'Dhuhr': '12:00 (UTC)',
        'Asr': '15:00 (UTC)', 'Maghrib': '18:00 (UTC)', 'Isha': '19:30 (UTC)',
      },
      'date': {
        'hijri': {
          'month': {'ar': 'x', 'en': 'x'},
          'weekday': {'ar': 'x', 'en': 'x'},
          'day': '1', 'year': '1447',
        },
        'gregorian': {'date': '30-05-2026'},
      },
    };
    final model = PrayerTimesModel.fromJson(json);
    expect(model.key, '30-05-2026');
    expect(model.timings.length, 6);
  });
}
