# Prayer Time Notifications with Adhan Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schedule local OS notifications that play adhan sound at each prayer time, firing even when the app is fully killed.

**Architecture:** The OS delivers `flutter_local_notifications` scheduled alarms independently of the app process. An abstract `PrayerNotificationScheduler` lives in `lib/core/notifications/` (pure Dart interface, implementation imports Flutter plugin). The existing `DailyPrayerContextLoaded` BlocListener in `HomePage` triggers fire-and-forget scheduling after every successful prayer times fetch.

**Tech Stack:** `flutter_local_notifications ^18.x`, `timezone ^0.9.4`, `flutter_timezone ^3.1.0`, `flutter_bloc`, `get_it`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `lib/core/notifications/prayer_notification_scheduler.dart` | Abstract interface (pure Dart) |
| Create | `lib/core/notifications/prayer_notification_scheduler_impl.dart` | Concrete implementation (imports flutter plugin) |
| Create | `lib/features/home/domain/usecases/schedule_prayer_notifications.dart` | Use case — delegates to scheduler |
| Create | `test/features/home/domain/usecases/schedule_prayer_notifications_test.dart` | Unit test for use case |
| Modify | `pubspec.yaml` | Add three new dependencies |
| Modify | `android/app/src/main/AndroidManifest.xml` | Add POST_NOTIFICATIONS, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED |
| Modify | `lib/features/home/home_di.dart` | Register scheduler + use case |
| Modify | `lib/features/home/presentation/pages/home_page.dart` | Add third BlocListener |
| Modify | `lib/main.dart` | Call `scheduler.init()` on startup |
| Add file | `android/app/src/main/res/raw/adhan.mp3` | Adhan audio for Android |
| Add file | `ios/Runner/adhan.mp3` | Adhan audio for iOS (+ Xcode bundle step) |

---

### Task 1: Add Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages via pub add**

Run from project root:

```bash
flutter pub add flutter_local_notifications timezone flutter_timezone
```

Expected output ends with: `Changed N dependencies!`

- [ ] **Step 2: Verify pubspec.yaml has all three**

Open `pubspec.yaml` and confirm `dependencies:` section contains:

```yaml
flutter_local_notifications: ^18.0.0   # version may vary
timezone: ^0.9.4                        # version may vary
flutter_timezone: ^3.1.0               # version may vary
```

- [ ] **Step 3: Run flutter pub get to confirm no conflicts**

```bash
flutter pub get
```

Expected: no errors, `pubspec.lock` updated.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_local_notifications, timezone, flutter_timezone deps"
```

---

### Task 2: Add Adhan Audio Files

**Files:**
- Add: `android/app/src/main/res/raw/adhan.mp3`
- Add: `ios/Runner/adhan.mp3`

> Source your adhan MP3 file before this step. A free one is available at https://islamicfinder.org/prayer-sounds/ or use any short adhan clip (≤30 s recommended).

- [ ] **Step 1: Create the Android raw resource directory**

```bash
mkdir -p android/app/src/main/res/raw
```

- [ ] **Step 2: Copy adhan file for Android**

Place the MP3 (or WAV) in `android/app/src/main/res/raw/` named exactly `adhan.mp3` (lowercase, no spaces). The filename without extension becomes the sound reference: `RawResourceAndroidNotificationSound('adhan')`.

- [ ] **Step 3: Copy adhan file for iOS**

Place the same file in `ios/Runner/adhan.mp3`.

> **CRITICAL iOS step (manual — cannot be scripted):** Open `ios/Runner.xcworkspace` in Xcode. In the Project Navigator, right-click the `Runner` folder → "Add Files to Runner…" → select `adhan.mp3`. In the dialog, ensure **"Add to targets: Runner"** is checked and **"Copy items if needed"** is checked. This adds the file to "Copy Bundle Resources" — without this the iOS notification sound will not play.

- [ ] **Step 4: Verify files are present**

```bash
ls android/app/src/main/res/raw/
ls ios/Runner/ | grep adhan
```

Expected: `adhan.mp3` appears in both.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/res/raw/adhan.mp3 ios/Runner/adhan.mp3
git commit -m "feat: add adhan audio file for Android and iOS notifications"
```

---

### Task 3: Android Manifest Permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

> Do NOT add `ScheduledNotificationReceiver` or `ScheduledNotificationBootReceiver` manually — the `flutter_local_notifications` plugin auto-merges those via its own AndroidManifest. Only add the three permissions below.

