# Pinned Prayer Notification — Android Native (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the Android native side of the pinned prayer-times strip so the feature actually renders. By the end, toggling the in-app Settings → Notifications switch surfaces (and updates) an ongoing notification with today's six prayer times and a gold pill on the next prayer.

**Architecture:** Foreground service (`PrayerStripService`) hosting an ongoing notification rendered via `RemoteViews`. State is pushed from Flutter through the `quran_app/notifications` MethodChannel (already defined by Plan A). The service caches state in `SharedPreferences` so a `BroadcastReceiver` can re-render after boot and `AlarmManager` can move the pill highlight when each prayer time arrives. **Plan B does not touch adhan playback** — that stays on the legacy `PrayerNotificationScheduler` (via `NotificationsRepositoryImpl.scheduleDailyAdhans` → legacy delegate) until Plan C.

**Tech Stack:** Kotlin (Android 14 target), `MethodChannel` from `io.flutter.embedding`, `NotificationCompat` + `RemoteViews`, `AlarmManager`, `SharedPreferences`, Flutter/Dart bloc + go_router on the app side.

**Sister documents:**
- Spec: `docs/superpowers/specs/2026-05-23-pinned-prayer-notification-design.md`
- Plan A (Dart foundation, **merged**): `docs/superpowers/plans/2026-05-23-pinned-prayer-notification-dart-foundation.md`
- Plan C (iOS Live Activity + adhan rewrite): not yet written; produced after Plan B merges.

**UI decision (settled before plan):** The pinned-prayer toggle lives on a dedicated **Notifications** screen reached from the Settings bottom sheet (`Notifications ›` row), not inline in the sheet. This scales for future per-prayer adhan toggles, adhan voice, and volume.

**Test command:** `flutter test` for the whole suite, `flutter test test/path/to/file.dart` for a single file. Run from project root (`D:\flutter_projects\quran_app`). Kotlin code has no automated tests — verification is the manual device checklist in Phase B5 (per spec §13.4).

**Commit style:** Conventional commits scoped by area: `feat(notifications)`, `feat(android)`, `feat(home)`, `feat(i18n)`, `chore(android)`. One commit per task.

**Native package:** `com.example.quran_app` (per `android/app/build.gradle.kts:9`). All new Kotlin files go under `android/app/src/main/kotlin/com/example/quran_app/`.

---

## File structure (new + modified)

**Created in this plan:**

```
android/app/src/main/kotlin/com/example/quran_app/
├── PrayerStripPlugin.kt           # FlutterPlugin + MethodChannel handler
├── PrayerStripService.kt          # foreground service (ACTION_SHOW_STRIP, ACTION_HIDE_STRIP)
├── PrayerStripRenderer.kt         # builds Notification + RemoteViews from cached state
├── PrayerStripStateStore.kt       # SharedPreferences read/write of state JSON
├── PrayerStripState.kt            # parses JSON into a Kotlin data class
├── PrayerAlarmReceiver.kt         # re-renders strip when AlarmManager fires
└── PrayerStripBootReceiver.kt     # re-arms strip after BOOT_COMPLETED

android/app/src/main/res/
├── layout/
│   ├── prayer_strip_expanded.xml
│   └── prayer_strip_collapsed.xml
├── drawable/
│   └── strip_pill.xml
└── values/
    └── colors.xml                  # palette tokens used by RemoteViews

lib/features/home/presentation/pages/
└── notifications_settings_page.dart

lib/features/notifications/domain/services/
└── next_prayer_resolver.dart       # pure-Dart: which prayer is "next" right now?

test/features/notifications/domain/services/
└── next_prayer_resolver_test.dart

test/features/home/presentation/pages/
└── notifications_settings_page_test.dart
```

**Modified in this plan:**

```
android/app/src/main/AndroidManifest.xml                       # service + receivers + permissions
android/app/src/main/kotlin/com/example/quran_app/MainActivity.kt   # register PrayerStripPlugin
lib/config/router/app_router.dart                              # add /notifications route
lib/core/constants/feature_flags.dart                          # flip pinnedPrayerStripUi → true
lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart   # replace inline switch with nav row
lib/features/home/presentation/pages/home_page.dart            # add strip enable/refresh listeners
lib/features/settings/presentation/cubit/settings_cubit.dart   # updatePrayerStripPinned wires use cases
lib/l10n/intl_en.arb                                           # "Notifications" entry + a11y strings
lib/l10n/intl_ar.arb                                           # Arabic equivalents
test/features/settings/settings_cubit_test.dart                # cover use-case side effects
```

**Untouched on purpose (defer to Plan C):**

```
lib/core/notifications/prayer_notification_scheduler.dart           # legacy adhan path
lib/core/notifications/prayer_notification_scheduler_impl.dart      # legacy adhan path
ios/                                                                # iOS Live Activity
```

---

## Phase B0 — UI restructure (Notifications sub-page)

### Task 1: Add l10n strings for the Notifications navigation entry

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`
- Regenerate: `lib/generated/l10n.dart`

- [ ] **Step 1: Add English strings**

In `lib/l10n/intl_en.arb`, add (near other Settings-related entries):

```json
  "notifications": "Notifications",
  "notificationsScreenSubtitle": "Manage prayer-time notifications.",
```

- [ ] **Step 2: Add Arabic strings**

In `lib/l10n/intl_ar.arb`:

```json
  "notifications": "الإشعارات",
  "notificationsScreenSubtitle": "إدارة إشعارات أوقات الصلاة.",
