# Notifications Fixes & Adhan Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land three notification fixes on the current branch: (1) replace the broken Android legacy adhan scheduler with a native AlarmManager + foreground-service pipeline so adhan notifications actually fire; (2) play adhan audio via `MediaPlayer` on `STREAM_ALARM` from inside the foreground service so audio continues when the user expands the notification shade and persists until manual dismissal; (3) redesign the pinned prayer strip with Cairo typography, transparent background, deep-teal mini-pill on the next-prayer time, vector solid crescent moon, no "Quran App" header text.

**Architecture:** Three new Kotlin classes (`AdhanScheduler`, `AdhanAlarmReceiver`, `AdhanPlaybackService`) extend the existing `PrayerStripPlugin` channel. Dart `NotificationsRepositoryImpl` branches by `defaultTargetPlatform` — Android → native; iOS → legacy `flutter_local_notifications` (unchanged). Strip redesign is XML-only on the native side plus one Cairo font bundle.

**Tech Stack:** Kotlin (Android 14 target), `MethodChannel` from `io.flutter.embedding`, `NotificationCompat`, `AlarmManager`, `MediaPlayer`, Cairo TTFs from Google Fonts. Flutter/Dart bloc on the app side.

**Spec:** `docs/superpowers/specs/2026-05-23-notifications-fixes-design.md`
**Visual mockup:** `docs/superpowers/specs/2026-05-23-strip-redesign-mockups.html` (★ section at top = locked design)

**Test command:** `flutter test` for the suite, `flutter test test/path/to/file.dart` for a single file. From project root `D:\flutter_projects\quran_app`.

**Commit style:** Conventional commits scoped by area: `feat(notifications)`, `feat(android)`, `feat(home)`, `feat(i18n)`, `chore(android)`, `refactor(notifications)`, `fix(notifications)`. One commit per task.

**Native package:** `com.example.quran_app`. All new Kotlin under `android/app/src/main/kotlin/com/example/quran_app/`.

**Branch:** `feature/004-pinned-prayer-notification`. Sister plan (Plan B, merged) at `docs/superpowers/plans/2026-05-23-pinned-prayer-notification-android.md` is the foundation we extend.

---

## File structure

**Created in this plan:**

```
android/app/src/main/kotlin/com/example/quran_app/
├── AdhanScheduler.kt           # arms/cancels AlarmManager pendingIntents for each prayer
├── AdhanAlarmReceiver.kt       # fires at HH:mm, starts AdhanPlaybackService
├── AdhanPlaybackService.kt     # FGS playing MediaPlayer + ongoing notification w/ Stop
└── AdhanBootReceiver.kt        # declared, no-op initially (reserved)

android/app/src/main/res/
├── font/
│   ├── cairo.xml               # font-family declaring 3 weights
│   ├── cairo_regular.ttf       # downloaded from Google Fonts (manual step)
│   ├── cairo_semibold.ttf
│   └── cairo_bold.ttf
├── drawable/
│   ├── moon_crescent.xml       # solid deep-teal crescent (vector)
│   ├── strip_time_pill.xml     # rounded deep-teal background for active time text
│   └── ic_adhan_stop.xml       # stop-circle icon (vector)
└── values/
│   └── strings.xml             # "Stop", "It's time for X prayer", prayer names
│
└── values-ar/
    └── strings.xml             # Arabic mirror
```

**Modified in this plan:**

```
android/app/src/main/AndroidManifest.xml                        # +permissions, +service, +receivers
android/app/src/main/res/values/colors.xml                      # refined accent tokens
android/app/src/main/res/layout/prayer_strip_expanded.xml       # redesign
android/app/src/main/res/layout/prayer_strip_collapsed.xml      # redesign
android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt    # +adhan routes
android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt  # mini-pill + moon + Cairo

lib/features/notifications/data/datasources/notifications_native_data_source.dart   # +scheduleTestAdhan
lib/features/notifications/data/repositories/notifications_repository_impl.dart     # platform-switch
lib/features/home/presentation/pages/widgets/home_view.dart                          # FAB Android branch
lib/core/notifications/prayer_notification_scheduler_impl.dart                       # Android no-op marker
test/features/notifications/data/repositories/notifications_repository_impl_test.dart
```

**Deleted in this plan:**

```
android/app/src/main/res/drawable/strip_pill.xml   # replaced by strip_time_pill.xml
```

**Untouched on purpose:**

```
android/app/src/main/kotlin/com/example/quran_app/PrayerStripService.kt   # strip orchestrator (Plan B)
ios/                                                                       # iOS path stays on legacy
lib/core/notifications/prayer_notification_scheduler.dart                 # interface only
```

---

## Phase R — Strip visual redesign (XML only)

### Task 1: Refine `colors.xml` with the locked palette tokens

**Files:**
- Modify: `android/app/src/main/res/values/colors.xml`

- [ ] **Step 1: Replace contents**

Open `android/app/src/main/res/values/colors.xml` and replace with:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Mirrors lib/config/theme/app_colors.dart.
         RemoteViews can't read dynamic theme — these are the canonical strip colors. -->
    <color name="strip_onyx">#FF081815</color>
    <color name="strip_evergreen">#FF0C231F</color>
    <color name="strip_pine_teal">#FF134E3E</color>
    <color name="strip_deep_teal">#FF4A7C6A</color>
    <color name="strip_bright_snow">#FFF8F9F8</color>
    <color name="strip_grey_olive">#FF8B9A94</color>

    <!-- Strip semantic tokens (used by layouts + renderer) -->
    <color name="strip_text_primary">#FFF8F9F8</color>   <!-- bright-snow -->
    <color name="strip_text_muted">#FF8B9A94</color>     <!-- grey-olive -->
    <color name="strip_text_dim">#66F8F9F8</color>       <!-- snow @ 40% — passed prayers -->
    <color name="strip_accent">#FF4A7C6A</color>         <!-- deep-teal — pill + moon + Friday -->
</resources>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/values/colors.xml
git commit -m "refactor(android): retire strip_pill_gold, add deep-teal accent tokens"
```

---

### Task 2: Download Cairo TTF font files

**Files:**
- Create: `android/app/src/main/res/font/cairo_regular.ttf`
- Create: `android/app/src/main/res/font/cairo_semibold.ttf`
- Create: `android/app/src/main/res/font/cairo_bold.ttf`

Cairo is downloaded from Google Fonts. The font is licensed under SIL Open Font License 1.1 (free for commercial use).

- [ ] **Step 1: Download Cairo**

Go to https://fonts.google.com/specimen/Cairo and click "Download family". You'll get a ZIP containing static and variable variants. Inside the ZIP, look in `Cairo/static/`:

- `Cairo-Regular.ttf` → rename to `cairo_regular.ttf` (Android font filenames must be lowercase with underscores, no hyphens)
- `Cairo-SemiBold.ttf` → rename to `cairo_semibold.ttf`
- `Cairo-Bold.ttf` → rename to `cairo_bold.ttf`

Copy the three renamed files into `android/app/src/main/res/font/` (create the directory if missing).

- [ ] **Step 2: Verify files exist**

Run (PowerShell):
```powershell
Get-ChildItem android/app/src/main/res/font/
```
Expected: three `.ttf` files listed. Total size ~600 KB.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/res/font/cairo_regular.ttf android/app/src/main/res/font/cairo_semibold.ttf android/app/src/main/res/font/cairo_bold.ttf
git commit -m "feat(android): bundle Cairo TTF (3 weights) for notification typography"
```

