# Prayer Notification Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four prayer-notification defects — 12h highlight/alarm bug, sunrise ellipsis, notification dying after hours/overnight, and non-swipeable adhan audio — by sending a format-independent `minutes` key, dropping sunrise to 5 cells, retiring the `dataSync` foreground service for an alarm-driven ongoing notification with a 7-day cached window, and making the adhan notification swipe-to-dismiss.

**Architecture:** Decouple the native logic from localized display strings (a per-cell `minutes` int), and decouple persistence from a long-lived foreground service (an ordinary ongoing notification re-posted by the exact alarms + boot receiver that already exist). The Dart side builds a bounded window of day-states from the already-precached month; the native side stores the window and renders whichever day is "today".

**Tech Stack:** Flutter (Dart, `flutter_bloc`, `dartz`, `get_it`, `mocktail`, `flutter_test`) + Android (Kotlin, `NotificationCompat`/RemoteViews, `AlarmManager`). FVM-pinned Flutter 3.38.1 — run tests with `fvm flutter test`.

> **CRITICAL test caveat (from project memory):** NEVER run the full `fvm flutter test` — `test/tools/generate_mushaf_assets_test.dart` rewrites `assets/mushaf/**`. Always scope to `test/features/...`. Never `git add -A`; stage explicit paths.

---

## Architecture / contract reference

**New MethodChannel payload for `enableStrip` / `refreshStrip`** (was a single day):
```json
{
  "days": [
    {
      "dateKey": "22-05-2026",
      "cells": [ {"label": "Fajr", "time": "04:15", "minutes": 255}, … 5 cells ],
      "nextPrayerIndex": 0,
      "hijriDateLabel": "5 Dhul-Hijjah",
      "weekdayLabel": "Friday",
      "localeCode": "en",
      "isFriday": false,
      "accentColor": "#FF2E5244"
    }
  ]
}
```
- `minutes` = 24-hour minutes-from-midnight (`h*60+m`), format-/locale-independent. Native uses it for highlight + alarm scheduling.
- `dateKey` = `"dd-MM-yyyy"` (equals `PrayerTimes.date.gregorianDate`). Native selects the day where `dateKey == today`.
- `nextPrayerIndex` is advisory only — native always recomputes from `minutes`.
- `disableStrip` is unchanged (no args).

**Type names used across tasks (must match exactly):**
- Dart: `PrayerCell.minutes` (int), `PrayerStripState.dateKey` (String), `PrayerStripWindow.days` (`List<PrayerStripState>`), `PrayerStripWindow.toJson()`, `BuildPrayerStripWindow` / `BuildPrayerStripWindowParams`, `PrayerTimesRepository.getCachedForDate(DateTime)`, `Settings.is24HourFormat`.
- Kotlin: `PrayerCellNative(label, time, minutes)`, `PrayerStripDay(dateKey, cells, hijriDateLabel, weekdayLabel, localeCode, isFriday, accentColor)`, `PrayerStripWindow.fromJsonString` / `.toJsonString`, `PrayerStripController.show/refresh/hide`, `PrayerStripRenderer.build(day, nextIndex)`.

---

# PHASE 1 — Dart domain: `minutes`, drop sunrise, `dateKey`, window, getter

### Task 1: Add `minutes` to `PrayerCell`

**Files:**
- Modify: `lib/features/notifications/domain/entities/prayer_cell.dart`
- Test: `test/features/notifications/domain/entities/prayer_cell_test.dart`

- [ ] **Step 1: Rewrite the test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

