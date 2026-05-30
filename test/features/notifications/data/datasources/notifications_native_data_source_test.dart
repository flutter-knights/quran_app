import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NotificationsNativeDataSourceImpl.channelName);
  late List<MethodCall> calls;
  late NotificationsNativeDataSourceImpl ds;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    weekdayLabel: '',
    localeCode: 'en',
    isFriday: false,
  );

  setUp(() {
    calls = [];
    ds = NotificationsNativeDataSourceImpl();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enableStrip invokes the channel with the right method + state JSON',
      () async {
    await ds.enableStrip(state);
    expect(calls.length, 1);
    expect(calls.single.method, 'enableStrip');
    final args = calls.single.arguments as Map;
    expect(args['nextPrayerIndex'], 0);
    expect(args['localeCode'], 'en');
  });

  test('disableStrip invokes the channel', () async {
    await ds.disableStrip();
    expect(calls.single.method, 'disableStrip');
  });

  test('refreshStrip invokes the channel', () async {
    await ds.refreshStrip(state);
    expect(calls.single.method, 'refreshStrip');
  });

  test('scheduleDailyAdhans invokes the channel with days + audio map',
      () async {
    final days = [
      {
        'date': '2026-05-22',
        'timings': {'fajr': '04:15', 'isha': '21:16'},
      }
    ];
    await ds.scheduleDailyAdhans(
      days: days,
      clipAssetByPrayer: const {'fajr': 'fajr_adhan', 'isha': 'normal_adhan'},
      volume: 1.0,
      localeCode: 'en',
    );
    expect(calls.single.method, 'scheduleDailyAdhans');
    final args = calls.single.arguments as Map;
    expect(args['days'], days);
    expect(args['volume'], 1.0);
    expect(args['localeCode'], 'en');
  });

  test('cancelAllAdhans invokes the channel', () async {
    await ds.cancelAllAdhans();
    expect(calls.single.method, 'cancelAllAdhans');
  });

  test('throws PlatformNotImplementedException when native side is missing',
      () async {
    // Removing the mock makes the call raise MissingPluginException internally;
    // the data source wraps that as a `PlatformNotImplementedException`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(
      () => ds.disableStrip(),
      throwsA(isA<PlatformNotImplementedException>()),
    );
  });

  test('schedulePrayerReminders invokes the channel with the days + reminder map',
      () async {
    final days = [
      {
        'date': '2026-05-22',
        'timings': {'fajr': '04:15', 'dhuhr': '12:52', 'maghrib': '19:46'},
      }
    ];
    await ds.schedulePrayerReminders(
      days: days,
      remindersByPrayer: const {'fajr': 15, 'maghrib': 5},
      localeCode: 'ar',
    );
    expect(calls.single.method, 'schedulePrayerReminders');
    final args = calls.single.arguments as Map;
    expect(args['days'], days);
    expect(args['remindersByPrayer'], {'fajr': 15, 'maghrib': 5});
    expect(args['localeCode'], 'ar');
  });

  test('cancelAllReminders invokes the channel', () async {
    await ds.cancelAllReminders();
    expect(calls.single.method, 'cancelAllReminders');
  });
}
