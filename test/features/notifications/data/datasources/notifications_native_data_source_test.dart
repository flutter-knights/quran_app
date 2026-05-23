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

  test('scheduleDailyAdhans invokes the channel with timings + audio map',
      () async {
    await ds.scheduleDailyAdhans(
      timingsByPrayer: const {'fajr': '04:15', 'isha': '21:16'},
      clipAssetByPrayer: const {'fajr': 'fajr_adhan', 'isha': 'normal_adhan'},
      volume: 1.0,
    );
    expect(calls.single.method, 'scheduleDailyAdhans');
    final args = calls.single.arguments as Map;
    expect(args['timings'], {'fajr': '04:15', 'isha': '21:16'});
    expect(args['volume'], 1.0);
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
}
