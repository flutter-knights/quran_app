import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

void main() {
  test('is24HourFormat mirrors the (misnamed) isFormat12Hours field', () {
    expect(
      const Settings(isFormat12Hours: true, isArabic: false).is24HourFormat,
      isTrue,
    );
    expect(
      const Settings(isFormat12Hours: false, isArabic: false).is24HourFormat,
      isFalse,
    );
  });
}