```

- [ ] **Step 3: Regenerate `lib/generated/l10n.dart`**

If using the `flutter_intl` VS Code / Android Studio extension: save both ARB files (it auto-regenerates).
If running CLI: `flutter pub run intl_utils:generate`

Verify: `lib/generated/l10n.dart` now contains `S.current.notifications` and `S.current.notificationsScreenSubtitle`.

- [ ] **Step 4: Analyzer**

Run: `flutter analyze lib/generated/l10n.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated
git commit -m "feat(i18n): add Notifications screen entry strings"
```

---

### Task 2: Create the empty `NotificationsSettingsPage`

**Files:**
- Create: `lib/features/home/presentation/pages/notifications_settings_page.dart`

In Plan B this page hosts exactly one control — the pinned-strip toggle (moved here from the bottom sheet). Plan C adds adhan voice / per-prayer toggles.

- [ ] **Step 1: Create the page**

Write `lib/features/home/presentation/pages/notifications_settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.notifications, style: TS.bold20.cairo),
        backgroundColor: context.colorScheme.surface,
      ),
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final settings = state.settingsModel;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingSwitch(
                  settings: settings,
                  settingTitle: S.current.pinnedPrayerTimes,
                  icons: const [
                    HugeIcons.strokeRoundedNotification01,
                    HugeIcons.strokeRoundedNotificationOff01,
                  ],
                  value: settings.isPrayerStripPinned,
                  action: () => sl<SettingsCubit>().updatePrayerStripPinned(
                    !settings.isPrayerStripPinned,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    S.current.pinnedPrayerTimesSubtitle,
                    style: TS.regular14.cairo.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyzer**

Run: `flutter analyze lib/features/home/presentation/pages/notifications_settings_page.dart`
Expected: `No issues found!`

If `TS.regular14` doesn't exist, substitute the closest existing typography token from `lib/config/theme/typography_styles.dart`. Same for `colorScheme.onSurfaceVariant` (use any "muted text" token already in the theme).

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/notifications_settings_page.dart
git commit -m "feat(home): add NotificationsSettingsPage hosting the pinned-prayer toggle"
```

---

### Task 3: Register `/notifications` route in `app_router.dart`

**Files:**
- Modify: `lib/config/router/app_router.dart`

- [ ] **Step 1: Add the route**

Open `lib/config/router/app_router.dart`. Add an import (sort alphabetically near the existing `home_page.dart` import):

```dart
import 'package:quran_app/features/home/presentation/pages/notifications_settings_page.dart';
```

Add a path constant inside the `abstract class AppRouter` (after `homePath`):

```dart
  static const String notificationsPath = "/notifications";
```

Add a new `GoRoute` inside `routes: [ ... ]` (after the `splashPath` route, before `booksPath`):

```dart
      GoRoute(
        path: notificationsPath,
        pageBuilder: GoTransitions.fade.withFade.build(
          builder: (context, state) => const NotificationsSettingsPage(),
        ),
      ),
```

- [ ] **Step 2: Analyzer**

Run: `flutter analyze lib/config/router/app_router.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/config/router/app_router.dart
git commit -m "feat(router): add /notifications route"
```

---

### Task 4: Replace inline switch in `settings_bottom_sheet.dart` with a navigation row

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`

The bottom sheet currently shows a gated `SettingSwitch` for `pinnedPrayerTimes`. Replace it with a navigation row that pushes `/notifications`. Keep the **same `FeatureFlags.pinnedPrayerStripUi` gate** for now — the flag still flips to `true` only in Task 19 once Android is wired.

- [ ] **Step 1: Modify the sheet**

Replace this block (lines 84-96 in the current file):

```dart
              if (FeatureFlags.pinnedPrayerStripUi)
                SettingSwitch(
                  settings: settings,
                  settingTitle: S.current.pinnedPrayerTimes,
                  icons: const [
                    HugeIcons.strokeRoundedNotification01,
                    HugeIcons.strokeRoundedNotificationOff01,
                  ],
                  value: settings.isPrayerStripPinned,
                  action: () => sl<SettingsCubit>().updatePrayerStripPinned(
                    !settings.isPrayerStripPinned,
                  ),
                ),
```

with:

```dart
              if (FeatureFlags.pinnedPrayerStripUi)
                ListTile(
                  leading: const Icon(HugeIcons.strokeRoundedNotification01),
                  title: Text(S.current.notifications, style: TS.regular16.cairo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();
                    GoRouter.of(context).push(AppRouter.notificationsPath);
                  },
                ),
```

Add imports at the top (sort alphabetically):

```dart
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
```

If `TS.regular16` doesn't exist, substitute the existing typography token used by other items in the sheet.

- [ ] **Step 2: Analyzer**

Run: `flutter analyze lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`
Expected: `No issues found!`

- [ ] **Step 3: Smoke run full tests**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart
git commit -m "feat(home): replace inline pinned-prayer switch with Notifications nav row"
```

---

## Phase B1 — Android manifest + permissions

### Task 5: Update `AndroidManifest.xml` with service, receivers, and permissions

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

The plan declares a `dataSync` foreground-service type for Plan B (no audio yet). Plan C will broaden to `mediaPlayback` when the adhan moves into this service.

- [ ] **Step 1: Add permissions**

In `android/app/src/main/AndroidManifest.xml`, add these after the existing `<uses-permission>` lines:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

(`POST_NOTIFICATIONS`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED` are already declared.)

- [ ] **Step 2: Add service + receivers**

Inside `<application>...</application>`, after the existing `flutter_local_notifications` receivers, add:

```xml
        <service
            android:name=".PrayerStripService"
            android:foregroundServiceType="dataSync"
            android:exported="false" />

        <receiver
            android:name=".PrayerAlarmReceiver"
            android:exported="false" />

        <receiver
            android:name=".PrayerStripBootReceiver"
            android:exported="true"
            android:enabled="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
```

- [ ] **Step 3: Verify build**

Run: `flutter build apk --debug --target-platform android-arm64`
Expected: build succeeds. (Errors here usually point at namespace mismatch — fix immediately.)

If `flutter build` is too slow on this machine, skip it and verify by running the analyzer instead: `flutter analyze android/` (note: the analyzer only checks Dart). For native, the next Kotlin task will fail the build if the manifest references missing classes — that's acceptable since we'll create them next.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): declare PrayerStripService, alarm + boot receivers, FGS permissions"
```

---

## Phase B2 — Android resources

### Task 6: Add palette colors to `res/values/colors.xml`

**Files:**
- Create: `android/app/src/main/res/values/colors.xml`

The RemoteViews can't use Material 3 dynamic theming — colors must be hardcoded. We mirror the Dart palette from `lib/config/theme/app_colors.dart`.

- [ ] **Step 1: Write the colors file**

Write `android/app/src/main/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Mirrors lib/config/theme/app_colors.dart (dark palette).
         RemoteViews can't read dynamic theme — these are the canonical strip colors. -->
    <color name="strip_onyx">#FF081815</color>
    <color name="strip_evergreen">#FF0C231F</color>
    <color name="strip_pine_teal">#FF134E3E</color>
    <color name="strip_bright_snow">#FFF8F9F8</color>
    <color name="strip_grey_olive">#FF8B9A94</color>
    <color name="strip_pill_gold">#FFD4A857</color>
