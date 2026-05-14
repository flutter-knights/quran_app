# Adhan Audio Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single placeholder `adhan.mp3` notification sound with two distinct adhan recordings — a dedicated one for Fajr and a standard one for the other four prayers — wired through two new notification channels so it works on Android 8.0+ where channel sounds are immutable.

**Architecture:** Two `AndroidNotificationChannel` instances (`prayer_fajr_channel`, `prayer_standard_channel`) created explicitly in `PrayerNotificationSchedulerImpl.init()`, plus a small `_detailsFor(PrayerName)` lookup that picks `_fajrDetails` or `_standardDetails` when scheduling each prayer. iOS uses per-notification sound names (no channel concept). The old `prayer_times_channel` is explicitly deleted on init for a clean migration.

**Tech Stack:** Flutter, `flutter_local_notifications`, Android raw resources, iOS bundle resources, `ffmpeg`/`afconvert` for trimming iOS clips.

**Spec reference:** `docs/superpowers/specs/2026-05-14-adhan-audio-notifications-design.md`

---

## File Map

**Will create:**
- `android/app/src/main/res/raw/fajr_adhan.mp3` — Fajr adhan (full length, copied from `assets/audio/fajr adhan.mp3`)
- `android/app/src/main/res/raw/normal_adhan.mp3` — standard adhan (full length, copied from `assets/audio/normal adhan.mp3`)
- `ios/Runner/fajr_adhan.caf` — 30s clip of Fajr adhan
- `ios/Runner/normal_adhan.caf` — 30s clip of standard adhan

**Will modify:**
- `lib/core/notifications/prayer_notification_scheduler_impl.dart` — replace single `_notificationDetails` with two-channel + lookup pattern; add explicit channel creation and old-channel deletion in `init()`.

**Will delete:**
- `android/app/src/main/res/raw/adhan.mp3` (orphaned)
- `ios/Runner/adhan.mp3` (orphaned)