---

### Task 3: Add `cairo.xml` font-family resource

**Files:**
- Create: `android/app/src/main/res/font/cairo.xml`

- [ ] **Step 1: Write the font-family**

Write `android/app/src/main/res/font/cairo.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<font-family xmlns:android="http://schemas.android.com/apk/res/android">
    <font
        android:fontStyle="normal"
        android:fontWeight="400"
        android:font="@font/cairo_regular" />
    <font
        android:fontStyle="normal"
        android:fontWeight="600"
        android:font="@font/cairo_semibold" />
    <font
        android:fontStyle="normal"
        android:fontWeight="700"
        android:font="@font/cairo_bold" />
</font-family>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/font/cairo.xml
git commit -m "feat(android): add Cairo font-family declaring 3 weights"
```

---

### Task 4: Add `moon_crescent.xml` vector drawable

**Files:**
- Create: `android/app/src/main/res/drawable/moon_crescent.xml`

This is MOON-B from the mockup file — a solid crescent. Vector path is a circle minus a smaller offset circle (the "bite").

- [ ] **Step 1: Write the drawable**

Write `android/app/src/main/res/drawable/moon_crescent.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="14dp"
    android:height="14dp"
    android:viewportWidth="14"
    android:viewportHeight="14">
    <path
        android:fillColor="@color/strip_accent"
        android:pathData="M11,7 A4,4 0 1 1 7,3 A3,3 0 1 0 11,7 Z" />
</vector>
```

The path: starts at (11,7), arcs to (7,3) — that's the outer crescent edge — then from (7,3) arcs back to (11,7) on a smaller radius — that's the inner concave edge. Result is a solid crescent.

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/drawable/moon_crescent.xml
git commit -m "feat(android): add solid crescent vector drawable for hijri date row"
```

---

### Task 5: Replace `strip_pill.xml` with `strip_time_pill.xml`

The old pill wraps the whole cell; the new design wraps only the time text. Padding tightens to hug the time.

**Files:**
- Delete: `android/app/src/main/res/drawable/strip_pill.xml`
- Create: `android/app/src/main/res/drawable/strip_time_pill.xml`

- [ ] **Step 1: Delete the old drawable**

```bash
git rm android/app/src/main/res/drawable/strip_pill.xml
```

- [ ] **Step 2: Write the new drawable**

Write `android/app/src/main/res/drawable/strip_time_pill.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="@color/strip_accent" />
    <corners android:radius="8dp" />
    <padding
        android:left="8dp"
        android:right="8dp"
        android:top="2dp"
        android:bottom="2dp" />
</shape>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/res/drawable/strip_time_pill.xml
git commit -m "feat(android): replace cell-wide gold pill with deep-teal time-only pill"
```

---

### Task 6: Add `ic_adhan_stop.xml` vector for the Stop action

**Files:**
- Create: `android/app/src/main/res/drawable/ic_adhan_stop.xml`

- [ ] **Step 1: Write the drawable**

Write `android/app/src/main/res/drawable/ic_adhan_stop.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <!-- Outer circle ring -->
    <path
        android:fillColor="@color/strip_text_primary"
        android:pathData="M12,2 A10,10 0 1 0 12,22 A10,10 0 1 0 12,2 Z M12,4 A8,8 0 1 1 12,20 A8,8 0 1 1 12,4 Z" />
    <!-- Inner square -->
    <path
        android:fillColor="@color/strip_text_primary"
        android:pathData="M8,8 H16 V16 H8 Z" />
</vector>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/drawable/ic_adhan_stop.xml
git commit -m "feat(android): add stop-circle vector for adhan notification action"
```

---

### Task 7: Add Android `strings.xml` (English) for the adhan notification

**Files:**
- Create: `android/app/src/main/res/values/strings.xml`

- [ ] **Step 1: Write the strings file**

Write `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Quran App</string>

    <!-- Adhan notification -->
    <string name="adhan_stop">Stop</string>
    <string name="adhan_body_fajr">It\'s time for Fajr prayer</string>
    <string name="adhan_body_dhuhr">It\'s time for Dhuhr prayer</string>
    <string name="adhan_body_asr">It\'s time for Asr prayer</string>
    <string name="adhan_body_maghrib">It\'s time for Maghrib prayer</string>
    <string name="adhan_body_isha">It\'s time for Isha prayer</string>

    <string name="adhan_title_fajr">Fajr</string>
    <string name="adhan_title_dhuhr">Dhuhr</string>
    <string name="adhan_title_asr">Asr</string>
    <string name="adhan_title_maghrib">Maghrib</string>
    <string name="adhan_title_isha">Isha</string>
</resources>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/values/strings.xml
git commit -m "feat(i18n): add English strings for adhan notification + Stop action"
```

---

### Task 8: Add Arabic strings

**Files:**
- Create: `android/app/src/main/res/values-ar/strings.xml`

- [ ] **Step 1: Create the directory if missing**

```powershell
New-Item -ItemType Directory -Force android/app/src/main/res/values-ar
```

- [ ] **Step 2: Write the Arabic file**

Write `android/app/src/main/res/values-ar/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">تطبيق القرآن</string>

    <string name="adhan_stop">إيقاف</string>
    <string name="adhan_body_fajr">حان موعد صلاة الفجر</string>
    <string name="adhan_body_dhuhr">حان موعد صلاة الظهر</string>
    <string name="adhan_body_asr">حان موعد صلاة العصر</string>
    <string name="adhan_body_maghrib">حان موعد صلاة المغرب</string>
    <string name="adhan_body_isha">حان موعد صلاة العشاء</string>

    <string name="adhan_title_fajr">الفجر</string>
    <string name="adhan_title_dhuhr">الظهر</string>
    <string name="adhan_title_asr">العصر</string>
    <string name="adhan_title_maghrib">المغرب</string>
    <string name="adhan_title_isha">العشاء</string>