</resources>
```

(Gold token added because the spec calls for a gold pill on the next prayer. If the Dart palette later adopts an official `gold` token, replace `#FFD4A857` to match.)

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/values/colors.xml
git commit -m "feat(android): add prayer-strip color palette resources"
```

---

### Task 7: Add `strip_pill.xml` drawable (the gold rounded-rect)

**Files:**
- Create: `android/app/src/main/res/drawable/strip_pill.xml`

- [ ] **Step 1: Write the drawable**

Write `android/app/src/main/res/drawable/strip_pill.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="@color/strip_pill_gold" />
    <corners android:radius="12dp" />
    <padding
        android:left="10dp"
        android:right="10dp"
        android:top="6dp"
        android:bottom="6dp" />
</shape>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/drawable/strip_pill.xml
git commit -m "feat(android): add strip_pill drawable for next-prayer highlight"
```

---

### Task 8: Add the expanded RemoteViews layout

**Files:**
- Create: `android/app/src/main/res/layout/prayer_strip_expanded.xml`

The layout is intentionally dumb — six pairs of `(label, time)` `TextView`s and a header. The renderer (Task 12) sets per-cell text and applies the pill background to the next-prayer cell only.

- [ ] **Step 1: Write the layout**

Write `android/app/src/main/res/layout/prayer_strip_expanded.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:background="@color/strip_onyx"
    android:padding="12dp"
    android:layoutDirection="locale">

    <TextView
        android:id="@+id/strip_header"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:textColor="@color/strip_bright_snow"
        android:textSize="14sp"
        android:paddingBottom="8dp"
        tools:text="Quran App · 5 ذو الحجة" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:weightSum="6"
        android:layoutDirection="locale">

        <LinearLayout android:id="@+id/cell_0"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:padding="6dp">
            <TextView android:id="@+id/cell_0_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_bright_snow" android:textSize="12sp" />
            <TextView android:id="@+id/cell_0_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_grey_olive" android:textSize="11sp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_1"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:padding="6dp">
            <TextView android:id="@+id/cell_1_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_bright_snow" android:textSize="12sp" />
            <TextView android:id="@+id/cell_1_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_grey_olive" android:textSize="11sp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_2"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:padding="6dp">
            <TextView android:id="@+id/cell_2_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_bright_snow" android:textSize="12sp" />
            <TextView android:id="@+id/cell_2_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_grey_olive" android:textSize="11sp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_3"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:padding="6dp">
            <TextView android:id="@+id/cell_3_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_bright_snow" android:textSize="12sp" />
            <TextView android:id="@+id/cell_3_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_grey_olive" android:textSize="11sp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_4"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:padding="6dp">
            <TextView android:id="@+id/cell_4_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_bright_snow" android:textSize="12sp" />
            <TextView android:id="@+id/cell_4_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_grey_olive" android:textSize="11sp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_5"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:padding="6dp">
            <TextView android:id="@+id/cell_5_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_bright_snow" android:textSize="12sp" />
            <TextView android:id="@+id/cell_5_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_grey_olive" android:textSize="11sp" />
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
```

Remove the `xmlns:tools=` reference if Android Studio inserts it as required (or add `xmlns:tools="http://schemas.android.com/tools"` at the root).

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/layout/prayer_strip_expanded.xml
git commit -m "feat(android): add expanded RemoteViews layout for prayer strip"
```

---

### Task 9: Add the collapsed RemoteViews layout

**Files:**
- Create: `android/app/src/main/res/layout/prayer_strip_collapsed.xml`

- [ ] **Step 1: Write the layout**

Write `android/app/src/main/res/layout/prayer_strip_collapsed.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:background="@color/strip_onyx"
    android:padding="12dp"
    android:gravity="center_vertical"
    android:layoutDirection="locale">

    <TextView
        android:id="@+id/collapsed_label"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:textColor="@color/strip_bright_snow"
        android:textSize="14sp" />

    <TextView
        android:id="@+id/collapsed_time"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="@color/strip_pill_gold"
        android:textSize="14sp"
        android:textStyle="bold"
        android:paddingStart="12dp"
        android:paddingEnd="12dp" />

    <TextView
        android:id="@+id/collapsed_hijri"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="@color/strip_grey_olive"
        android:textSize="12sp" />
</LinearLayout>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/layout/prayer_strip_collapsed.xml
git commit -m "feat(android): add collapsed RemoteViews layout for prayer strip"
```

---

## Phase B3 — Kotlin code

### Task 10: Add `PrayerStripState.kt` — JSON parser data class

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt`

The shape must match `PrayerStripState.toJson()` from Plan A (in `lib/features/notifications/domain/entities/prayer_strip_state.dart`):

```
{
  cells: [{label: "Fajr", time: "04:15"}, ...],
  nextPrayerIndex: int,
  hijriDateLabel: "5 Dhul-Hijjah",
  localeCode: "en" | "ar",
  isFriday: bool
}
```

- [ ] **Step 1: Write the file**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt`:

