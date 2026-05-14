# Adhan audio on prayer notifications — Design

**Status:** Approved
**Date:** 2026-05-14
**Scope:** Replace the single placeholder `adhan.mp3` notification sound with two distinct adhans — a dedicated one for Fajr and a standard one for the other four prayers.

## Goal

When a scheduled prayer notification fires:
- **Fajr** plays `fajr adhan.mp3` (the dedicated Fajr adhan).
- **Dhuhr, Asr, Maghrib, Isha** play `normal adhan.mp3`.
- **Sunrise** remains silent (already not scheduled).

## Constraint that drives the design

On Android 8.0+ (API 26+), the notification sound is bound to the **channel**, not the individual notification. A channel's sound is locked at creation and cannot be changed without deleting + recreating the channel under a new ID. Selecting a different sound per prayer therefore requires **two channels**: one for Fajr, one for the other four prayers.

## File layout

Source-of-truth audio files stay in `assets/audio/`. Native copies live in platform-specific folders, renamed to satisfy each platform's filename rules (Android raw resources must match `[a-z0-9_]`).

| Source (kept as-is)             | Android copy                                       | iOS copy                       |
|---------------------------------|----------------------------------------------------|--------------------------------|
| `assets/audio/fajr adhan.mp3`   | `android/app/src/main/res/raw/fajr_adhan.mp3`      | `ios/Runner/fajr_adhan.caf`    |
| `assets/audio/normal adhan.mp3` | `android/app/src/main/res/raw/normal_adhan.mp3`    | `ios/Runner/normal_adhan.caf`  |

**iOS clip length:** iOS hard-caps notification sounds at 30 seconds; longer files silently fall back to the system default. The iOS copies are 30-second trimmed clips produced from the source files (e.g., via `afconvert` or `ffmpeg`). Container is `.caf` (Apple's preferred format), though `.mp3` would also work — implementer's choice per file.

**Orphaned files:** Delete `android/app/src/main/res/raw/adhan.mp3` and `ios/Runner/adhan.mp3` in the same change set.

**pubspec.yaml:** No entry needed. The two `assets/audio/*.mp3` files are not loaded via `AssetBundle`; they exist only as source files for the human. The OS reads from the native locations.

## Channel architecture (Android)

Two notification channels, registered explicitly during `init()`:

| Channel ID                 | User-facing name | Sound resource  | Used by                       |
|----------------------------|------------------|-----------------|-------------------------------|
| `prayer_fajr_channel`      | "Fajr adhan"     | `fajr_adhan`    | Fajr                          |
| `prayer_standard_channel`  | "Prayer adhan"   | `normal_adhan`  | Dhuhr, Asr, Maghrib, Isha     |

Both channels: `Importance.max`, vibration disabled, description "Adhan at prayer time" (matching today's behaviour).

**Explicit creation, not lazy.** Today the scheduler relies on `flutter_local_notifications` to lazily create the channel from `AndroidNotificationDetails` on first scheduled notification. With two channels, switch to creating both up front via `AndroidFlutterLocalNotificationsPlugin.createNotificationChannel(...)` inside `init()`. Single place to manage both, no ordering surprises.

**Migration off the old channel.** In `init()`, also call `deleteNotificationChannel('prayer_times_channel')`. No-op if it doesn't exist; cleans up the orphaned channel from system settings for anyone who already ran the dev build. Safe to run on every launch.

## iOS specifics

iOS has no channel concept — each `DarwinNotificationDetails` names its sound file directly. The Fajr-vs-standard split is implemented purely in the per-notification `NotificationDetails` constants. No extra setup, no migration step.

## Code changes

All changes confined to `lib/core/notifications/prayer_notification_scheduler_impl.dart`. No interface changes, no DI changes, no caller changes.

1. **Replace** the single `_notificationDetails` constant with two:
   - `_fajrDetails` — channel `prayer_fajr_channel`, Android sound `fajr_adhan`, iOS sound `fajr_adhan.caf`.
   - `_standardDetails` — channel `prayer_standard_channel`, Android sound `normal_adhan`, iOS sound `normal_adhan.caf`.

2. **Add** static `AndroidNotificationChannel` instances (`_fajrChannel`, `_standardChannel`) mirroring those `AndroidNotificationDetails`. The duplication is unavoidable: `flutter_local_notifications` uses separate types for channel registration vs. per-notification details.

3. **Add** a small lookup:
   ```dart
   NotificationDetails _detailsFor(PrayerName p) =>
       p == PrayerName.fajr ? _fajrDetails : _standardDetails;
   ```

4. **In `init()`**, after `_plugin.initialize(...)` and before permission requests:
   - Resolve the Android plugin.
   - Call `deleteNotificationChannel('prayer_times_channel')` (one-time cleanup, idempotent).
   - Call `createNotificationChannel(_fajrChannel)` and `createNotificationChannel(_standardChannel)`.

5. **In `scheduleDailyPrayerNotifications`**, change `notificationDetails: _notificationDetails` to `notificationDetails: _detailsFor(prayerName)`. One-line change inside the existing loop.

6. **`scheduleTestNotification`** keeps using `_standardDetails` — it's just a delivery-path smoke test.

## Behaviour on failure / edge cases

- **Missing native sound file**: if `fajr_adhan` is not present in `res/raw/`, Android plays the channel's default sound silently rather than failing. The build won't catch this; verification is a manual install-and-fire check.
- **Channel already exists with a different sound**: `createNotificationChannel` is a no-op when a channel with that ID already exists, so the sound *cannot* be changed retroactively. Because we use brand-new channel IDs (`prayer_fajr_channel`, `prayer_standard_channel`), this only matters if we ever change the sound under these IDs in the future — at that point we'd need new IDs again. Not in scope for this change.
- **Existing scheduled notifications under the old channel**: `cancelAllPrayerNotifications` runs at the start of `scheduleDailyPrayerNotifications`, so any in-flight notifications from the old channel are cancelled before new ones are scheduled. The day's first reschedule cleans up automatically.

## Out of scope (deferred)

- Per-prayer user-configurable adhan/reciter selection.
- Per-prayer enable/disable toggle.
- Pre-adhan reminder (e.g., 10 min before).

## Verification (manual)

After implementation:
1. Fresh install on Android — open system settings → app notifications → confirm "Fajr adhan" and "Prayer adhan" channels appear; "Prayer Times" (old) is gone.
2. Use `scheduleTestNotification(delay: 30s)` — confirm `normal_adhan` plays.
3. Manually schedule a Fajr-time notification ~1 min ahead — confirm `fajr_adhan` plays.
4. iOS: same test pair — confirm the 30s clips play under foreground and locked-screen states.
