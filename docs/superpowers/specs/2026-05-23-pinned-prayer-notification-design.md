# Pinned Prayer Notification — Design

**Status:** Draft, awaiting implementation.
**Author:** Brainstormed with Sameh Ibrahim, 2026-05-23.
**Scope:** Add an ongoing pinned notification showing today's six prayer times, with the next prayer visually highlighted; rewrite the existing adhan flow so swiping the adhan notification reliably stops the sound.

---

## 1. Overview

The app currently schedules a one-off notification for each prayer (Fajr, Dhuhr, Asr, Maghrib, Isha) via `flutter_local_notifications` channel-played sounds (`lib/core/notifications/prayer_notification_scheduler_impl.dart`). That flow handles the adhan but offers no glanceable schedule.

This design adds:

1. **Pinned prayer strip** — an ongoing system notification (Android) / Live Activity (iOS 16.1+) that shows the day's six prayers with the next prayer highlighted in a gold pill on the app's dark-teal background.
2. **Reliable swipe-to-stop adhan** — the existing per-prayer notification + audio is rewritten to use a foreground service with an explicit `MediaPlayer`, so swiping the notification immediately stops the sound regardless of clip length or OEM behavior.

The two changes ship together because they share a single foreground service on Android and the same MethodChannel surface on the Flutter side.

## 2. Goals

- Match the reference design's structure: header row (app icon + name + Hijri date) + 6-cell prayer strip with one cell highlighted as a pill.
- Use the app's existing dark-teal palette and Arabic-Indic numerals when locale is Arabic.
- Survive app process death, force-quit, and reboot (Android).
- Adhan swipe reliably stops the sound on every supported Android OEM.
- Live Activity surface on iOS 16.1+ with the same structure; older iOS versions get a disabled toggle with explanation.

## 3. Non-goals

- No live countdown ("in 2h 15m") in the strip — adds a per-minute refresh job we want to avoid.
- No per-prayer icons in the strip cells.
- No Play / Pause / Stop action buttons on the adhan notification.
- No always-on iOS pinned notification — Apple's Live Activity model caps each activity at ~8 hours; we document this honestly in the Settings tile and do not work around it.
- No 24/7 background service on iOS.
- No persistence of prayer times across users (existing Hive-backed cache is unchanged).

## 4. Visual specification

### 4.1 Strip layout (Android expanded view, iOS lock-screen Live Activity)

```
┌────────────────────────────────────────────────────────────────────┐
│  [icon]  Quran App  ·  5 ذو الحجة                           ︿     │  ← header
├────────────────────────────────────────────────────────────────────┤
│   العشاء   المغرب   العصر   الظهر   الشروق   ┌─── الفجر ───┐       │
│    9:16    7:46    4:28   12:52    5:07    │     4:15     │       │  ← strip
│                                            └──────────────┘       │
└────────────────────────────────────────────────────────────────────┘
   Background: surface (onyx #081815 in dark mode, brightSnow in light).
   Cells laid out RTL when locale = ar, LTR when locale = en.
   Times in Arabic-Indic numerals (٤:١٥) when locale = ar.
   Next-prayer cell wrapped in a rounded-rect pill using surfaceContainer
   (evergreen #0C231F in dark mode, lightMist in light) — same treatment
   as the home strip's next-prayer highlight in `single_prayer_card.dart`.
```

### 4.2 Collapsed view (Android only, when strip is collapsed in the shade)

Single line condensed: `[icon]  next prayer name  ·  time  ·  Hijri date`. Tap expands.

### 4.3 Friday label

On Fridays, the Dhuhr cell label is `الجمعة` (Arabic) / "Jumu'ah" (English). The time is unchanged.

### 4.4 Theming

Colors are sourced from `lib/config/theme/app_colors.dart` and `color_scheme.dart`. The strip always uses the **dark palette** regardless of system theme — the reference notification is a self-contained branded surface, not a system-themed one. (Light-mode tokens are listed for completeness in case we later allow following the system.)

| Element | Dark token | Light token |
|---|---|---|
| Strip background | `onyx` `#081815` | `brightSnow` `#F8F9F8` |
| Next-prayer pill | `evergreen` `#0C231F` (= `surfaceContainer`) | `lightMist` `#E9E9E9` |
| Prayer label | `brightSnow` `#F8F9F8` | `onyx` `#081815` |
| Prayer time | `greyOlive` `#8B9A94` (= `onSurfaceVariant`) | `greyOlive` |
| Header text | `brightSnow` | `onyx` |
| Divider / accent | `pineTeal` `#134E3E` (= `primary`) | `pineTeal` |