```kotlin
package com.example.quran_app

import org.json.JSONObject

data class PrayerCellNative(val label: String, val time: String)

data class PrayerStripState(
    val cells: List<PrayerCellNative>,
    val nextPrayerIndex: Int,
    val hijriDateLabel: String,
    val localeCode: String,
    val isFriday: Boolean
) {
    companion object {
        fun fromJsonString(raw: String): PrayerStripState {
            val obj = JSONObject(raw)
            val rawCells = obj.getJSONArray("cells")
            val cells = mutableListOf<PrayerCellNative>()
            for (i in 0 until rawCells.length()) {
                val c = rawCells.getJSONObject(i)
                cells += PrayerCellNative(c.getString("label"), c.getString("time"))
            }
            return PrayerStripState(
                cells = cells,
                nextPrayerIndex = obj.getInt("nextPrayerIndex"),
                hijriDateLabel = obj.getString("hijriDateLabel"),
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday")
            )
        }
    }

    fun toJsonString(): String {
        val obj = JSONObject()
        val arr = org.json.JSONArray()
        for (c in cells) {
            arr.put(JSONObject().put("label", c.label).put("time", c.time))
        }
        obj.put("cells", arr)
        obj.put("nextPrayerIndex", nextPrayerIndex)
        obj.put("hijriDateLabel", hijriDateLabel)
        obj.put("localeCode", localeCode)
        obj.put("isFriday", isFriday)
        return obj.toString()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt
git commit -m "feat(android): add PrayerStripState data class mirroring Dart JSON"
```

---

### Task 11: Add `PrayerStripStateStore.kt` — SharedPreferences read/write

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripStateStore.kt`

- [ ] **Step 1: Write the file**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripStateStore.kt`:

```kotlin
package com.example.quran_app

import android.content.Context

/** Wraps SharedPreferences for the prayer-strip cached state JSON. */
class PrayerStripStateStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(
        PREFS_NAME, Context.MODE_PRIVATE
    )

    fun save(stateJson: String) {
        prefs.edit()
            .putBoolean(KEY_ENABLED, true)
            .putString(KEY_STATE_JSON, stateJson)
            .apply()
    }

    fun load(): PrayerStripState? {
        if (!prefs.getBoolean(KEY_ENABLED, false)) return null
        val raw = prefs.getString(KEY_STATE_JSON, null) ?: return null
        return runCatching { PrayerStripState.fromJsonString(raw) }.getOrNull()
    }

    fun clear() {
        prefs.edit()
            .putBoolean(KEY_ENABLED, false)
            .remove(KEY_STATE_JSON)
            .apply()
    }

    fun isEnabled(): Boolean = prefs.getBoolean(KEY_ENABLED, false)

    companion object {
        private const val PREFS_NAME = "prayer_strip_prefs"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_STATE_JSON = "state_json"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripStateStore.kt
git commit -m "feat(android): add SharedPreferences-backed PrayerStripStateStore"
```

---

### Task 12: Add `PrayerStripRenderer.kt` — builds the Notification

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt`

- [ ] **Step 1: Write the renderer**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt`:

```kotlin
package com.example.quran_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/** Builds the ongoing prayer-strip notification from a [PrayerStripState] snapshot. */
class PrayerStripRenderer(private val context: Context) {

    fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Prayer times strip",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Ongoing pinned strip showing today's prayer schedule"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    fun build(state: PrayerStripState): Notification {
        val expanded = RemoteViews(context.packageName, R.layout.prayer_strip_expanded)
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)

        // Expanded header: "Quran App · <hijri>"
        expanded.setTextViewText(
            R.id.strip_header,
            context.getString(R.string.app_name) + " · " + state.hijriDateLabel
        )

        // Six cells: ids assigned by cellIds()/labelIds()/timeIds()
        val cellIds = intArrayOf(
            R.id.cell_0, R.id.cell_1, R.id.cell_2, R.id.cell_3, R.id.cell_4, R.id.cell_5
        )
        val labelIds = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label,
            R.id.cell_3_label, R.id.cell_4_label, R.id.cell_5_label
        )
        val timeIds = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time,
            R.id.cell_3_time, R.id.cell_4_time, R.id.cell_5_time
        )

        for (i in 0 until 6) {
            val cell = state.cells.getOrNull(i) ?: continue
            expanded.setTextViewText(labelIds[i], cell.label)
            expanded.setTextViewText(timeIds[i], cell.time)
            // Pill highlight on next prayer.
            if (i == state.nextPrayerIndex) {
                expanded.setInt(cellIds[i], "setBackgroundResource", R.drawable.strip_pill)
            } else {
                expanded.setInt(cellIds[i], "setBackgroundResource", 0)
            }
        }

        // Collapsed view: "<next-prayer label> · <time> · <hijri>"
        val next = state.cells.getOrNull(state.nextPrayerIndex)
        collapsed.setTextViewText(R.id.collapsed_label, next?.label ?: "")
        collapsed.setTextViewText(R.id.collapsed_time, next?.time ?: "")
        collapsed.setTextViewText(R.id.collapsed_hijri, state.hijriDateLabel)

        val launchPI = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentIntent(launchPI)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "prayer_strip_channel"
        const val NOTIFICATION_ID = 100
    }
}
```

If `R.string.app_name` doesn't exist in this project's resources, replace with the literal `"Quran App"`. Check `android/app/src/main/res/values/strings.xml` (may not exist).

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt
git commit -m "feat(android): add PrayerStripRenderer building ongoing Notification + RemoteViews"
```

---

### Task 13: Add `PrayerAlarmReceiver.kt` — re-renders on alarm fire

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerAlarmReceiver.kt`

The receiver's only job is to wake up the service and ask it to re-render with the cached state. The service then re-computes `nextPrayerIndex` locally based on current wall-clock time vs. cached prayer times.

