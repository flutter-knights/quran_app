import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

void main() {
  test('equal cells with same label and time are equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥');
    const b = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥');
    expect(a, b);
  });

  test('cells with different labels are not equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥');
    const b = PrayerCell(label: 'الظهر', timeFormatted: '٤:١٥');
    expect(a == b, false);
  });
}