No new color tokens are introduced. If the existing palette needs adjustment, that's a separate change.

### 4.5 RTL

When locale is Arabic, all rows flow right-to-left. The next-prayer pill is the visually-leading cell. When locale is English, flow is left-to-right.

## 5. User-facing behavior

| Trigger | Behavior |
|---|---|
| User taps anywhere on the pinned strip | App opens to home screen. |
| User taps anywhere on the adhan notification | App opens to home; adhan sound continues. |
| User swipes the adhan notification | Adhan sound stops immediately. |
| User swipes the pinned strip | Notification redisplays after a short delay — it is `ongoing`. To stop it, the user must use the in-app Settings toggle. |
| User toggles "Pinned prayer times" ON | If permission granted, strip appears within ~1s. If permission denied, snackbar prompts to grant; toggle stays OFF. |
| User toggles "Pinned prayer times" OFF | Strip disappears immediately. Scheduled adhans continue. |
| Prayer time arrives | Adhan notification appears, sound plays, pill highlight on the strip moves to the next prayer. |
| Midnight | Strip rebuilds with the new day's times. Friday label applied as needed. |

## 6. Platform scope

- **Android:** full support, default target. Pinned ongoing notification via foreground service.
- **iOS 16.1+:** Live Activity on lock screen and Dynamic Island. Limited to ~8 hours per activity by Apple — strip re-arms next time the app is opened. Settings tile subtitle explains this.
- **iOS < 16.1:** Settings toggle is disabled with explanation. Adhan scheduling still works via standard `UNNotificationRequest`.
- **Other platforms (linux/macos/windows/web):** Settings toggle hidden.

## 7. Architecture

### 7.1 Feature layout

The work is structured as a new `notifications` feature under `lib/features/`. The existing `lib/core/notifications/` files (`prayer_notification_scheduler.dart` and `prayer_notification_scheduler_impl.dart`) are deleted as part of this change — the new feature owns all notification responsibilities.

```
lib/features/notifications/
├── domain/
│   ├── entities/
│   │   ├── prayer_strip_state.dart           # snapshot rendered into the strip
│   │   └── adhan_audio_settings.dart         # which clip + volume per prayer
│   ├── repositories/
│   │   └── notifications_repository.dart     # abstract contract
│   └── usecases/
│       ├── enable_prayer_strip.dart
│       ├── disable_prayer_strip.dart
│       ├── refresh_prayer_strip.dart         # called when today's times reload
│       └── sync_daily_adhans.dart            # replaces old PrayerNotificationScheduler
├── data/
│   ├── datasources/
│   │   └── notifications_native_data_source.dart  # MethodChannel facade
│   └── repositories/
│       └── notifications_repository_impl.dart
├── presentation/                             # empty — toggle lives in settings feature
└── notifications_di.dart                     # initNotifications(); called from core/di
```

### 7.2 Boundary rules

- Domain layer is pure Dart. `PrayerStripState` and `AdhanAudioSettings` contain only primitives (`String`, `int`, `bool`, `List<PrayerCell>` where `PrayerCell` is itself primitives-only).
- Data layer owns the MethodChannel. Nothing in domain or presentation touches `MethodChannel` directly.
- Failures map: `PermissionDeniedFailure`, `NoPrayerDataFailure`, `PlatformNotSupportedFailure`, `UnknownNotificationFailure` (in `core/errors/failures.dart`, alongside existing failures).

### 7.3 Entities

```dart
class PrayerStripState {
  final List<PrayerCell> cells;        // exactly 6 entries
  final int nextPrayerIndex;           // 0..5
  final String hijriDateLabel;         // e.g. "5 ذو الحجة" or "5 Dhul-Hijjah"
  final String localeCode;             // "ar" | "en"
  final bool isFriday;                 // for Jumu'ah label swap
}

class PrayerCell {
  final String label;                  // pre-localized + Friday-aware
  final String timeFormatted;          // Arabic-Indic numerals if locale == ar
}

class AdhanAudioSettings {
  final Map<PrayerName, String> clipAssetByPrayer;  // raw resource name
  final double volume;                              // 0.0 .. 1.0
}
```

Formatting (Friday swap, numeral conversion) is done in Dart before crossing the bridge so the native side is dumb — it paints the strings it receives.

### 7.4 Repository contract