void main() {
  test('equal cells with same label, time and minutes are equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    const b = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    expect(a, b);
  });

  test('cells with different labels are not equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    const b = PrayerCell(label: 'الظهر', timeFormatted: '٤:١٥', minutes: 255);
    expect(a == b, false);
  });

  test('cells with different minutes are not equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 255);
    const b = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥', minutes: 256);
    expect(a == b, false);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails to compile**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_cell_test.dart`
Expected: FAIL — `minutes` is not a parameter of `PrayerCell`.

- [ ] **Step 3: Add the field**

Replace the body of `lib/features/notifications/domain/entities/prayer_cell.dart` with:

```dart
import 'package:equatable/equatable.dart';

class PrayerCell extends Equatable {
  final String label;
  final String timeFormatted;

  /// 24-hour minutes-from-midnight (`h*60+m`). Format-/locale-independent —
  /// the native side uses this for highlight + alarm scheduling so it never
  /// parses the localized [timeFormatted] string.
  final int minutes;

  const PrayerCell({
    required this.label,
    required this.timeFormatted,
    required this.minutes,
  });

  @override
  List<Object?> get props => [label, timeFormatted, minutes];
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_cell_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_cell.dart test/features/notifications/domain/entities/prayer_cell_test.dart
git commit -m "feat(notifications): add format-independent minutes to PrayerCell

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Drop sunrise from `NextPrayerResolver`

**Files:**
- Modify: `lib/features/notifications/domain/services/next_prayer_resolver.dart`
- Test: `test/features/notifications/domain/services/next_prayer_resolver_test.dart`

- [ ] **Step 1: Rewrite the test** (timings keep sunrise in the map to prove it is ignored; the morning window now resolves to Dhuhr)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

void main() {
  const timings = {
    PrayerName.fajr: '04:15',
    PrayerName.sunrise: '05:07',
    PrayerName.dhuhr: '12:52',
    PrayerName.asr: '16:28',
    PrayerName.maghrib: '19:46',
    PrayerName.isha: '21:16',
  };

  group('NextPrayerResolver.resolve (5 prayers, sunrise excluded)', () {
    test('before Fajr → Fajr', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 3, 30)),
        PrayerName.fajr,
      );
    });

    test('after Fajr, before Dhuhr → Dhuhr (sunrise is not a target)', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 5, 30)),
        PrayerName.dhuhr,
      );
    });

    test('between Maghrib and Isha → Isha', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 20, 0)),
        PrayerName.isha,
      );
    });

    test('after Isha → Fajr (wraps to tomorrow\'s first)', () {
      expect(
        NextPrayerResolver.resolve(timings: timings, now: DateTime(2026, 5, 23, 23, 30)),
        PrayerName.fajr,
      );
    });

    test('empty timings → Fajr (sane default)', () {
      expect(
        NextPrayerResolver.resolve(timings: const {}, now: DateTime(2026, 5, 23, 12, 0)),
        PrayerName.fajr,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/notifications/domain/services/next_prayer_resolver_test.dart`
Expected: FAIL — "after Fajr, before Dhuhr" currently returns `sunrise`.

- [ ] **Step 3: Remove sunrise from `_order`**

In `lib/features/notifications/domain/services/next_prayer_resolver.dart`, change the `_order` list (was 6 entries) to:

```dart
  static const _order = <PrayerName>[
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/notifications/domain/services/next_prayer_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/services/next_prayer_resolver.dart test/features/notifications/domain/services/next_prayer_resolver_test.dart
git commit -m "feat(notifications): exclude sunrise from strip next-prayer resolution

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Add `dateKey` + cell `minutes` to `PrayerStripState` JSON

**Files:**
- Modify: `lib/features/notifications/domain/entities/prayer_strip_state.dart`
- Test: `test/features/notifications/domain/entities/prayer_strip_state_test.dart`

- [ ] **Step 1: Rewrite the test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  PrayerStripState build() => const PrayerStripState(
        cells: [
          PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255),
          PrayerCell(label: 'Dhuhr', timeFormatted: '12:52', minutes: 772),
        ],
        nextPrayerIndex: 1,
        dateKey: '22-05-2026',
        hijriDateLabel: '5 Dhul-Hijjah',
        weekdayLabel: 'Friday',
        localeCode: 'en',
        isFriday: false,
        accentColor: 0xFF2E5244,
      );

  test('toJson includes dateKey and per-cell minutes', () {
    final json = build().toJson();
    expect(json['dateKey'], '22-05-2026');
    final cells = (json['cells'] as List).cast<Map>();
    expect(cells[0]['label'], 'Fajr');
    expect(cells[0]['time'], '04:15');
    expect(cells[0]['minutes'], 255);
    expect(cells[1]['minutes'], 772);
  });

  test('toJson serializes accentColor as #AARRGGBB hex', () {
    expect(build().toJson()['accentColor'], '#FF2E5244');
  });

  test('fromJson round-trips dateKey, minutes and accentColor', () {
    final s = PrayerStripState.fromJson(build().toJson());
    expect(s.dateKey, '22-05-2026');
    expect(s.cells[0].minutes, 255);
    expect(s.cells[1].minutes, 772);
    expect(s.accentColor, 0xFF2E5244);
  });

  test('fromJson tolerates a missing accentColor', () {
    final json = build().toJson()..remove('accentColor');
    expect(PrayerStripState.fromJson(json).accentColor, isNull);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_strip_state_test.dart`
Expected: FAIL — `dateKey` not defined; cell JSON lacks `minutes`.

- [ ] **Step 3: Add `dateKey` and serialize `minutes`**

In `lib/features/notifications/domain/entities/prayer_strip_state.dart`:

1. Add the field after `cells` (and to the constructor as a required param):
```dart
  final int nextPrayerIndex;

  /// Calendar day this snapshot describes, `"dd-MM-yyyy"` (== `PrayerTimes.date.gregorianDate`).
  final String dateKey;
```
Constructor — add `required this.dateKey,` next to the other required fields.

2. Update `copyWith` to include `String? dateKey,` and `dateKey: dateKey ?? this.dateKey,`.

3. Change the cell serialization in `toJson` and add `dateKey`:
```dart
  Map<String, Object> toJson() => {
        'cells': cells
            .map((c) => {
                  'label': c.label,
                  'time': c.timeFormatted,
                  'minutes': c.minutes,
                })
            .toList(),
        'nextPrayerIndex': nextPrayerIndex,
        'dateKey': dateKey,
        'hijriDateLabel': hijriDateLabel,
        'weekdayLabel': weekdayLabel,
        'localeCode': localeCode,
        'isFriday': isFriday,
        if (accentColor != null) 'accentColor': _toHex(accentColor!),
      };
```

4. Update `fromJson` to read `minutes` + `dateKey`:
```dart
  factory PrayerStripState.fromJson(Map<String, Object?> json) {
    final rawCells = (json['cells'] as List).cast<Map<String, Object?>>();
    final rawAccent = json['accentColor'] as String?;
    return PrayerStripState(
      cells: rawCells
          .map((m) => PrayerCell(
                label: m['label'] as String,
                timeFormatted: m['time'] as String,
                minutes: m['minutes'] as int,
              ))
          .toList(),
      nextPrayerIndex: json['nextPrayerIndex'] as int,
      dateKey: (json['dateKey'] as String?) ?? '',
      hijriDateLabel: json['hijriDateLabel'] as String,
      weekdayLabel: (json['weekdayLabel'] as String?) ?? '',
      localeCode: json['localeCode'] as String,
      isFriday: json['isFriday'] as bool,
      accentColor: rawAccent == null
          ? null
          : int.parse(rawAccent.substring(1), radix: 16),
    );
  }
```

5. Add `dateKey` to the `props` list.

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_strip_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_strip_state.dart test/features/notifications/domain/entities/prayer_strip_state_test.dart
git commit -m "feat(notifications): carry dateKey + per-cell minutes in PrayerStripState JSON

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Update `PrayerStripStateBuilder` — 5 cells, compute `minutes`, derive `dateKey`

**Files:**
- Modify: `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`
- Test: `test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`

- [ ] **Step 1: Rewrite the test** (the `pt` fixture and 12h cases are retained; cell indices shift because sunrise is gone: Dhuhr is now index 1, Asr index 2, Isha index 4)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';

void main() {
  // Friday May 22 2026.
  final pt = PrayerTimes(
    key: '22-05-2026',
    timings: {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'ذو الحجة',
      weekDay: 'الجمعة',
      day: '5',
      year: '1447',
      enMonth: 'Dhul-Hijjah',
      enWeekDay: 'Friday',
      gregorianDate: '22-05-2026',
    ),
  );

  group('PrayerStripStateBuilder.build', () {
    test('produces 5 cells in Fajr→Isha order (no sunrise)', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'en', isFriday: false, use24Hour: true,
      );
      expect(s.cells.length, 5);
      expect(s.cells[0].label, 'Fajr');
      expect(s.cells[1].label, 'Dhuhr');
      expect(s.cells[2].label, 'Asr');
      expect(s.cells[3].label, 'Maghrib');
      expect(s.cells[4].label, 'Isha');
    });

    test('each cell carries 24h minutes regardless of display format', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'ar', isFriday: false, use24Hour: false,
      );
      expect(s.cells[0].minutes, 255); // 04:15
      expect(s.cells[1].minutes, 772); // 12:52
      expect(s.cells[2].minutes, 988); // 16:28
      expect(s.cells[4].minutes, 1276); // 21:16
    });

    test('dateKey is derived from gregorianDate', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'en', isFriday: false, use24Hour: true,
      );
      expect(s.dateKey, '22-05-2026');
    });

    test('Arabic locale uses Arabic-Indic numerals in display times', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'ar', isFriday: false, use24Hour: true,
      );
      expect(s.cells[0].timeFormatted, '٠٤:١٥');
    });

    test('isFriday=true swaps Dhuhr label to Jumu\'ah / الجمعة (index 1)', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar', isFriday: true, use24Hour: true,
      );
      expect(ar.cells[1].label, 'الجمعة');
      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.dhuhr,
        localeCode: 'en', isFriday: true, use24Hour: true,
      );
      expect(en.cells[1].label, "Jumu'ah");
    });

    test('nextPrayerIndex matches nextPrayer position in 5-prayer order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.maghrib,
        localeCode: 'en', isFriday: false, use24Hour: true,
      );
      expect(s.nextPrayerIndex, 3); // fajr=0,dhuhr=1,asr=2,maghrib=3
    });

    test('accentColor passes through; defaults to null', () {
      expect(
        PrayerStripStateBuilder.build(
          prayerTimes: pt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: true,
          accentColor: 0xFF2E5244,
        ).accentColor,
        0xFF2E5244,
      );
      expect(
        PrayerStripStateBuilder.build(
          prayerTimes: pt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: true,
        ).accentColor,
        isNull,
      );
    });

    test('hijri + weekday labels honour locale', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'ar', isFriday: true, use24Hour: true,
      );
      expect(ar.hijriDateLabel, '٥ ذو الحجة');
      expect(ar.weekdayLabel, 'الجمعة');
      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt, nextPrayer: PrayerName.fajr,
        localeCode: 'en', isFriday: true, use24Hour: true,
      );
      expect(en.hijriDateLabel, '5 Dhul-Hijjah');
      expect(en.weekdayLabel, 'Friday');
    });

    group('12-hour format (use24Hour=false) — display only', () {
      test('English afternoon uses 12-hour digits, no suffix', () {
        final s = PrayerStripStateBuilder.build(
          prayerTimes: pt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: false,
        );
        expect(s.cells[0].timeFormatted, '04:15'); // Fajr
        expect(s.cells[1].timeFormatted, '12:52'); // Dhuhr (noon boundary)
        expect(s.cells[2].timeFormatted, '04:28'); // Asr 16:28
        expect(s.cells[4].timeFormatted, '09:16'); // Isha 21:16
      });

      test('midnight 00:00 renders as 12:00', () {
        final midnightPt = PrayerTimes(
          key: pt.key,
          timings: {...pt.timings, PrayerName.fajr: '00:00'},
          date: pt.date,
        );
        final s = PrayerStripStateBuilder.build(
          prayerTimes: midnightPt, nextPrayer: PrayerName.fajr,
          localeCode: 'en', isFriday: false, use24Hour: false,
        );
        expect(s.cells[0].timeFormatted, '12:00');
        expect(s.cells[0].minutes, 0);
      });
    });
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`
Expected: FAIL — 6 cells, no `minutes`, no `dateKey`.

- [ ] **Step 3: Update the builder**

In `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`:

1. Drop sunrise from `_renderOrder`, `_labelsAr`, `_labelsEn`:
```dart
const _renderOrder = <PrayerName>[
  PrayerName.fajr,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

const _labelsAr = <PrayerName, String>{
  PrayerName.fajr: 'الفجر',
  PrayerName.dhuhr: 'الظهر',
  PrayerName.asr: 'العصر',
  PrayerName.maghrib: 'المغرب',
  PrayerName.isha: 'العشاء',
};

const _labelsEn = <PrayerName, String>{
  PrayerName.fajr: 'Fajr',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};
```

2. In `build`, compute `minutes` and pass it + `dateKey` through. Replace the `cells` mapping and the `return`:
```dart
    final cells = _renderOrder.map((p) {
      final rawLabel = labels[p]!;
      final label = (isFriday && p == PrayerName.dhuhr) ? jumuah : rawLabel;
      final raw = prayerTimes.timings[p] ?? '';
      final time = use24Hour
          ? raw.toIndicNumerals(localeCode)
          : _format12Hour(raw, localeCode);
      return PrayerCell(
        label: label,
        timeFormatted: time,
        minutes: _parseMinutes(raw),
      );
    }).toList();

    final nextIndex = _renderOrder.indexOf(nextPrayer);

    final monthName =
        localeCode == 'ar' ? prayerTimes.date.month : prayerTimes.date.enMonth;
    final dayPart = prayerTimes.date.day.toIndicNumerals(localeCode);
    final hijriLabel = '$dayPart $monthName';

    final weekdayLabel =
        localeCode == 'ar' ? prayerTimes.date.weekDay : prayerTimes.date.enWeekDay;

    return PrayerStripState(
      cells: cells,
      nextPrayerIndex: nextIndex < 0 ? 0 : nextIndex,
      dateKey: prayerTimes.date.gregorianDate,
      hijriDateLabel: hijriLabel,
      weekdayLabel: weekdayLabel,
      localeCode: localeCode,
      isFriday: isFriday,
      accentColor: accentColor,
    );
```

3. Add the helper next to `_format12Hour`:
```dart
  /// Parses a `HH:mm` 24-hour string to minutes-from-midnight. Returns 0 on a
  /// malformed input (the cell still renders; it just sorts to the top).
  static int _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/builders/prayer_strip_state_builder.dart test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart
git commit -m "feat(notifications): builder emits 5 cells with minutes + dateKey

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: New `PrayerStripWindow` entity

**Files:**
- Create: `lib/features/notifications/domain/entities/prayer_strip_window.dart`
- Test: `test/features/notifications/domain/entities/prayer_strip_window_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';

void main() {
  PrayerStripState day(String dateKey) => PrayerStripState(
        cells: const [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
        nextPrayerIndex: 0,
        dateKey: dateKey,
        hijriDateLabel: '5 Dhul-Hijjah',
        weekdayLabel: 'Friday',
        localeCode: 'en',
        isFriday: false,
      );

  test('toJson wraps each day under "days"', () {
    final w = PrayerStripWindow(days: [day('22-05-2026'), day('23-05-2026')]);
    final json = w.toJson();
    final days = (json['days'] as List).cast<Map>();
    expect(days.length, 2);
    expect(days[0]['dateKey'], '22-05-2026');
    expect(days[1]['dateKey'], '23-05-2026');
    expect((days[0]['cells'] as List).length, 1);
  });

  test('value equality by days', () {
    expect(
      PrayerStripWindow(days: [day('22-05-2026')]),
      PrayerStripWindow(days: [day('22-05-2026')]),
    );
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_strip_window_test.dart`
Expected: FAIL — file/class does not exist.

- [ ] **Step 3: Create the entity**

`lib/features/notifications/domain/entities/prayer_strip_window.dart`:
```dart
import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// A bounded window of consecutive day-states sent to the native strip in one
/// payload. The native side stores the window and renders whichever day is
/// "today", so the strip survives day rollover without the app being reopened.
class PrayerStripWindow extends Equatable {
  final List<PrayerStripState> days;

  const PrayerStripWindow({required this.days});

  Map<String, Object> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
      };

  @override
  List<Object?> get props => [days];
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_strip_window_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_strip_window.dart test/features/notifications/domain/entities/prayer_strip_window_test.dart
git commit -m "feat(notifications): add PrayerStripWindow (multi-day payload)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: `Settings.is24HourFormat` semantic getter

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/home/presentation/pages/home_page.dart:202`
- Test: `test/features/settings/domain/entities/settings_is24h_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

void main() {
  test('is24HourFormat mirrors the (misnamed) isFormat12Hours field', () {
    expect(
      const Settings(isFormat12Hours: true, isArabic: false).is24HourFormat,
      isTrue,
    );
    expect(
      const Settings(isFormat12Hours: false, isArabic: false).is24HourFormat,
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/settings/domain/entities/settings_is24h_test.dart`
Expected: FAIL — `is24HourFormat` getter not defined.

- [ ] **Step 3: Add the getter**

In `lib/features/settings/domain/entities/settings.dart`, immediately after the constructor (before `copyWith`), add:
```dart
  /// Clearer alias for the misnamed [isFormat12Hours] field: it is `true` when
  /// the user has the **24-hour** format enabled. Use this at call sites so the
  /// inverted name stops being a bug-trap. Persisted field name is unchanged.
  bool get is24HourFormat => isFormat12Hours;
```

Then at `lib/features/home/presentation/pages/home_page.dart` line ~202, change:
```dart
      use24Hour: settings.isFormat12Hours,
```
to:
```dart
      use24Hour: settings.is24HourFormat,
```
(and delete the now-redundant 2-line `// isFormat12Hours is named opposite…` comment above it).

> NOTE: this call site is reworked again in Task 9; the change here keeps the build green in the meantime.

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/settings/domain/entities/settings_is24h_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/domain/entities/settings.dart lib/features/home/presentation/pages/home_page.dart test/features/settings/domain/entities/settings_is24h_test.dart
git commit -m "refactor(settings): add is24HourFormat getter for the misnamed flag

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# PHASE 2 — Dart multi-day assembly + new contract

### Task 7: `PrayerTimesRepository.getCachedForDate`

**Files:**
- Modify: `lib/features/home/domain/repositories/prayer_times_repository.dart`
- Modify: `lib/features/home/data/repositories/prayer_times_repository_impl.dart`
- Test: `test/features/home/data/repositories/prayer_times_get_cached_for_date_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/data/repositories/prayer_times_repository_impl.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class _MockLocal extends Mock implements PrayerTimesLocalDataSource {}
class _MockRemote extends Mock implements PrayerTimeRemoteDataSource {}

void main() {
  late _MockLocal local;
  late _MockRemote remote;
  late PrayerTimesRepositoryImpl repo;

  final pt = PrayerTimes(
    key: '23-05-2026',
    timings: const {PrayerName.fajr: '04:14'},
    date: Date(
      month: '', weekDay: '', day: '6', year: '1447',
      enMonth: '', enWeekDay: '', gregorianDate: '23-05-2026',
    ),
  );

  setUp(() {
    local = _MockLocal();
    remote = _MockRemote();
    repo = PrayerTimesRepositoryImpl(
      prayerTimeRemoteDataSource: remote,
      prayerTimesLocalDataSource: local,
    );
  });

  test('returns the cached entry for the given date (no network)', () async {
    final date = DateTime(2026, 5, 23);
    when(() => local.getCached(date: date)).thenReturn(pt);
    final result = await repo.getCachedForDate(date);
    expect(result, pt);
    verifyNever(() => remote.getPrayerTimesList(any()));
  });

  test('returns null on a cache miss', () async {
    final date = DateTime(2026, 5, 23);
    when(() => local.getCached(date: date)).thenReturn(null);
    expect(await repo.getCachedForDate(date), isNull);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/home/data/repositories/prayer_times_get_cached_for_date_test.dart`
Expected: FAIL — `getCachedForDate` not defined.

- [ ] **Step 3: Add the method**

In `lib/features/home/domain/repositories/prayer_times_repository.dart`, add to the abstract class:
```dart
  /// Reads the cached prayer times for [date] from local storage only — never
  /// hits the network. Returns null when that day is not cached. Used to build
  /// the multi-day pinned-strip window from the already pre-cached month.
  Future<PrayerTimes?> getCachedForDate(DateTime date);
```

In `lib/features/home/data/repositories/prayer_times_repository_impl.dart`, add the override (after `getPrayerTimes`):
```dart
  @override
  Future<PrayerTimes?> getCachedForDate(DateTime date) async {
    return prayerTimesLocalDataSource.getCached(date: date);
  }
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/home/data/repositories/prayer_times_get_cached_for_date_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/domain/repositories/prayer_times_repository.dart lib/features/home/data/repositories/prayer_times_repository_impl.dart test/features/home/data/repositories/prayer_times_get_cached_for_date_test.dart
git commit -m "feat(home): add cache-only getCachedForDate to PrayerTimesRepository

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: `BuildPrayerStripWindow` usecase + DI

**Files:**
- Create: `lib/features/notifications/domain/usecases/build_prayer_strip_window.dart`
- Modify: `lib/features/notifications/notifications_di.dart`
- Test: `test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';

class _MockРrepoFix extends Mock implements PrayerTimesRepository {}

PrayerTimes _pt(String dateKey) => PrayerTimes(
      key: dateKey,
      timings: const {
        PrayerName.fajr: '04:15',
        PrayerName.sunrise: '05:07',
        PrayerName.dhuhr: '12:52',
        PrayerName.asr: '16:28',
        PrayerName.maghrib: '19:46',
        PrayerName.isha: '21:16',
      },
      date: Date(
        month: 'ذو الحجة', weekDay: 'الجمعة', day: '5', year: '1447',
        enMonth: 'Dhul-Hijjah', enWeekDay: 'Friday', gregorianDate: dateKey,
      ),
    );

void main() {
  late _MockРepoFix repo;
  late BuildPrayerStripWindow useCase;

  setUp(() {
    repo = _MockРepoFix();
    useCase = BuildPrayerStripWindow(prayerTimesRepository: repo);
  });

  test('builds up to N consecutive cached days starting today', () async {
    final now = DateTime(2026, 5, 22, 6, 0);
    when(() => repo.getCachedForDate(any())).thenAnswer((inv) async {
      final d = inv.positionalArguments.first as DateTime;
      final key =
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      return _pt(key);
    });

    final window = await useCase.call(BuildPrayerStripWindowParams(
      localeCode: 'en', use24Hour: true, now: now, days: 3,
    ));

    expect(window, isNotNull);
    expect(window!.days.length, 3);
    expect(window.days[0].dateKey, '22-05-2026');
    expect(window.days[1].dateKey, '23-05-2026');
    expect(window.days[0].cells.length, 5); // sunrise dropped
  });

  test('stops at the first cache gap', () async {
    final now = DateTime(2026, 5, 22, 6, 0);
    when(() => repo.getCachedForDate(any())).thenAnswer((inv) async {
      final d = inv.positionalArguments.first as DateTime;
      if (d.day >= 24) return null; // 24th onward missing
      final key =
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      return _pt(key);
    });

    final window = await useCase.call(BuildPrayerStripWindowParams(
      localeCode: 'en', use24Hour: true, now: now, days: 7,
    ));

    expect(window!.days.length, 2); // 22nd, 23rd
  });

  test('returns null when today is not cached', () async {
    when(() => repo.getCachedForDate(any())).thenAnswer((_) async => null);
    final window = await useCase.call(BuildPrayerStripWindowParams(
      localeCode: 'en', use24Hour: true, now: DateTime(2026, 5, 22), days: 7,
    ));
    expect(window, isNull);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart`
Expected: FAIL — usecase does not exist.

- [ ] **Step 3: Create the usecase**

`lib/features/notifications/domain/usecases/build_prayer_strip_window.dart`:
```dart
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';

class BuildPrayerStripWindowParams {
  final String localeCode;
  final bool use24Hour;
  final int? accentColor;
  final DateTime? now;
  final int days;

  const BuildPrayerStripWindowParams({
    required this.localeCode,
    required this.use24Hour,
    this.accentColor,
    this.now,
    this.days = 7,
  });
}

/// Assembles a bounded window of strip day-states from the locally cached
/// month. Stops at the first day with no cached prayer times, and returns null
/// when not even today is cached (caller then skips posting the strip).
class BuildPrayerStripWindow {
  final PrayerTimesRepository prayerTimesRepository;

  BuildPrayerStripWindow({required this.prayerTimesRepository});

  Future<PrayerStripWindow?> call(BuildPrayerStripWindowParams params) async {
    final now = params.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final states = <PrayerStripState>[];

    for (var i = 0; i < params.days; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      final pt = await prayerTimesRepository.getCachedForDate(date);
      if (pt == null) break; // stop at the first gap

      // Today resolves "next" against the live clock; future days against
      // their own start so they open on Fajr.
      final resolveAt = i == 0 ? now : date;
      final nextPrayer =
          NextPrayerResolver.resolve(timings: pt.timings, now: resolveAt);

      states.add(PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: nextPrayer,
        localeCode: params.localeCode,
        isFriday: date.weekday == DateTime.friday,
        use24Hour: params.use24Hour,
        accentColor: params.accentColor,
      ));
    }

    if (states.isEmpty) return null;
    return PrayerStripWindow(days: states);
  }
}
```

In `lib/features/notifications/notifications_di.dart`, add the import and registration. Import:
```dart
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';
```
Registration (inside `initNotifications`, after `EnablePrayerStrip`):
```dart
  sl.registerLazySingleton(
    () => BuildPrayerStripWindow(prayerTimesRepository: sl()),
  );
```
> `PrayerTimesRepository` is registered in `initHome()`, which runs before `initNotifications()` — no ordering change needed.

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/usecases/build_prayer_strip_window.dart lib/features/notifications/notifications_di.dart test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart
git commit -m "feat(notifications): BuildPrayerStripWindow usecase (7-day cached window)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Switch the strip contract to `PrayerStripWindow` end-to-end

Changes the data source, repository, usecases, their tests, and the home wiring so a window is sent instead of a single state.

**Files:**
- Modify: `lib/features/notifications/data/datasources/notifications_native_data_source.dart`
- Modify: `lib/features/notifications/domain/repositories/notifications_repository.dart`
- Modify: `lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- Modify: `lib/features/notifications/domain/usecases/enable_prayer_strip.dart`
- Modify: `lib/features/notifications/domain/usecases/refresh_prayer_strip.dart`
- Modify: `lib/features/home/presentation/pages/home_page.dart`
- Tests: `test/features/notifications/data/datasources/notifications_native_data_source_test.dart`, `test/features/notifications/domain/usecases/enable_prayer_strip_test.dart`, `test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart`, `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`

- [ ] **Step 1: Update the data source test** to send a window

Replace the `state` fixture and the enable/refresh assertions in `notifications_native_data_source_test.dart`:

Change the imports block to add:
```dart
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
```
Replace the `final state = …` block with:
```dart
  final window = PrayerStripWindow(days: [
    const PrayerStripState(
      cells: [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
      nextPrayerIndex: 0,
      dateKey: '22-05-2026',
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: '',
      localeCode: 'en',
      isFriday: false,
    ),
  ]);
```
Replace the `enableStrip` test body with:
```dart
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
```
Replace the `refreshStrip` test body with:
```dart
  test('refreshStrip invokes the channel with the days payload', () async {
    await ds.refreshStrip(window);
    expect(calls.single.method, 'refreshStrip');
    expect((calls.single.arguments as Map)['days'], isA<List>());
  });
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/notifications/data/datasources/notifications_native_data_source_test.dart`
Expected: FAIL — `enableStrip` still takes `PrayerStripState`.

- [ ] **Step 3: Change the data source signatures**

In `lib/features/notifications/data/datasources/notifications_native_data_source.dart`:
- Replace the import of `prayer_strip_state.dart` with `prayer_strip_window.dart`.
- In the abstract class, change:
```dart
  Future<void> enableStrip(PrayerStripWindow window);
  Future<void> disableStrip();
  Future<void> refreshStrip(PrayerStripWindow window);
```
- In the impl:
```dart
  @override
  Future<void> enableStrip(PrayerStripWindow window) =>
      _invoke('enableStrip', window.toJson());

  @override
  Future<void> disableStrip() => _invoke('disableStrip');

  @override
  Future<void> refreshStrip(PrayerStripWindow window) =>
      _invoke('refreshStrip', window.toJson());
```

- [ ] **Step 4: Change the repository interface + impl**

In `lib/features/notifications/domain/repositories/notifications_repository.dart`:
- Replace the `prayer_strip_state.dart` import with `prayer_strip_window.dart`.
- Change the three signatures:
```dart
  Future<Either<Failure, Unit>> enableStrip(PrayerStripWindow window);
  Future<Either<Failure, Unit>> disableStrip();
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripWindow window);
```

In `lib/features/notifications/data/repositories/notifications_repository_impl.dart`:
- Replace the `prayer_strip_state.dart` import with `prayer_strip_window.dart`.
- Change:
```dart
  @override
  Future<Either<Failure, Unit>> enableStrip(PrayerStripWindow window) =>
      _run(() => native.enableStrip(window));

  @override
  Future<Either<Failure, Unit>> disableStrip() =>
      _run(() => native.disableStrip());

  @override
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripWindow window) =>
      _run(() => native.refreshStrip(window));
```

- [ ] **Step 5: Change the usecases**

`lib/features/notifications/domain/usecases/enable_prayer_strip.dart`:
```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class EnablePrayerStripParams {
  final PrayerStripWindow window;
  const EnablePrayerStripParams({required this.window});
}

class EnablePrayerStrip
    extends UseCase<Either<Failure, Unit>, EnablePrayerStripParams> {
  final NotificationsRepository repository;
  EnablePrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(EnablePrayerStripParams params) =>
      repository.enableStrip(params.window);
}
```

`lib/features/notifications/domain/usecases/refresh_prayer_strip.dart`:
```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class RefreshPrayerStripParams {
  final PrayerStripWindow window;
  const RefreshPrayerStripParams({required this.window});
}

class RefreshPrayerStrip
    extends UseCase<Either<Failure, Unit>, RefreshPrayerStripParams> {
  final NotificationsRepository repository;
  RefreshPrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(RefreshPrayerStripParams params) =>
      repository.refreshStrip(params.window);
}
```

- [ ] **Step 6: Rewrite the usecase tests**

`test/features/notifications/domain/usecases/enable_prayer_strip_test.dart`:
```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late EnablePrayerStrip useCase;

  final window = PrayerStripWindow(days: [
    const PrayerStripState(
      cells: [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
      nextPrayerIndex: 0,
      dateKey: '22-05-2026',
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: '',
      localeCode: 'en',
      isFriday: false,
    ),
  ]);

  setUp(() {
    repo = _MockRepo();
    useCase = EnablePrayerStrip(repository: repo);
    registerFallbackValue(window);
  });

  test('delegates to repository.enableStrip with the given window', () async {
    when(() => repo.enableStrip(any())).thenAnswer((_) async => const Right(unit));
    final result = await useCase.call(EnablePrayerStripParams(window: window));
    expect(result, const Right(unit));
    verify(() => repo.enableStrip(window)).called(1);
  });
}
```

`test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart`:
```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late RefreshPrayerStrip useCase;

  final window = PrayerStripWindow(days: [
    const PrayerStripState(
      cells: [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
      nextPrayerIndex: 0,
      dateKey: '22-05-2026',
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: '',
      localeCode: 'en',
      isFriday: false,
    ),
  ]);

  setUp(() {
    repo = _MockRepo();
    useCase = RefreshPrayerStrip(repository: repo);
    registerFallbackValue(window);
  });

  test('delegates to repository.refreshStrip with the given window', () async {
    when(() => repo.refreshStrip(any())).thenAnswer((_) async => const Right(unit));
    final result = await useCase.call(RefreshPrayerStripParams(window: window));
    expect(result, const Right(unit));
    verify(() => repo.refreshStrip(window)).called(1);
  });
}
```

- [ ] **Step 7: Fix the repository-impl test**

In `test/features/notifications/data/repositories/notifications_repository_impl_test.dart` only the `enableStrip` fixture + group reference the strip; the adhans/reminders groups are untouched. Make exactly these edits:

1. Add the import (after the `prayer_strip_state.dart` import line):
```dart
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
```

2. Replace the `state` fixture (the `final state = PrayerStripState(…);` block) with a window fixture:
```dart
  final window = PrayerStripWindow(days: [
    const PrayerStripState(
      cells: [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
      nextPrayerIndex: 0,
      dateKey: '22-05-2026',
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: '',
      localeCode: 'en',
      isFriday: false,
    ),
  ]);
```

3. In `setUp`, change `registerFallbackValue(state);` to `registerFallbackValue(window);`.

4. In the `enableStrip` group, change all three `await repo.enableStrip(state)` calls to `await repo.enableStrip(window)`. The `when(() => native.enableStrip(any()))` stubs are unchanged (`any()` + the new fallback value cover the new `PrayerStripWindow` type).

- [ ] **Step 8: Rewire `home_page._enableOrRefreshStrip`**

In `lib/features/home/presentation/pages/home_page.dart`, replace the body of `_enableOrRefreshStrip` (the `try { … }` that builds `nextPrayer` + `stripState` and calls `EnablePrayerStrip`) with an async build via the new usecase. The new version:

```dart
void _enableOrRefreshStrip(
  BuildContext context,
  DailyPrayerContextLoaded loaded,
) {
  final settings = context.read<SettingsCubit>().state.settingsModel;
  if (!settings.isPrayerStripPinned) return;

  // Best-effort side effect — must never crash the app.
  unawaited(() async {
    try {
      final window = await sl<BuildPrayerStripWindow>().call(
        BuildPrayerStripWindowParams(
          localeCode: settings.isArabic ? 'ar' : 'en',
          use24Hour: settings.is24HourFormat,
          accentColor: settings.palette.primary.toARGB32(),
        ),
      );
      if (window == null) return; // nothing cached yet
      final r = await sl<EnablePrayerStrip>()
          .call(EnablePrayerStripParams(window: window));
      r.fold(
        (f) => debugPrint('[prayer-strip] enable failed: ${f.message}'),
        (_) {},
      );
    } catch (e, st) {
      debugPrint('refresh prayer strip failed: $e\n$st');
    }
  }());
}
```
Add the imports if not present:
```dart
import 'package:quran_app/features/notifications/domain/usecases/build_prayer_strip_window.dart';
```
Remove now-unused imports (`NextPrayerResolver`, `PrayerStripStateBuilder`) **only if** no longer referenced anywhere else in the file. The `loaded` parameter stays (it is the trigger) even though its `prayerTimes` is no longer read directly — the window is built from the cache, which `loaded` guarantees is warm.

- [ ] **Step 9: Run the affected Dart tests**

Run:
```bash
fvm flutter test test/features/notifications/data/datasources/notifications_native_data_source_test.dart test/features/notifications/domain/usecases/enable_prayer_strip_test.dart test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart test/features/notifications/data/repositories/notifications_repository_impl_test.dart
```
Expected: PASS.

- [ ] **Step 10: Analyze + commit**

Run: `fvm flutter analyze lib/features/notifications lib/features/home lib/features/settings`
Expected: No issues (fix any unused-import warnings introduced).

```bash
git add lib/features/notifications lib/features/home/presentation/pages/home_page.dart test/features/notifications
git commit -m "feat(notifications): send a PrayerStripWindow (multi-day) over the channel

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# PHASE 3 — Android: parse the window, drop the FGS, 5-cell render

> No Kotlin unit-test harness exists in this project. Verify each native task with a Kotlin compile and, at the end, the manual on-device gate (Task 18). Compile check used below:
> `cd android && ./gradlew :app:compileDebugKotlin` (run from repo root in one command; do not leave the shell `cd`-ed).

### Task 10: Native window/day/cell data classes + JSON

**Files:**
- Modify (rewrite): `android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt`

- [ ] **Step 1: Replace the file contents**

```kotlin
package com.example.quran_app

import org.json.JSONArray
import org.json.JSONObject

data class PrayerCellNative(val label: String, val time: String, val minutes: Int)

data class PrayerStripDay(
    val dateKey: String,
    val cells: List<PrayerCellNative>,
    val hijriDateLabel: String,
    val weekdayLabel: String,
    val localeCode: String,
    val isFriday: Boolean,
    /** ARGB for the next-prayer pill; null → renderer falls back to strip_accent. */
    val accentColor: Int? = null,
)

/** A bounded window of consecutive day-states. The renderer shows whichever
 *  day matches the current calendar date. */
data class PrayerStripWindow(val days: List<PrayerStripDay>) {

    companion object {
        fun fromJsonString(raw: String): PrayerStripWindow {
            val obj = JSONObject(raw)
            val daysArr = obj.getJSONArray("days")
            val days = mutableListOf<PrayerStripDay>()
            for (i in 0 until daysArr.length()) {
                days += dayFromJson(daysArr.getJSONObject(i))
            }
            return PrayerStripWindow(days)
        }

        private fun dayFromJson(obj: JSONObject): PrayerStripDay {
            val rawCells = obj.getJSONArray("cells")
            val cells = mutableListOf<PrayerCellNative>()
            for (i in 0 until rawCells.length()) {
                val c = rawCells.getJSONObject(i)
                cells += PrayerCellNative(
                    c.getString("label"),
                    c.getString("time"),
                    c.getInt("minutes"),
                )
            }
            val accent = if (obj.has("accentColor")) {
                try {
                    android.graphics.Color.parseColor(obj.getString("accentColor"))
                } catch (e: IllegalArgumentException) {
                    null
                }
            } else {
                null
            }
            return PrayerStripDay(
                dateKey = obj.getString("dateKey"),
                cells = cells,
                hijriDateLabel = obj.getString("hijriDateLabel"),
                weekdayLabel = if (obj.has("weekdayLabel")) obj.getString("weekdayLabel") else "",
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday"),
                accentColor = accent,
            )
        }
    }

    fun toJsonString(): String {
        val obj = JSONObject()
        val daysArr = JSONArray()
        for (d in days) {
            val dObj = JSONObject()
            val cellsArr = JSONArray()
            for (c in d.cells) {
                cellsArr.put(
                    JSONObject()
                        .put("label", c.label)
                        .put("time", c.time)
                        .put("minutes", c.minutes)
                )
            }
            dObj.put("dateKey", d.dateKey)
            dObj.put("cells", cellsArr)
            dObj.put("hijriDateLabel", d.hijriDateLabel)
            dObj.put("weekdayLabel", d.weekdayLabel)
            dObj.put("localeCode", d.localeCode)
            dObj.put("isFriday", d.isFriday)
            d.accentColor?.let { dObj.put("accentColor", String.format("#%08X", it)) }
            daysArr.put(dObj)
        }
        obj.put("days", daysArr)
        return obj.toString()
    }
}
```

- [ ] **Step 2: (Compile happens after Task 13, which removes the old `PrayerStripState` references.)** No standalone compile here — `PrayerStripService.kt` and others still reference the old `PrayerStripState`; they are replaced/removed in Tasks 13–16. Proceed.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt
git commit -m "feat(android): PrayerStripWindow/Day/Cell data classes with minutes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: 5-cell RemoteViews layouts

**Files:**
- Modify: `android/app/src/main/res/layout/prayer_strip_collapsed.xml`
- Modify: `android/app/src/main/res/layout/prayer_strip_expanded.xml`

- [ ] **Step 1: Rewrite `prayer_strip_collapsed.xml` to 5 cells**

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:weightSum="5"
    android:layoutDirection="locale">

    <LinearLayout android:id="@+id/cell_0"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_0_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_0_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_semibold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_1"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_1_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_1_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_semibold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_2"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_2_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_2_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_semibold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_3"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_3_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_3_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_semibold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_4"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_4_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_4_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_semibold"
            android:layout_marginTop="2dp" />
    </LinearLayout>
</LinearLayout>
```

- [ ] **Step 2: Rewrite `prayer_strip_expanded.xml` to 5 cells**

This file is structurally identical to the collapsed one except the time `TextView`s use `@font/cairo_bold` (not `cairo_semibold`). Replace its full contents with:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:weightSum="5"
    android:layoutDirection="locale">

    <LinearLayout android:id="@+id/cell_0"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_0_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_0_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_bold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_1"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_1_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_1_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_bold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_2"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_2_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_2_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_bold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_3"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_3_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_3_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_bold"
            android:layout_marginTop="2dp" />
    </LinearLayout>

    <LinearLayout android:id="@+id/cell_4"
        android:layout_width="0dp" android:layout_height="wrap_content"
        android:layout_weight="1" android:orientation="vertical" android:gravity="center"
        android:paddingTop="0dp" android:paddingBottom="0dp"
        android:paddingStart="4dp" android:paddingEnd="4dp">
        <TextView android:id="@+id/cell_4_label"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_primary" android:textSize="14sp"
            android:fontFamily="@font/cairo_bold"
            android:maxLines="1" android:ellipsize="end" />
        <TextView android:id="@+id/cell_4_time"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="@color/strip_text_muted" android:textSize="12sp"
            android:fontFamily="@font/cairo_bold"
            android:layout_marginTop="2dp" />
    </LinearLayout>
</LinearLayout>
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/res/layout/prayer_strip_collapsed.xml android/app/src/main/res/layout/prayer_strip_expanded.xml
git commit -m "feat(android): 5-cell prayer strip layouts (drop sunrise)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 12: Renderer — `build(day, nextIndex)`, 5 cells

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt`

- [ ] **Step 1: Change `build` signature and `bindCells`**

Replace the `build` method and the `bindCells` method with:

```kotlin
    fun build(day: PrayerStripDay, nextIndex: Int): Notification {
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)
        val expanded = RemoteViews(context.packageName, R.layout.prayer_strip_expanded)
        bindCells(collapsed, day, nextIndex)
        bindCells(expanded, day, nextIndex)

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

    private fun bindCells(views: RemoteViews, day: PrayerStripDay, nextIndex: Int) {
        val labelIds = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label,
            R.id.cell_3_label, R.id.cell_4_label
        )
        val timeIds = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time,
            R.id.cell_3_time, R.id.cell_4_time
        )

        val primary = context.resources.getColor(R.color.strip_text_primary, null)
        val muted = context.resources.getColor(R.color.strip_text_muted, null)
        val dim = context.resources.getColor(R.color.strip_text_dim, null)
        val pillText = context.resources.getColor(R.color.strip_pill_text, null)
        val accent = day.accentColor
            ?: context.resources.getColor(R.color.strip_accent, null)

        for (i in 0 until 5) {
            val cell = day.cells.getOrNull(i) ?: continue
            views.setTextViewText(labelIds[i], cell.label)
            views.setTextViewText(timeIds[i], cell.time)

            when {
                i == nextIndex -> {
                    views.setTextViewText(labelIds[i], boldLabel(cell.label))
                    views.setTextColor(labelIds[i], primary)
                    views.setTextColor(timeIds[i], pillText)
                    applyAccentPill(views, timeIds[i], accent)
                }
                i < nextIndex -> {
                    views.setTextColor(labelIds[i], dim)
                    views.setTextColor(timeIds[i], dim)
                    views.setInt(timeIds[i], "setBackgroundResource", 0)
                }
                else -> {
                    views.setTextColor(labelIds[i], primary)
                    views.setTextColor(timeIds[i], muted)
                    views.setInt(timeIds[i], "setBackgroundResource", 0)
                }
            }
        }
    }
```

`boldLabel`, `applyAccentPill`, `ensureChannel`, and the `companion object` (`CHANNEL_ID`, `NOTIFICATION_ID`) stay unchanged.

- [ ] **Step 2: Commit** (compile deferred to Task 16)

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt
git commit -m "feat(android): renderer takes (day, nextIndex); 5 cells

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 13: `PrayerStripController` (no foreground service)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripController.kt`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripStateStore.kt`

- [ ] **Step 1: Change the store to load a window**

In `PrayerStripStateStore.kt`, change `load()`:
```kotlin
    fun load(): PrayerStripWindow? {
        if (!prefs.getBoolean(KEY_ENABLED, false)) return null
        val raw = prefs.getString(KEY_STATE_JSON, null) ?: return null
        return runCatching { PrayerStripWindow.fromJsonString(raw) }.getOrNull()
    }
```
`save`, `clear`, `isEnabled`, and the companion stay unchanged.

- [ ] **Step 2: Create the controller**

`android/app/src/main/kotlin/com/example/quran_app/PrayerStripController.kt`:
```kotlin
package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Drives the pinned prayer strip as an ordinary ongoing notification — NO
 * foreground service. show/refresh/hide are invoked in-process by the plugin,
 * the alarm receiver, and the boot receiver. Exact alarms (each prayer + one
 * minute past midnight) re-post the notification, so it survives Doze and day
 * rollover without a long-lived service (avoids the Android-15 dataSync FGS
 * 6h/day timeout and the boot/alarm FGS-start restrictions).
 */
object PrayerStripController {

    private const val MIDNIGHT_REQUEST_CODE = 99

    fun show(context: Context, windowJson: String) {
        val ctx = context.applicationContext
        PrayerStripStateStore(ctx).save(windowJson)
        renderCurrentDay(ctx)
    }

    fun refresh(context: Context) = renderCurrentDay(context.applicationContext)

    fun hide(context: Context) {
        val ctx = context.applicationContext
        PrayerStripStateStore(ctx).clear()
        cancelAlarms(ctx)
        NotificationManagerCompat.from(ctx).cancel(PrayerStripRenderer.NOTIFICATION_ID)
    }

    private fun renderCurrentDay(ctx: Context) {
        val window = PrayerStripStateStore(ctx).load() ?: return
        val today = todayKey()
        val day = window.days.firstOrNull { it.dateKey == today }
        if (day == null) {
            // Cached window exhausted — clear the (now stale) strip until the
            // app reopens and re-arms a fresh window.
            cancelAlarms(ctx)
            NotificationManagerCompat.from(ctx).cancel(PrayerStripRenderer.NOTIFICATION_ID)
            return
        }
        val renderer = PrayerStripRenderer(ctx)
        renderer.ensureChannel()
        val nextIndex = computeNextIndex(day)
        NotificationManagerCompat.from(ctx)
            .notify(PrayerStripRenderer.NOTIFICATION_ID, renderer.build(day, nextIndex))
        scheduleAlarms(ctx, day)
    }

    /** First cell whose 24h [PrayerCellNative.minutes] is still in the future, else 0 (Fajr). */
    private fun computeNextIndex(day: PrayerStripDay): Int {
        val now = Calendar.getInstance()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for ((i, cell) in day.cells.withIndex()) {
            if (cell.minutes > nowMinutes) return i
        }
        return 0
    }

    private fun scheduleAlarms(ctx: Context, day: PrayerStripDay) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance().timeInMillis
        for (i in day.cells.indices) {
            val minutes = day.cells[i].minutes
            val triggerCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (triggerCal.timeInMillis < now) continue
            scheduleExact(
                am, triggerCal.timeInMillis,
                prayerAlarmPI(ctx, i, PrayerAlarmReceiver.REASON_PRAYER)
            )
        }
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        scheduleExact(
            am, midnight.timeInMillis,
            prayerAlarmPI(ctx, MIDNIGHT_REQUEST_CODE, PrayerAlarmReceiver.REASON_MIDNIGHT)
        )
    }

    private fun cancelAlarms(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0..5) am.cancel(prayerAlarmPI(ctx, i, PrayerAlarmReceiver.REASON_PRAYER))
        am.cancel(prayerAlarmPI(ctx, MIDNIGHT_REQUEST_CODE, PrayerAlarmReceiver.REASON_MIDNIGHT))
    }

    private fun prayerAlarmPI(ctx: Context, requestCode: Int, reason: String): PendingIntent {
        val intent = Intent(ctx, PrayerAlarmReceiver::class.java).apply {
            putExtra(PrayerAlarmReceiver.EXTRA_REASON, reason)
        }
        return PendingIntent.getBroadcast(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleExact(am: AlarmManager, triggerAt: Long, pi: PendingIntent) {
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun todayKey(): String =
        SimpleDateFormat("dd-MM-yyyy", Locale.US).format(Calendar.getInstance().time)
}
```

- [ ] **Step 3: Commit** (compile deferred to Task 16)

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripController.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripStateStore.kt
git commit -m "feat(android): PrayerStripController posts an alarm-driven ongoing notification

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 14: Plugin routes to the controller; serialize the window

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`

- [ ] **Step 1: Replace `handleEnableOrRefreshStrip` and `handleDisableStrip`**

```kotlin
    private fun handleEnableOrRefreshStrip(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val json = serializeStripArgs(call.arguments)
        if (json == null) {
            result.error("BAD_ARGS", "Expected {days:[...]} state, got ${call.arguments}", null)
            return
        }
        PrayerStripController.show(ctx, json)
        result.success(null)
    }

    private fun handleDisableStrip(ctx: Context, result: MethodChannel.Result) {
        PrayerStripController.hide(ctx)
        result.success(null)
    }
```

- [ ] **Step 2: Replace `serializeStripArgs` to build the `{days:[...]}` payload**

```kotlin
    private fun serializeStripArgs(args: Any?): String? {
        if (args !is Map<*, *>) return null
        val daysRaw = args["days"] as? List<*> ?: return null
        val daysArr = org.json.JSONArray()
        for (d in daysRaw) {
            val dm = d as? Map<*, *> ?: return null
            val cellsRaw = dm["cells"] as? List<*> ?: return null
            val cellsArr = org.json.JSONArray()
            for (c in cellsRaw) {
                val cm = c as? Map<*, *> ?: return null
                cellsArr.put(
                    org.json.JSONObject()
                        .put("label", cm["label"] as? String ?: return null)
                        .put("time", cm["time"] as? String ?: return null)
                        .put("minutes", (cm["minutes"] as? Int) ?: return null)
                )
            }
            val dObj = org.json.JSONObject()
                .put("dateKey", dm["dateKey"] as? String ?: return null)
                .put("cells", cellsArr)
                .put("hijriDateLabel", dm["hijriDateLabel"] as? String ?: return null)
                .put("weekdayLabel", dm["weekdayLabel"] as? String ?: return null)
                .put("localeCode", dm["localeCode"] as? String ?: return null)
                .put("isFriday", dm["isFriday"] as? Boolean ?: return null)
            (dm["accentColor"] as? String)?.let { dObj.put("accentColor", it) }
            daysArr.put(dObj)
        }
        return org.json.JSONObject().put("days", daysArr).toString()
    }
```

The `enableStrip`/`refreshStrip`/`disableStrip` cases in `onMethodCall` are unchanged (they already route to `handleEnableOrRefreshStrip`/`handleDisableStrip`). Adhan/reminder handlers are untouched.

- [ ] **Step 3: Commit** (compile deferred to Task 16)

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt
git commit -m "feat(android): plugin routes strip to PrayerStripController; serialize window

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 15: Receivers call the controller; midnight rebuilds

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerAlarmReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripBootReceiver.kt`

- [ ] **Step 1: Rewrite `PrayerAlarmReceiver.kt`**

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by AlarmManager at each remaining prayer time + one minute past
 * midnight. Both reasons simply re-render the current day: a prayer-time alarm
 * advances the highlight; the midnight alarm rolls the strip onto the new day
 * (or clears it if the cached window is exhausted).
 */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return
        PrayerStripController.refresh(context)
    }

    companion object {
        const val EXTRA_REASON = "reason"
        const val REASON_PRAYER = "prayer"
        const val REASON_MIDNIGHT = "midnight"
    }
}
```

- [ ] **Step 2: Rewrite `PrayerStripBootReceiver.kt`**

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-posts the prayer strip after device boot if the user had it enabled. */
class PrayerStripBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return
        PrayerStripController.refresh(context)
    }
}
```

- [ ] **Step 3: Commit** (compile deferred to Task 16)

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerAlarmReceiver.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripBootReceiver.kt
git commit -m "feat(android): strip receivers refresh via controller; midnight rebuilds

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 16: Delete the foreground service + manifest/permission cleanup

**Files:**
- Delete: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Delete the service**

```bash
git rm android/app/src/main/kotlin/com/example/quran_app/PrayerStripService.kt
```

- [ ] **Step 2: Edit the manifest**

Remove the `FOREGROUND_SERVICE_DATA_SYNC` permission line:
```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
```
Remove the strip service block:
```xml
        <service
            android:name=".PrayerStripService"
            android:foregroundServiceType="dataSync"
            android:exported="false" />
```
**Keep** `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (adhan service still needs them), the `.PrayerAlarmReceiver` and `.PrayerStripBootReceiver` receivers, and the `.AdhanPlaybackService` block.

- [ ] **Step 3: Compile the whole Kotlin module**

Run: `cd android && ./gradlew :app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL. Fix any unresolved references (all old `PrayerStripState`/`PrayerStripService` usages should now be gone).

> If gradle is not directly runnable in this environment, use `fvm flutter build apk --debug` instead, which compiles the Android module.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): remove dataSync foreground service + permission for the strip

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# PHASE 4 — Adhan swipe-to-terminate

### Task 17: Make the adhan notification dismissible

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt`

- [ ] **Step 1: Track the locale and re-post a dismissible notification on completion**

1. Add a field next to `currentPrayer`:
```kotlin
    private var currentPrayer: String? = null
    private var currentLocale: String = "en"
```

2. In `handlePlay`, capture the locale and pass `ongoing = false` to both `buildNotification` calls:
```kotlin
        val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: "fajr"
        val clipName = intent.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        currentLocale = localeCode

        ensureChannel()

        if (mediaPlayer != null) {
            Log.w(TAG, "handlePlay: adhan already playing ($currentPrayer); ignoring $prayer")
            startForeground(NOTIFICATION_ID, buildNotification(currentPrayer ?: prayer, localeCode, ongoing = false))
            return
        }

        currentPrayer = prayer
        Log.i(TAG, "onStartCommand action=ACTION_PLAY prayer=$prayer clip=$clipName")

        val notif = buildNotification(prayer, localeCode, ongoing = false)
        startForeground(NOTIFICATION_ID, notif)

        startMediaPlayer(clipName)
```

3. In `startMediaPlayer`, update the completion listener to detach + re-post a freely-dismissible notification:
```kotlin
            setOnCompletionListener {
                Log.i(TAG, "MediaPlayer onCompletion (released; notification kept, now dismissible)")
                it.release()
                mediaPlayer = null
                // Detach from the foreground service so the notification can be
                // swiped on every Android version; the swipe fires the delete
                // intent → ACTION_STOP, which tears the service down.
                stopForeground(STOP_FOREGROUND_DETACH)
                NotificationManagerCompat.from(this@AdhanPlaybackService).notify(
                    NOTIFICATION_ID,
                    buildNotification(currentPrayer ?: "fajr", currentLocale, ongoing = false),
                )
            }
```

4. Change `buildNotification` to take an `ongoing` flag and drop the forced ongoing:
```kotlin
    private fun buildNotification(
        prayer: String,
        localeCode: String,
        ongoing: Boolean,
    ): android.app.Notification {
```
and inside, change the builder line `.setOngoing(true)` to `.setOngoing(ongoing)`. Keep `.setAutoCancel(false)`, `.setDeleteIntent(stopPI)`, and the Stop action exactly as they are.

5. Add the import at the top:
```kotlin
import androidx.core.app.NotificationManagerCompat
```

- [ ] **Step 2: Compile**

Run: `cd android && ./gradlew :app:compileDebugKotlin`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt
git commit -m "feat(android): adhan notification is swipe-to-dismiss (stops playback)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

# PHASE 5 — Verification

### Task 18: Scoped test sweep, analyze, manual gate

**Files:** none (verification only).

- [ ] **Step 1: Run the full notifications + touched home/settings Dart suites (scoped — never the whole suite)**

Run:
```bash
fvm flutter test test/features/notifications test/features/home test/features/settings
```
Expected: All PASS.

- [ ] **Step 2: Analyze the changed Dart**

Run: `fvm flutter analyze lib/features/notifications lib/features/home lib/features/settings`
Expected: No issues.

- [ ] **Step 3: Build the Android debug APK**

Run: `fvm flutter build apk --debug`
Expected: BUILD SUCCESSFUL (confirms manifest + Kotlin are consistent).

- [ ] **Step 4: Manual on-device verification (document results in the PR description)**

Confirm each on a real device / emulator with the strip pinned:
1. Set device + app to **12-hour** format → the **correct** upcoming prayer is highlighted (not just Fajr); the highlight advances at each prayer time.
2. Strip shows **5 cells** (no Sunrise) with **no ellipsis** on Arabic labels.
3. Leave the app **closed for > 6 hours** and across **local midnight** → the strip stays and shows the **new day** (within the 7-day window).
4. **Reboot** the device → the strip returns.
5. Trigger an adhan (use the debug `scheduleTestAdhan`) → **swipe** the adhan notification → audio **stops** and the notification clears (test on Android 12, 14, and 15 if available). The **Stop** button also still works.

- [ ] **Step 5: Finalize**

Use the `superpowers:finishing-a-development-branch` skill to decide merge/PR. Note the manual-gate results from Step 4 in the PR body.

---

## Self-review notes (author)

- **Spec coverage:** Fix 1 (minutes) → Tasks 1,3,4,10,12,13; Fix 2 (sunrise/5 cells) → Tasks 2,4,11,12; Fix 3 (no FGS) → Tasks 13,14,15,16; Fix 3b (multi-day/midnight) → Tasks 5,7,8,9,13,15; Fix 4 (adhan swipe) → Task 17; cosmetic getter → Task 6. All covered.
- **Contract consistency:** `minutes` (int), `dateKey` ("dd-MM-yyyy" == `gregorianDate`), `{days:[...]}` payload, `PrayerStripController.show/refresh/hide`, `PrayerStripRenderer.build(day, nextIndex)` used identically across Dart and Kotlin tasks.
- **Native compile ordering:** intermediate native commits (Tasks 10,12,13,14,15) don't compile in isolation because old `PrayerStripState`/`PrayerStripService` references are removed only in Task 16; the first green Kotlin compile is Task 16 Step 3. This is called out in each task.
- **Test caveat honored:** every `flutter test` invocation is scoped to `test/features/...`.
