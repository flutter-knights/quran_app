import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NotificationsNativeDataSourceImpl.channelName);
  late List<MethodCall> calls;
  late NotificationsNativeDataSourceImpl ds;

  final window = PrayerStripWindow(
    days: [
      const PrayerStripState(
        cells: [
          PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255),
        ],
        nextPrayerIndex: 0,
        dateKey: '22-05-2026',
        hijriDateLabel: '5 Dhul-Hijjah',
        weekdayLabel: '',
        localeCode: 'en',
        isFriday: false,
      ),
    ],
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

  test('enableStrip invokes the channel with the days payload', () async {
    await ds.enableStrip(window);
    expect(calls.length, 1);
    expect(calls.single.method, 'enableStrip');
    final args = calls.single.arguments as Map;
    final days = (args['days'] as List).cast<Map>();
    expect(days.length, 1);
    expect(days[0]['dateKey'], '22-05-2026');
    final cells = (days[0]['cells'] as List).cast<Map>();
    expect(cells[0]['minutes'], 255);
  });

  test('enableStrip sends the style, nextLabel and nextTag', () async {
    await ds.enableStrip(
      const PrayerStripWindow(
        days: [
          PrayerStripState(
            cells: [
              PrayerCell(
                label: 'Fajr',
                timeFormatted: '04:15',
                minutes: 255,
                nextLabel: 'Fajr in',
              ),
            ],
            nextPrayerIndex: 0,
            dateKey: '22-05-2026',
            hijriDateLabel: '5 Dhul-Hijjah',
            weekdayLabel: '',
            localeCode: 'en',
            isFriday: false,
            nextTag: 'Next',
          ),
        ],
        style: StripRenderStyle(
          expanded: true,
          countdown: true,
          highlightDay: 0xFF2E5244,
          highlightNight: 0xFF93BAA8,
          pillTextDay: 0xFFFFFFFF,
          pillTextNight: 0xFF121413,
          backgroundDay: 0xFFE3EFEA,
          backgroundNight: 0xFF16302A,
          shape: 'rounded',
        ),
      ),
    );
    final args = calls.single.arguments as Map;
    final day = (args['days'] as List).cast<Map>().single;
    expect(day['nextTag'], 'Next');
    expect((day['cells'] as List).cast<Map>().single['nextLabel'], 'Fajr in');
    final style = args['style'] as Map;
    expect(style['highlightDay'], '#FF2E5244');
    expect(style['backgroundNight'], '#FF16302A');
    expect(style['shape'], 'rounded');
  });

  test('disableStrip invokes the channel', () async {
    await ds.disableStrip();
    expect(calls.single.method, 'disableStrip');
  });

  test('refreshStrip invokes the channel with the days payload', () async {
    await ds.refreshStrip(window);
    expect(calls.single.method, 'refreshStrip');
    expect((calls.single.arguments as Map)['days'], isA<List>());
  });

  test('scheduleDailyAdhans sends days, alerts and localeCode', () async {
    final days = [
      {
        'date': '2026-11-15',
        'timings': {'fajr': '04:52'},
      },
    ];
    await ds.scheduleDailyAdhans(
      days: days,
      alerts: {
        'fajr': {'sound': 'tone', 'ringInSilent': false},
      },
      localeCode: 'ar',
    );
    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'scheduleDailyAdhans');
    expect(args['days'], days);
    expect(args['alerts'], {
      'fajr': {'sound': 'tone', 'ringInSilent': false},
    });
    expect(args['localeCode'], 'ar');
    expect(args.containsKey('clips'), isFalse);
    expect(args.containsKey('volume'), isFalse);
  });

  test('cancelAllAdhans invokes the channel', () async {
    await ds.cancelAllAdhans();
    expect(calls.single.method, 'cancelAllAdhans');
  });

  test(
    'throws PlatformNotImplementedException when native side is missing',
    () async {
      // Removing the mock makes the call raise MissingPluginException internally;
      // the data source wraps that as a `PlatformNotImplementedException`.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(
        () => ds.disableStrip(),
        throwsA(isA<PlatformNotImplementedException>()),
      );
    },
  );

  test('schedulePrayerReminders sends the reminders key', () async {
    final days = [
      {
        'date': '2026-05-22',
        'timings': {'fajr': '04:15', 'maghrib': '19:46'},
      },
    ];
    await ds.schedulePrayerReminders(
      days: days,
      reminders: {
        'fajr': {'minutes': 15, 'reminderSound': 'silent'},
      },
      localeCode: 'ar',
    );
    expect(calls.single.method, 'schedulePrayerReminders');
    final args = calls.single.arguments as Map;
    expect(args['days'], days);
    expect(args['reminders'], {
      'fajr': {'minutes': 15, 'reminderSound': 'silent'},
    });
    expect(args.containsKey('remindersByPrayer'), isFalse);
    expect(args['localeCode'], 'ar');
  });

  test(
    'scheduleTestAdhan sends delay, locale, sound and ringInSilent',
    () async {
      await ds.scheduleTestAdhan(
        delay: const Duration(seconds: 5),
        localeCode: 'ar',
        sound: 'vibrate',
        ringInSilent: true,
      );
      expect(calls.single.method, 'scheduleTestAdhan');
      expect(calls.single.arguments, {
        'delaySeconds': 5,
        'localeCode': 'ar',
        'sound': 'vibrate',
        'ringInSilent': true,
      });
    },
  );

  test('getReliabilityStatus returns the native map', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'isXiaomi': true};
        });
    final result = await ds.getReliabilityStatus();
    expect(calls.single.method, 'getReliabilityStatus');
    expect(result['isXiaomi'], true);
  });

  test('getReliabilityStatus returns an empty map on null', () async {
    expect(await ds.getReliabilityStatus(), isEmpty);
  });

  test('getReliabilityStatus throws PlatformNotImplementedException when '
      'native side is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(
      () => ds.getReliabilityStatus(),
      throwsA(isA<PlatformNotImplementedException>()),
    );
  });

  test('openSystemSettings sends the target name', () async {
    await ds.openSystemSettings('xiaomiBattery');
    expect(calls.single.method, 'openSystemSettings');
    expect(calls.single.arguments, {'target': 'xiaomiBattery'});
  });

  test('previewSound sends sound and prayer', () async {
    await ds.previewSound(sound: 'adhan', prayer: 'fajr');
    expect(calls.single.method, 'previewSound');
    expect(calls.single.arguments, {'sound': 'adhan', 'prayer': 'fajr'});
  });

  test('ackMissed sends upTo', () async {
    await ds.ackMissed(upTo: 1763190000000);
    expect(calls.single.method, 'ackMissed');
    expect(calls.single.arguments, {'upTo': 1763190000000});
  });

  test('stopPreview invokes the channel', () async {
    await ds.stopPreview();
    expect(calls.single.method, 'stopPreview');
  });

  test(
    'openSystemSettings completes when native replies with a bool',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return false;
          });
      await ds.openSystemSettings('autostart');
      expect(calls.single.arguments, {'target': 'autostart'});
    },
  );

  test('cancelAllReminders invokes the channel', () async {
    await ds.cancelAllReminders();
    expect(calls.single.method, 'cancelAllReminders');
  });

  test('previewEnded emits the sound the native side reports', () async {
    final events = <String>[];
    final sub = ds.previewEnded.listen(events.add);
    final replies = <ByteData?>[];
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          NotificationsNativeDataSourceImpl.channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('previewEnded', {'sound': 'adhan'}),
          ),
          replies.add,
        );
    await pumpEventQueue();
    expect(events, ['adhan']);
    expect(replies, hasLength(1));
    await sub.cancel();
  });

  test('previewEnded ignores other native calls', () async {
    final events = <String>[];
    final sub = ds.previewEnded.listen(events.add);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          NotificationsNativeDataSourceImpl.channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('somethingElse', {'sound': 'adhan'}),
          ),
          (_) {},
        );
    await pumpEventQueue();
    expect(events, isEmpty);
    await sub.cancel();
  });
}