```dart
abstract class NotificationsRepository {
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state);
  Future<Either<Failure, Unit>> disableStrip();
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state);
  Future<Either<Failure, Unit>> scheduleDailyAdhans(
    PrayerTimes prayerTimes,
    AdhanAudioSettings audio,
  );
  Future<Either<Failure, Unit>> cancelAllAdhans();
}
```

### 7.5 State flow

```
User toggles Settings switch ─→ SettingsCubit.updatePrayerStripPinned(true)
                                          │
                                          ↓
                                EnablePrayerStrip.call(state)
                                          │
                                          ↓
                       NotificationsRepository.enableStrip(state)
                                          │
                                          ↓
                       NativeDataSource.invokeMethod('enableStrip', json)
                                          │
                                          ↓
            Android: startService(PrayerStripService, ACTION_SHOW_STRIP)
            iOS:     Activity<PrayerStripAttributes>.request(...)
```

Refresh happens on:

- Every prayer-time crossing (so the pill moves to the next prayer).
- Midnight (new day, new times). Already wired in `PrayerCountdownCubit` lines 95-101.
- Locale change (`SettingsCubit` already broadcasts).
- Location change (existing prayer-times reload chain).

`PrayerCountdownCubit` gains one side effect: when its tick crosses a prayer boundary or a minute boundary that matters, it invokes `RefreshPrayerStrip`. The cubit itself stays a `Cubit`, not a `BlocConsumer` — the use case is awaited from a non-blocking helper.

## 8. Android implementation

### 8.1 Single foreground service

"Ongoing notification" on Android = a notification with `setOngoing(true)`, hosted by a started foreground service. The two are coupled: the service keeps the process alive, the flag prevents the user from swiping the notification away. One service owns both the pinned strip and the adhan playback:

```kotlin
class PrayerStripService : Service() {
    // Notification IDs
    private val STRIP_NOTIF_ID = 100   // ongoing, pinned
    private val ADHAN_NOTIF_ID = 101   // transient

    // Channels
    //   prayer_strip_channel    IMPORTANCE_LOW, no sound, no vibration  → silent pin
    //   prayer_adhan_channel    IMPORTANCE_MAX, sound via MediaPlayer (not channel)

    fun onStartCommand(intent, flags, startId) {
        when (intent.action) {
            ACTION_SHOW_STRIP    -> renderStrip(intent.getStringExtra(EXTRA_STATE_JSON))
            ACTION_HIDE_STRIP    -> stopForeground(STOP_FOREGROUND_REMOVE); stopSelf()
            ACTION_FIRE_ADHAN    -> playAdhanFor(intent.getStringExtra(EXTRA_PRAYER))
            ACTION_STOP_ADHAN    -> adhanPlayer.stop(); cancel(ADHAN_NOTIF_ID)
        }
    }
}
```

`foregroundServiceType` is `mediaPlayback` to cover Android 14's typed-foreground-service requirement (the adhan is media playback; the pinned strip rides along on the same service).

### 8.2 Strip rendering

`PrayerStripRenderer.build(state)` returns a `Notification` using:

- `setCustomContentView(collapsed)` → `R.layout.prayer_strip_collapsed`
- `setCustomBigContentView(expanded)` → `R.layout.prayer_strip_expanded`
- `setStyle(DecoratedCustomViewStyle())`

Both layouts are `RemoteViews` XML files. The expanded layout is a vertical `LinearLayout` (header row + horizontal weighted 6-cell row). The pill is a single `drawable/pill_gold.xml` shape; it's applied to the next-prayer cell via `setBackgroundResource` from the renderer.

RTL is handled by `android:layoutDirection="locale"` on the strip row, plus the Dart layer ordering cells appropriately.

### 8.3 Alarms and refresh

`AlarmManager.setExactAndAllowWhileIdle` is set for:

- Each of today's six prayer times (to move the highlight pill).
- 00:01 the next day (to roll the strip over).
- Fallback every 6 hours (resilience in case an exact alarm is dropped).

`PrayerAlarmReceiver` receives those broadcasts and calls `PrayerStripService` with `ACTION_SHOW_STRIP` and the cached state (a small JSON blob written to shared prefs on each Dart-side refresh).

`BOOT_COMPLETED` re-arms alarms and re-posts the strip if the user has the toggle on.

### 8.4 Adhan playback

`AdhanPlayer` wraps `android.media.MediaPlayer`:

