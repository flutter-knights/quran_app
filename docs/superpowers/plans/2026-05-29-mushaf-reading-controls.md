# Mushaf Reading Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tap-toggled top/bottom chrome, mushaf-only paper color themes, juz/hizb/rub metadata, an ayah long-press popover (replacing the bottom sheet), and a reciter control in the playback overlay.

**Architecture:** Approach 1 — extend existing cubits. Chrome state in `MushafCubit`; paper theme persisted on the Hydrated `SettingsCubit`; juz/hizb/rub from a new `QuranMetaService`; the two `srcIn` page layers + background tinted from the active paper. Clean Architecture + `flutter_bloc` cubits + `GetIt` DI, matching existing patterns.

**Tech Stack:** Flutter, flutter_bloc (Cubit/HydratedCubit), GetIt (`sl`), `quran` package, `share_plus`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-05-29-mushaf-reading-controls-design.md`

**Conventions:** Run all tests with `flutter test <path>`. Commit after each task. Run `flutter analyze <changed paths>` before each commit. End commit messages with the Co-Authored-By line.

---

### Task 1: `MushafPaper` enum + paper colors

**Files:**
- Create: `lib/core/constants/mushaf_paper.dart`
- Create: `lib/features/surah/presentation/utils/mushaf_paper_colors.dart`
- Test: `test/features/surah/presentation/utils/mushaf_paper_colors_test.dart`

- [ ] **Step 1: Create the enum** (pure Dart, no Flutter import)

```dart
// lib/core/constants/mushaf_paper.dart
enum MushafPaper { defaultPaper, parchment, night, sky, mint }
```

- [ ] **Step 2: Write the failing test**

```dart
// test/features/surah/presentation/utils/mushaf_paper_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  const scheme = ColorScheme.light(
    surface: Color(0xFFF4F4F4),
    onSurface: Color(0xFF141414),
    secondary: Color(0xFF5C8070),
  );

  test('parchment has fixed colors', () {
    final c = MushafPaper.parchment.colors(scheme, mushafBg: const Color(0xFFFFFCF5));
    expect(c.background, const Color(0xFFF0E6D2));
    expect(c.ink, const Color(0xFF3A2A14));
    expect(c.accent, const Color(0xFF8A6D3B));
  });

  test('default follows the app scheme + mushaf bg', () {
    final c = MushafPaper.defaultPaper.colors(scheme, mushafBg: const Color(0xFFFFFCF5));
    expect(c.background, const Color(0xFFFFFCF5));
    expect(c.ink, scheme.onSurface);
    expect(c.accent, scheme.secondary);
  });
}
```

- [ ] **Step 3: Run it, expect FAIL** — `flutter test test/features/surah/presentation/utils/mushaf_paper_colors_test.dart` → fails (no `colors`).

- [ ] **Step 4: Implement the extension**

```dart
// lib/features/surah/presentation/utils/mushaf_paper_colors.dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';

class MushafPaperColors {
  const MushafPaperColors({required this.background, required this.ink, required this.accent});
  final Color background; // page fill
  final Color ink;        // body srcIn tint
  final Color accent;     // accent (frame + rosettes) srcIn tint
}

extension MushafPaperX on MushafPaper {
  /// Arabic display label for the bottom-bar swatch tooltip.
  String get label => switch (this) {
        MushafPaper.defaultPaper => 'افتراضي',
        MushafPaper.parchment => 'رق',
        MushafPaper.night => 'ليلي',
        MushafPaper.sky => 'سماوي',
        MushafPaper.mint => 'نعناعي',
      };