**Will NOT change:**
- `lib/core/notifications/prayer_notification_scheduler.dart` (abstract interface unchanged)
- `lib/features/home/domain/usecases/schedule_prayer_notifications.dart` (calls the same interface method)
- `lib/main.dart`, `lib/features/home/home_di.dart` (no DI changes)
- `pubspec.yaml` (native sound files don't need Flutter asset registration)

**Testing note:** There is no existing unit test for `PrayerNotificationSchedulerImpl` — its behaviour is a thin pass-through to `flutter_local_notifications`, which uses platform channels that can't be exercised meaningfully from a Dart unit test. Verification is **manual install-and-fire** on a real device, captured in Task 3.

---

## Task 1: Add native sound resources

**Files:**
- Create: `android/app/src/main/res/raw/fajr_adhan.mp3`
- Create: `android/app/src/main/res/raw/normal_adhan.mp3`
- Create: `ios/Runner/fajr_adhan.caf`
- Create: `ios/Runner/normal_adhan.caf`
- Delete: `android/app/src/main/res/raw/adhan.mp3`
- Delete: `ios/Runner/adhan.mp3`

- [ ] **Step 1: Copy the Android raw resources**

Run (PowerShell, from repo root):

```powershell
Copy-Item "assets/audio/fajr adhan.mp3"   "android/app/src/main/res/raw/fajr_adhan.mp3"
Copy-Item "assets/audio/normal adhan.mp3" "android/app/src/main/res/raw/normal_adhan.mp3"
```

Verify:

```powershell
Get-ChildItem "android/app/src/main/res/raw/" | Select-Object Name
```

Expected output includes `fajr_adhan.mp3` and `normal_adhan.mp3`.

- [ ] **Step 2: Produce the 30-second iOS clips**

iOS notification sounds are capped at 30s. Trim each source file to 30s and convert to Apple's preferred `.caf` container. Run (requires `ffmpeg` on PATH):

```powershell
ffmpeg -y -i "assets/audio/fajr adhan.mp3"   -t 30 -c:a pcm_s16le "ios/Runner/fajr_adhan.caf"
ffmpeg -y -i "assets/audio/normal adhan.mp3" -t 30 -c:a pcm_s16le "ios/Runner/normal_adhan.caf"
```

Verify:

```powershell
Get-ChildItem ios/Runner/fajr_adhan.caf, ios/Runner/normal_adhan.caf | Select-Object Name, Length
```

Expected: both files exist, length > 0 bytes.

(If `ffmpeg` is not available, run on macOS with `afconvert` instead: `afconvert -d ima4 -f caff "fajr adhan.mp3" "fajr_adhan.caf"` after trimming. Either way, the deliverable is a ≤30s `.caf` file at the path above.)

- [ ] **Step 3: Register the iOS sound files in the Runner Xcode project**

This step requires Xcode on macOS — it cannot be done from Windows alone. If implementing from Windows, defer this step to whoever runs the iOS build; document it as a manual prerequisite.

On macOS:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. In the Project navigator, right-click the `Runner` folder → "Add Files to Runner…".
3. Select `ios/Runner/fajr_adhan.caf` and `ios/Runner/normal_adhan.caf`.
4. In the dialog: "Copy items if needed" off (files already in place), "Added folders: Create groups", Target: `Runner` checked.
5. Confirm both files appear under the `Runner` group with `Runner` membership.

Verify: Build the iOS target (`flutter build ios --debug --no-codesign`); both filenames should appear in `ios/Runner/Runner.app/` after build.

- [ ] **Step 4: Delete the orphaned old sound files**

```powershell
Remove-Item "android/app/src/main/res/raw/adhan.mp3"
Remove-Item "ios/Runner/adhan.mp3"
```

If the old iOS file is referenced in `ios/Runner.xcodeproj/project.pbxproj`, also remove its reference from Xcode (Project navigator → right-click `adhan.mp3` → Delete → "Remove Reference"). Build will fail at link time if a dangling reference is left.

Verify:

```powershell
Test-Path "android/app/src/main/res/raw/adhan.mp3"
Test-Path "ios/Runner/adhan.mp3"
```

Expected: both `False`.

- [ ] **Step 5: Commit**

```powershell
git add android/app/src/main/res/raw/ ios/Runner/
git commit -m "chore: add fajr/normal adhan native sound resources"
```

---

## Task 2: Two-channel scheduler with per-prayer sound

**Files:**
- Modify: `lib/core/notifications/prayer_notification_scheduler_impl.dart` (full rewrite of constants section + `init()` + `_notificationDetails` reference in `scheduleDailyPrayerNotifications`)

- [ ] **Step 1: Replace the file contents**

Open `lib/core/notifications/prayer_notification_scheduler_impl.dart` and replace the whole file with the following. (Whole-file replacement keeps the diff coherent — the imports, class shape, and most method bodies are unchanged; only the channel/details constants and `init()` migration block are new.)

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationSchedulerImpl implements PrayerNotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  PrayerNotificationSchedulerImpl({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const Map<PrayerName, int> _notificationIds = {
    PrayerName.fajr: 10,
    // 11 reserved for sunrise (not scheduled — sunrise has no adhan)
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

  static const String _fajrChannelId = 'prayer_fajr_channel';
  static const String _standardChannelId = 'prayer_standard_channel';
  static const String _legacyChannelId = 'prayer_times_channel';

  static const AndroidNotificationChannel _fajrChannel =
      AndroidNotificationChannel(
    _fajrChannelId,
    'Fajr adhan',
    description: 'Adhan at prayer time',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('fajr_adhan'),
    playSound: true,
    enableVibration: false,
  );

  static const AndroidNotificationChannel _standardChannel =
      AndroidNotificationChannel(
    _standardChannelId,
    'Prayer adhan',
    description: 'Adhan at prayer time',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('normal_adhan'),
    playSound: true,
    enableVibration: false,
  );

  static const NotificationDetails _fajrDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _fajrChannelId,
      'Fajr adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('fajr_adhan'),
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'fajr_adhan.caf',
      presentSound: true,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  static const NotificationDetails _standardDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _standardChannelId,
      'Prayer adhan',
      channelDescription: 'Adhan at prayer time',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('normal_adhan'),
      playSound: true,
      enableVibration: false,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'normal_adhan.caf',
      presentSound: true,
      presentAlert: true,
      presentBadge: false,
    ),
  );

  NotificationDetails _detailsFor(PrayerName p) =>
      p == PrayerName.fajr ? _fajrDetails : _standardDetails;

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // One-time migration: drop the legacy single-sound channel. No-op if absent.
    await androidPlugin?.deleteNotificationChannel(_legacyChannelId);
    await androidPlugin?.createNotificationChannel(_fajrChannel);
    await androidPlugin?.createNotificationChannel(_standardChannel);

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
    debugPrint('[PrayerNotif] init complete, tz=${tz.local.name}');
  }

  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] schedule called before init — skipping');
      return;
    }

    await cancelAllPrayerNotifications();
    final date = prayerTimes.date.gregorianDate.gregorianDate();
    final now = DateTime.now();
    debugPrint('[PrayerNotif] scheduling for date=$date, now=$now');

    var scheduled = 0;
    var skipped = 0;
    for (final entry in _notificationIds.entries) {
      final prayerName = entry.key;
      final notificationId = entry.value;
      final timeStr = prayerTimes.timings[prayerName];
      if (timeStr == null) {
        skipped++;
        continue;
      }

      try {
        final parts = timeStr.split(':');
        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        if (scheduledTime.isBefore(now)) {
          skipped++;
          continue;
        }

        await _plugin.zonedSchedule(
          id: notificationId,
          title: _prayerTitles[prayerName],
          body: 'Time for ${_prayerTitles[prayerName]} prayer',
          scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails: _detailsFor(prayerName),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        scheduled++;
        debugPrint(
          '[PrayerNotif] scheduled $prayerName id=$notificationId at $scheduledTime',
        );
      } catch (e) {
        skipped++;
        debugPrint('[PrayerNotif] schedule failed for $prayerName: $e');
        continue;
      }
    }
    debugPrint(
      '[PrayerNotif] done: scheduled=$scheduled, skipped=$skipped',
    );
  }

  @override
  Future<void> cancelAllPrayerNotifications() async {
    for (final id in _notificationIds.values) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> scheduleTestNotification({
    Duration delay = const Duration(seconds: 30),
  }) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] test called before init — skipping');
      return;
    }
    final fireAt = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id: 9999,
      title: 'Adhan test',
      body: 'Background fire check (${delay.inSeconds}s)',
      scheduledDate: fireAt,
      notificationDetails: _standardDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[PrayerNotif] test scheduled at $fireAt');
  }
}
```

**Notes on the diff** (read these before saving — they prevent the most likely mistakes):
- Two new channel ID constants + the legacy ID constant for the one-time delete call.
- `_fajrChannel` / `_standardChannel` are `AndroidNotificationChannel` objects used **only** for `createNotificationChannel`. Their sound MUST match the channel of the same ID's `AndroidNotificationDetails` in `_fajrDetails` / `_standardDetails`, otherwise the per-notification details get ignored and you'll think the sound is broken when it's actually the channel.
- Sound resource names are `fajr_adhan` and `normal_adhan` (no `.mp3` extension) — that's how `RawResourceAndroidNotificationSound` references Android raw resources.
- iOS sound names include the `.caf` extension because Darwin reads them as bundle filenames.
- `_legacyChannelId` is referenced inside `init()` for `deleteNotificationChannel` — this is safe to keep calling on every launch (no-op once deleted).

- [ ] **Step 2: Static analysis**

Run:

```powershell
flutter analyze lib/core/notifications/
```

Expected: `No issues found!`

If there are issues, fix them before continuing.

- [ ] **Step 3: Existing tests still pass**

The only test that references the scheduler is the use-case test, which uses a mock. Run it:

```powershell
flutter test test/features/home/domain/usecases/schedule_prayer_notifications_test.dart
```

Expected: all tests pass. (The mock implements the abstract interface, which is unchanged, so this should not regress.)

- [ ] **Step 4: Commit**

```powershell
git add lib/core/notifications/prayer_notification_scheduler_impl.dart
git commit -m "feat: per-prayer adhan via fajr and standard notification channels"
```

---

## Task 3: Manual device verification

This task has no commit — it's a manual verification gate. Only proceed to mark the plan complete after all checks pass.

**Files:** none modified.

- [ ] **Step 1: Fresh install on Android (uninstall first to drop the old channel cache)**

```powershell
flutter clean
adb uninstall com.example.quran_app   # adjust to actual applicationId if different
flutter run
```

Wait for the app to fully launch and reach the home screen (which loads `DailyPrayerContext` and triggers scheduling).

- [ ] **Step 2: Verify channels in Android system settings**

On the device: Settings → Apps → Quran App → Notifications.

Expected: exactly two channels — "Fajr adhan" and "Prayer adhan". The old "Prayer Times" channel must be absent.

If "Prayer Times" still appears, `deleteNotificationChannel` didn't run — recheck Task 2 Step 1 for the call placement inside `init()`.

- [ ] **Step 3: Fire the standard-channel test notification**

In the running app, trigger `scheduleTestNotification(delay: const Duration(seconds: 30))` via whatever debug entry point exists (the home view has a debug button in dev builds per recent commits; if not, add a temporary FAB → remove before commit). Lock the device, wait ~30 seconds.

Expected: notification fires, plays `normal_adhan`, body reads "Background fire check (30s)".

- [ ] **Step 4: Verify Fajr-specific sound**

The cleanest way without spoofing real prayer times: temporarily add a one-off test call in `home_view.dart` (or wherever you trigger Step 3) that uses the scheduler's plugin directly to fire a notification under id 10 with `_fajrDetails`. **Easier path:** add a second public method `scheduleFajrTestNotification` mirroring `scheduleTestNotification` but with `notificationDetails: _fajrDetails`, exercise it, then revert that addition before the final commit.

Expected: notification fires, plays `fajr_adhan` (audibly different from `normal_adhan`).

If both sound identical, the channels were probably created before the new sound resources were in place. Uninstall the app fully (`adb uninstall …`) and reinstall — channel sound cannot be updated in-place.

- [ ] **Step 5: iOS verification (if a Mac + device/simulator are available)**

Run on iOS, repeat Steps 3 and 4. Both clips should play their respective 30-second trims. If a sound is silent on iOS, the most likely cause is the `.caf` file is not in `Runner.app` — re-check Task 1 Step 3 (Xcode bundle membership).

- [ ] **Step 6: Tidy up**

If you added a temporary `scheduleFajrTestNotification` in Step 4, remove it now. Re-run `flutter analyze lib/` to make sure the cleanup didn't leave dangling references.

```powershell
flutter analyze lib/
```

Expected: `No issues found!`

If nothing to clean up, this step is a no-op.

---

## Verification summary

After all three tasks:
- `git log --oneline -3` shows two new commits: `chore: add fajr/normal adhan native sound resources` and `feat: per-prayer adhan via fajr and standard notification channels`.
- `flutter analyze lib/` is clean.
- Existing scheduler test (`schedule_prayer_notifications_test.dart`) still passes.
- On a freshly installed Android build, exactly two notification channels appear ("Fajr adhan", "Prayer adhan"), the old "Prayer Times" channel is gone, and Fajr notifications play `fajr_adhan` while the other four play `normal_adhan`.
