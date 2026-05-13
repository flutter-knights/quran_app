import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

void main() {
  late Directory tempDir;
  late Box<PrayerTimesHiveModel> box;
  late PrayerTimesLocalDataSource ds;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PrayerTimesHiveModelAdapter());
    }
  });

  setUp(() async {
    box = await Hive.openBox<PrayerTimesHiveModel>(
      'prayerTimesCache_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    ds = PrayerTimesLocalDataSource(prayerTimesBox: box);
  });

  tearDown(() async => box.deleteFromDisk());

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  PrayerTimes mkEntry(String ddMMyyyy) => PrayerTimes(
        key: ddMMyyyy,
        timings: const {
          PrayerName.fajr: '04:00',
          PrayerName.sunrise: '05:30',
          PrayerName.dhuhr: '12:00',
          PrayerName.asr: '15:30',
          PrayerName.maghrib: '18:00',
          PrayerName.isha: '19:30',
        },
        date: Date(
          month: '1',
          weekDay: 'Mon',
          year: '1446',
          day: '1',
          enMonth: 'Muharram',
          enWeekDay: 'Mon',
          gregorianDate: ddMMyyyy,
        ),
      );

  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  group('clearOldCache', () {
    test('deletes entries strictly before yesterday (dd-MM-yyyy keys)',
        () async {
      final now = DateTime.now();
      final older = fmt(now.subtract(const Duration(days: 10)));
      final yesterday = fmt(now.subtract(const Duration(days: 1)));
      final today = fmt(now);

      await ds.cache([mkEntry(older), mkEntry(yesterday), mkEntry(today)]);

      expect(box.containsKey(older), isFalse,
          reason: 'entry older than yesterday should be removed');
      expect(box.containsKey(yesterday), isTrue);
      expect(box.containsKey(today), isTrue);
    });

    test('keeps entries from a future month', () async {
      final now = DateTime.now();
      final future = DateTime(now.year, now.month + 2, 5);
      await ds.cache([mkEntry(fmt(future))]);
      expect(box.containsKey(fmt(future)), isTrue);
    });
  });
}