</resources>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/res/values-ar/strings.xml
git commit -m "feat(i18n): add Arabic strings for adhan notification + Stop action"
```

---

### Task 9: Rewrite `prayer_strip_expanded.xml` (the big view)

This is the locked design from the spec §7: transparent background, Cairo, vector moon + hijri date header (no "Quran App" prefix), 6 cells with the deep-teal mini-pill **wrapping only the active time** (not the whole cell).

**Files:**
- Modify (full rewrite): `android/app/src/main/res/layout/prayer_strip_expanded.xml`

- [ ] **Step 1: Replace contents**

Write `android/app/src/main/res/layout/prayer_strip_expanded.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:background="@android:color/transparent"
    android:padding="14dp"
    android:layoutDirection="locale">

    <!-- Header: [moon] hijri-date ........ weekday -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical"
        android:paddingBottom="10dp"
        android:layoutDirection="locale">

        <ImageView
            android:id="@+id/strip_moon"
            android:layout_width="14dp"
            android:layout_height="14dp"
            android:src="@drawable/moon_crescent"
            android:contentDescription="@null"
            android:layout_marginEnd="6dp" />

        <TextView
            android:id="@+id/strip_hijri"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:textColor="@color/strip_text_muted"
            android:textSize="12sp"
            android:fontFamily="@font/cairo"
            android:textFontWeight="400" />

        <TextView
            android:id="@+id/strip_weekday"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted"
            android:textSize="12sp"
            android:fontFamily="@font/cairo"
            android:textFontWeight="400" />
    </LinearLayout>

    <!-- 6-cell strip -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:weightSum="6"
        android:layoutDirection="locale">

        <LinearLayout android:id="@+id/cell_0"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:paddingTop="8dp" android:paddingBottom="8dp"
            android:paddingStart="4dp" android:paddingEnd="4dp">
            <TextView android:id="@+id/cell_0_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_primary" android:textSize="12sp"
                android:fontFamily="@font/cairo" android:textFontWeight="600" />
            <TextView android:id="@+id/cell_0_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_muted" android:textSize="11sp"
                android:fontFamily="@font/cairo" android:textFontWeight="400"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_1"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:paddingTop="8dp" android:paddingBottom="8dp"
            android:paddingStart="4dp" android:paddingEnd="4dp">
            <TextView android:id="@+id/cell_1_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_primary" android:textSize="12sp"
                android:fontFamily="@font/cairo" android:textFontWeight="600" />
            <TextView android:id="@+id/cell_1_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_muted" android:textSize="11sp"
                android:fontFamily="@font/cairo" android:textFontWeight="400"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_2"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:paddingTop="8dp" android:paddingBottom="8dp"
            android:paddingStart="4dp" android:paddingEnd="4dp">
            <TextView android:id="@+id/cell_2_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_primary" android:textSize="12sp"
                android:fontFamily="@font/cairo" android:textFontWeight="600" />
            <TextView android:id="@+id/cell_2_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_muted" android:textSize="11sp"
                android:fontFamily="@font/cairo" android:textFontWeight="400"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_3"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:paddingTop="8dp" android:paddingBottom="8dp"
            android:paddingStart="4dp" android:paddingEnd="4dp">
            <TextView android:id="@+id/cell_3_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_primary" android:textSize="12sp"
                android:fontFamily="@font/cairo" android:textFontWeight="600" />
            <TextView android:id="@+id/cell_3_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_muted" android:textSize="11sp"
                android:fontFamily="@font/cairo" android:textFontWeight="400"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_4"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:paddingTop="8dp" android:paddingBottom="8dp"
            android:paddingStart="4dp" android:paddingEnd="4dp">
            <TextView android:id="@+id/cell_4_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_primary" android:textSize="12sp"
                android:fontFamily="@font/cairo" android:textFontWeight="600" />
            <TextView android:id="@+id/cell_4_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_muted" android:textSize="11sp"
                android:fontFamily="@font/cairo" android:textFontWeight="400"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <LinearLayout android:id="@+id/cell_5"
            android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:orientation="vertical" android:gravity="center"
            android:paddingTop="8dp" android:paddingBottom="8dp"
            android:paddingStart="4dp" android:paddingEnd="4dp">
            <TextView android:id="@+id/cell_5_label"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_primary" android:textSize="12sp"
                android:fontFamily="@font/cairo" android:textFontWeight="600" />
            <TextView android:id="@+id/cell_5_time"
                android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:textColor="@color/strip_text_muted" android:textSize="11sp"
                android:fontFamily="@font/cairo" android:textFontWeight="400"
                android:layout_marginTop="2dp" />
        </LinearLayout>
    </LinearLayout>
</LinearLayout>
```

Note: `android:textFontWeight` requires API 28+. `flutter create` defaults to minSdk 21, but Cairo via `fontFamily` works on all APIs; on pre-28 the weight is approximated by the nearest font in the family.

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/layout/prayer_strip_expanded.xml
git commit -m "feat(android): redesign expanded strip layout with Cairo + transparent BG + vector moon"
```

---

### Task 10: Rewrite `prayer_strip_collapsed.xml` (the one-line view)

**Files:**
- Modify (full rewrite): `android/app/src/main/res/layout/prayer_strip_collapsed.xml`

- [ ] **Step 1: Replace contents**

Write `android/app/src/main/res/layout/prayer_strip_collapsed.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:background="@android:color/transparent"
    android:padding="14dp"
    android:gravity="center_vertical"
    android:layoutDirection="locale">

    <TextView
        android:id="@+id/collapsed_label"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:textColor="@color/strip_text_primary"
        android:textSize="14sp"
        android:fontFamily="@font/cairo"
        android:textFontWeight="700" />

    <TextView
        android:id="@+id/collapsed_time"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="@color/strip_text_primary"
        android:textSize="14sp"
        android:fontFamily="@font/cairo"
        android:textFontWeight="700"
        android:background="@drawable/strip_time_pill"
        android:paddingStart="8dp"
        android:paddingEnd="8dp" />

    <TextView
        android:id="@+id/collapsed_hijri"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="@color/strip_text_muted"
        android:textSize="12sp"
        android:fontFamily="@font/cairo"
        android:textFontWeight="400"
        android:layout_marginStart="12dp" />
</LinearLayout>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/layout/prayer_strip_collapsed.xml
git commit -m "feat(android): redesign collapsed strip with Cairo + deep-teal time pill"
```

---