- [ ] **Step 1: Write the receiver**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerAlarmReceiver.kt`:

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by AlarmManager at each remaining prayer time + midnight. */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return

        val action = intent?.getStringExtra(EXTRA_REASON) ?: REASON_PRAYER

        val serviceIntent = Intent(context, PrayerStripService::class.java).apply {
            this.action = when (action) {
                REASON_MIDNIGHT -> PrayerStripService.ACTION_HIDE_STRIP
                else -> PrayerStripService.ACTION_REFRESH_STRIP
            }
        }
        context.startForegroundService(serviceIntent)
    }

    companion object {
        const val EXTRA_REASON = "reason"
        const val REASON_PRAYER = "prayer"
        const val REASON_MIDNIGHT = "midnight"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerAlarmReceiver.kt
git commit -m "feat(android): add PrayerAlarmReceiver for prayer-tick and midnight wake-ups"
```

---

### Task 14: Add `PrayerStripBootReceiver.kt`

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripBootReceiver.kt`

- [ ] **Step 1: Write the receiver**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripBootReceiver.kt`:

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms the prayer strip after device boot if the user had it enabled. */
class PrayerStripBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return

        val serviceIntent = Intent(context, PrayerStripService::class.java).apply {
            action = PrayerStripService.ACTION_REFRESH_STRIP
        }
        context.startForegroundService(serviceIntent)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripBootReceiver.kt
git commit -m "feat(android): add PrayerStripBootReceiver to restore strip after reboot"
```

---

### Task 15: Add `PrayerStripService.kt` — the foreground service

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripService.kt`

This is the core orchestrator. Actions:
- `ACTION_SHOW_STRIP` (called from MethodChannel `enableStrip` / `refreshStrip`): save state JSON, start foreground with notification, schedule alarms for each remaining prayer time + midnight.
- `ACTION_REFRESH_STRIP` (called by AlarmReceiver / BootReceiver): re-load state, re-compute nextPrayerIndex from current time, re-post notification.
- `ACTION_HIDE_STRIP` (called from MethodChannel `disableStrip` and on midnight): clear cache, cancel alarms, stop foreground.

- [ ] **Step 1: Write the service**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripService.kt`:

```kotlin
package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/**
 * Ongoing foreground service that hosts the pinned prayer strip.
 * Plan B does **not** play audio — adhan playback stays on the legacy scheduler.
 * Plan C will extend this service with the AdhanPlayer.
 */
class PrayerStripService : Service() {

    private lateinit var store: PrayerStripStateStore
    private lateinit var renderer: PrayerStripRenderer

