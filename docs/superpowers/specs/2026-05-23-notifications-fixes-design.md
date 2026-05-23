# Notifications Fixes & Adhan Playback — Design

**Date:** 2026-05-23
**Branch:** `feature/004-pinned-prayer-notification`
**Scope:** Resolve three notification issues on the current branch:

1. Real adhan never fires at prayer time (test button works)
2. Pinned prayer strip needs redesign with the app's color scheme + Cairo typography
3. Per-prayer adhan audio is cut off when the notification shade is expanded; the notification must persist until manually dismissed

## Companion documents

- Existing plan (Plan B, in progress): `docs/superpowers/plans/2026-05-23-pinned-prayer-notification-android.md`
- Existing strip spec: `docs/superpowers/specs/2026-05-23-pinned-prayer-notification-design.md`
- Visual mockups for the redesign: `docs/superpowers/specs/2026-05-23-strip-redesign-mockups.html`

The implementation plan that follows this spec will be written by `superpowers:writing-plans` and saved alongside the existing Plan B plan.

---

## 1. Background

The branch already merged the Android pinned-strip foreground service (`PrayerStripService`), the Kotlin `PrayerStripPlugin` on `quran_app/notifications`, and the Dart-side cubit wiring for `EnablePrayerStrip` / `DisablePrayerStrip`. Per-prayer adhan notifications, however, still go through the legacy Dart `PrayerNotificationSchedulerImpl` (a `flutter_local_notifications` wrapper), and that path is broken in two ways the user can observe:

- Scheduled prayer notifications never fire (despite the test button working through the same plugin and channel).
- Even when a notification does fire (test path), the adhan audio is interrupted when the user expands the notification shade — because `flutter_local_notifications` plays the audio as a notification sound, not as independent media playback.

The pinned strip itself is functional but uses the system default font and a baseline color treatment (gold pill on a solid onyx background). The user finds the gold accent visually wrong for an Islamic prayer app and the typography off-brand (no Cairo).

## 2. Goals

1. Per-prayer adhan notifications **reliably fire** at the scheduled prayer time on Android, with a permanent diagnostic trail.
2. Adhan audio **plays through to completion** (or until user dismissal) regardless of notification-shade interaction.
3. Adhan notification is **ongoing** — the user must explicitly dismiss it (Stop action or swipe). Three dismissal paths: Stop button, swipe, audio completion (notification stays silent until swiped).
4. Pinned strip uses the **Cairo typeface** and a **typography-led** active-prayer treatment (no gold pill).
5. Strip and adhan playback live in **separate, independent services**. Either can be toggled without affecting the other.

## 3. Non-goals

- iOS path. iOS continues to use the legacy `PrayerNotificationScheduler` via `flutter_local_notifications` until a future iOS Live Activity plan.
- Per-prayer adhan voice selection (different voices per prayer beyond the existing Fajr / standard split). Stays out of scope.
- Adhan volume slider in settings. The audio is played at alarm volume; the OS volume control governs.
- Boot-time recovery for the adhan. If the device reboots, the next `DailyPrayerContextLoaded` re-arms; missing one adhan after a reboot before next app open is accepted.