- Loads the bundled clip from `res/raw/fajr_adhan.mp3` or `res/raw/normal_adhan.mp3`.
- Stream: `AudioAttributes.USAGE_NOTIFICATION` (respects Do-Not-Disturb exemption when channel allows it).
- `OnCompletionListener` cancels `ADHAN_NOTIF_ID` and stops the player.

The adhan notification's `setDeleteIntent` points at `PrayerStripService.ACTION_STOP_ADHAN`. This is the guarantee that swipe reliably stops audio — independent of clip length or OEM.

### 8.5 Manifest additions

```xml
<service
    android:name=".PrayerStripService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="false" />

<receiver
    android:name=".PrayerAlarmReceiver"
    android:exported="false" />
```

Permissions added: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`. Existing permissions (`POST_NOTIFICATIONS`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`) are kept.

### 8.6 Native file layout

```
android/app/src/main/kotlin/com/example/quran_app/
├── PrayerStripPlugin.kt           # FlutterPlugin + MethodChannel handler
├── PrayerStripService.kt          # foreground service
├── PrayerStripRenderer.kt         # builds RemoteViews from state JSON
├── AdhanPlayer.kt                 # MediaPlayer wrapper
└── PrayerAlarmReceiver.kt         # AlarmManager broadcast receiver

android/app/src/main/res/
├── layout/
│   ├── prayer_strip_collapsed.xml
│   └── prayer_strip_expanded.xml
└── drawable/
    └── pill_gold.xml
```

## 9. iOS implementation

### 9.1 Live Activity coverage

A Live Activity is started by the Flutter app when:

- The user enables the strip toggle, or
- The app launches and the toggle is already on, or
- A previous activity has expired (~8 hours after start) and the app is foregrounded again.

Apple's ~8-hour cap means the activity will not persist all day in the worst case. Settings tile subtitle explicitly says so.

### 9.2 Files (new Widget Extension target)

```
ios/PrayerStripWidget/
├── PrayerStripActivityAttributes.swift
│   └── struct PrayerStripAttributes : ActivityAttributes
│       static fields:  prayerNamesAr[6], prayerNamesEn[6]
│       ContentState:   times[6], nextPrayerIndex, hijriDate, isFriday, isArabic
├── PrayerStripLiveActivity.swift
│   └── ActivityConfiguration(for: PrayerStripAttributes.self) { ctx in
│         LockScreenView(ctx.state)
│       } dynamicIsland: { ctx in
│         DynamicIsland { compact / minimal / expanded variants }
│       }
├── PrayerStripWidget.swift                   # WidgetBundle entrypoint
└── Info.plist                                # NSExtensionPointIdentifier = widget
```

### 9.3 Flutter bridge

`ios/Runner/PrayerStripChannel.swift` handles the same MethodChannel methods as Android:

- `enableStrip` → `Activity<PrayerStripAttributes>.request(attributes:, contentState:)`
- `refreshStrip` → `activity.update(using: newState)`
- `disableStrip` → `activity.end(dismissalPolicy: .immediate)`

### 9.4 Adhan playback on iOS

Bundled `fajr_adhan.caf` and `normal_adhan.caf` already ship via the existing `DarwinNotificationDetails` config. We extend that to:

1. Schedule a `UNNotificationRequest` with `UNNotificationSound.criticalSoundNamed` for the adhan time.
2. Register `UNUserNotificationCenterDelegate.userNotificationCenter:didReceive:` to handle `dismissAction` → stop `just_audio_background` player.
3. `UIBackgroundModes` includes `audio` (already enabled via `just_audio_background` in `pubspec.yaml` line 57).

iOS notification sounds max out at 30 seconds — for full adhan clips we delegate to `just_audio_background`, kicked off from the notification-fired hook. This keeps the swipe-stop semantics intact.

## 10. Settings integration

### 10.1 Entity change

```dart
class Settings {
  // existing fields...
  final bool isPrayerStripPinned;   // default false
}
```

`SettingsModel.fromMap` / `toMap` updated to round-trip the new field; old persisted state without the field defaults to `false`.

### 10.2 Cubit change

```dart
void updatePrayerStripPinned(bool value) async {
  emit(SettingsState(state.settingsModel.copyWith(isPrayerStripPinned: value)));
  final useCase = value ? sl<EnablePrayerStrip>() : sl<DisablePrayerStrip>();
  await useCase.call(/* current PrayerStripState if enable */);
}
```

Side effect lives in the cubit, not the entity.

### 10.3 UI