### Task 11: Update `PrayerStripRenderer.kt` — apply pill to **time only**, drop "Quran App" prefix, Friday accent, dim passed cells

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt`

- [ ] **Step 1: Replace contents**

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

        // Header: hijri date + weekday. App name is shown by the system notification frame.
        expanded.setTextViewText(R.id.strip_hijri, state.hijriDateLabel)
        // Weekday: derived in Dart later; for now show empty if not present.
        // Friday gets deep-teal bold (uses isFriday).
        val weekdayText = "" // weekday name now lives in PrayerStripState; left blank until plumbed
        expanded.setTextViewText(R.id.strip_weekday, weekdayText)
        val weekdayColor =
            if (state.isFriday) context.resources.getColor(R.color.strip_accent, null)
            else context.resources.getColor(R.color.strip_text_muted, null)
        expanded.setTextColor(R.id.strip_weekday, weekdayColor)

        val labelIds = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label,
            R.id.cell_3_label, R.id.cell_4_label, R.id.cell_5_label
        )
        val timeIds = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time,
            R.id.cell_3_time, R.id.cell_4_time, R.id.cell_5_time
        )

        // Color tokens, resolved once.
        val primary = context.resources.getColor(R.color.strip_text_primary, null)
        val muted = context.resources.getColor(R.color.strip_text_muted, null)
        val dim = context.resources.getColor(R.color.strip_text_dim, null)
        val accentTextOnPill = context.resources.getColor(R.color.strip_text_primary, null)

        for (i in 0 until 6) {
            val cell = state.cells.getOrNull(i) ?: continue
            expanded.setTextViewText(labelIds[i], cell.label)
            expanded.setTextViewText(timeIds[i], cell.time)

            when {
                // Active prayer (next): label snow-bold, time wrapped in deep-teal pill.
                i == state.nextPrayerIndex -> {
                    expanded.setTextColor(labelIds[i], primary)
                    expanded.setTextColor(timeIds[i], accentTextOnPill)
                    expanded.setInt(
                        timeIds[i], "setBackgroundResource", R.drawable.strip_time_pill
                    )
                }
                // Passed prayer: dim everything.
                i < state.nextPrayerIndex -> {
                    expanded.setTextColor(labelIds[i], dim)
                    expanded.setTextColor(timeIds[i], dim)
                    expanded.setInt(timeIds[i], "setBackgroundResource", 0)
                }
                // Future prayer: primary label, muted time, no pill.
                else -> {
                    expanded.setTextColor(labelIds[i], primary)
                    expanded.setTextColor(timeIds[i], muted)
                    expanded.setInt(timeIds[i], "setBackgroundResource", 0)
                }
            }
        }

        // Collapsed view: "Asr   [16:28 pill]   5 ذو الحجة"
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

Notes for the Flutter dev:
- `expanded.setInt(viewId, "setBackgroundResource", drawableId)` is a `RemoteViews` reflection hack — it dispatches to the view's `setBackgroundResource(int)` method. Setting `0` clears the background.
- `R.color.strip_accent` etc are auto-generated from `colors.xml`. Passing the second arg `null` to `getColor` means "use the current theme" — fine because our colors are theme-independent.
- Weekday text remains empty until Task R12 plumbs it through `PrayerStripState`.

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt
git commit -m "feat(android): pill on time only, dim passed cells, Friday accent"
```

---

### Task 12: Plumb `weekdayLabel` through `PrayerStripState` (Dart) and renderer (Kotlin)

The Dart `PrayerStripState` carries `isFriday` but not the localized weekday string. The renderer needs it to fill `R.id.strip_weekday`.

**Files:**
- Modify: `lib/features/notifications/domain/entities/prayer_strip_state.dart`
- Modify: `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt`
- Test: `test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`

- [ ] **Step 1: Read the builder**

Read the file:
```
Read lib/features/notifications/domain/builders/prayer_strip_state_builder.dart
```

Confirm where weekday is sourced (likely from `prayerTimes.date.weekDay` for Arabic, `enWeekDay` for English).

- [ ] **Step 2: Add `weekdayLabel` to `PrayerStripState`**

In `lib/features/notifications/domain/entities/prayer_strip_state.dart`, add the field after `isFriday`:

```dart
final String weekdayLabel;
```

Add to the constructor (required), `copyWith`, `toJson` (`'weekdayLabel': weekdayLabel`), `fromJson` (`weekdayLabel: json['weekdayLabel'] as String`), and `props`.

- [ ] **Step 3: Update the builder**

In `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`, add a `weekdayLabel` to the `PrayerStripState(...)` constructor call. Source it from `prayerTimes.date.weekDay` when `localeCode == 'ar'`, else `prayerTimes.date.enWeekDay`.

- [ ] **Step 4: Update the existing builder test**

Edit `test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart` to assert the new `weekdayLabel` field (Arabic and English cases).

If the file doesn't exist, skip — there are integration tests downstream.

- [ ] **Step 5: Update Kotlin `PrayerStripState.kt`**

In `android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt`, add `val weekdayLabel: String` to the data class. Update `fromJsonString` to read `obj.getString("weekdayLabel")`. Update `toJsonString` to put `"weekdayLabel"`.

- [ ] **Step 6: Update `PrayerStripRenderer.kt`**

Replace `val weekdayText = ""` with `val weekdayText = state.weekdayLabel`.

- [ ] **Step 7: Update other tests that build a `PrayerStripState`**

Run `flutter analyze` — any constructor calls missing `weekdayLabel:` will surface. Fix each (most should be in `test/`).

```
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 8: Run the suite**

```
flutter test
```

Expected: all pass.

- [ ] **Step 9: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_strip_state.dart lib/features/notifications/domain/builders/prayer_strip_state_builder.dart android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt test/
git commit -m "feat(notifications): plumb weekdayLabel through PrayerStripState for Friday accent"
```

---

## Phase A — Android adhan infrastructure

### Task 13: Add manifest permissions, service registration, and adhan-channel-related receivers

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add the permission**

Open `android/app/src/main/AndroidManifest.xml`. Just after the existing `<uses-permission>` lines (after `SCHEDULE_EXACT_ALARM`), add:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

- [ ] **Step 2: Register the adhan service + receivers**

Inside `<application>...</application>`, after the existing `PrayerStripBootReceiver` block, add:

```xml
        <service
            android:name=".AdhanPlaybackService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="false" />

        <receiver
            android:name=".AdhanAlarmReceiver"
            android:exported="false" />

        <receiver
            android:name=".AdhanBootReceiver"
            android:exported="true"
            android:enabled="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): declare AdhanPlaybackService + adhan receivers + FGS_MEDIA_PLAYBACK"
```

---

### Task 14: Implement `AdhanScheduler.kt` — arms AlarmManager pendingIntents per prayer

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/AdhanScheduler.kt`

- [ ] **Step 1: Write the scheduler**

Write `android/app/src/main/kotlin/com/example/quran_app/AdhanScheduler.kt`:

```kotlin
package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * Schedules per-prayer adhan alarms via [AlarmManager].
 * - Cancels any previously-armed alarms first (request codes 200..205).
 * - Skips sunrise (no adhan) and any prayers whose time has already passed today.
 * - Each alarm fires AdhanAlarmReceiver with extras (prayer, clipResName).
 *
 * Logs every step under tag "Adhan" so issue #1 (silent failure) is diagnosable
 * via `adb logcat *:S Adhan:V`.
 */
object AdhanScheduler {

    private const val TAG = "Adhan"
    private const val PREFS = "adhan_prefs"
    private const val KEY_DATE = "armed_for_date"

    // Stable request code per prayer (must NOT collide with PrayerAlarmReceiver 0..5).
    private val REQUEST_CODES = mapOf(
        "fajr" to 200,
        "dhuhr" to 201,
        "asr" to 202,
        "maghrib" to 203,
        "isha" to 204
    )