  MushafPaperColors colors(ColorScheme scheme, {required Color mushafBg}) {
    switch (this) {
      case MushafPaper.defaultPaper:
        return MushafPaperColors(background: mushafBg, ink: scheme.onSurface, accent: scheme.secondary);
      case MushafPaper.parchment:
        return const MushafPaperColors(background: Color(0xFFF0E6D2), ink: Color(0xFF3A2A14), accent: Color(0xFF8A6D3B));
      case MushafPaper.night:
        return const MushafPaperColors(background: Color(0xFF0D0F12), ink: Color(0xFFE8D9A8), accent: Color(0xFFC9A227));
      case MushafPaper.sky:
        return const MushafPaperColors(background: Color(0xFFEAF1F7), ink: Color(0xFF1A3550), accent: Color(0xFF3C6E9E));
      case MushafPaper.mint:
        return const MushafPaperColors(background: Color(0xFFE4EDE4), ink: Color(0xFF1B3A26), accent: Color(0xFF3C7A55));
    }
  }
}
```

- [ ] **Step 5: Run test, expect PASS.**
- [ ] **Step 6: `flutter analyze` the two files; then commit** (`feat(mushaf): add MushafPaper enum + paper colors`).

---

### Task 2: Persist paper theme on Settings

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Test: `test/features/settings/data/models/settings_model_paper_test.dart`

- [ ] **Step 1: Failing test**

```dart
// test/features/settings/data/models/settings_model_paper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  test('mushafPaper round-trips through map', () {
    const m = SettingsModel(isArabic: true, isFormat12Hours: false, mushafPaper: MushafPaper.night);
    final back = SettingsModel.fromMap(m.toMap());
    expect(back.mushafPaper, MushafPaper.night);
  });

  test('missing mushafPaper defaults to defaultPaper', () {
    final back = SettingsModel.fromMap({'isArabic': true});
    expect(back.mushafPaper, MushafPaper.defaultPaper);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** (no `mushafPaper`).

- [ ] **Step 3: Add `mushafPaper` to `Settings`** — import `package:quran_app/core/constants/mushaf_paper.dart`; add field `final MushafPaper mushafPaper;`, constructor param `this.mushafPaper = MushafPaper.defaultPaper,`, `copyWith` param `MushafPaper? mushafPaper,` + `mushafPaper: mushafPaper ?? this.mushafPaper,`, and add `mushafPaper` to `props`.

- [ ] **Step 4: Add to `SettingsModel`** — import the enum; add `super.mushafPaper,` to constructor; add `MushafPaper? mushafPaper,` + `mushafPaper: mushafPaper ?? this.mushafPaper,` to `copyWith`; in `fromMap` add:

```dart
mushafPaper: MushafPaper.values.firstWhere(
  (p) => p.name == (map['mushafPaper'] as String?),
  orElse: () => MushafPaper.defaultPaper,
),
```

  and in `toMap` add `'mushafPaper': mushafPaper.name,`.

- [ ] **Step 5: Add cubit method**

```dart
// settings_cubit.dart — import the enum, then:
void updateMushafPaper(MushafPaper paper) {
  emit(SettingsState(state.settingsModel.copyWith(mushafPaper: paper)));
}
```

- [ ] **Step 6: Run test, expect PASS. Analyze. Commit** (`feat(settings): persist mushaf paper theme`).

---

### Task 3: Chrome state in MushafCubit

**Files:**
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Test: `test/features/surah/presentation/cubit/mushaf_chrome_test.dart`

- [ ] **Step 1: Failing test**

```dart
// test/features/surah/presentation/cubit/mushaf_chrome_test.dart
import 'package:flutter_test/flutter_test.dart';
// import MushafCubit + its deps; construct as the existing mushaf cubit tests do
// (see test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
//  for how MushafCubit/CurrentAyahNotifier are built in tests).

void main() {
  test('toggleChrome flips chromeVisible; default false', () {
    final cubit = /* build MushafCubit(initialPage: 1, ...) */;
    expect(cubit.state.chromeVisible, isFalse);
    cubit.toggleChrome();
    expect(cubit.state.chromeVisible, isTrue);
    cubit.setChrome(false);
    expect(cubit.state.chromeVisible, isFalse);
  });
}
```

> Note: mirror the existing MushafCubit construction from `mushaf_page_dispose_test.dart`. If that test fakes `CurrentAyahNotifier`, reuse the same fake.

- [ ] **Step 2: Run it, expect FAIL.**

- [ ] **Step 3: Add `chromeVisible` to `MushafState`** — add `final bool chromeVisible;`, constructor `this.chromeVisible = false,`, `copyWith` param `bool? chromeVisible,` + `chromeVisible: chromeVisible ?? this.chromeVisible,`, and add to `props`.

- [ ] **Step 4: Add cubit methods** (in `MushafCubit`):

```dart
void toggleChrome() => emit(state.copyWith(chromeVisible: !state.chromeVisible));
void setChrome(bool visible) => emit(state.copyWith(chromeVisible: visible));
```

- [ ] **Step 5: Run test, expect PASS. Analyze. Commit** (`feat(mushaf): chrome visibility state`).

---

### Task 4: QuranMetaService (juz / hizb / rub)

**Files:**
- Create: `lib/features/quran_playback/domain/services/quran_meta_service.dart`
- Modify: `lib/features/quran_playback/playback_di.dart` (register, near line 35)
- Test: `test/features/quran_playback/domain/services/quran_meta_service_test.dart`

> **Data sourcing (do this first):** the project has no hizb/rub data. Obtain the authoritative **240 rubʿ-al-hizb boundaries** (the `surah:ayah` that starts each quarter; quarter 1 = 1:1). Use a reliable open source (e.g. Tanzil quran-metadata / a well-known Quran metadata JSON) via WebFetch, OR a vetted constant list. **Validate before use:** exactly 240 entries, strictly increasing by absolute ayah order, entry 0 == (1,1), entry 1 == (2,142) (start of Juz 2 / Hizb 2), and every `ayah <= quran.getVerseCount(surah)`. If the data cannot be sourced/validated, STOP and report — do not ship guessed boundaries.

- [ ] **Step 1: Failing test** (spot-checks that must hold for the standard division)

```dart
// test/features/quran_playback/domain/services/quran_meta_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';

void main() {
  final svc = QuranMetaServiceImpl(pageService: QuranPageServiceImpl());

  test('page 1 → juz 1, hizb 1, rub 1', () {
    final m = svc.getPageMeta(1);
    expect(m.juz, 1);
    expect(m.hizb, 1);
    expect(m.rub, 1);
  });

  test('page 22 (start of Juz 2 / Hizb 3 region) → juz 2', () {
    expect(svc.getPageMeta(22).juz, 2);
  });

  test('hizb in 1..60 and rub in 1..4 for every page', () {
    for (var p = 1; p <= 604; p++) {
      final m = svc.getPageMeta(p);
      expect(m.hizb, inInclusiveRange(1, 60));
      expect(m.rub, inInclusiveRange(1, 4));
      expect(m.juz, inInclusiveRange(1, 30));
    }
  });
}
```

- [ ] **Step 2: Run it, expect FAIL.**

- [ ] **Step 3: Implement** (mirror the `QuranPageService` file layout: abstract + impl + const data in one domain/services file)

```dart
// quran_meta_service.dart
import 'package:quran/quran.dart' as quran;
import 'quran_page_service.dart';

class PageMeta {
  const PageMeta({required this.surah, required this.juz, required this.hizb, required this.rub});
  final int surah; // first surah on the page
  final int juz;   // 1..30
  final int hizb;  // 1..60
  final int rub;   // 1..4 within the hizb
}

abstract class QuranMetaService {
  PageMeta getPageMeta(int page);
}

class QuranMetaServiceImpl implements QuranMetaService {
  QuranMetaServiceImpl({required this.pageService});
  final QuranPageService pageService;

  @override
  PageMeta getPageMeta(int page) {
    final first = pageService.getFirstAyahOfPage(page);
    final surah = first?.surah ?? 1;
    final ayah = first?.ayah ?? 1;
    final abs = _absolute(surah, ayah);
    // quarterIndex 0..239: last boundary whose absolute position <= abs
    var q = 0;
    for (var i = 0; i < _rubBoundaries.length; i++) {
      if (_absolute(_rubBoundaries[i][0], _rubBoundaries[i][1]) <= abs) {
        q = i;
      } else {
        break;
      }
    }
    return PageMeta(
      surah: surah,
      juz: quran.getJuzNumber(surah, ayah),
      hizb: (q ~/ 4) + 1,
      rub: (q % 4) + 1,
    );
  }

  static int _absolute(int surah, int ayah) {
    var total = 0;
    for (var s = 1; s < surah; s++) {
      total += quran.getVerseCount(s);
    }
    return total + ayah;
  }

  // 240 [surah, ayah] quarter starts. SOURCED + VALIDATED per the note above.
  static const List<List<int>> _rubBoundaries = [
    [1, 1], [2, 26], /* … 240 validated entries … */
  ];
}
```

- [ ] **Step 4: Register in DI** — in `playback_di.dart` after the `QuranPageService` registration:

```dart
sl.registerLazySingleton<QuranMetaService>(
  () => QuranMetaServiceImpl(pageService: sl<QuranPageService>()),
);
```

  (add the import for `quran_meta_service.dart`).

- [ ] **Step 5: Run tests, expect PASS** (all 604 pages + spot-checks). If a spot-check fails, the boundary data is wrong — fix the data, not the test.
- [ ] **Step 6: Analyze. Commit** (`feat(quran): juz/hizb/rub page metadata service`).

---

### Task 5: Paper-driven page tints + gesture branching

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
- (depends on Task 1, 2, 3)

- [ ] **Step 1: Read the active paper colors.** In `MushafPageView.build`, resolve colors once:

```dart
final paper = context.watch<SettingsCubit>().state.settingsModel.mushafPaper;
final scheme = Theme.of(context).colorScheme;
// mushafBg: reuse the app palette's mushaf bg if exposed; else scheme.surface.
final paperColors = paper.colors(scheme, mushafBg: scheme.surface);
```

  (Import `SettingsCubit`, `mushaf_paper_colors.dart`. If a dedicated mushaf-bg color exists on the palette extension, use it; otherwise `scheme.surface` is the documented fallback.)

- [ ] **Step 2: Apply tints.** Replace the body `Image.asset` `color:` with `paperColors.ink`, the accent `Image.asset` `color:` with `paperColors.accent`, and wrap the `Stack` in a `ColoredBox(color: paperColors.background)` (or add a `Positioned.fill` background rect as the first Stack child). Replace the highlight/playing colors (`AyahHighlightPainter` args) to derive from `paperColors.accent` / `paperColors.ink` so highlights stay legible on every paper.

- [ ] **Step 3: Gesture branching.** Replace `_handleTap` so it reads `MushafCubit`:

```dart
void _handleTap(BuildContext context, Offset local, BoxConstraints c, List<AyahBoundEntity> ayahs) {
  final cubit = context.read<MushafCubit>();
  if (!cubit.state.chromeVisible) {
    cubit.setChrome(true);
    return;
  }
  final hit = _hitTest(local, c, ayahs);
  if (hit != null) {
    cubit.toggleHighlight(hit); // opens the playback overlay via existing plumbing
  } else {
    cubit.setChrome(false);
  }
}
```

- [ ] **Step 4:** Change `_handleLongPress` to call the popover (Task 6): `AyahActionPopover.show(context, hit, c, bound)` instead of `AyahLongPressSheet.show`. (Wire the exact call in Task 6.)

- [ ] **Step 5:** `flutter analyze`; run existing `mushaf_page_dispose_test.dart` + `ayah_playback_overlay_test.dart` to confirm no regression. Commit (`feat(mushaf): paper tints + tap-to-toggle chrome`).

---

### Task 6: Ayah action popover (replaces the bottom sheet)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart`
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` (import swap)
- Test: `test/features/surah/presentation/pages/mushaf/ayah_action_popover_test.dart`

- [ ] **Step 1: Failing placement test** — pure function for above/below choice:

```dart
// in the test, import the helper:
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart';
void main() {
  test('verse low on page → popover above', () {
    expect(popoverPlacement(verseCenterY: 0.8), PopoverPlacement.above);
  });
  test('verse high on page → popover below', () {
    expect(popoverPlacement(verseCenterY: 0.2), PopoverPlacement.below);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL.**

- [ ] **Step 3: Implement the popover** — an `OverlayEntry`-based card. Expose:

```dart
enum PopoverPlacement { above, below }
PopoverPlacement popoverPlacement({required double verseCenterY}) =>
    verseCenterY > 0.5 ? PopoverPlacement.above : PopoverPlacement.below;

class AyahActionPopover {
  static void show(BuildContext context, AyahIdentifier ayah, {
    required Offset anchorGlobal, required PopoverPlacement placement,
  }) { /* insert OverlayEntry with a Material card: bookmark (BookmarkCubit),
         share (share_plus), tafsir (coming-soon snackbar), translation
         (coming-soon snackbar). Dismiss on barrier tap. Reuse the action
         button + bookmark widgets/logic from the removed sheet. */ }
}
```

  Port the `_ActionButton`, `_BookmarkButton`, `_onShare`, and `_comingSoon` logic from `ayah_long_press_sheet.dart` (reuse `S.of(context)` strings `tafsir`, `translation`, `bookmark`, `share`, `coming_soon`, `share_failed`). **No reciter dropdown, no play.**

- [ ] **Step 4:** In `mushaf_page_view.dart` `_handleLongPress`, compute the verse's global anchor + `popoverPlacement(verseCenterY: bound.lines.first.y + ...)` and call `AyahActionPopover.show(...)`. Delete `ayah_long_press_sheet.dart` and its import.

- [ ] **Step 5:** Run placement test (PASS) + `flutter analyze`. Commit (`feat(mushaf): ayah action popover replaces long-press sheet`).

---

### Task 7: MushafTopBar

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart`
- (l10n) Modify: `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb` — add `juz_label`, `hizb_label`, `rub_label` (e.g. EN "Juz {n}", AR "الجزء {n}"; "Hizb {n}", "حزب {n}"; "Rubʿ {n}", "ربع {n}"). Then run `dart run intl_utils:generate`.

- [ ] **Step 1: Build the widget** — a flush, glassy top bar reading `QuranMetaService` + surah name:

```dart
// reads sl<QuranMetaService>().getPageMeta(page) and quran.getSurahNameArabic(surah)
// Layout (RTL): start = الجزء N ; center = surah name (Amiri/title style) ;
// end = حزب M · ربع R. Numbers via an Arabic-Indic helper.
// Background: scheme.surface @ ~82% + subtle bottom border; full width, top-anchored.
```

  Use Arabic-Indic numerals (reuse/extract the digit map already used by the asset generator, or a small local helper). Pull labels from `S.of(context)`.

- [ ] **Step 2:** Add a `golden`-free widget test that pumps `MushafTopBar` for page 2 inside a `MaterialApp` with DI registered, and asserts the surah name + "٢" appear. (Register `QuranMetaService`/`QuranPageService` in the test's `setUp` via `sl`.)
- [ ] **Step 3:** Run test, analyze, commit (`feat(mushaf): top metadata bar`).

---

### Task 8: MushafBottomBar (paper swatches + page number + FAB)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_bottom_bar.dart`
- Reuse: `mushaf_page_number_text.dart` (page number rendering) — embed or call it.

- [ ] **Step 1: Build the widget** — flush bottom bar, top border:
  - **start:** a `Row` of 5 `paper-swatch` circular buttons (one per `MushafPaper`), each filled with that paper's `background` (and a ring for the active one). Tapping calls `context.read<SettingsCubit>().updateMushafPaper(p)`.
  - **center:** page number (reuse `MushafPageNumberText` or its formatting).
  - **end:** a play **FAB** (filled, primary) that plays the page from its first ayah — reuse the existing FAB logic from `mushaf_page.dart` (first-ayah resolution via `sl<QuranPageService>().getFirstAyahOfPage` + `MushafCubit.toggleHighlight`/`pinOverlay`).

- [ ] **Step 2:** Widget test: pump with neutral settings, tap the `night` swatch, assert `SettingsCubit.updateMushafPaper(MushafPaper.night)` was applied (state reflects it).
- [ ] **Step 3:** Run test, analyze, commit (`feat(mushaf): bottom bar with paper swatches + play`).

---

### Task 9: Integrate bars into MushafPage + chrome animation

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`

- [ ] **Step 1:** In the `Expanded > Stack`, add `MushafTopBar` and `MushafBottomBar` wrapped in animated show/hide bound to `MushafCubit.chromeVisible`:
  - Top: `Align(topCenter)` + `AnimatedSlide`/`AnimatedOpacity` (slide `-1`→`0`).
  - Bottom: `Align(bottomCenter)` + `AnimatedSlide` (slide `1`→`0`).
  - Use a `BlocBuilder<MushafCubit, MushafState>` with `buildWhen: (a,b) => a.chromeVisible != b.chromeVisible || a.currentPage != b.currentPage`.

- [ ] **Step 2:** Remove the old standalone footer `MushafPageNumberText` (now inside the bottom bar) and the headphones-FAB `BlocBuilder` block (its play role moves to the bottom-bar FAB). Keep `AyahPlaybackOverlay`.

- [ ] **Step 3:** `flutter analyze`; run `flutter test test/features/surah/` to confirm mushaf tests pass. Commit (`feat(mushaf): wire top/bottom chrome with animation`).

---

### Task 10: Reciter control in the playback overlay

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`

- [ ] **Step 1:** In `_Body`, add a reciter affordance to the top `Row` (next to `_SpeedChip`): a small chip showing `context.watch<PlaybackCubit>().state.reciter.arabicName`; tapping opens a `PopupMenuButton<Reciter>` over `Reciter.values` calling `context.read<PlaybackCubit>().setReciter(r)`. Reuse the `reciter_label`/reciter strings already in l10n.

- [ ] **Step 2:** Run `flutter test test/features/surah/presentation/pages/mushaf/ayah_playback_overlay_test.dart` (update if it asserts the row contents). `flutter analyze`. Commit (`feat(mushaf): reciter control in playback overlay`).

---

### Task 11: Final verification

- [ ] **Step 1:** `flutter analyze lib/ test/` — zero new issues.
- [ ] **Step 2:** `flutter test test/features/surah/ test/features/quran_playback/ test/features/settings/` — all pass.
- [ ] **Step 3:** Build/run the app (or `flutter run -d windows`) and manually confirm: swipe reads; tap shows/hides chrome; tapping a verse with chrome up opens the playback overlay off the verse; long-press shows the popover (no play); each paper swatch retints body+accent+background separately and persists across restart; top bar shows correct juz/hizb/rub. Use the `verify`/`run` skill if helpful.
- [ ] **Step 4:** Final commit if any fixups (`chore(mushaf): reading controls polish`).

---

## Self-review notes
- Spec §A→Task 3; §B→Tasks 7,8,9; §C→Tasks 1,2,5; §D→Task 4; §E→Task 6; §F→Task 10; testing→each task + Task 11.
- Type consistency: `MushafPaper`, `MushafPaperColors.{background,ink,accent}`, `PageMeta.{surah,juz,hizb,rub}`, `popoverPlacement`, `updateMushafPaper`, `toggleChrome`/`setChrome` used consistently across tasks.
- Known risk flagged: the 240 rubʿ boundaries are external data — Task 4 gates correctness with validation + spot-check tests and a STOP condition rather than shipping guesses.
