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

  group('toAsciiDigits', () {
    test('folds Arabic-Indic digits', () {
      expect(toAsciiDigits('٤٢'), '42');
    });

    test('folds Extended Arabic-Indic digits', () {
      expect(toAsciiDigits('۶۰۴'), '604');
    });

    test('folds mixed digits', () {
      expect(toAsciiDigits('1٢3'), '123');
    });

    test('leaves other characters alone', () {
      expect(toAsciiDigits('abc'), 'abc');
    });
  });
}