    private val PRAYERS_WITH_ADHAN = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    /**
     * Arms today's remaining prayers.
     *
     * @param timings keys are lowercase prayer names ("fajr", "sunrise", "dhuhr"…),
     *                values are "HH:mm" 24-hour strings.
     * @param clipResNames keys are lowercase prayer names, values are the basename
     *                     of a raw resource (e.g. "fajr_adhan" matches R.raw.fajr_adhan).
     * @param localeCode "en" or "ar" — passed to the receiver so the notification
     *                   body uses the right language at fire time.
     */
    fun armToday(
        context: Context,
        timings: Map<String, String>,
        clipResNames: Map<String, String>,
        localeCode: String
    ) {
        Log.i(TAG, "armToday: starting (locale=$localeCode, " +
            "timings=${timings.keys.size} prayers)")

        cancelAll(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance()
        val today = "%04d-%02d-%02d".format(
            now.get(Calendar.YEAR),
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH)
        )

        var armed = 0
        var skipped = 0
        for (prayer in PRAYERS_WITH_ADHAN) {
            val hhmm = timings[prayer]
            val clip = clipResNames[prayer]
            if (hhmm == null || clip == null) {
                Log.w(TAG, "armToday: skipped $prayer (missing timing or clip)")
                skipped++
                continue
            }

            val parts = hhmm.split(":")
            if (parts.size != 2) {
                Log.w(TAG, "armToday: skipped $prayer (bad time format: $hhmm)")
                skipped++
                continue
            }
            val hour = parts[0].toIntOrNull()
            val minute = parts[1].toIntOrNull()
            if (hour == null || minute == null) {
                Log.w(TAG, "armToday: skipped $prayer (unparseable: $hhmm)")
                skipped++
                continue
            }

            val trigger = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (trigger.timeInMillis <= now.timeInMillis) {
                Log.i(TAG, "armToday: skipped $prayer (past: $hhmm)")
                skipped++
                continue
            }

            val rc = REQUEST_CODES[prayer]!!
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                putExtra(AdhanAlarmReceiver.EXTRA_PRAYER, prayer)
                putExtra(AdhanAlarmReceiver.EXTRA_CLIP, clip)
                putExtra(AdhanAlarmReceiver.EXTRA_LOCALE, localeCode)
            }
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                am.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, trigger.timeInMillis, pi
                )
                Log.i(TAG, "armed $prayer at $today $hhmm (request=$rc)")
                armed++
            } catch (e: SecurityException) {
                // SCHEDULE_EXACT_ALARM denied — fall back to inexact.
                Log.w(TAG, "armToday: SCHEDULE_EXACT_ALARM denied, using inexact for $prayer")
                am.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, trigger.timeInMillis, pi
                )
                armed++
            }
        }

        // Persist for diagnostic visibility.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DATE, today).apply()

        Log.i(TAG, "armToday: $armed armed, $skipped skipped")
    }

    /** Cancels all armed adhan alarms. Idempotent. */
    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for ((prayer, rc) in REQUEST_CODES) {
            val intent = Intent(context, AdhanAlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
        }
        Log.i(TAG, "cancelAll: cleared ${REQUEST_CODES.size} alarms")
    }

    /** One-shot test alarm: fires `delaySeconds` from now with normal_adhan. */
    fun armTest(context: Context, delaySeconds: Int, localeCode: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val trigger = System.currentTimeMillis() + delaySeconds * 1000L
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER, "dhuhr") // arbitrary, for title
            putExtra(AdhanAlarmReceiver.EXTRA_CLIP, "normal_adhan")
            putExtra(AdhanAlarmReceiver.EXTRA_LOCALE, localeCode)
        }
        val pi = PendingIntent.getBroadcast(
            context, 299, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        }
        Log.i(TAG, "armTest: in ${delaySeconds}s (request=299)")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AdhanScheduler.kt
git commit -m "feat(android): add AdhanScheduler with AlarmManager + diagnostic logging"
```

---

### Task 15: Implement `AdhanAlarmReceiver.kt`

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt`

- [ ] **Step 1: Write the receiver**

