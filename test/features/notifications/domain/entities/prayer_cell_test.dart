import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

void main() {
  test('equal cells with same label, time and minutes are equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    const b = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    expect(a, b);
  });

  test('cells with different labels are not equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    const b = PrayerCell(label: 'الظهر', timeFormatted: '٤:١٥', minutes: 255);
    expect(a == b, false);
  });

  test('cells with different minutes are not equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    const b = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 256);
    expect(a == b, false);
  });

  test('nextLabel defaults to empty and takes part in equality', () {
    const a = PrayerCell(label: 'العصر', timeFormatted: '٢:٣٩', minutes: 879);
    const b = PrayerCell(
      label: 'العصر',
      timeFormatted: '٢:٣٩',
      minutes: 879,
      nextLabel: 'العصر بعد',
    );
    expect(a.nextLabel, '');
    expect(a == b, false);
  });

  test('timeFull defaults to the compact time', () {
    const a = PrayerCell(label: 'العصر', timeFormatted: '٠٢:٣٩', minutes: 879);
    const b = PrayerCell(
      label: 'العصر',
      timeFormatted: '٠٢:٣٩',
      timeFull: '٠٢:٣٩ م',
      minutes: 879,
    );
    expect(a.timeFull, '٠٢:٣٩');
    expect(b.timeFull, '٠٢:٣٩ م');
    expect(a == b, false);
  });
}
