import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

void main() {
  group('toIndicNumerals', () {
    test('converts ASCII digits to Arabic-Indic for ar locale', () {
      expect('4:15'.toIndicNumerals('ar'), '٤:١٥');
      expect('12:52'.toIndicNumerals('ar'), '١٢:٥٢');
      expect('0'.toIndicNumerals('ar'), '٠');
    });

    test('returns input unchanged for non-Arabic locales', () {
      expect('4:15'.toIndicNumerals('en'), '4:15');
      expect('12:52'.toIndicNumerals('fr'), '12:52');
    });

    test('returns input unchanged for empty input', () {
      expect(''.toIndicNumerals('ar'), '');
    });

    test('preserves non-digit characters', () {
      expect('Fajr 4:15 AM'.toIndicNumerals('ar'), 'Fajr ٤:١٥ AM');
    });
  });
}