## 4. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Dart                                                            │
│                                                                  │
│  HomePage listener                                               │
│    │                                                             │
│    ├── SyncDailyAdhans  ──►  NotificationsRepository             │
│    │                              │                              │
│    │                              ├── Android: native.scheduleDailyAdhans
│    │                              └── iOS: legacyScheduler (unchanged)
│    │                                                             │
│    └── EnablePrayerStrip / RefreshPrayerStrip / DisablePrayerStrip
└─────────────────────────────────────────────────────────────────┘
                              │ MethodChannel: quran_app/notifications
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Android native (com.example.quran_app)                          │
│                                                                  │
│  PrayerStripPlugin                                               │
│    ├── enableStrip / refreshStrip / disableStrip ──► PrayerStripService  (existing)
│    └── scheduleDailyAdhans / cancelAllAdhans     ──► AdhanScheduler      (NEW)
│                                                                  │
│  AdhanScheduler           — schedules AlarmManager pendingIntents
│  AdhanAlarmReceiver       — fires at prayer time, starts service
│  AdhanPlaybackService     — FGS, plays MediaPlayer + ongoing notif
│                                                                  │
│  PrayerStripService       — UNTOUCHED                            │
└─────────────────────────────────────────────────────────────────┘
```

Key invariants:

- Strip and adhan are two independent Android foreground services. They share the `quran_app/notifications` MethodChannel and the font + color resources, but neither owns the other.
- Adhan delivery on Android moves off `flutter_local_notifications`. The Dart `PrayerNotificationScheduler` becomes Android-skipped (iOS-only). This is what enables reliable diagnostics — we own the alarm chain end-to-end.
- Strip redesign is XML-only on the native side plus one new font resource (Cairo TTFs). No Kotlin changes for visuals.

## 5. New Android components

```
android/app/src/main/kotlin/com/example/quran_app/
├── AdhanScheduler.kt          — schedules + cancels per-prayer AlarmManager intents
├── AdhanAlarmReceiver.kt      — fires at HH:mm, starts AdhanPlaybackService
├── AdhanPlaybackService.kt    — FGS playing MediaPlayer + ongoing notification
└── AdhanBootReceiver.kt       — no-op reserved for future use
```

| Class | Purpose | Lifetime |
|---|---|---|
| `AdhanScheduler` | Pure helper. Given `(prayerName, hhmm, clipResName)` schedules a `setExactAndAllowWhileIdle` alarm. Cancels previously-armed alarms before arming the next set. Logs every step. | Stateless |
| `AdhanAlarmReceiver` | Wakes at prayer time. Reads extras, calls `startForegroundService(AdhanPlaybackService)`. Returns within 10ms. | One-shot per alarm |
| `AdhanPlaybackService` | Foreground service, `foregroundServiceType="mediaPlayback"`. Starts MediaPlayer on `STREAM_ALARM` with `USAGE_ALARM`. Posts ongoing notification (channel `prayer_adhan_channel`, importance HIGH, no own sound). On audio completion: release player, keep notification. On Stop or swipe: stopForeground + stopSelf. | Until dismissed |
| `AdhanBootReceiver` | Declared in manifest for future use. On `BOOT_COMPLETED` does nothing initially (see §6.4). | Boot-only |

### New Android resources

```
res/font/cairo.xml                    — font-family declaring 3 weights
res/font/cairo_regular.ttf            (W400)
res/font/cairo_semibold.ttf           (W600)
res/font/cairo_bold.ttf               (W700)
res/drawable/moon_crescent.xml        — vector drawable (solid deep-teal crescent)
res/drawable/strip_time_pill.xml      — rounded-rect deep-teal background for active time
res/drawable/adhan_stop_icon.xml      — vector icon for notification Stop action
res/values/strings.xml                — "Stop" / app name
res/values-ar/strings.xml             — Arabic mirrors
```

Existing files modified:

- `AndroidManifest.xml` — add `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission; register `AdhanPlaybackService`, `AdhanAlarmReceiver`, `AdhanBootReceiver`.
- `PrayerStripPlugin.kt` — implement `scheduleDailyAdhans` / `cancelAllAdhans` (currently `notImplemented()`), delegating to `AdhanScheduler`.
- `colors.xml` — refine palette tokens (see §7).
- `prayer_strip_expanded.xml`, `prayer_strip_collapsed.xml` — redesign (see §7).

### Dart-side changes