Write `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt`:

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Fires at prayer time. Must return within 10s (Android limit on BroadcastReceiver).
 * Hands off immediately to AdhanPlaybackService.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prayer = intent?.getStringExtra(EXTRA_PRAYER) ?: "unknown"
        val clip = intent?.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent?.getStringExtra(EXTRA_LOCALE) ?: "en"

        Log.i(TAG, "onReceive prayer=$prayer clip=$clip locale=$localeCode")

        val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
            action = AdhanPlaybackService.ACTION_PLAY
            putExtra(AdhanPlaybackService.EXTRA_PRAYER, prayer)
            putExtra(AdhanPlaybackService.EXTRA_CLIP, clip)
            putExtra(AdhanPlaybackService.EXTRA_LOCALE, localeCode)
        }
        context.startForegroundService(serviceIntent)
    }

    companion object {
        private const val TAG = "AdhanReceiver"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt
git commit -m "feat(android): add AdhanAlarmReceiver that starts AdhanPlaybackService at prayer time"
```

---

### Task 16: Implement `AdhanBootReceiver.kt` (no-op shell)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/AdhanBootReceiver.kt`

- [ ] **Step 1: Write the receiver**

Write `android/app/src/main/kotlin/com/example/quran_app/AdhanBootReceiver.kt`:

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Reserved boot receiver for the adhan path. Per spec §6.4, we deliberately do
 * NOT re-arm adhan alarms after reboot — the next app launch will re-arm via
 * DailyPrayerContextLoaded → SyncDailyAdhans. Declared in the manifest only so
 * future work can plug in here without an additional manifest change.
 */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.i(TAG, "onReceive ${intent?.action} — no-op (reserved)")
    }

    companion object {
        private const val TAG = "Adhan"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AdhanBootReceiver.kt
git commit -m "feat(android): add AdhanBootReceiver shell (no-op, reserved)"
```

---

### Task 17: Implement `AdhanPlaybackService.kt` — foreground service with MediaPlayer

This is the heart of issue #3 (audio independent of notification-shade interaction).

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt`

- [ ] **Step 1: Write the service**

Write `android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt`:

```kotlin
package com.example.quran_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that plays one adhan and shows an ongoing notification.
 *
 * Why a service (not a plain notification with sound)?
 * - flutter_local_notifications routes audio through the notification-sound
 *   system, which Android can interrupt when the user expands the shade.
 * - MediaPlayer on STREAM_ALARM is independent media playback. Audio continues
 *   even when the user interacts with the shade.
 *
 * Lifecycle:
 *   ACTION_PLAY → start foreground, post ongoing notification, start MediaPlayer.
 *   ACTION_STOP → stop player, cancel notification, stopSelf.
 *   onCompletion (audio finished) → release player, KEEP notification + service
 *                                    alive until user dismisses (per spec §6.3).
 */
class AdhanPlaybackService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var currentPrayer: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> handlePlay(intent)
            ACTION_STOP -> handleStop(reason = "user_stop")
            else -> {
                Log.w(TAG, "onStartCommand: unknown action ${intent?.action}")
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun handlePlay(intent: Intent) {
        val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: "fajr"
        val clipName = intent.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        currentPrayer = prayer

        Log.i(TAG, "onStartCommand action=ACTION_PLAY prayer=$prayer clip=$clipName")

        ensureChannel()

        val notif = buildNotification(prayer, localeCode)
        startForeground(NOTIFICATION_ID, notif)

        startMediaPlayer(clipName)
    }

    private fun startMediaPlayer(clipName: String) {
        val resId = resources.getIdentifier(clipName, "raw", packageName)
        if (resId == 0) {
            Log.e(TAG, "startMediaPlayer: R.raw.$clipName not found")
            return
        }

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(attrs)
            try {
                val afd = resources.openRawResourceFd(resId)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                prepare()
                start()
                Log.i(TAG, "MediaPlayer started clip=$clipName")
            } catch (e: Exception) {
                Log.e(TAG, "MediaPlayer setup failed", e)
                release()
                mediaPlayer = null
                return
            }
            setOnCompletionListener {
                Log.i(TAG, "MediaPlayer onCompletion (released, notification kept)")
                it.release()
                mediaPlayer = null
                // Notification + service stay alive; user must Stop or swipe.
            }
            setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer onError what=$what extra=$extra")
                false  // don't auto-handle; let onCompletion fire if possible
            }
        }
    }

    private fun handleStop(reason: String) {
        Log.i(TAG, "dismissed reason=$reason prayer=$currentPrayer")
        mediaPlayer?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        mediaPlayer = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        mediaPlayer?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        mediaPlayer = null
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Prayer adhan",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Plays the adhan at each prayer time"
            setShowBadge(false)
            enableVibration(false)
            // No sound — the service plays audio via MediaPlayer.
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(prayer: String, localeCode: String): android.app.Notification {
        val ctx = localizedContext(localeCode)

        val titleResId = ctx.resources.getIdentifier(
            "adhan_title_$prayer", "string", packageName
        ).let { if (it != 0) it else R.string.adhan_title_fajr }
        val bodyResId = ctx.resources.getIdentifier(
            "adhan_body_$prayer", "string", packageName
        ).let { if (it != 0) it else R.string.adhan_body_fajr }
        val title = ctx.getString(titleResId)
        val body = ctx.getString(bodyResId)
        val stopLabel = ctx.getString(R.string.adhan_stop)

        // Tap notification body → open MainActivity.
        val openPI = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Tap Stop action → stop the service.
        val stopIntent = Intent(this, AdhanPlaybackService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPI = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPI)
            .setDeleteIntent(stopPI)  // handles swipe-away
            .addAction(R.drawable.ic_adhan_stop, stopLabel, stopPI)
            .build()
    }

    /**
     * Returns a Context whose resources are bound to the requested locale —
     * so the notification title/body always match the app's language, not the
     * system locale (which may differ).
     */
    private fun localizedContext(localeCode: String): Context {
        val locale = java.util.Locale(localeCode)
        java.util.Locale.setDefault(locale)
        val config = Configuration(resources.configuration)
        config.setLocale(locale)
        return createConfigurationContext(config)
    }

    companion object {
        private const val TAG = "AdhanService"
        const val CHANNEL_ID = "prayer_adhan_channel"
        const val NOTIFICATION_ID = 200

        const val ACTION_PLAY = "com.example.quran_app.ACTION_ADHAN_PLAY"
        const val ACTION_STOP = "com.example.quran_app.ACTION_ADHAN_STOP"

        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt
git commit -m "feat(android): add AdhanPlaybackService (FGS + MediaPlayer + Stop action)"
```

---

### Task 18: Extend `PrayerStripPlugin.kt` with adhan routes + test route

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`

- [ ] **Step 1: Replace contents**

Write `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`:

```kotlin
package com.example.quran_app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the `quran_app/notifications` MethodChannel.
 *
 * Strip routes (unchanged): enableStrip / refreshStrip / disableStrip → PrayerStripService.
 * Adhan routes (NEW):       scheduleDailyAdhans / cancelAllAdhans / scheduleTestAdhan → AdhanScheduler.
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
            "enableStrip", "refreshStrip" -> handleEnableOrRefreshStrip(ctx, call, result)
            "disableStrip" -> handleDisableStrip(ctx, result)
            "scheduleDailyAdhans" -> handleScheduleDailyAdhans(ctx, call, result)
            "cancelAllAdhans" -> handleCancelAllAdhans(ctx, result)
            "scheduleTestAdhan" -> handleScheduleTestAdhan(ctx, call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleEnableOrRefreshStrip(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val json = serializeStripArgs(call.arguments)
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

    private fun handleDisableStrip(ctx: Context, result: MethodChannel.Result) {
        val intent = Intent(ctx, PrayerStripService::class.java).apply {
            action = PrayerStripService.ACTION_HIDE_STRIP
        }
        ctx.startForegroundService(intent)
        result.success(null)
    }

    private fun handleScheduleDailyAdhans(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("BAD_ARGS", "Expected Map", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val timings = (args["timings"] as? Map<String, String>) ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val clips = (args["clips"] as? Map<String, String>) ?: emptyMap()
        val localeCode = (args["localeCode"] as? String) ?: "en"

        AdhanScheduler.armToday(ctx, timings, clips, localeCode)
        result.success(null)
    }

    private fun handleCancelAllAdhans(ctx: Context, result: MethodChannel.Result) {
        AdhanScheduler.cancelAll(ctx)
        result.success(null)
    }

    private fun handleScheduleTestAdhan(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        val delay = (args?.get("delaySeconds") as? Int) ?: 30
        val localeCode = (args?.get("localeCode") as? String) ?: "en"
        AdhanScheduler.armTest(ctx, delay, localeCode)
        result.success(null)
    }

    private fun serializeStripArgs(args: Any?): String? {
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
        obj.put("weekdayLabel", (args["weekdayLabel"] as? String) ?: return null)
        obj.put("localeCode", (args["localeCode"] as? String) ?: return null)
        obj.put("isFriday", (args["isFriday"] as? Boolean) ?: return null)
        return obj.toString()
    }

    companion object {
        const val CHANNEL = "quran_app/notifications"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt
git commit -m "feat(android): wire scheduleDailyAdhans + cancelAllAdhans + scheduleTestAdhan on plugin"
```

---

## Phase D — Dart wiring

### Task 19: Add `scheduleTestAdhan` to the native data source

**Files:**
- Modify: `lib/features/notifications/data/datasources/notifications_native_data_source.dart`

- [ ] **Step 1: Add to the interface**

Open `lib/features/notifications/data/datasources/notifications_native_data_source.dart`. Inside `abstract class NotificationsNativeDataSource`, add:

```dart
  /// Debug-only. Fires a one-off adhan `delay` from now via the native pipeline.
  Future<void> scheduleTestAdhan({
    Duration delay = const Duration(seconds: 30),
    String localeCode = 'en',
  });
```

- [ ] **Step 2: Add to the impl**

In the same file, inside `NotificationsNativeDataSourceImpl`, add:

```dart
  @override
  Future<void> scheduleTestAdhan({
    Duration delay = const Duration(seconds: 30),
    String localeCode = 'en',
  }) =>
      _invoke('scheduleTestAdhan', {
        'delaySeconds': delay.inSeconds,
        'localeCode': localeCode,
      });
```

- [ ] **Step 3: Analyzer**

```
flutter analyze lib/features/notifications/data/datasources/notifications_native_data_source.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/notifications/data/datasources/notifications_native_data_source.dart
git commit -m "feat(notifications): add scheduleTestAdhan on native data source"
```

---

### Task 20: Update `NotificationsRepositoryImpl` to branch by platform

**Files:**
- Modify: `lib/features/notifications/data/repositories/notifications_repository_impl.dart`

- [ ] **Step 1: Write the failing test**

Edit `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`. Replace the `group('scheduleDailyAdhans', …)` block with:

```dart
  group('scheduleDailyAdhans', () {
    test('Android: routes to native.scheduleDailyAdhans, ignores legacy scheduler',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          )).thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );

      expect(r, const Right(unit));
      verify(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          )).called(1);
      verifyNever(() => scheduler.scheduleDailyPrayerNotifications(any()));
      debugDefaultTargetPlatformOverride = null;
    });

    test('iOS: routes to legacy scheduler, ignores native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => scheduler.scheduleDailyPrayerNotifications(any()))
          .thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );

      expect(r, const Right(unit));
      verify(() => scheduler.scheduleDailyPrayerNotifications(pt)).called(1);
      verifyNever(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          ));
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns Left(UnknownNotificationFailure) when native throws on Android',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
          )).thenThrow(Exception('boom'));

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );
      r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
      debugDefaultTargetPlatformOverride = null;
    });
  });