One new `SwitchListTile` in the existing settings page:

- Title (localized): "Pinned prayer times" / "أوقات الصلاة المثبتة"
- Subtitle (localized): "Shows today's prayers in your notification shade. On iPhone (iOS 16.1+), stays for up to 8 hours after you open the app."
- Disabled on iOS < 16.1 with helper text explaining the OS requirement.
- Permission prompt triggered on first enable; if denied, toggle reverts to off with a snackbar.

## 11. Dependency injection

`notifications_di.dart`:

```dart
void initNotifications() {
  sl.registerLazySingleton<NotificationsNativeDataSource>(
    () => NotificationsNativeDataSourceImpl(),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => EnablePrayerStrip(sl()));
  sl.registerLazySingleton(() => DisablePrayerStrip(sl()));
  sl.registerLazySingleton(() => RefreshPrayerStrip(sl()));
  sl.registerLazySingleton(() => SyncDailyAdhans(sl()));
}
```

Called from `core/di/dependency_injection.dart` alongside the existing `initHome()` etc.

## 12. Edge cases

| # | Situation | Behavior |
|---|---|---|
| 1 | Toggle ON but prayer times not loaded | `EnablePrayerStrip` returns `Left(NoPrayerDataFailure)`. Tile shows "Waiting for prayer times…". When times load, `RefreshPrayerStrip` fires the real enable. |
| 2 | Notification permission denied | Toggle reverts to false. Snackbar: "Notification permission required". |
| 3 | Android: `USE_EXACT_ALARM` not granted | Fallback to `setAndAllowWhileIdle()` (inexact). Highlight may drift a few minutes. Not a blocker. |
| 4 | Android: device reboot | `PrayerAlarmReceiver` listens for `BOOT_COMPLETED`. If `isPrayerStripPinned == true` (read from shared prefs), re-arm alarms and re-post strip with cached state. |
| 5 | App uninstall / data clear | Foreground service dies with the app. Notification disappears. Nothing to clean up. |
| 6 | Midnight crossover | Existing `PrayerCountdownCubit` midnight refresh path wired to `SyncDailyAdhans` + `RefreshPrayerStrip`. |
| 7 | Locale switch | `SettingsCubit` calls `RefreshPrayerStrip` with new locale; strip re-renders. |
| 8 | Location change | Existing prayer-times reload propagates via `RefreshPrayerStrip`. |
| 9 | Friday ⇄ Saturday rollover | Midnight refresh recalculates `isFriday`; Dhuhr cell renames itself. |
| 10 | Adhan fires while phone is in DND | Adhan channel has `setBypassDnd(true)`. Strip channel does not. |
| 11 | User taps adhan notification body | Opens app to home; sound continues until clip ends or app stops it. |
| 12 | iOS: app force-killed | Live Activity continues in the system. Updates resume next app open. |
| 13 | iOS: 8-hour activity expiry | Activity ends; next app open restarts it. |
| 14 | Two adhans collide (clock skip) | `AdhanPlayer` checks "is already playing"; if so, queues the next clip until the current ends. |
| 15 | User disables strip channel in OS settings | `NotificationManager.areNotificationsEnabled()` checked at startup; if false, app-level toggle flips off to stay in sync. |

## 13. Testing strategy

### 13.1 Pure Dart unit tests (target ≥ 90% coverage)

- `prayer_strip_state.dart`: formatter logic (Arabic-Indic conversion, Friday label swap, `nextPrayerIndex` boundary cases at midnight, after Isha, before Fajr).
- Use cases: `enable_prayer_strip`, `disable_prayer_strip`, `refresh_prayer_strip`, `sync_daily_adhans` (via `bloc_test` + `mocktail` mocks of the repository).
- `notifications_repository_impl.dart`: mock the data source, assert `Right(...)` / `Left(Failure)` mapping.
- `settings_cubit.dart`: new `bloc_test` cases for `updatePrayerStripPinned(true/false)` verifying the right use case is invoked.

### 13.2 MethodChannel tests

`notifications_native_data_source.dart`: `TestDefaultBinaryMessengerBinding` stubs the native side. Verify each method (`enableStrip`, `refreshStrip`, `disableStrip`, `scheduleDailyAdhans`, `cancelAllAdhans`) is called with the right JSON payload.

### 13.3 Manual device test plan