- `NotificationsRepositoryImpl.scheduleDailyAdhans` — branch by `defaultTargetPlatform`. Android routes to `native.scheduleDailyAdhans`. iOS continues to call `legacyScheduler.scheduleDailyPrayerNotifications`.
- `lib/core/notifications/prayer_notification_scheduler_impl.dart` — `scheduleDailyPrayerNotifications` becomes a no-op on Android (logs a debug line so the audit trail makes it clear we didn't fall through to the legacy path); unchanged on iOS.
- `lib/features/home/presentation/pages/widgets/home_view.dart` — debug "Test adhan 30s" FAB switches to invoke the **new native path** on Android (a `scheduleTestAdhan(+30s)` method added to the channel). iOS continues calling the legacy scheduler for the test button.

## 6. Data flow

### 6.1 Flow A — Daily adhan scheduling

```
DailyPrayerContextLoaded
    │
    ▼  HomePage listener
SyncDailyAdhans(prayerTimes)
    │
    ▼
NotificationsRepositoryImpl.scheduleDailyAdhans
    │
    ├── Android: native.scheduleDailyAdhans(timings, clipsByPrayer, volume)
    │       │
    │       ▼  MethodChannel: quran_app/notifications
    │       │
    │       PrayerStripPlugin.onMethodCall("scheduleDailyAdhans")
    │       │
    │       ▼
    │       AdhanScheduler.armToday(args)
    │           1. Cancel previously-armed PendingIntents (request codes 200..205)
    │           2. For each prayer (skip sunrise + past times):
    │              - Build PendingIntent → AdhanAlarmReceiver with extras
    │                  {prayer: "fajr", clipResName: "fajr_adhan", at: <epoch ms>}
    │              - alarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, at, pi)
    │              - Log: "[Adhan] armed fajr at 2026-05-23 04:15"
    │           3. Persist {armed: true, dateKey: "2026-05-23"} to SharedPreferences
    │
    └── iOS: legacyScheduler.scheduleDailyPrayerNotifications  (unchanged)
```

Request-code allocation:
- Fajr → 200
- Dhuhr → 201
- Asr → 202
- Maghrib → 203
- Isha → 204
- (Sunrise has no adhan; index 205 reserved for future use)

### 6.2 Flow B — Adhan firing at prayer time

```
AlarmManager wakes
    │
    ▼
AdhanAlarmReceiver.onReceive   (must return within 10ms)
    │  - Reads extras (prayer, clipResName)
    │  - context.startForegroundService(Intent(AdhanPlaybackService) + extras)
    │  - Returns immediately
    │
    ▼
AdhanPlaybackService.onStartCommand(ACTION_PLAY)
    │
    1. Build ongoing notification (channel "prayer_adhan_channel"):
       - Title:  localized prayer name (e.g. "Fajr" / "الفجر")
       - Body:   localized "It's time for <Prayer> prayer"
       - Smallicon: app launcher
       - setOngoing(true)
       - setAutoCancel(false)
       - addAction(stopIcon, "Stop"|"إيقاف", stopPI)
       - setContentIntent(launchAppPI)
       - setDeleteIntent(stopPI)  // handles swipe
       - Uses Cairo font (via NotificationCompat's RemoteInput / Builder spans — see §7.4)
    │
    2. startForeground(NOTIF_ID, notification)
    │
    3. MediaPlayer:
       - setAudioAttributes(USAGE_ALARM | CONTENT_TYPE_SONIFICATION)
       - setDataSource(resources.openRawResourceFd(R.raw.<clipResName>))
       - prepare(); start()
       - setOnCompletionListener { mediaPlayer.release(); mediaPlayer = null; /* keep service alive */ }
       - setOnErrorListener { log; release; do not crash }
    │
    4. Log: "[AdhanService] playing <clip> at <time>"
```

Notification body localization comes from the channel call args (Section 7), not from `Locale.getDefault()`, so it always matches the app's current language.

Audio attributes use `USAGE_ALARM` so the adhan rides the alarm volume and bypasses Do Not Disturb (alarms are exempted by default on Android). This is religiously time-critical audio; treating it as an alarm is the correct semantic.

### 6.3 Flow C — Dismissal

```
User taps Stop  ─┐
User swipes    ──┼──► broadcast ACTION_STOP → AdhanPlaybackService
                  ┘
                       │
                       ▼
                AdhanPlaybackService.onStartCommand(ACTION_STOP)
                       1. mediaPlayer?.stop(); release(); null
                       2. stopForeground(STOP_FOREGROUND_REMOVE)
                       3. stopSelf()
                       Log: "[AdhanService] dismissed reason=<stop|swipe>"

Audio finishes naturally
                       │
                       ▼
                MediaPlayer.onCompletion
                       1. mediaPlayer.release(); null
                       2. Notification kept (no stopForeground, no stopSelf)
                       Log: "[AdhanService] audio completed, notification kept"
                User must swipe or tap Stop to dismiss.
```

### 6.4 Flow D — Reboot recovery

Adhan: **no-op**. `AdhanBootReceiver` is declared for future use but does nothing initially. Rationale: timings depend on location which the app re-fetches on next launch; rather than caching `(timings, clips)` separately for the boot path, accept that one adhan can be missed if the device reboots and the user doesn't open the app before the next prayer.

Strip: continues to re-arm via its existing `PrayerStripBootReceiver` (unchanged).

## 7. Visual design — pinned strip

### 7.1 Locked design

| Property | Value |
|---|---|
| Background | **Transparent** — strip body inherits the system shade surface |
| Active-prayer label | Bright snow (`#F8F9F8`), Cairo bold 12sp |
| Active-prayer time | Bright snow, Cairo bold 14sp, wrapped in a **deep-teal solid mini-pill** (`#4A7C6A`, padding 2dp×8dp, corner radius 8dp) |
| Passed-prayer cells | Snow @ 40% opacity for both label and time, Cairo semibold 12 / regular 11 |
| Future-prayer cells | Label snow @ 90%, time grey-olive (`#8B9A94`), Cairo semibold 12 / regular 11 |
| Hijri date | Grey-olive, Cairo regular 12sp, preceded by a **solid deep-teal vector crescent** (≈12dp) |
| Weekday name | Grey-olive Cairo regular 12sp by default; **deep-teal Cairo bold** when `isFriday=true` |
| Cell padding | 8dp top/bottom, 4dp left/right |
| Strip padding | 14dp all sides |
| RTL | `android:layoutDirection="locale"` — Arabic locale renders Fajr on the right |

The "Quran App" text is dropped from the header — Android's system notification frame already shows the app name above the custom view.

### 7.2 Color tokens — `res/values/colors.xml`

```xml
<color name="strip_text_primary">#FFF8F9F8</color>   <!-- bright-snow -->
<color name="strip_text_muted">#FF8B9A94</color>     <!-- grey-olive -->
<color name="strip_text_dim">#66F8F9F8</color>       <!-- snow @ 40% -->
<color name="strip_accent">#FF4A7C6A</color>         <!-- deep-teal -->
<color name="strip_accent_soft">#594A7C6A</color>    <!-- deep-teal @ 35% -->
```

Single source of truth: comment at top points to `lib/config/theme/app_colors.dart`. Gold and pine-teal tokens are removed from strip usage (gold no longer used; pine-teal too dark for active-cell accent).

### 7.3 Cairo font integration

Three TTF weights bundled in `res/font/`:

- `cairo_regular.ttf` (W400)
- `cairo_semibold.ttf` (W600)
- `cairo_bold.ttf` (W700)

`res/font/cairo.xml` declares the font-family. Every `TextView` in the strip + adhan layouts uses `android:fontFamily="@font/cairo"` with `android:textFontWeight` to pick a weight on API 28+. APK growth ≈ 600 KB.

### 7.4 Adhan-notification visual

Standard `NotificationCompat.Builder` (not custom `RemoteViews`) — keeps the OS-themed parts intact and only customizes title + body + action. Title and body are spannable strings using the Cairo bundled font where the OS supports `android:fontFamily` on notification text (API 28+); on older devices it falls back to system Arabic. The Stop action uses a vector stop-circle icon (~24dp).

## 8. Issue #1 diagnostics

The new path logs every step. Diagnostic commands:

```
# capture armed alarms
adb shell dumpsys alarm | grep -A5 com.example.quran_app

# stream the adhan pipeline live
adb logcat -c && adb logcat *:S Adhan:V AdhanReceiver:V AdhanService:V
```

Expected log lines on a healthy app open:

```
[Adhan] armToday: starting (today=2026-05-23, location=Cairo, Egypt)
[Adhan] permission SCHEDULE_EXACT_ALARM = granted
[Adhan] permission POST_NOTIFICATIONS = granted
[Adhan] armed Fajr at 2026-05-23 04:15:00 (request=200, +18h12m)
[Adhan] armed Dhuhr at 2026-05-23 12:52:00 (request=201, +2h36m)
[Adhan] armed Asr at 2026-05-23 16:28:00 (request=202, +6h12m)
[Adhan] armed Maghrib at 2026-05-23 19:46:00 (request=203, +9h30m)
[Adhan] armed Isha at 2026-05-23 21:16:00 (request=204, +11h00m)
[Adhan] armToday: 5 armed, 1 skipped (sunrise=no adhan)
```

When alarm fires:

```
[AdhanReceiver] onReceive prayer=asr clip=normal_adhan
[AdhanService] onStartCommand action=ACTION_PLAY
[AdhanService] MediaPlayer setDataSource ok → prepare → start
[AdhanService] playing for 142s (estimated)
... (after audio completes)
[AdhanService] MediaPlayer onCompletion (released, notification kept)
... (after user dismissal)
[AdhanService] dismissed reason=user_stop
```

If any step is missing, the gap identifies the root cause.

## 9. Testing strategy

### 9.1 Automated

**Dart**:
- `NotificationsRepositoryImpl` — verify Android-path routes to `native.scheduleDailyAdhans` (mock both data sources).
- iOS path still routes to `legacyScheduler` (mock).
- `SyncDailyAdhans` — extend existing tests with the platform-switch coverage.

**Kotlin (JVM-only)**:
- `AdhanScheduler` — given `(timings, clips)`, verify request-code assignment, exact-alarm scheduling calls, and re-arm cancellation logic. Uses mocked `AlarmManager`.
- `AdhanPlaybackService` — stub `MediaPlayer`, verify play → onCompletion → service stays alive → ACTION_STOP → `stopSelf`.

No instrumented Android tests — the manual checklist covers them.

### 9.2 Manual device checklist

| # | Scenario | Expected |
|---|---|---|
| 1 | Open app, wait for `DailyPrayerContextLoaded`. Stream logcat. | 5 `[Adhan] armed` lines, "5 armed, 1 skipped" |
| 2 | `adb shell dumpsys alarm \| grep com.example.quran_app` | 5 pending alarms with `setExactAndAllowWhileIdle`, correct trigger times |
| 3 | Wait for next prayer (or simulate with `setSystemTime`) | Notification appears, adhan plays at alarm volume |
| 4 | While adhan playing, expand notification shade fully | **Audio continues** (issue #3 fix verified) |
| 5 | Tap Stop on the notification | Audio stops immediately, notification disappears |
| 6 | Trigger again, swipe notification away during playback | Audio stops, notification dismissed |
| 7 | Trigger again, let adhan complete | Audio stops at clip end, notification stays silent, can be dismissed by swipe |
| 8 | Reboot device with strip enabled | Strip reappears (existing boot receiver); adhan does NOT re-arm |
| 9 | Pinned strip visual: Cairo renders, transparent BG, deep-teal mini-pill on next prayer | Matches V5 mockup |
| 10 | Switch app language to Arabic, repeat #9 | Cells render RTL starting Fajr on the right |
| 11 | Hit "Test adhan 30s" FAB | After 30s, adhan plays via new native path (logcat shows `[AdhanReceiver]`) |
| 12 | Friday: header weekday in deep-teal bold | Friday-only emphasis works |

### 9.3 Cross-cutting checks

- `flutter analyze` clean
- `flutter test` all green
- Kotlin compile clean
- APK size delta ≤ 700 KB (Cairo + small vector drawables)

## 10. Migration & rollback

- The pinned-strip feature flag `FeatureFlags.pinnedPrayerStripUi` stays as-is (already flipped to `true` for Plan B).
- This work does **not** introduce a new feature flag — the adhan-foreground-service path replaces the legacy path unconditionally on Android, behind no flag.
- Rollback: if the new path causes regressions, revert the `NotificationsRepositoryImpl` platform-switch commit. The legacy `PrayerNotificationScheduler` Android branch remains intact (just dormant during this work), so reverting the routing change restores prior behaviour.
- iOS path is untouched throughout — unaffected by the work.

## 11. Open questions

None at spec-write time. All design decisions are locked in §7 and §6. Implementation will surface implementation-detail questions which the writing-plans phase will address.
