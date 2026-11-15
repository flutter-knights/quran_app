import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_local_data_source.dart';

void main() {
  late Box box;
  late NotificationsLocalDataSource local;

  setUp(() async {
    Hive.init(
      './.dart_tool/hive_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    box = await Hive.openBox('prayerConfig_alerts_test');
    local = NotificationsLocalDataSource(boxName: 'prayerConfig_alerts_test');
  });
  tearDown(() async => box.deleteFromDisk());

  test('iosScheduledUntil is null before the first write', () {
    expect(local.readIosScheduledUntil(), isNull);
  });

  test('iosScheduledUntil round-trips as epoch milliseconds', () async {
    final until = DateTime(2026, 11, 20, 18, 16);
    await local.writeIosScheduledUntil(until);
    expect(local.readIosScheduledUntil(), until);
    expect(box.get('iosScheduledUntil'), until.millisecondsSinceEpoch);
  });

  test('writing null clears iosScheduledUntil', () async {
    await local.writeIosScheduledUntil(DateTime(2026, 11, 20));
    await local.writeIosScheduledUntil(null);
    expect(local.readIosScheduledUntil(), isNull);
    expect(box.containsKey('iosScheduledUntil'), isFalse);
  });

  test('a non-int stored value reads as null', () async {
    await box.put('iosScheduledUntil', 'bogus');
    expect(local.readIosScheduledUntil(), isNull);
  });

  test('the default box is prayerConfig', () {
    expect(NotificationsLocalDataSource().boxName, 'prayerConfig');
  });
}