```

Also add the import at the top of the test file:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

```
flutter test test/features/notifications/data/repositories/notifications_repository_impl_test.dart
```

Expected: 3 new tests FAIL (because the repository still always uses the legacy scheduler).

- [ ] **Step 3: Update the repository impl**

Replace `lib/features/notifications/data/repositories/notifications_repository_impl.dart` with:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsNativeDataSource native;
  final PrayerNotificationScheduler legacyScheduler;

  NotificationsRepositoryImpl({
    required this.native,
    required this.legacyScheduler,
  });

  Future<Either<Failure, Unit>> _run(Future<void> Function() body) async {
    try {
      await body();
      return const Right(unit);
    } on PlatformNotImplementedException {
      return const Left(PlatformNotSupportedFailure(
        'Pinned prayer strip is not implemented on this platform yet.',
      ));
    } catch (e) {
      return Left(UnknownNotificationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state) =>
      _run(() => native.enableStrip(state));

  @override
  Future<Either<Failure, Unit>> disableStrip() =>
      _run(() => native.disableStrip());

  @override
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state) =>
      _run(() => native.refreshStrip(state));

  @override
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
  }) =>
      _run(() async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.scheduleDailyAdhans(
            timingsByPrayer: _lowercasePrayerKeys(prayerTimes.timings),
            clipAssetByPrayer:
                _lowercasePrayerKeys(audio.clipAssetByPrayer),
            volume: audio.volume,
          );
        } else {
          // iOS (or any non-Android target) keeps the legacy path.
          await legacyScheduler.scheduleDailyPrayerNotifications(prayerTimes);
        }
      });

  @override
  Future<Either<Failure, Unit>> cancelAllAdhans() =>
      _run(() async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllAdhans();
        } else {
          await legacyScheduler.cancelAllPrayerNotifications();
        }
      });

  /// PrayerName enum to lowercase string key ("fajr", "sunrise", "dhuhr"…).
  Map<String, String> _lowercasePrayerKeys(Map<PrayerName, String> source) {
    return {for (final e in source.entries) e.key.name.toLowerCase(): e.value};
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```
flutter test test/features/notifications/data/repositories/notifications_repository_impl_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Run the full suite**

```
flutter test
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/notifications/data/repositories/notifications_repository_impl.dart test/features/notifications/data/repositories/notifications_repository_impl_test.dart
git commit -m "feat(notifications): branch scheduleDailyAdhans by platform — Android native, iOS legacy"
```

---

### Task 21: Convert legacy Android scheduler path to a no-op

After Task 20, `legacyScheduler.scheduleDailyPrayerNotifications` is no longer reached on Android via the repository. To make sure no other call site sneaks in (and to leave a breadcrumb if someone digs into logs), add an early-return for Android with a debug log.

**Files:**
- Modify: `lib/core/notifications/prayer_notification_scheduler_impl.dart`

- [ ] **Step 1: Add the guard**

In `lib/core/notifications/prayer_notification_scheduler_impl.dart`, modify `scheduleDailyPrayerNotifications` (around line 135) — replace the first lines of the method:

```dart
  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] schedule called before init — skipping');
      return;
    }
```

with:

```dart
  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      debugPrint(
        '[PrayerNotif] Android: legacy path is intentionally inert (handled '
        'natively via AdhanScheduler). Call site should branch by platform.',
      );
      return;
    }
    if (!_initialized) {
      debugPrint('[PrayerNotif] schedule called before init — skipping');
      return;
    }
```

- [ ] **Step 2: Analyzer**

```
flutter analyze lib/core/notifications/prayer_notification_scheduler_impl.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run the full suite**

```
flutter test
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/core/notifications/prayer_notification_scheduler_impl.dart
git commit -m "refactor(notifications): legacy Android path is inert (native owns adhan)"
```

---

### Task 22: Rewrite the debug "Test adhan 30s" FAB on Android

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart`

- [ ] **Step 1: Update the FAB**

Replace the `onPressed` callback in `lib/features/home/presentation/pages/widgets/home_view.dart` (around lines 19-35) with:

```dart
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              onPressed: () async {
                final isAndroid =
                    defaultTargetPlatform == TargetPlatform.android;
                final localeCode =
                    context.read<SettingsCubit>().state.settingsModel.isArabic
                        ? 'ar'
                        : 'en';
                if (isAndroid) {
                  await sl<NotificationsNativeDataSource>()
                      .scheduleTestAdhan(localeCode: localeCode);
                } else {
                  await sl<PrayerNotificationScheduler>()
                      .scheduleTestNotification();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Adhan test scheduled in 30s'),
                    ),
                  );
                }
              },
              label: const Text('Test adhan 30s'),
              icon: const Icon(Icons.notifications_active),
            )
          : null,
```

Add these imports at the top (sort alphabetically with existing):

```dart
import 'package:flutter/foundation.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
```

- [ ] **Step 2: Analyzer**

```
flutter analyze lib/features/home/presentation/pages/widgets/home_view.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/home_view.dart
git commit -m "feat(home): test adhan FAB drives native path on Android, legacy on iOS"
```

---

### Task 23: Pass `localeCode` into `scheduleDailyAdhans` native call

The native side needs `localeCode` so the notification body language matches the app. The Dart impl already passes `timingsByPrayer` and `clipAssetByPrayer`; add the locale.

**Files:**
- Modify: `lib/features/notifications/data/datasources/notifications_native_data_source.dart`
- Modify: `lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- Modify: `lib/features/notifications/domain/repositories/notifications_repository.dart`
- Modify: `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`
- Modify: `lib/features/home/presentation/pages/home_page.dart`
- Modify: `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`

- [ ] **Step 1: Add `localeCode` to the native data source signature**

In `lib/features/notifications/data/datasources/notifications_native_data_source.dart`, update both the abstract and impl `scheduleDailyAdhans`:

```dart
  Future<void> scheduleDailyAdhans({
    required Map<String, String> timingsByPrayer,
    required Map<String, String> clipAssetByPrayer,
    required double volume,
    required String localeCode,
  });