    override fun onCreate() {
        super.onCreate()
        store = PrayerStripStateStore(applicationContext)
        renderer = PrayerStripRenderer(applicationContext)
        renderer.ensureChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_STRIP -> handleShow(intent.getStringExtra(EXTRA_STATE_JSON))
            ACTION_REFRESH_STRIP -> handleRefresh()
            ACTION_HIDE_STRIP -> handleHide()
            else -> handleRefresh()
        }
        return START_STICKY
    }

    private fun handleShow(stateJson: String?) {
        if (stateJson == null) {
            stopSelf()
            return
        }
        store.save(stateJson)
        val state = PrayerStripState.fromJsonString(stateJson)
        val withRecomputedNext = state.copy(nextPrayerIndex = computeNextIndex(state))
        startForeground(
            PrayerStripRenderer.NOTIFICATION_ID,
            renderer.build(withRecomputedNext)
        )
        scheduleAlarms(withRecomputedNext)
    }

    private fun handleRefresh() {
        val state = store.load() ?: run { stopSelf(); return }
        val withRecomputedNext = state.copy(nextPrayerIndex = computeNextIndex(state))
        startForeground(
            PrayerStripRenderer.NOTIFICATION_ID,
            renderer.build(withRecomputedNext)
        )
    }

    private fun handleHide() {
        store.clear()
        cancelAlarms()
        NotificationManagerCompat.from(this)
            .cancel(PrayerStripRenderer.NOTIFICATION_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Re-computes which of the six cells is "next" right now.
     * Returns the index of the first cell whose time > now, or 0 (wrap to Fajr) if all passed.
     * Time strings come in as either ASCII "HH:mm" or Arabic-Indic — we parse digits only.
     */
    private fun computeNextIndex(state: PrayerStripState): Int {
        val now = Calendar.getInstance()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for ((i, cell) in state.cells.withIndex()) {
            val minutes = parseHHmm(cell.time) ?: continue
            if (minutes > nowMinutes) return i
        }
        return 0
    }

    private fun parseHHmm(raw: String): Int? {
        // Map Arabic-Indic ٠-٩ to 0-9 if present, then parse "HH:mm".
        val ascii = StringBuilder()
        for (ch in raw) {
            ascii.append(
                when (ch) {
                    in '٠'..'٩' -> ('0' + (ch - '٠'))
                    else -> ch
                }
            )
        }
        val parts = ascii.toString().split(':')
        if (parts.size < 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return h * 60 + m
    }

    private fun scheduleAlarms(state: PrayerStripState) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance().timeInMillis

        // One alarm per remaining cell to nudge the pill at that prayer's time.
        for (i in state.cells.indices) {
            val minutes = parseHHmm(state.cells[i].time) ?: continue
            val triggerCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (triggerCal.timeInMillis < now) continue
            val pi = prayerAlarmPI(i, PrayerAlarmReceiver.REASON_PRAYER)
            scheduleExact(alarmManager, triggerCal.timeInMillis, pi)
        }

        // Midnight hide alarm — strips disappear at 00:01 to avoid showing yesterday's data.
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val piMidnight = prayerAlarmPI(99, PrayerAlarmReceiver.REASON_MIDNIGHT)
        scheduleExact(alarmManager, midnight.timeInMillis, piMidnight)
    }

    private fun cancelAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0..5) {
            alarmManager.cancel(prayerAlarmPI(i, PrayerAlarmReceiver.REASON_PRAYER))
        }
        alarmManager.cancel(prayerAlarmPI(99, PrayerAlarmReceiver.REASON_MIDNIGHT))
    }

    private fun prayerAlarmPI(requestCode: Int, reason: String): PendingIntent {
        val intent = Intent(this, PrayerAlarmReceiver::class.java).apply {
            putExtra(PrayerAlarmReceiver.EXTRA_REASON, reason)
        }
        return PendingIntent.getBroadcast(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleExact(am: AlarmManager, triggerAt: Long, pi: PendingIntent) {
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        } catch (_: SecurityException) {
            // SCHEDULE_EXACT_ALARM denied — fall back to inexact.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    companion object {
        const val ACTION_SHOW_STRIP = "com.example.quran_app.ACTION_SHOW_STRIP"
        const val ACTION_REFRESH_STRIP = "com.example.quran_app.ACTION_REFRESH_STRIP"
        const val ACTION_HIDE_STRIP = "com.example.quran_app.ACTION_HIDE_STRIP"
        const val EXTRA_STATE_JSON = "state_json"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripService.kt
git commit -m "feat(android): add PrayerStripService (foreground orchestrator + AlarmManager)"
```

---

### Task 16: Add `PrayerStripPlugin.kt` and register in `MainActivity.kt`

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/MainActivity.kt`

- [ ] **Step 1: Write the plugin**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`:

```kotlin
package com.example.quran_app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the `quran_app/notifications` MethodChannel for the strip.
 * Adhan methods (`scheduleDailyAdhans`, `cancelAllAdhans`) are intentionally
 * left unimplemented — Plan A routes them through the legacy scheduler,
 * not this channel.
 */
class PrayerStripPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = appContext ?: run {
            result.error("NO_CONTEXT", "Plugin not attached", null)
            return
        }
        when (call.method) {
            "enableStrip", "refreshStrip" -> {
                val json = serializeArgs(call.arguments)
                if (json == null) {
                    result.error("BAD_ARGS", "Expected Map state, got ${call.arguments}", null)
                    return
                }
                val intent = Intent(ctx, PrayerStripService::class.java).apply {
                    action = PrayerStripService.ACTION_SHOW_STRIP
                    putExtra(PrayerStripService.EXTRA_STATE_JSON, json)
                }
                ctx.startForegroundService(intent)
                result.success(null)
            }
            "disableStrip" -> {
                val intent = Intent(ctx, PrayerStripService::class.java).apply {
                    action = PrayerStripService.ACTION_HIDE_STRIP
                }
                ctx.startForegroundService(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Re-serializes a Map<String,Object?> (as Flutter sends it) back to a JSON string
     *  using PrayerStripState's structure. */
    private fun serializeArgs(args: Any?): String? {
        if (args !is Map<*, *>) return null
        val obj = org.json.JSONObject()
        val cellsRaw = args["cells"] as? List<*> ?: return null
        val arr = org.json.JSONArray()
        for (c in cellsRaw) {
            val cm = c as? Map<*, *> ?: return null
            arr.put(
                org.json.JSONObject()
                    .put("label", cm["label"] as? String ?: return null)
                    .put("time", cm["time"] as? String ?: return null)
            )
        }
        obj.put("cells", arr)
        obj.put("nextPrayerIndex", (args["nextPrayerIndex"] as? Int) ?: return null)
        obj.put("hijriDateLabel", (args["hijriDateLabel"] as? String) ?: return null)
        obj.put("localeCode", (args["localeCode"] as? String) ?: return null)
        obj.put("isFriday", (args["isFriday"] as? Boolean) ?: return null)
        return obj.toString()
    }

    companion object {
        const val CHANNEL = "quran_app/notifications"
    }
}
```

- [ ] **Step 2: Register the plugin from `MainActivity.kt`**

Replace `android/app/src/main/kotlin/com/example/quran_app/MainActivity.kt` with:

```kotlin
package com.example.quran_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PrayerStripPlugin())
    }
}
```

- [ ] **Step 3: Build verify**

Run: `flutter build apk --debug --target-platform android-arm64`
Expected: build succeeds. If you see "unresolved reference" errors, double-check imports and the package name (`com.example.quran_app`).

If `flutter build` is too slow on this machine, skip — Task 17 (Dart wiring) will compile-test the channel end-to-end.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt android/app/src/main/kotlin/com/example/quran_app/MainActivity.kt
git commit -m "feat(android): register PrayerStripPlugin on quran_app/notifications channel"
```

---

## Phase B4 — Dart wiring

### Task 17: Add `NextPrayerResolver` (pure Dart helper)

**Files:**
- Create: `lib/features/notifications/domain/services/next_prayer_resolver.dart`
- Create: `test/features/notifications/domain/services/next_prayer_resolver_test.dart`

The `EnablePrayerStrip` use case needs a `PrayerStripState`, which needs `nextPrayer: PrayerName`. The native side will re-compute its own index later, but the initial JSON we push must contain a sensible value. This helper computes that.

- [ ] **Step 1: Write the failing test**

Write `test/features/notifications/domain/services/next_prayer_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

void main() {
  // Today's timings (24-hour HH:mm).
  const timings = {
    PrayerName.fajr: '04:15',
    PrayerName.sunrise: '05:07',
    PrayerName.dhuhr: '12:52',
    PrayerName.asr: '16:28',
    PrayerName.maghrib: '19:46',
    PrayerName.isha: '21:16',
  };

  group('NextPrayerResolver.resolve', () {
    test('before Fajr → Fajr', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 3, 30),
      );
      expect(r, PrayerName.fajr);
    });

    test('between Sunrise and Dhuhr → Dhuhr', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 8, 0),
      );
      expect(r, PrayerName.dhuhr);
    });

    test('between Maghrib and Isha → Isha', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 20, 0),
      );
      expect(r, PrayerName.isha);
    });

    test('after Isha → Fajr (wraps to tomorrow\'s first)', () {
      final r = NextPrayerResolver.resolve(
        timings: timings,
        now: DateTime(2026, 5, 23, 23, 30),
      );
      expect(r, PrayerName.fajr);
    });

    test('empty / missing timings → Fajr (sane default)', () {
      final r = NextPrayerResolver.resolve(
        timings: const {},
        now: DateTime(2026, 5, 23, 12, 0),
      );
      expect(r, PrayerName.fajr);
    });
  });
}
```

- [ ] **Step 2: Run to verify FAIL**

Run: `flutter test test/features/notifications/domain/services/next_prayer_resolver_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the resolver**

Write `lib/features/notifications/domain/services/next_prayer_resolver.dart`:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';

/// Picks which prayer is "next" given a snapshot of today's timings and
/// the current wall-clock time. Pure Dart; no Flutter dependency.
class NextPrayerResolver {
  const NextPrayerResolver._();

  static const _order = <PrayerName>[
    PrayerName.fajr,
    PrayerName.sunrise,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  /// Returns the first prayer whose time is strictly greater than [now].
  /// Wraps to [PrayerName.fajr] when all of today's prayers have passed,
  /// or when [timings] is empty / unparseable.
  static PrayerName resolve({
    required Map<PrayerName, String> timings,
    required DateTime now,
  }) {
    final nowMinutes = now.hour * 60 + now.minute;
    for (final p in _order) {
      final raw = timings[p];
      if (raw == null) continue;
      final minutes = _parseHHmm(raw);
      if (minutes == null) continue;
      if (minutes > nowMinutes) return p;
    }
    return PrayerName.fajr;
  }

  static int? _parseHHmm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
```

- [ ] **Step 4: Run to verify PASS**

Run: `flutter test test/features/notifications/domain/services/next_prayer_resolver_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/services/next_prayer_resolver.dart test/features/notifications/domain/services/next_prayer_resolver_test.dart
git commit -m "feat(notifications): add NextPrayerResolver for current next-prayer computation"
```

---

### Task 18: Wire `EnablePrayerStrip` / `RefreshPrayerStrip` / `DisablePrayerStrip` from `home_page.dart`

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

We listen to two cubits and call the right use case:
- `DailyPrayerContextCubit.Loaded` AND `Settings.isPrayerStripPinned == true` → `EnablePrayerStrip` with current state.
- `SettingsCubit` emits a state with `isPrayerStripPinned` flipped: enable or disable accordingly.
- `PrayerCountdownCubit` ticks across a prayer boundary → `RefreshPrayerStrip`.

For Plan B we keep the contract simple: re-fire `EnablePrayerStrip` whenever any input changes (locale, isFriday, prayer crossing). The native side debounces by replacing the same notification ID.

- [ ] **Step 1: Read the file, then replace the build**

Open `lib/features/home/presentation/pages/home_page.dart`. Replace the entire `build` method body (or the `MultiBlocListener.listeners` list) so the file becomes:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_view.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<DailyPrayerContextCubit>()..fetchDailyPrayerContext(),
        ),
        BlocProvider(create: (_) => PrayerCountdownCubit()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<PrayerCountdownCubit, PrayerCountdownState>(
            listenWhen: (_, s) => s is PrayerCountdownRequestRefresh,
            listener: (context, state) {
              final s = state as PrayerCountdownRequestRefresh;
              context
                  .read<DailyPrayerContextCubit>()
                  .fetchDailyPrayerContext(silent: s.silent);
            },
          ),
          BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
            listenWhen: (_, s) => s is DailyPrayerContextLoaded,
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              unawaited(
                sl<PreCachePrayerTimes>().call(
                  PreCachePrayerTimesParams(
                    location: loaded.dailyPrayerContext.location,
                  ),
                ),
              );
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                  ),
                ),
              );
              _enableOrRefreshStrip(context, loaded);
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) =>
                prev.settingsModel.isPrayerStripPinned !=
                    curr.settingsModel.isPrayerStripPinned ||
                prev.settingsModel.isArabic !=
                    curr.settingsModel.isArabic,
            listener: (context, settings) {
              final ctxState = context.read<DailyPrayerContextCubit>().state;
              if (settings.settingsModel.isPrayerStripPinned &&
                  ctxState is DailyPrayerContextLoaded) {
                _enableOrRefreshStrip(context, ctxState);
              } else if (!settings.settingsModel.isPrayerStripPinned) {
                unawaited(sl<DisablePrayerStrip>().call(NoParams()));
              }
            },
          ),
        ],
        child: HomeView(),
      ),
    );
  }

  void _enableOrRefreshStrip(
    BuildContext context,
    DailyPrayerContextLoaded loaded,
  ) {
    final settings = context.read<SettingsCubit>().state.settingsModel;
    if (!settings.isPrayerStripPinned) return;

    final now = DateTime.now();
    final nextPrayer = NextPrayerResolver.resolve(
      timings: loaded.dailyPrayerContext.prayerTimes.timings,
      now: now,
    );
    final stripState = PrayerStripStateBuilder.build(
      prayerTimes: loaded.dailyPrayerContext.prayerTimes,
      nextPrayer: nextPrayer,
      localeCode: settings.isArabic ? 'ar' : 'en',
      isFriday: now.weekday == DateTime.friday,
    );
    unawaited(
      sl<EnablePrayerStrip>().call(
        EnablePrayerStripParams(state: stripState),
      ),
    );
  }
}
```

You'll need a `NoParams` import for `DisablePrayerStrip.call(NoParams())`:

```dart
import 'package:quran_app/core/usecases/usecase.dart';
```

- [ ] **Step 2: Analyzer**

Run: `flutter analyze lib/features/home/presentation/pages/home_page.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run home tests**

