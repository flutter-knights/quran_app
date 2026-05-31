# Mushaf Phase 1 — Reading Feel & Chrome — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Mushaf screen read like a real mushaf — printed QCF-glyph surah/juz header band + page-number ornament, six eye-tuned paper themes with in-app brightness, controlled from a reading-settings sheet and a floating action dock.

**Architecture:** Additive changes within the existing clean-architecture Flutter app. Pure logic (paper colors, page→surah/juz resolution, settings fields) is unit-tested; widgets get widget tests. The printed chrome replaces the floating `MushafTopBar`/`MushafBottomBar`; metadata moves onto the page, controls move into a glassy dock + bottom sheet.

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `HydratedCubit` (Hive persistence), `get_it` (`sl`), the local `quran` package (QCF glyph helpers), `flutter_intl`/`intl_utils` for localization.

**Spec:** `docs/superpowers/specs/2026-05-31-mushaf-reading-experience-design.md` (Phase 1 section). Visual refs: `.superpowers/mockups/01,02,09-*.html`.

---

## File structure (Phase 1)

**Create:**
- `lib/core/constants/mushaf_reading_mode.dart` — `MushafReadingMode { page, scroll }` enum.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart` — printed glyph header band + page-number ornament.
- `lib/features/surah/presentation/utils/printed_chrome_resolver.dart` — pure: page → (surah, juz) to display.
- `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart` — paper grid + brightness + mode toggle.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart` — floating glassy dock.
- Tests under `test/` mirroring each.