```

In the impl body, add `'localeCode': localeCode,` to the invoked map.

- [ ] **Step 2: Thread it through repository, use case, and call site**

In `lib/features/notifications/domain/repositories/notifications_repository.dart`, add `required String localeCode,` to `scheduleDailyAdhans` (and update Dart docs).

In `lib/features/notifications/data/repositories/notifications_repository_impl.dart`, accept `localeCode` and pass it to `native.scheduleDailyAdhans`.

In `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`, add `localeCode` to `SyncDailyAdhansParams` and pipe it through.

In `lib/features/home/presentation/pages/home_page.dart`, when invoking `SyncDailyAdhans`, pass `localeCode: settings.isArabic ? 'ar' : 'en'`. You'll need `context.read<SettingsCubit>().state.settingsModel` available — it already is inside `_enableOrRefreshStrip`.

Restructure: pull the localeCode read out of `_enableOrRefreshStrip` and reuse for both calls. Concretely, in the `BlocListener<DailyPrayerContextCubit, ...>` listener:

```dart
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              final settings = context.read<SettingsCubit>().state.settingsModel;
              final localeCode = settings.isArabic ? 'ar' : 'en';

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
                    localeCode: localeCode,
                  ),
                ),
              );
              _enableOrRefreshStrip(context, loaded);
            },
```

- [ ] **Step 3: Update tests**

In `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`, update the `scheduleDailyAdhans` calls to pass `localeCode: 'en'` and add `localeCode: any(named: 'localeCode')` to the `native.scheduleDailyAdhans` mock matchers.

Also update the existing `SyncDailyAdhans` use-case test (if any) under `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart` to pass the new field.

- [ ] **Step 4: Analyzer + tests**

```
flutter analyze
flutter test
```

Expected: clean + all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications lib/features/home/presentation/pages/home_page.dart test/features/notifications
git commit -m "feat(notifications): thread localeCode into scheduleDailyAdhans for native-side i18n"
```

---

## Phase V — Verification

### Task 24: Manual device verification

**Pre-flight:**

- Build + install on a real Android device (emulator works but adhan-time testing is faster via system clock change which is unreliable on emulators). Recommended: physical Android 14 device.
- Open `adb logcat` in a terminal:

```
adb logcat -c
adb logcat *:S Adhan:V AdhanReceiver:V AdhanService:V PrayerNotif:V
```

- [ ] **Step 1: Cold launch & arm**

Launch the app fresh. Open Home, wait for prayer times to load.

Expected logcat:
```
Adhan: armToday: starting (locale=…, timings=6 prayers)
Adhan: armed Fajr at YYYY-MM-DD HH:MM (request=200)
Adhan: armed Dhuhr at YYYY-MM-DD HH:MM (request=201)
Adhan: armed Asr at YYYY-MM-DD HH:MM (request=202)
Adhan: armed Maghrib at YYYY-MM-DD HH:MM (request=203)
Adhan: armed Isha at YYYY-MM-DD HH:MM (request=204)
Adhan: armToday: N armed, M skipped
```

Also run:

```
adb shell dumpsys alarm | findstr com.example.quran_app
```

Expected: N pending alarms with `setExactAndAllowWhileIdle` and matching trigger times.

- [ ] **Step 2: Test adhan FAB**

Tap "Test adhan 30s". Wait 30 seconds.

Expected:
- Notification appears with title "Dhuhr" / "الظهر" (or whatever your test prayer), body "It's time for Dhuhr prayer" / "حان موعد صلاة الظهر", and a **Stop** action with stop-circle icon.
- Adhan audio plays at alarm volume.
- Logcat shows:
  ```
  AdhanReceiver: onReceive prayer=dhuhr clip=normal_adhan locale=…
  AdhanService: onStartCommand action=ACTION_PLAY prayer=dhuhr clip=normal_adhan
  AdhanService: MediaPlayer started clip=normal_adhan
  ```

- [ ] **Step 3: Shade-expansion test (issue #3 fix)**

While the adhan is playing, fully expand the notification shade.

Expected: **audio continues uninterrupted**.

- [ ] **Step 4: Stop action**

Tap the **Stop** action on the notification.

Expected: audio stops within ~100ms, notification disappears, logcat shows `AdhanService: dismissed reason=user_stop`.

- [ ] **Step 5: Swipe-dismiss**

Trigger another test (Step 2). Once audio is playing, swipe the notification away.

Expected: audio stops, notification disappears, logcat shows `AdhanService: dismissed reason=user_stop` (the `deleteIntent` routes through ACTION_STOP).

- [ ] **Step 6: Audio completion**

Trigger another test. Let the audio play through to the end (the `normal_adhan.mp3` length).

Expected:
- Audio stops naturally at the end of the clip.
- Notification **remains visible** (silent) with the Stop action.
- Logcat shows `AdhanService: MediaPlayer onCompletion (released, notification kept)`.
- Swipe the notification to dismiss. Logcat shows the dismissal line.

- [ ] **Step 7: Pinned strip visual check**

In the app: Settings → Notifications → enable "Pinned prayer times". Pull down the notification shade.

Expected (matches V5 mockup, MOON-B):
- Cairo font throughout.
- Transparent background — strip body blends into shade surface color.
- Header: solid deep-teal crescent moon + hijri date (e.g. "5 ذو الحجة 1446") on start side; weekday on end side.
- Six cells. Passed prayers are dim; future prayers normal; **next prayer's time wrapped in a deep-teal solid mini-pill**.
- If today is Friday, weekday text is deep-teal bold.

Compare against the ★ section of `docs/superpowers/specs/2026-05-23-strip-redesign-mockups.html`.

- [ ] **Step 8: RTL**

In the app, switch language to Arabic. Pull down the shade.

Expected: Strip mirrors. Fajr now on the right side, Isha on the left. Hijri date and weekday swap.

- [ ] **Step 9: iOS regression check** (if iOS device available)

Build + install on iOS. Tap the test FAB.

Expected: legacy iOS path fires the test adhan as before (no regression).

- [ ] **Step 10: Real prayer time delivery**

Wait for the next real prayer time (or set the device clock just before one for a faster test).

Expected:
- At the exact prayer time the adhan fires.
- Logcat shows the `AdhanReceiver` → `AdhanService` chain.
- Issues #1 + #3 both resolved.

- [ ] **Step 11: Document results**

Append a short report to the bottom of `docs/superpowers/specs/2026-05-23-notifications-fixes-design.md` under a new "## Verification report" heading: PASS/FAIL per step + any unexpected behavior.

- [ ] **Step 12: Commit verification report**

```bash
git add docs/superpowers/specs/2026-05-23-notifications-fixes-design.md
git commit -m "docs(notifications): manual verification report"
```

---

## Done

All three issues are addressed:

1. **Real adhan doesn't fire** — Android now uses the native `AdhanScheduler` + `AlarmManager` + `AdhanAlarmReceiver` + `AdhanPlaybackService` pipeline with full `[Adhan]` logcat trace. Every armed alarm is logged; every fire is logged; every dismissal is logged.
2. **Audio stops on shade expansion** — `MediaPlayer` on `STREAM_ALARM` in a `mediaPlayback` foreground service. Audio is independent of notification-shade interaction.
3. **Pinned strip redesign** — Cairo throughout, transparent background, deep-teal mini-pill wrapping only the next-prayer time, solid vector crescent moon, no "Quran App" header text, Friday weekday in deep-teal bold.