1. Fresh install → Settings → toggle on → grant permission. **Expect:** pinned strip at top of notification shade, dark teal background, gold pill on next prayer, Hijri date in header.
2. Lock the phone for 2 min, unlock. **Expect:** strip still there.
3. Swipe down on lock screen. **Expect:** strip visible.
4. Force-quit the app. **Expect:** strip still there.
5. Wait for next prayer time. **Expect:** adhan sound plays, separate notification appears, swipe it → sound stops immediately.
6. Tap pinned strip. **Expect:** app opens to home.
7. Toggle off in Settings. **Expect:** strip disappears within ~1s.
8. Reboot phone. **Expect:** strip re-appears within ~30s of unlock.
9. Switch to English in Settings. **Expect:** strip re-renders with English names + Western numerals.
10. iPhone 14 Pro / iOS 16.1+: open app, lock screen. **Expect:** Live Activity visible.
11. iPhone with iOS < 16.1: open Settings. **Expect:** toggle disabled with explanation.
12. Friday morning: **Expect:** Dhuhr cell shows الجمعة.

### 13.4 Coverage honesty

Automated coverage stops at the MethodChannel boundary. The actual rendering of `RemoteViews` / SwiftUI, AlarmManager firing, and foreground-service lifecycle require physical-device verification per the manual plan above. This is acknowledged limitation, not a defect — the design keeps native code small and dumb so manual verification is straightforward.

## 14. Migration plan

The change ships on `feature/004-pinned-prayer-notification`. The implementation plan (produced separately by the writing-plans skill) is expected to phase the work so each phase is independently reviewable; suggested phases:

1. Dart-side feature folder, use cases, repository, MethodChannel stubs, settings entity + UI (no real native rendering yet).
2. Android pinned strip (foreground service, RemoteViews, AlarmManager scheduling).
3. Android adhan rewrite + delete the old `core/notifications/` scheduler.
4. iOS Live Activity (new widget extension target).
5. iOS adhan rewrite (delete notification swipe handling + just_audio_background integration).

Whether shipped as one PR or several is left to the implementation plan; the design above is platform-symmetric so phases can land independently.

When the work lands as a single PR, that PR:

1. Adds the new `lib/features/notifications/` feature, fully tested.
2. Adds native Android files under `android/app/src/main/kotlin/com/example/quran_app/` and resources under `res/layout/` + `res/drawable/`.
3. Adds the iOS Widget Extension target under `ios/PrayerStripWidget/`.
4. Updates `Settings` entity, `SettingsCubit`, and the settings page UI.
5. Wires the new use cases into `PrayerCountdownCubit` refresh hooks.
6. Deletes `lib/core/notifications/prayer_notification_scheduler.dart` and `lib/core/notifications/prayer_notification_scheduler_impl.dart`. Removes their registrations from DI. No parallel/legacy path is kept.
7. Updates `AndroidManifest.xml` with the new service, receiver, and permissions; removes the now-unused `flutter_local_notifications` receivers if `flutter_local_notifications` is no longer used elsewhere.
8. Updates `pubspec.yaml` only if `flutter_local_notifications` becomes unused (remove it) — otherwise leave it.

`flutter_local_notifications` usage audit will be done during implementation; if it's only used by the old scheduler, remove it from `pubspec.yaml`.

## 15. Out of scope (deferred to later work)

- Multiple adhan voices / user-selectable reciter for the adhan.
- Adhan volume control in Settings.
- Strip layout variants (e.g. landscape, foldable, tablet).
- Strip on Wear OS / watchOS.
- Per-prayer enable/disable for adhans (currently all five fire).
- Snooze button on the adhan notification.
- Mute-today / silence-this-prayer actions.

## 16. Open questions

None at design time. Implementation may surface additional native-platform details (specific OEM quirks, exact behavior of `setExactAndAllowWhileIdle` on Android 14+ with battery-optimized apps, ActivityKit push-update entitlement requirements) — those will be addressed inline in the implementation plan.

## 17. References

- Reference screenshot: another prayer-times app's pinned notification (cream background, brown pill on next prayer).
- Existing home strip implementation: `lib/features/home/presentation/pages/widgets/single_prayer_card.dart` — source of the next-prayer highlight pattern reused here.
- Existing notification scheduler being replaced: `lib/core/notifications/prayer_notification_scheduler_impl.dart`.
- Android docs: foreground service types (Android 14), `RemoteViews`, `AlarmManager.setExactAndAllowWhileIdle`.
- Apple docs: `ActivityKit`, Live Activity lifecycle, `UNNotificationSound.criticalSoundNamed`.