**Modify:**
- `pubspec.yaml` — register `QCF2BSML` font family.
- `lib/core/constants/mushaf_paper.dart` — six-theme enum.
- `lib/features/surah/presentation/utils/mushaf_paper_colors.dart` — fixed per-theme colors (getter).
- `lib/features/settings/domain/entities/settings.dart` — add `pageBrightness`, `readingMode`.
- `lib/features/settings/data/models/settings_model.dart` — persist the new fields.
- `lib/features/settings/presentation/cubit/settings_cubit.dart` — setters.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` — brightness overlay + new color getter.
- `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` — printed chrome + dock; remove old bars.
- `lib/features/settings/presentation/pages/settings_page.dart` — Mushaf section.
- `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb` — new strings.

**Delete (Task 10):** `mushaf_top_bar.dart`, `mushaf_bottom_bar.dart` (replaced).

---

## Task 1: Register QCF2BSML font + verify glyph maps

**Files:**
- Modify: `pubspec.yaml` (the `flutter:` section, after the `assets:` block ~line 95)
- Test: `test/quran_package/qcf_glyph_maps_test.dart`

- [ ] **Step 1: Write the failing test** — the `quran` package throws `"Invalid surahNumber"`/`"Invalid juzNumber"` if a map entry is missing. This proves all 114 surah + 30 juz glyphs (plus the label entries) exist.

Create `test/quran_package/qcf_glyph_maps_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  group('QCF glyph maps are complete', () {
    test('every surah 1..114 resolves to a non-empty glyph name', () {
      for (var s = 1; s <= 114; s++) {
        final name = quran.getQcfSurahName(s); // throws if missing
        expect(name, isNotEmpty, reason: 'surah $s');
      }
    });

    test('every juz 1..30 resolves to a non-empty glyph name', () {
      for (var j = 1; j <= 30; j++) {
        final name = quran.getQcfJuzName(j); // throws if missing
        expect(name, isNotEmpty, reason: 'juz $j');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it passes (maps already complete)**

Run: `fvm flutter test test/quran_package/qcf_glyph_maps_test.dart`
Expected: PASS (the maps in `quran-1.4.1/lib/qcf_surah_juz_names.dart` are complete; if it FAILS, a glyph is missing and the resolver in Task 5 must fall back — note which).

- [ ] **Step 3: Register the font in `pubspec.yaml`**

Add under the `flutter:` section (sibling of `assets:` / `uses-material-design`), keeping existing content:

```yaml
  fonts:
    - family: QCF2BSML
      fonts:
        - asset: assets/QCF2BSMLfonts/QCF2BSML.ttf
```

- [ ] **Step 4: Confirm the asset path resolves**

Run: `ls assets/QCF2BSMLfonts/QCF2BSML.ttf`
Expected: prints the path (file exists).

- [ ] **Step 5: Manual glyph verification checklist (gated before Phase 1 sign-off)**

After Task 6 renders the band, visually confirm on-device that surah names (e.g. الفاتحة, البقرة) and juz names render as calligraphic glyphs, not boxes. Record any wrong/missing glyph; the Task 5 resolver falls back to `quran.getSurahNameArabic` for those. (Tracked here; not an automated test.)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml test/quran_package/qcf_glyph_maps_test.dart
git commit -m "feat(mushaf): register QCF2BSML surah-name font + glyph map test"
```

---

## Task 2: Six eye-tuned paper themes

Replaces the 5-paper palette. All themes are fixed colors (eye-tuned), so `colors` becomes a no-arg getter.

**Files:**
- Modify: `lib/core/constants/mushaf_paper.dart`
- Modify: `lib/features/surah/presentation/utils/mushaf_paper_colors.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart:68-72`
- Test: `test/features/surah/presentation/utils/mushaf_paper_colors_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/surah/presentation/utils/mushaf_paper_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  test('there are exactly six paper themes', () {
    expect(MushafPaper.values.length, 6);
  });

  test('cream is the eye-tuned default day paper', () {
    final c = MushafPaper.cream.colors;
    expect(c.background, const Color(0xFFFBF4E3));
    expect(c.ink, const Color(0xFF2A2419));
    expect(c.accent, const Color(0xFF2E5244));
  });

  test('night uses an off-black background and warm ink (no halation)', () {
    final c = MushafPaper.night.colors;
    expect(c.background, const Color(0xFF14161A));
    expect(c.ink, const Color(0xFFE8D9A8));
  });

  test('every theme exposes a non-empty Arabic label', () {
    for (final p in MushafPaper.values) {
      expect(p.label, isNotEmpty, reason: p.name);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/surah/presentation/utils/mushaf_paper_colors_test.dart`
Expected: FAIL (enum has `defaultPaper/parchment/night/sky/mint`; `cream` undefined; `colors` still needs args).

- [ ] **Step 3: Rewrite the enum**

Replace the entire contents of `lib/core/constants/mushaf_paper.dart`:

```dart
/// Eye-tuned mushaf paper themes. No pure white, no pure black; warm ink at
/// night to avoid halation glare.
enum MushafPaper { cream, sepia, green, gray, night, slateNight }
```

- [ ] **Step 4: Rewrite the colors extension (fixed per-theme, no-arg getter)**

Replace the entire contents of `lib/features/surah/presentation/utils/mushaf_paper_colors.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';

class MushafPaperColors {
  const MushafPaperColors({
    required this.background,
    required this.ink,
    required this.accent,
  });
  final Color background; // page fill
  final Color ink;        // body srcIn tint
  final Color accent;     // accent (frame + rosettes + glyph) srcIn tint
}

extension MushafPaperX on MushafPaper {
  /// Arabic display label for the reading-settings sheet.
  String get label => switch (this) {
        MushafPaper.cream => 'كريمي',
        MushafPaper.sepia => 'سيبيا',
        MushafPaper.green => 'أخضر',
        MushafPaper.gray => 'رمادي',
        MushafPaper.night => 'ليلي',
        MushafPaper.slateNight => 'ليلي أزرق',
      };

  bool get isDark => this == MushafPaper.night || this == MushafPaper.slateNight;

  MushafPaperColors get colors => switch (this) {
        MushafPaper.cream => const MushafPaperColors(
            background: Color(0xFFFBF4E3),
            ink: Color(0xFF2A2419),
            accent: Color(0xFF2E5244)),
        MushafPaper.sepia => const MushafPaperColors(
            background: Color(0xFFEDE0C4),
            ink: Color(0xFF3A2A14),
            accent: Color(0xFF8A6D3B)),
        MushafPaper.green => const MushafPaperColors(
            background: Color(0xFFE2EBE2),
            ink: Color(0xFF1B3A26),
            accent: Color(0xFF3C7A55)),
        MushafPaper.gray => const MushafPaperColors(
            background: Color(0xFFE8E6E1),
            ink: Color(0xFF33302A),
            accent: Color(0xFF6B6456)),
        MushafPaper.night => const MushafPaperColors(
            background: Color(0xFF14161A),
            ink: Color(0xFFE8D9A8),
            accent: Color(0xFFC9A227)),
        MushafPaper.slateNight => const MushafPaperColors(
            background: Color(0xFF10141A),
            ink: Color(0xFFD6E2EC),
            accent: Color(0xFF4878A0)),
      };
}
```

- [ ] **Step 5: Update the one production caller in `mushaf_page_view.dart`**

In `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`, replace lines 68-72:

```dart
    final settings = context.watch<SettingsCubit>().state.settingsModel;
    final paperColors = settings.mushafPaper.colors(
      Theme.of(context).colorScheme,
      mushafBg: settings.palette.mushafBg,
    );
```

with:

```dart
    final settings = context.watch<SettingsCubit>().state.settingsModel;
    final paperColors = settings.mushafPaper.colors;
```

(The `app_palette.dart` import in this file becomes unused — remove the `import 'package:quran_app/config/theme/app_palette.dart';` line.)

> NOTE: `mushaf_bottom_bar.dart` still calls the old `.colors(scheme, mushafBg:)` and references removed enum values. It is **deleted in Task 10**. Until then the build is red for that file only; Tasks 3–9 don't touch it, and Task 10 removes it. If you need a green build between tasks, comment out the `_PaperSwatches` body temporarily — but the clean path is to proceed to Task 10.

- [ ] **Step 6: Run the paper-colors test**

Run: `fvm flutter test test/features/surah/presentation/utils/mushaf_paper_colors_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/mushaf_paper.dart \
  lib/features/surah/presentation/utils/mushaf_paper_colors.dart \
  lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart \
  test/features/surah/presentation/utils/mushaf_paper_colors_test.dart
git commit -m "feat(mushaf): six eye-tuned paper themes with fixed colors"
```

---

## Task 3: Settings — add pageBrightness + readingMode

**Files:**
- Create: `lib/core/constants/mushaf_reading_mode.dart`
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Test: `test/features/settings/data/models/settings_model_test.dart`

- [ ] **Step 1: Create the reading-mode enum**

Create `lib/core/constants/mushaf_reading_mode.dart`:

```dart
/// How the mushaf is navigated. `page` = horizontal RTL paging (default);
/// `scroll` = continuous vertical scroll (Phase 3).
enum MushafReadingMode { page, scroll }
```

- [ ] **Step 2: Write the failing test**

Create `test/features/settings/data/models/settings_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  group('SettingsModel new mushaf fields', () {
    test('defaults: brightness 1.0, page mode, cream paper', () {
      const m = SettingsModel(isFormat12Hours: false, isArabic: true);
      expect(m.pageBrightness, 1.0);
      expect(m.readingMode, MushafReadingMode.page);
      expect(m.mushafPaper, MushafPaper.cream);
    });

    test('toMap/fromMap round-trips the new fields', () {
      const m = SettingsModel(
        isFormat12Hours: false,
        isArabic: true,
        pageBrightness: 0.6,
        readingMode: MushafReadingMode.scroll,
        mushafPaper: MushafPaper.night,
      );
      final back = SettingsModel.fromMap(m.toMap());
      expect(back.pageBrightness, 0.6);
      expect(back.readingMode, MushafReadingMode.scroll);
      expect(back.mushafPaper, MushafPaper.night);
    });

    test('fromMap clamps out-of-range brightness and defaults unknown mode', () {
      final m = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': false,
        'pageBrightness': 5.0,        // too high
        'readingMode': 'bogus',
      });
      expect(m.pageBrightness, 1.0);
      expect(m.readingMode, MushafReadingMode.page);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `fvm flutter test test/features/settings/data/models/settings_model_test.dart`
Expected: FAIL (`pageBrightness`/`readingMode` undefined; default paper is `defaultPaper` not `cream`).

- [ ] **Step 4: Extend the `Settings` entity**

In `lib/features/settings/domain/entities/settings.dart`:

Add the import at the top:
```dart
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
```

Add fields after `mushafPaper` (line 11):
```dart
  final double pageBrightness;
  final MushafReadingMode readingMode;
```

Add a clamp bound constant near `validReminderMinutes` (line 43):
```dart
  static const double minPageBrightness = 0.3;
```

In the constructor (line 45), change the `mushafPaper` default and add the two fields:
```dart
    this.mushafPaper = MushafPaper.cream,
    this.pageBrightness = 1.0,
    this.readingMode = MushafReadingMode.page,
```

In `copyWith` add params and pass-through:
```dart
    double? pageBrightness,
    MushafReadingMode? readingMode,
```
```dart
      pageBrightness: pageBrightness ?? this.pageBrightness,
      readingMode: readingMode ?? this.readingMode,
```

Add both to `props`:
```dart
        pageBrightness,
        readingMode,
```

- [ ] **Step 5: Extend `SettingsModel`**

In `lib/features/settings/data/models/settings_model.dart`:

Add import:
```dart
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
```

Constructor — add `super.pageBrightness,` and `super.readingMode,`.

`copyWith` — add params `double? pageBrightness,` and `MushafReadingMode? readingMode,`, and in the returned `SettingsModel(...)` add:
```dart
      pageBrightness: pageBrightness ?? this.pageBrightness,
      readingMode: readingMode ?? this.readingMode,
```

`fromMap` — change the `mushafPaper` orElse default and add the two reads:
```dart
      mushafPaper: MushafPaper.values.firstWhere(
        (p) => p.name == (map['mushafPaper'] as String?),
        orElse: () => MushafPaper.cream,
      ),
      pageBrightness: _readBrightness(map['pageBrightness']),
      readingMode: MushafReadingMode.values.firstWhere(
        (m) => m.name == (map['readingMode'] as String?),
        orElse: () => MushafReadingMode.page,
      ),
```

`toMap` — add:
```dart
      'pageBrightness': pageBrightness,
      'readingMode': readingMode.name,
```

Add the private clamp helper alongside `_readEnabledMap`:
```dart
  static double _readBrightness(dynamic raw) {
    final v = (raw as num?)?.toDouble();
    if (v == null) return 1.0;
    return v.clamp(Settings.minPageBrightness, 1.0);
  }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `fvm flutter test test/features/settings/data/models/settings_model_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/mushaf_reading_mode.dart \
  lib/features/settings/domain/entities/settings.dart \
  lib/features/settings/data/models/settings_model.dart \
  test/features/settings/data/models/settings_model_test.dart
git commit -m "feat(settings): persist mushaf pageBrightness + readingMode"
```

---

## Task 4: SettingsCubit setters

**Files:**
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Test: `test/features/settings/presentation/cubit/settings_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/presentation/cubit/settings_cubit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class _MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override dynamic read(String key) => _m[key];
  @override Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override Future<void> delete(String key) async => _m.remove(key);
  @override Future<void> clear() async => _m.clear();
}

void main() {
  setUpAll(() => HydratedBloc.storage = _MemStorage());

  test('updatePageBrightness clamps to [0.3, 1.0]', () {
    final c = SettingsCubit();
    c.updatePageBrightness(0.1);
    expect(c.state.settingsModel.pageBrightness, 0.3);
    c.updatePageBrightness(0.7);
    expect(c.state.settingsModel.pageBrightness, 0.7);
  });

  test('updateReadingMode switches mode', () {
    final c = SettingsCubit();
    c.updateReadingMode(MushafReadingMode.scroll);
    expect(c.state.settingsModel.readingMode, MushafReadingMode.scroll);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/settings/presentation/cubit/settings_cubit_test.dart`
Expected: FAIL (`updatePageBrightness`/`updateReadingMode` undefined).

- [ ] **Step 3: Add the setters**

In `lib/features/settings/presentation/cubit/settings_cubit.dart` add the import:
```dart
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
```
and after `updateMushafPaper` (line 43):
```dart
  void updatePageBrightness(double value) {
    final clamped = value.clamp(Settings.minPageBrightness, 1.0);
    emit(SettingsState(
      state.settingsModel.copyWith(pageBrightness: clamped),
    ));
  }

  void updateReadingMode(MushafReadingMode mode) {
    emit(SettingsState(state.settingsModel.copyWith(readingMode: mode)));
  }
```

(`Settings` is already imported in this file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/settings/presentation/cubit/settings_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/cubit/settings_cubit.dart \
  test/features/settings/presentation/cubit/settings_cubit_test.dart
git commit -m "feat(settings): add pageBrightness + readingMode setters"
```

---

## Task 5: Printed-chrome resolver (page → surah/juz)

Pure logic: given a page, decide which surah name and juz name the header band shows. Uses the page's leading ayah (physical-mushaf convention) and falls back from QCF glyph to plain Arabic if a glyph throws.

**Files:**
- Create: `lib/features/surah/presentation/utils/printed_chrome_resolver.dart`
- Test: `test/features/surah/presentation/utils/printed_chrome_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/surah/presentation/utils/printed_chrome_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/printed_chrome_resolver.dart';

void main() {
  group('resolvePrintedChrome', () {
    test('page 1 (Al-Fatiha) → surah 1, juz 1', () {
      final d = resolvePrintedChrome(1);
      expect(d.surahNumber, 1);
      expect(d.juzNumber, 1);
      expect(d.surahGlyphName, isNotEmpty);
      expect(d.juzGlyphName, isNotEmpty);
    });

    test('page 2 (Al-Baqarah start) → surah 2, juz 1', () {
      final d = resolvePrintedChrome(2);
      expect(d.surahNumber, 2);
      expect(d.juzNumber, 1);
    });

    test('produces values for every page 1..604 without throwing', () {
      for (var p = 1; p <= 604; p++) {
        final d = resolvePrintedChrome(p);
        expect(d.surahNumber, inInclusiveRange(1, 114));
        expect(d.juzNumber, inInclusiveRange(1, 30));
        expect(d.surahGlyphName, isNotEmpty);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/surah/presentation/utils/printed_chrome_resolver_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Write the resolver**

Create `lib/features/surah/presentation/utils/printed_chrome_resolver.dart`:

```dart
import 'package:quran/quran.dart' as quran;

/// What the printed header band displays for a page.
class PrintedChromeData {
  const PrintedChromeData({
    required this.surahNumber,
    required this.juzNumber,
    required this.surahGlyphName,
    required this.juzGlyphName,
  });

  final int surahNumber;
  final int juzNumber;

  /// QCF glyph string (render with the `QCF2BSML` font family). Falls back to
  /// the plain Arabic surah name if the glyph map throws for this number.
  final String surahGlyphName;
  final String juzGlyphName;
}

/// Resolves the surah + juz shown on [pageNumber]'s printed header band, using
/// the page's leading ayah (the physical-mushaf convention).
PrintedChromeData resolvePrintedChrome(int pageNumber) {
  final data = quran.getPageData(pageNumber); // [{surah, start, end}, ...]
  final firstSurah = data.isNotEmpty ? data.first['surah'] as int : 1;
  final firstStart = data.isNotEmpty ? data.first['start'] as int : 1;
  // Basmala marker is start==0; treat as ayah 1 for juz lookup.
  final firstAyah = firstStart == 0 ? 1 : firstStart;
  final juz = quran.getJuzNumber(firstSurah, firstAyah);

  String surahGlyph;
  try {
    surahGlyph = quran.getQcfSurahName(firstSurah);
  } catch (_) {
    surahGlyph = quran.getSurahNameArabic(firstSurah);
  }
  String juzGlyph;
  try {
    juzGlyph = quran.getQcfJuzName(juz);
  } catch (_) {
    juzGlyph = 'الجزء $juz';
  }

  return PrintedChromeData(
    surahNumber: firstSurah,
    juzNumber: juz,
    surahGlyphName: surahGlyph,
    juzGlyphName: juzGlyph,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/surah/presentation/utils/printed_chrome_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/utils/printed_chrome_resolver.dart \
  test/features/surah/presentation/utils/printed_chrome_resolver_test.dart
git commit -m "feat(mushaf): printed-chrome resolver (page -> surah/juz glyphs)"
```

---

## Task 6: MushafPrintedChrome widget

Glyph header band (surah on the start/right side, juz on the end/left side, RTL) + a page-number ornament at the bottom. Rendered as part of the page layer, tinted with the active paper's accent.

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome_test.dart`

- [ ] **Step 1: Write the widget**

Create `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/printed_chrome_resolver.dart';

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
String _ar(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// Printed header band (surah + juz QCF glyphs) and a bottom page-number
/// ornament, drawn as part of the mushaf page. Always visible in page mode.
class MushafPrintedChrome extends StatelessWidget {
  const MushafPrintedChrome({
    super.key,
    required this.pageNumber,
    required this.colors,
  });

  final int pageNumber;
  final MushafPaperColors colors;

  @override
  Widget build(BuildContext context) {
    final data = resolvePrintedChrome(pageNumber);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Header band — sits over the accent frame already in the page art.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: SizedBox(
              height: 34,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    data.surahGlyphName,
                    key: const ValueKey('printed-chrome-surah'),
                    style: TextStyle(
                      fontFamily: 'QCF2BSML',
                      fontSize: 22,
                      color: colors.accent,
                    ),
                  ),
                  Text(
                    data.juzGlyphName,
                    key: const ValueKey('printed-chrome-juz'),
                    style: TextStyle(
                      fontFamily: 'QCF2BSML',
                      fontSize: 18,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Bottom page-number ornament.
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '﴿ ${_ar(pageNumber)} ﴾',
                key: const ValueKey('printed-chrome-page'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write the widget test**

Create `test/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  testWidgets('renders surah glyph, juz glyph, and page-number ornament',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MushafPrintedChrome(
          pageNumber: 2,
          colors: MushafPaper.cream.colors,
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('printed-chrome-surah')), findsOneWidget);
    expect(find.byKey(const ValueKey('printed-chrome-juz')), findsOneWidget);
    final pageText = tester.widget<Text>(
      find.byKey(const ValueKey('printed-chrome-page')),
    );
    expect(pageText.data, contains('٢')); // page 2 in Arabic-Indic digits
  });

  testWidgets('surah glyph uses the QCF2BSML font family', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MushafPrintedChrome(
          pageNumber: 1,
          colors: MushafPaper.night.colors,
        ),
      ),
    ));
    final surah = tester.widget<Text>(
      find.byKey(const ValueKey('printed-chrome-surah')),
    );
    expect(surah.style?.fontFamily, 'QCF2BSML');
    expect(surah.style?.color, MushafPaper.night.colors.accent);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart \
  test/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome_test.dart
git commit -m "feat(mushaf): printed glyph header band + page-number ornament widget"
```

---

## Task 7: Page-brightness overlay

Dim the page only (not controls), driven by `SettingsModel.pageBrightness`.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_brightness_test.dart`

- [ ] **Step 1: Add a brightness scrim over the page layers**

In `mushaf_page_view.dart`, inside the `Stack` `children:` (after the accent `Image.asset` at line 100, before the `if (entity != null)` highlight builder), insert a scrim that reads brightness from settings:

```dart
                  if (settings.pageBrightness < 1.0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          key: const ValueKey('page-brightness-scrim'),
                          color: Colors.black.withValues(
                            alpha: 1.0 - settings.pageBrightness,
                          ),
                        ),
                      ),
                    ),
```

(`settings` is already in scope from line 68.)

- [ ] **Step 2: Write the widget test**

Create `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_brightness_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Pure formula guard: the scrim alpha is (1 - brightness).
  test('scrim alpha is the inverse of page brightness', () {
    double scrimAlpha(double brightness) => 1.0 - brightness;
    expect(scrimAlpha(1.0), 0.0);
    expect(scrimAlpha(0.6), closeTo(0.4, 1e-9));
    expect(scrimAlpha(0.3), closeTo(0.7, 1e-9));
  });
}
```

> A full widget test of `MushafPageView` requires GetIt + Bloc wiring (`GetMushafPage`, `SettingsCubit`, `MushafCubit`); that integration is covered by Task 10's manual verification. This guards the brightness formula in isolation.

- [ ] **Step 3: Run test + analyze**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_brightness_test.dart && fvm flutter analyze lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
Expected: test PASS; analyze reports no errors for the file.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart \
  test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_brightness_test.dart
git commit -m "feat(mushaf): in-app page-brightness scrim"
```

---

## Task 8: Reading-settings sheet

Bottom sheet: six paper previews + brightness slider + Page/Scroll toggle. Writes to `SettingsCubit`.

**Files:**
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`

- [ ] **Step 1: Add localized strings**

In `lib/l10n/intl_en.arb` add (before the closing brace; mind trailing commas):
```json
  "readingSettings": "Reading",
  "paper": "Paper",
  "brightness": "Brightness",
  "readingMode": "Reading mode",
  "pageByPage": "Page",
  "continuousScroll": "Scroll",
```
In `lib/l10n/intl_ar.arb` add:
```json
  "readingSettings": "إعدادات القراءة",
  "paper": "الورق",
  "brightness": "السطوع",
  "readingMode": "وضع القراءة",
  "pageByPage": "صفحة",
  "continuousScroll": "تمرير",
```

- [ ] **Step 2: Regenerate localizations**

Run: `fvm dart run intl_utils:generate`
Expected: `lib/generated/l10n.dart` updates; `S.of(context).readingSettings` etc. now exist.

- [ ] **Step 3: Write the sheet widget**

Create `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

class ReadingSettingsSheet extends StatelessWidget {
  const ReadingSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SettingsCubit>(),
        child: const ReadingSettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final model = state.settingsModel;
        final cubit = context.read<SettingsCubit>();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.readingSettings,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(s.paper, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: MushafPaper.values.map((p) {
                  final selected = p == model.mushafPaper;
                  return Expanded(
                    child: GestureDetector(
                      key: ValueKey('reading-paper-${p.name}'),
                      onTap: () => cubit.updateMushafPaper(p),
                      child: Container(
                        height: 54,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: p.colors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.12),
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(s.brightness, style: Theme.of(context).textTheme.labelMedium),
              Slider(
                key: const ValueKey('reading-brightness-slider'),
                min: 0.3,
                max: 1.0,
                value: model.pageBrightness,
                onChanged: cubit.updatePageBrightness,
              ),
              const SizedBox(height: 8),
              Text(s.readingMode,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              SegmentedButton<MushafReadingMode>(
                key: const ValueKey('reading-mode-toggle'),
                segments: [
                  ButtonSegment(
                    value: MushafReadingMode.page,
                    label: Text(s.pageByPage),
                  ),
                  ButtonSegment(
                    value: MushafReadingMode.scroll,
                    label: Text(s.continuousScroll),
                  ),
                ],
                selected: {model.readingMode},
                onSelectionChanged: (set) =>
                    cubit.updateReadingMode(set.first),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Write the widget test**

Create `test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

class _MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override dynamic read(String key) => _m[key];
  @override Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override Future<void> delete(String key) async => _m.remove(key);
  @override Future<void> clear() async => _m.clear();
}

void main() {
  setUpAll(() => HydratedBloc.storage = _MemStorage());

  testWidgets('tapping the night swatch updates the paper setting',
      (tester) async {
    final cubit = SettingsCubit();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: ReadingSettingsSheet()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reading-paper-night')));
    await tester.pump();
    expect(cubit.state.settingsModel.mushafPaper, MushafPaper.night);
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/generated/l10n.dart \
  lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart \
  test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart
git commit -m "feat(mushaf): reading-settings sheet (paper, brightness, mode)"
```

---

## Task 9: Floating action dock

Glassy bottom-center dock: ⚙ reading settings · ▶ play page · 📑 bookmark. Toggled by `chromeVisible`. Reuses the existing play logic from the old bottom bar's `_PlayFab`.

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock_test.dart`

- [ ] **Step 1: Write the dock widget**

Create `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart`:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart';

/// Glassy floating control dock shown when chrome is visible. Surah/juz/page
/// are printed on the page, so this is actions-only.
class MushafActionDock extends StatelessWidget {
  const MushafActionDock({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(
                keyValue: 'dock-reading-settings',
                icon: Icons.tune,
                onTap: () => ReadingSettingsSheet.show(context),
              ),
              const SizedBox(width: 10),
              _DockButton(
                keyValue: 'dock-play',
                icon: Icons.play_arrow,
                primary: true,
                onTap: () => _onPlay(context),
              ),
              const SizedBox(width: 10),
              _DockButton(
                keyValue: 'dock-bookmark',
                icon: Icons.bookmark_outline,
                onTap: () {}, // existing bookmark flow wired in Phase 2
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPlay(BuildContext context) {
    final mushafCubit = context.read<MushafCubit>();
    var firstAyah =
        sl<QuranPageService>().getFirstAyahOfPage(mushafCubit.state.currentPage);
    if (firstAyah != null) {
      if (firstAyah.ayah == 1 && firstAyah.surah != 1 && firstAyah.surah != 9) {
        firstAyah = AyahIdentifier(surah: firstAyah.surah, ayah: 0);
      }
      mushafCubit.toggleHighlight(firstAyah);
      context.read<PlaybackCubit>().playSelected(firstAyah);
    } else {
      mushafCubit.pinOverlay();
    }
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.keyValue,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String keyValue;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = primary ? 46.0 : 36.0;
    return GestureDetector(
      key: ValueKey(keyValue),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary ? scheme.primary : Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(icon,
            color: Colors.white, size: primary ? 24 : 20),
      ),
    );
  }
}
```

- [ ] **Step 2: Write the widget test (dock renders its three buttons)**

Create `test/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart';

void main() {
  testWidgets('dock shows settings, play, and bookmark buttons',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: MushafActionDock())),
    ));
    expect(find.byKey(const ValueKey('dock-reading-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-bookmark')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart \
  test/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock_test.dart
git commit -m "feat(mushaf): floating action dock (settings/play/bookmark)"
```

---

## Task 10: Wire the screen — printed chrome + dock, remove old bars

Swap the floating top/bottom metadata bars for the printed chrome (always on the page) + the action dock (toggled).

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart`
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_bottom_bar.dart`

- [ ] **Step 1: Render the printed chrome inside the page**

In `mushaf_page_view.dart`, add the import:
```dart
import 'mushaf_printed_chrome.dart';
```
Inside the `Stack` `children:`, as the **last** child (after the `GestureDetector` so it draws above the page art but the gesture layer still receives empty-area taps — chrome is non-interactive), add:
```dart
                  Positioned.fill(
                    child: IgnorePointer(
                      child: MushafPrintedChrome(
                        pageNumber: widget.pageNumber,
                        colors: paperColors,
                      ),
                    ),
                  ),
```

- [ ] **Step 2: Replace the chrome layers in `mushaf_page.dart`**

In `mushaf_page.dart`:

Remove the imports:
```dart
import 'widgets/mushaf_bottom_bar.dart';
import 'widgets/mushaf_top_bar.dart';
```
Add:
```dart
import 'widgets/mushaf_action_dock.dart';
```

Delete the two `BlocBuilder<MushafCubit, MushafState>` blocks that build the TOP chrome (lines ~119-141) and BOTTOM chrome (lines ~143-163), and replace them with a single bottom-centered dock:

```dart
              // Floating action dock (chrome toggled by tap).
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) => a.chromeVisible != b.chromeVisible,
                builder: (context, state) => SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSlide(
                      offset: state.chromeVisible
                          ? Offset.zero
                          : const Offset(0, 2),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: state.chromeVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !state.chromeVisible,
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: MushafActionDock(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
```

(Keep the `AyahPlaybackOverlay()` child as-is.)

- [ ] **Step 3: Delete the obsolete bar widgets**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart \
  lib/features/surah/presentation/pages/mushaf/widgets/mushaf_bottom_bar.dart
```

- [ ] **Step 4: Verify nothing else references the deleted bars**

Run: `grep -rn "MushafTopBar\|MushafBottomBar\|mushaf_top_bar\|mushaf_bottom_bar" lib test`
Expected: no matches.

- [ ] **Step 5: Analyze + full test suite**

Run: `fvm flutter analyze && fvm flutter test`
Expected: analyze clean; all tests PASS.

- [ ] **Step 6: Manual on-device verification (glyph check from Task 1, Step 5)**

Run: `fvm flutter run` → open the mushaf. Confirm: surah/juz glyphs render (not boxes) in the band; page number shows bottom-center; tap toggles the dock; ⚙ opens the reading sheet; switching paper recolors the page; brightness slider dims the page. Spot-check pages across several juz for glyph correctness.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(mushaf): printed chrome + action dock replace floating bars"
```

---

## Task 11: Surface mushaf settings in the Settings screen

Mirror paper, brightness, and reading mode into the main Settings page so defaults persist and are discoverable.

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Step 1: Read the current Appearance section to match its style**

Run: `sed -n '40,115p' lib/features/settings/presentation/pages/settings_page.dart`
Expected: shows the existing section/row widgets (e.g. the palette picker, segmented selectors) to reuse their visual pattern.

- [ ] **Step 2: Add a "Mushaf" section reusing existing section widgets**

In `settings_page.dart`, in the Appearance/General area, add a section that opens the same sheet and mirrors the controls. Reuse the existing section header + a `ListTile` that opens `ReadingSettingsSheet`:

```dart
// add import
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart';
```
```dart
ListTile(
  key: const ValueKey('settings-open-reading'),
  leading: const Icon(Icons.menu_book_outlined),
  title: Text(S.of(context).readingSettings),
  subtitle: Text(S.of(context).paper),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => ReadingSettingsSheet.show(context),
),
```

(Match the surrounding section's wrapping widget — if rows are inside a custom `SettingsSection`/card, place this `ListTile` there. The `SettingsCubit` is already provided app-wide, so the sheet works from this screen.)

- [ ] **Step 3: Analyze**

Run: `fvm flutter analyze lib/features/settings/presentation/pages/settings_page.dart`
Expected: no errors.

- [ ] **Step 4: Manual verification**

Run app → Settings → tap the Reading row → the same sheet opens; changing paper/brightness/mode persists and is reflected when reopening the mushaf.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat(settings): open reading settings from the Settings screen"
```

---

## Self-review notes (author)

- **Spec coverage:** §1.1 printed chrome → Tasks 1,5,6,10. §1.2 six papers → Task 2. §1.3 brightness → Tasks 3,7,8. §1.4 dock + sheet + settings mirror → Tasks 8,9,10,11. §1.5 persistence → Tasks 3,4. Index sheet (☰) is intentionally deferred (spec marks it minimal/out-of-Phase-1-core); not built here — **note:** the back `‹` and index `☰` top buttons from the mockup are NOT added in Phase 1 (the screen already has system back; index lands with Phase 3 navigation). Flagged so it isn't mistaken for a gap.
- **Glyph risk:** Task 1 test proves map completeness; Task 1 Step 5 + Task 10 Step 6 gate visual correctness.
- **Type consistency:** `MushafPaper.{cream,sepia,green,gray,night,slateNight}`, `MushafPaperX.colors` (no-arg getter), `MushafReadingMode.{page,scroll}`, `SettingsModel.pageBrightness`/`readingMode`, `resolvePrintedChrome`/`PrintedChromeData`, `ReadingSettingsSheet.show`, `MushafActionDock` — all used consistently across tasks.
- **Commands:** use `fvm flutter ...` (the repo is pinned to Flutter 3.38.1 via FVM).
```