Run: `flutter test test/features/home`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "feat(home): wire EnablePrayerStrip / DisablePrayerStrip from home listeners"
```

---

### Task 19: Flip the `pinnedPrayerStripUi` feature flag to `true`

**Files:**
- Modify: `lib/core/constants/feature_flags.dart`

This is the moment the toggle becomes visible to end users.

- [ ] **Step 1: Edit the flag**

In `lib/core/constants/feature_flags.dart`, change:

```dart
  static const bool pinnedPrayerStripUi = false;
```

to:

```dart
  static const bool pinnedPrayerStripUi = true;
```

- [ ] **Step 2: Analyzer**

Run: `flutter analyze`
Expected: `No issues found!` for the change.

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants/feature_flags.dart
git commit -m "feat(notifications): enable pinnedPrayerStripUi (Android native ready)"
```

---

## Phase B5 — Verification

### Task 20: Manual device verification

This is the canonical Plan B acceptance gate. Per spec §13.4, Kotlin code is not automatically tested — manual device verification IS the test.

Run the app on a real Android device (Android 10+, ideally including Android 14 for the foreground-service-type path):

- [ ] **Step 1:** Fresh install, open app, navigate `Settings → Notifications`. **Expect:** Pinned-prayer toggle visible, off.
- [ ] **Step 2:** Toggle ON, grant POST_NOTIFICATIONS when prompted. **Expect:** Strip appears in the notification shade within ~1s; dark teal background; gold pill on the next prayer; Hijri date in the header.
- [ ] **Step 3:** Swipe down on the lock screen. **Expect:** Strip visible.
- [ ] **Step 4:** Force-quit the app via Recents → swipe up. **Expect:** Strip remains pinned.
- [ ] **Step 5:** Wait until the next prayer time arrives (or change device clock for testing). **Expect:** Pill moves to the next prayer cell within ~30s of the time crossing.
- [ ] **Step 6:** Tap the strip. **Expect:** App opens to home.
- [ ] **Step 7:** Switch language to English / Arabic in Settings. **Expect:** Strip re-renders with new labels and numeral system on the next prayer-context load (open Home again to force).
- [ ] **Step 8:** Toggle the switch OFF in Settings → Notifications. **Expect:** Strip disappears within ~1s.
- [ ] **Step 9:** Re-enable, reboot the device. **Expect:** Strip re-appears within ~30s of unlock.
- [ ] **Step 10:** Friday morning (or set device clock to a Friday). **Expect:** Dhuhr cell label reads "الجمعة" / "Jumu'ah".
- [ ] **Step 11:** Adhan firing: confirm the legacy `flutter_local_notifications` adhan still plays at each prayer time independently of the pinned strip (Plan C will replace this; for Plan B it must be unchanged).
- [ ] **Step 12:** Disable POST_NOTIFICATIONS in OS settings, re-open app, toggle ON. **Expect:** Toggle reverts to OFF (or snackbar prompts to grant permission). *(Plan B implementation may not include the snackbar — verify it at least doesn't crash; permission flow can be polished in a follow-up.)*

Record any deviations and file as separate tickets.

- [ ] **Step 13:** No commit needed — this is a verification gate.

---

## Self-review

**Spec coverage (per the design doc sections deferred by Plan A):**

| Spec section | Covered by |
|---|---|
| §4 Visual specification | Tasks 6 (colors), 7 (pill), 8/9 (layouts), 12 (renderer) |
| §8.1 Single foreground service | Task 15 (Plan B = strip only; Plan C will add adhan to same service) |
| §8.2 Strip rendering (RemoteViews) | Tasks 8, 9, 12 |
| §8.3 Alarms and refresh | Task 15 (`scheduleAlarms`, `parseHHmm`, midnight hide) + Task 13 (alarm receiver) |
| §8.4 Adhan playback | **Deferred to Plan C** (legacy scheduler keeps playing) |
| §8.5 Manifest additions | Task 5 |
| §8.6 Native file layout | Tasks 10-16 |
| §10.3 UI (Settings tile) | Tasks 1-4 (dedicated sub-page per user choice) |
| §12 Edge case #4 (boot) | Task 14 (boot receiver) + Task 15 (service handles ACTION_REFRESH_STRIP) |
| §12 Edge case #6 (midnight) | Task 15 (midnight hide alarm) |
| §12 Edge case #7 (locale) | Task 18 (settings listener re-fires) |

**Deferred to Plan C (acknowledged):**
- §8.4 / §9.4 Adhan rewrite (foreground service hosts MediaPlayer; swipe-to-stop)
- §9 iOS Live Activity
- §10.3 iOS-specific subtitle text and disabled-on-iOS<16.1 behavior
- Deletion of `lib/core/notifications/prayer_notification_scheduler*.dart`
- Switching `foregroundServiceType` to `mediaPlayback`

**Placeholder scan:** No `TBD` / `TODO` strings. Every code block is complete.

**Type / name consistency across tasks:**
- Channel name: `quran_app/notifications` (Dart `NotificationsNativeDataSourceImpl.channelName`, Kotlin `PrayerStripPlugin.CHANNEL`) ✓
- Method names: `enableStrip` / `disableStrip` / `refreshStrip` ✓
- JSON shape: matches `PrayerStripState.toJson()` (Task 6 of Plan A, `cells: [{label, time}]`, `nextPrayerIndex`, `hijriDateLabel`, `localeCode`, `isFriday`) ✓
- Kotlin `PrayerStripState.fromJsonString` reads exactly those keys ✓
- Service actions: `ACTION_SHOW_STRIP` / `ACTION_REFRESH_STRIP` / `ACTION_HIDE_STRIP` consistent across plugin / receivers / service ✓
- Use cases: `EnablePrayerStrip` / `DisablePrayerStrip` / `RefreshPrayerStrip` (already registered in DI by Plan A) ✓
- Feature flag: `FeatureFlags.pinnedPrayerStripUi` flipped in exactly one place (Task 19) ✓

**Risks / known limitations of Plan B:**
1. Strip shows yesterday's data between 00:01 and the next app open if the user never opens the app overnight — mitigated by hiding the strip at midnight (Task 15 midnight alarm). Honest trade-off; the alternative requires Dart background isolates which are out of scope.
2. `foregroundServiceType="dataSync"` is a slight mismatch for "show ongoing notification" but is the safest Plan B choice; Plan C will broaden to `mediaPlayback` once audio joins the service.
3. AlarmManager prayer-tick alarms may drift on aggressive OEM battery optimization (Xiaomi, Huawei). Documented as acceptable in spec §12 #3.
4. Permission UX (denied POST_NOTIFICATIONS) is best-effort — Task 20 step 12 acknowledges this.

Plan B is internally consistent. Execute it.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-23-pinned-prayer-notification-android.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, two-stage review (spec + code quality) between tasks. Fast iteration; same playbook used for Plan A.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