- [ ] **Step 1: Read current manifest**

Open `android/app/src/main/AndroidManifest.xml` and locate the existing `<uses-permission>` block (currently contains ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, INTERNET).

- [ ] **Step 2: Add the three new permissions**

Add these three lines directly after the existing `<uses-permission>` entries, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

`POST_NOTIFICATIONS` — runtime permission (Android 13+) for showing any notification.
`USE_EXACT_ALARM` — grants exact alarm scheduling; auto-approved at install on API 33+, no runtime prompt.
`RECEIVE_BOOT_COMPLETED` — lets the plugin reschedule after device reboot.

- [ ] **Step 3: Verify manifest parses correctly**

```bash
flutter build apk --debug 2>&1 | tail -20
```

Expected: build succeeds (or fails only on unrelated issues). No `manifest merger failed` error.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add notification permissions to AndroidManifest"
```

---

### Task 4: Core Notification Infrastructure

**Files:**
- Create: `lib/core/notifications/prayer_notification_scheduler.dart`
- Create: `lib/core/notifications/prayer_notification_scheduler_impl.dart`

- [ ] **Step 1: Create the abstract interface**

Create `lib/core/notifications/prayer_notification_scheduler.dart`:

```dart
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerNotificationScheduler {
  Future<void> init();
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes);
  Future<void> cancelAllPrayerNotifications();
}
```

This is pure Dart — no Flutter imports — so it is safe to reference from domain use cases.

- [ ] **Step 2: Create the implementation**

Create `lib/core/notifications/prayer_notification_scheduler_impl.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationSchedulerImpl implements PrayerNotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  PrayerNotificationSchedulerImpl({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const Map<PrayerName, int> _notificationIds = {
    PrayerName.fajr: 10,
    PrayerName.dhuhr: 12,
    PrayerName.asr: 13,
    PrayerName.maghrib: 14,
    PrayerName.isha: 15,
  };

  static const Map<PrayerName, String> _prayerTitles = {
    PrayerName.fajr: 'Fajr',
    PrayerName.dhuhr: 'Dhuhr',
    PrayerName.asr: 'Asr',
    PrayerName.maghrib: 'Maghrib',
    PrayerName.isha: 'Isha',
  };

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_times_channel',
      'Prayer Times',
      channelDescription: 'Adhan at prayer times',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('adhan'),
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'adhan.mp3',
      presentSound: true,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes) async {
    await cancelAllPrayerNotifications();
    final date = DateFormat('dd-MM-yyyy').parse(prayerTimes.date.gregorianDate);
    final now = DateTime.now();

    for (final entry in _notificationIds.entries) {
      final prayerName = entry.key;
      final notificationId = entry.value;
      final timeStr = prayerTimes.timings[prayerName];
      if (timeStr == null) continue;

      final parts = timeStr.split(':');
      final scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      if (scheduledTime.isBefore(now)) continue;

      await _plugin.zonedSchedule(
        notificationId,
        _prayerTitles[prayerName],
        'Time for ${_prayerTitles[prayerName]} prayer',
        tz.TZDateTime.from(scheduledTime, tz.local),
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAllPrayerNotifications() async {
    for (final id in _notificationIds.values) {
      await _plugin.cancel(id);
    }
  }
}
```

Key design notes:
- `sunrise` is intentionally excluded from `_notificationIds` — Sunrise is not a prayer with adhan.
- `cancelAllPrayerNotifications()` is called first to prevent duplicate alarms on re-schedule.
- `isBefore(now)` skips prayers that already passed today.
- `tz.local` is only valid after `init()` sets it via `FlutterTimezone.getLocalTimezone()`. Without this, `tz.local` defaults to UTC and notifications fire at wrong times.

- [ ] **Step 3: Verify no analysis errors**

```bash
dart analyze lib/core/notifications/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/core/notifications/
git commit -m "feat: add PrayerNotificationScheduler interface and implementation"
```

---

### Task 5: Domain Use Case + Unit Test

**Files:**
- Create: `lib/features/home/domain/usecases/schedule_prayer_notifications.dart`
- Create: `test/features/home/domain/usecases/schedule_prayer_notifications_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/home/domain/usecases/schedule_prayer_notifications_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/usecases/schedule_prayer_notifications.dart';

class MockPrayerNotificationScheduler extends Mock
    implements PrayerNotificationScheduler {}

void main() {
  late MockPrayerNotificationScheduler mockScheduler;
  late SchedulePrayerNotifications useCase;

  final fakePrayerTimes = PrayerTimes(
    key: '13-05-2026',
    timings: {
      PrayerName.fajr: '04:30',
      PrayerName.sunrise: '06:00',
      PrayerName.dhuhr: '12:00',
      PrayerName.asr: '15:30',
      PrayerName.maghrib: '18:45',
      PrayerName.isha: '20:15',
    },
    date: Date(
      month: 'Dhul-Qidah',
      weekDay: 'Wednesday',
      day: '15',
      year: '1447',
      enMonth: 'November',
      enWeekDay: 'Wednesday',
      gregorianDate: '13-05-2026',
    ),
  );

  setUp(() {
    mockScheduler = MockPrayerNotificationScheduler();
    useCase = SchedulePrayerNotifications(scheduler: mockScheduler);
  });

  test('delegates to scheduler with the correct PrayerTimes', () async {
    when(
      () => mockScheduler.scheduleDailyPrayerNotifications(fakePrayerTimes),
    ).thenAnswer((_) async {});

    await useCase(
      SchedulePrayerNotificationsParams(prayerTimes: fakePrayerTimes),
    );

    verify(
      () => mockScheduler.scheduleDailyPrayerNotifications(fakePrayerTimes),
    ).called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/domain/usecases/schedule_prayer_notifications_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'schedule_prayer_notifications.dart'`

- [ ] **Step 3: Implement the use case**

Create `lib/features/home/domain/usecases/schedule_prayer_notifications.dart`:

```dart
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class SchedulePrayerNotificationsParams {
  final PrayerTimes prayerTimes;
  const SchedulePrayerNotificationsParams({required this.prayerTimes});
}

class SchedulePrayerNotifications
    extends UseCase<void, SchedulePrayerNotificationsParams> {
  final PrayerNotificationScheduler scheduler;

  const SchedulePrayerNotifications({required this.scheduler});

  @override
  Future<void> call(SchedulePrayerNotificationsParams params) =>
      scheduler.scheduleDailyPrayerNotifications(params.prayerTimes);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/home/domain/usecases/schedule_prayer_notifications_test.dart
```

Expected: PASS — `All tests passed!`

- [ ] **Step 5: Run the full test suite to check for regressions**

```bash
flutter test
```

Expected: all previously-passing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/domain/usecases/schedule_prayer_notifications.dart \
        test/features/home/domain/usecases/schedule_prayer_notifications_test.dart
git commit -m "feat: add SchedulePrayerNotifications use case with unit tests"
```

---

### Task 6: Dependency Injection Wiring

**Files:**
- Modify: `lib/features/home/home_di.dart`

- [ ] **Step 1: Read current home_di.dart to find the insertion point**

Open `lib/features/home/home_di.dart`. The last registered item is the `DailyPrayerContextCubit` factory at the bottom of `initHome()`.

- [ ] **Step 2: Add imports at top of home_di.dart**

Add these two imports after the existing import block:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler_impl.dart';
import 'package:quran_app/features/home/domain/usecases/schedule_prayer_notifications.dart';
```

- [ ] **Step 3: Register scheduler and use case at bottom of initHome()**

At the end of `initHome()`, after the Cubit registration, add:

```dart
  // Notifications
  sl.registerLazySingleton<PrayerNotificationScheduler>(
    () => PrayerNotificationSchedulerImpl(
      plugin: FlutterLocalNotificationsPlugin(),
    ),
  );
  sl.registerLazySingleton(
    () => SchedulePrayerNotifications(scheduler: sl()),
  );
```

- [ ] **Step 4: Verify analysis**

```bash
dart analyze lib/features/home/home_di.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_di.dart
git commit -m "feat: register PrayerNotificationScheduler and SchedulePrayerNotifications in DI"
```

---

### Task 7: Initialize Notifications on App Start

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Read current main.dart**

Open `lib/main.dart` and locate the async initialization sequence. It currently ends with `await initGetIt()` (or similar).

- [ ] **Step 2: Add scheduler init after GetIt initialization**

Add this block immediately after `await initGetIt()`:

```dart
await sl<PrayerNotificationScheduler>().init();
```

And add the import at the top of `main.dart`:

```dart
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
```

The full init sequence should now read:

```dart
await initHydratedCubit();
await initHive();
await initGetIt();
await sl<PrayerNotificationScheduler>().init();
```

> `init()` calls `tz.initializeTimeZones()`, fetches the local timezone via `FlutterTimezone`, and requests OS permissions. It must run after `initGetIt()` (which registers the scheduler) and before any screen is shown.

- [ ] **Step 3: Verify analysis**

```bash
dart analyze lib/main.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize PrayerNotificationScheduler on app start"
```

---

### Task 8: Trigger Scheduling from HomePage

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Read current home_page.dart**

Open `lib/features/home/presentation/pages/home_page.dart`. The `MultiBlocListener` currently has two listeners: one for `PrayerCountdownRequestRefresh` and one for `DailyPrayerContextLoaded` (fire-and-forget pre-cache).

- [ ] **Step 2: Add import for new use case**

Add at the top of the file:

```dart
import 'package:quran_app/features/home/domain/usecases/schedule_prayer_notifications.dart';
```

- [ ] **Step 3: Add third BlocListener in MultiBlocListener**

Inside the `listeners: [...]` list, add this third listener after the existing two:

```dart
BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
  listenWhen: (_, s) => s is DailyPrayerContextLoaded,
  listener: (context, state) {
    final loaded = state as DailyPrayerContextLoaded;
    unawaited(
      sl<SchedulePrayerNotifications>().call(
        SchedulePrayerNotificationsParams(
          prayerTimes: loaded.dailyPrayerContext.prayerTimes,
        ),
      ),
    );
  },
),
```

This fires every time fresh prayer times are loaded — which happens at startup, at midnight refresh, and after a manual refresh. The cancel-then-reschedule logic inside `scheduleDailyPrayerNotifications` ensures no duplicates.

- [ ] **Step 4: Verify analysis**

```bash
dart analyze lib/features/home/presentation/pages/home_page.dart
```

Expected: no errors.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "feat: schedule prayer notifications on DailyPrayerContextLoaded"
```

---

### Task 9: Manual End-to-End Verification

- [ ] **Step 1: Run app on Android device or emulator**

```bash
flutter run
```

- [ ] **Step 2: Verify notification permission dialog appears**

On first launch (Android 13+), a system dialog requesting notification permission should appear. Approve it.

- [ ] **Step 3: Check that notifications are scheduled**

Open device Settings → Apps → [Your App] → Notifications → confirm the "Prayer Times" channel is listed.

Alternatively, open Android Studio Device File Explorer or run:

```bash
adb shell dumpsys alarm | grep quran_app
```

Expected: 5 pending alarms registered (one per prayer, minus any already past).

- [ ] **Step 4: Manually trigger a test notification**

Temporarily edit `scheduleDailyPrayerNotifications` to schedule 1 minute from now for one prayer (to test without waiting hours). Revert after confirming adhan plays.

```dart
// Temporary test override — remove after testing
final testTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
await _plugin.zonedSchedule(
  99,
  'Test Prayer',
  'Adhan test',
  testTime,
  _notificationDetails,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
);
```

Kill the app completely, wait 1 minute — notification should appear with adhan sound.

- [ ] **Step 5: Revert test override if added**

```bash
git checkout lib/core/notifications/prayer_notification_scheduler_impl.dart
```

- [ ] **Step 6: Test on iOS simulator (if available)**

```bash
flutter run -d <ios-device-id>
```

Accept notification permission prompt. Verify iOS notification fires with sound. iOS simulator may not play audio — test on physical device for full sound verification.

- [ ] **Step 7: Final commit (if any test fixes were needed)**

```bash
git add -p
git commit -m "fix: address issues found during manual E2E notification testing"
```

---

## Self-Review

### Spec Coverage
- Background delivery when app is killed ✅ — `AndroidScheduleMode.exactAllowWhileIdle`
- Adhan sound on Android ✅ — `RawResourceAndroidNotificationSound('adhan')`
- Adhan sound on iOS ✅ — `DarwinNotificationDetails(sound: 'adhan.mp3')`
- Five prayers (not Sunrise) ✅ — `_notificationIds` excludes Sunrise
- No duplicate alarms ✅ — cancel-then-reschedule pattern
- Past prayers skipped ✅ — `isBefore(now)` guard
- Clean Architecture (domain layer stays pure Dart) ✅ — abstract interface in `core/`, implementation separate
- Runs on every prayer data refresh ✅ — BlocListener in HomePage

### Known Limitations (v1)
- Notification titles are hardcoded in English. Localized titles would require accessing `S.current` from a presentation-layer component and passing titles in, which adds complexity. Acceptable for v1.
- No per-prayer notification toggle. All five prayers are always scheduled.
- No notification tap action (opens app to prayer view). Not in scope for v1.
