# Mushaf S1 (reader logic fixes + paper colours) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix spec §1 ledger items 1–15, 17 and 20 in today's reader widgets (item 16 is deferred), split selection from playback state, add the arrival contract and the last-read guard, and re-tune the six reading papers behind a contrast-gate test.

**Architecture:** Pure functions carry the rules: `toAsciiDigits`, `resolveRunningSurah`, `pagePlaybackRange`, `nextFollowAction` / `followAfterManualTurn`, the `PlaybackState.canSkip*` range clamp, the `LastReadSaver` guard and the paper contrast gates. `MushafCubit` and `PlaybackCubit` call them. The existing widgets (`MushafTopBar`, `MushafBrowseBar`, `AyahPlaybackOverlay`, `AyahActionPopover`, `PageJumpSheet`) stay and are fixed in place. S3 replaces them, so no S3 widget is built here. Where S1 needs UI for items 5 and 6, it uses a SnackBar.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), flutter_bloc + bloc_test, mocktail, fake_async, dartz, equatable, hive_ce + hive_ce_generator, GoRouter, the vendored `quran` package (`quran-1.4.1/`).

**Spec:** `docs/superpowers/specs/2026-11-21-mushaf-leaf-ribbon-design.md` (§1, §1A, §2, §3.7 S1 line, §7). Where the spec and this plan disagree, the spec wins, except for the **Deliberate readings** below, where the plan governs. Raise any other disagreement in the task report.

## Global Constraints

- Work on `feature/mushaf-leaf-ribbon`. Never switch branches, never touch `main`, never push, never rebase, never amend.
- Commits: stage explicit paths only (never `git add -A` or `git add .`). Use a conventional message (`feat|fix|refactor|test(scope): …`) that ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Write no comments and no doc comments in new or changed code. Add no redundant type annotations (`final x = …`, closure parameters untyped). Write lean code.
- Comments the user wrote stay, with two exceptions. A comment inside lines a task replaces goes with those lines (for example the per-range comments in `parseCounter`'s body and the `// ✅ FIX` in `prepareAyahAudio`). A surviving comment that a task makes false (for example the `_onPlayPage` comment at `mushaf_page.dart:244-245`, or the `unpinOverlay` doc comment that names `highlightedAyah`) gets the smallest correction that makes it true, and the task report names it.
- New strings: add each one to both `lib/l10n/intl_ar.arb` and `lib/l10n/intl_en.arb` (a `"@key": {"placeholders": {"x": {"type": "String"}}}` block for each placeholder, as `home_untilSunrise` has), and mirror it in `lib/core/localization/pending_s.dart` in exactly one of these two shapes: `String get key => _ar ? '…' : '…';` or `String key(String a, String b) => _ar ? '… $a …' : '… $a …';`. Use only single quotes and only `String` parameters, and format numbers before passing them in. A method's `String key(String a, …)` signature must stay on one line after `dart format` (the `=>` body may wrap): `pending_s_test` counts methods with `RegExp(r'String \w+\(String')`, so keep at most three short parameters and pass preformatted text instead of many parts. Read strings with `PendingS.of(context)` in `build` and `PendingS.current` in callbacks. `test/core/localization/pending_s_test.dart` must stay green.
- Never edit `lib/generated/`. Never run `intl_utils:generate`. Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`. Never modify `assets/mushaf/**`.
- Arabic numbers use Arabic-Indic digits through `toLocalized(context)` or `toIndicNumerals(localeCode)`.
- Colours come only from `context.colorScheme` or `MushafPaperX`. Hex literals go only in `mushaf_paper_colors.dart`. Text styles come only from `TS.*`, and `test/config/theme/typography_ratchet_test.dart` must not rise.
- Mushaf and playback widgets keep Material `Icons.*` (`icons.md`: match the surrounding set).
- Every task ends at baseline or better: `flutter analyze --no-fatal-infos` gives 0 errors, 0 warnings and ≤ 70 infos, and `flutter test` passes in full (835 at start plus the tests this plan adds, 1 skipped). Run `dart format` on touched files.
- Rule catalogues change in the task that changes the code they describe (spec §3.8).

## Deliberate readings (the plan governs here)

1. **Landing by hand on the playing page re-arms follow.** `followAfterManualTurn` returns true, which counts the same as «العودة إلى الآية المتلوّة». The spec lists only the button and a new play.
2. **A next-ayah preload failure surfaces on advance, not at preload time.** It reaches `error` when the engine advances to that ayah and the retried download fails, so `requestedAyah` names the right ayah. A preload-time emit would name the ayah that is still playing.
3. **The ayah-0 long-press popover has one banner action**, «استماع من بداية السورة». «استماع الصفحة كاملة» stays on the browse bar's ▶ until S3 builds the banner leaf.
4. **The player title shows a selected banner (ayah 0) as ayah 1**, since playback starts there. It never reads «الآية ٠».
5. **Skips are new plays.** ⏮ and ⏭ clear `error`, just as `playSelected`, `playRange` and `retry` do, and they re-arm follow (item 5: "any new play").
6. **A surah opened from search opens as the surah list does.** Spec §1A puts "Search results" under `jump`. The search page tile (`_JumpTile`) and the ayah results follow that. The surah rows in search results are the same `SurahListTile` widget as the surah list, and opening a surah means reading it from its start, not peeking, so they stay `normal` with `openedSurah`.
7. **`jumpFrom` waits for S3.** Spec §3.7 lists it in the S1 `MushafState`, but its only consumer is the S3 notice chip, so S1 adds no field that nothing reads. S1's in-place jump only re-arms the last-read guard.
8. **Follow re-arms only on a play the reader starts.** These call `MushafCubit.resumeFollow()`: the overlay play button, ⏮/⏭, the browse bar's page play, the banner «استماع من بداية السورة» and the range-from edit in the options sheet. A null → non-null playing ayah also re-arms it inside the cubit. Auto-advance, repeats, the range-to edit and a reciter change (which replays the same ayah) do not.

## Three kinds of page turn

| Turn | How `MushafPage` sees it | `MushafCubit.setPage` | `LastReadSaver` |
|---|---|---|---|
| Playback-driven (follow) | `_turns.begin(target)` … `animateTo(...).whenComplete(_turns.end)` | `byUser: false`: keeps selection and follow | `schedule()` only (restarts the dwell when guarded) |
| Swipe or scroll by hand | `_turns.isManual(page)` is true | `byUser: true`: clears selection, applies `followAfterManualTurn` | `onManualTurn()`, then `schedule()` |
| In-place jump (`PageJumpSheet`) | `_turns.begin(page)`, jump, explicit `setPage(page, byUser: true)`, post-frame `_turns.end()`. The `onPageChanged` echo is suppressed. | `byUser: true`: clears selection; follow goes false when the jump leaves the playing page | `rearm()`, never `onManualTurn()` |
| Mode-switch and rotation re-sync (`mushaf_page.dart:421-430, 457-462`) | wrapped in `_turns.begin(currentPage)` … post-frame `_turns.end()` | echo is `byUser: false` | nothing |

## Review Focus

1. **A follow turn interrupted by a drag.** If the reader grabs the page mid-animation, the next manual swipe must count as manual. Task 1 pins this with `PageTurnTracker` tests: `end()` after an interrupted `begin()`, and a jump to the current page.
2. **Ayah 0 (the banner) in page lookups.** `CurrentAyahNotifier` reports `(s, 0)`, banner taps select `(s, 0)`, and old bookmarks may hold `(s, 0)`. `quran.getPageNumber(s, 0)` matches phantom page-data entries (4:0 resolves to p.76 while the banner is on p.77). Every page lookup or presence check of an ayah maps ayah 0 to ayah 1: `playingPage`, `MushafArgs.focus` and `resolveRunningSurah`. Task 5a adds a `playingPage` test for (4,0) → 77, Task 6 a `MushafArgs.focus(4:0)` test and Task 1 a selected-banner test.
3. **Fast swipes and the bounds load.** A late `GetMushafPage` result for page N must not overwrite the bounds of page N+1, and `setPage` clears the old bounds at once. Task 5a adds a completer-ordered race test.
4. **Coming back online.** After an offline failure, a retry must download again and must not play a truncated file. Task 3 pins this with repository tests: the in-flight entry is cleared and the partial file is deleted.
5. **Pause during a recitation with no selection.** The overlay must stay up while paused or errored (`requestedAyah` non-null), and the stop button must be the only way to hide it. Task 7 adds paused and errored visibility tests.

## Out of slice

- Item 16 (sajda map) is deferred by the spec and gets no task.
- Items 18–19 belong to S4. Everything in spec §3–§6 belongs to S2–S5. The `jumpFrom` field and the notice chip are S3 (Deliberate reading 7).
- `MushafPage.dispose` still calls `_playbackCubit.stop()`, and `mushaf_page_dispose_test` still asserts one stop call. Spec §4 (S2) changes both.

---

### Task 1: Pure page helpers (`toAsciiDigits`, bounds rules, juz/hizb oracle)

Ledger items 7 and 20, plus the pure halves of items 1 and 8.

**Files:**
- Modify: `lib/core/helper functions/numeral_helpers.dart`
- Modify: `lib/features/quran_playback/domain/services/playback_range_validator.dart` (`parseCounter`)
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart:33-41,61-69`
- Create: `lib/features/surah/presentation/utils/page_bounds.dart`
- Create: `lib/features/surah/presentation/utils/follow_playback.dart`
- Create: `lib/features/surah/presentation/pages/mushaf/page_turn_tracker.dart`
- Modify: `lib/features/quran_playback/domain/services/quran_meta_service.dart:36-62`
- Modify: `.claude/rules/core-utilities.md`, `.claude/rules/feature-widgets.md` (surah utils line)
- Modify: `test/core/helper functions/numeral_helpers_test.dart` (add a `toAsciiDigits` group)
- Create: `test/features/surah/presentation/utils/page_bounds_test.dart`
- Create: `test/features/surah/presentation/utils/follow_playback_test.dart`, `test/features/surah/presentation/pages/mushaf/page_turn_tracker_test.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart:45-47`
- Modify: `test/features/quran_playback/domain/services/quran_meta_service_test.dart`

**Interfaces:**
- Produces: `String toAsciiDigits(String input)` (top level, in `numeral_helpers.dart`).
- Produces (in `page_bounds.dart`): `int? resolveRunningSurah({required List<AyahBoundEntity> ayahs, AyahIdentifier? selected, AyahIdentifier? playing, int? openedSurah})`.
- Produces (in `page_bounds.dart`): `({AyahIdentifier start, AyahIdentifier end})? pagePlaybackRange(List<AyahBoundEntity> ayahs)`.
- Produces: `QuranMetaService.getPageMeta(page)` reports juz, hizb and rub at the page's **last** ayah.
- Produces (in `follow_playback.dart`): `int? nextFollowAction({required bool followPlayback, required int currentPage, required int? playingPage})` returns the page to turn to, or null. It also produces `bool followAfterManualTurn({required bool followPlayback, required int newPage, required int? playingPage})`. Both truth tables are in Task 5a and are pinned here, one test per row.
- Produces: `class PageTurnTracker { void begin(int page); void end(); bool isManual(int page); }`. `isManual` returns true when nothing has begun. Otherwise it returns false and clears the target once `page == target`.

- [ ] **Step 1: Write failing tests**
  - `numeral_helpers_test.dart`: `toAsciiDigits('٤٢')` → `'42'`, `toAsciiDigits('۶۰۴')` → `'604'`, `toAsciiDigits('1٢3')` → `'123'`, `toAsciiDigits('abc')` → `'abc'`.
  - `page_bounds_test.dart`: add a helper `List<AyahBoundEntity> bounds(int p) => MushafPageModel.fromJson(jsonDecode(File('assets/mushaf/bounds/page_${p.toString().padLeft(3, '0')}.json').readAsStringSync())).ayahs;` and these cases:
    - `resolveRunningSurah(ayahs: bounds(293), openedSurah: 18)` → 18
    - `resolveRunningSurah(ayahs: bounds(604))` → 114 (line counts 112:4, 113:6, 114:8)
    - `resolveRunningSurah(ayahs: bounds(106))` → 5 (4:5 lines vs 5:9)
    - `resolveRunningSurah(ayahs: bounds(76))` → 3
    - `resolveRunningSurah(ayahs: bounds(207))` → 9
    - `resolveRunningSurah(ayahs: bounds(293))` → 17, so the opened surah decides that page
    - `resolveRunningSurah(ayahs: bounds(106), selected: AyahIdentifier(surah: 4, ayah: 176))` → 4
    - `resolveRunningSurah(ayahs: bounds(106), playing: AyahIdentifier(surah: 4, ayah: 176))` → 4
    - `resolveRunningSurah(ayahs: bounds(106), selected: AyahIdentifier(surah: 2, ayah: 1), openedSurah: 9)` → 5: a selection off this page and an opened surah off this page both fall through
    - `resolveRunningSurah(ayahs: bounds(293), selected: AyahIdentifier(surah: 18, ayah: 0))` → 18: a selected banner counts as its ayah 1 (18:1 is on p.293)
    - `resolveRunningSurah(ayahs: bounds(293), playing: AyahIdentifier(surah: 18, ayah: 0))` → 18
    - a synthetic tie (two surahs with equal line counts) → the lower surah number
    - `resolveRunningSurah(ayahs: [])` → null
    - `pagePlaybackRange(bounds(76))` → 3:195–3:200
    - `pagePlaybackRange(bounds(106))` → 4:176–5:2
    - `pagePlaybackRange(bounds(207))` → 9:123–9:129
    - `pagePlaybackRange(bounds(604))` → 112:1–114:6
    - `pagePlaybackRange(bounds(2))` → 2:1–2:5, skipping the 2:0 banner
    - `pagePlaybackRange([])` → null
  - `quran_meta_service_test.dart`: add `juz start pages follow the Madinah print`. For each of the 29 pairs (juz j = 2…30, start ayah, page) from spec item 20 (2:142→22, 2:253→42, 3:93→62, 4:24→82, 4:148→102, 5:82→121, 6:111→142, 7:88→162, 8:41→182, 9:93→201, 11:6→222, 12:53→242, 15:1→262, 17:1→282, 18:75→302, 21:1→322, 23:1→342, 25:21→362, 27:56→382, 29:46→402, 33:31→422, 36:28→442, 39:32→462, 41:47→482, 46:1→502, 51:31→522, 58:1→542, 67:1→562, 78:1→582), assert all of these:
    - `quran.getPageNumber(s, a) == page`
    - `svc.getPageMeta(page).juz == j`
    - `svc.getPageMeta(page).hizb == 2 * j - 1`
    - `svc.getPageMeta(page - 1).juz == j - 1`
  - Pages 62, 121, 201 and 502 start mid-page, so their juz only shows at the last ayah. Keep the four existing tests.
  - `follow_playback_test.dart`: both truth tables in Task 5a, one test per row.
  - `page_turn_tracker_test.dart`:
    - With no `begin`, `isManual(5)` is true.
    - `begin(51)`: `isManual(51)` is false, then `isManual(52)` is true.
    - `begin(60)`: `isManual(58)` is false, `isManual(60)` is false, then `isManual(61)` is true.
    - `begin(51)`, `end()`: `isManual(50)` is true (an interrupted animation).
    - `begin(5)` (a jump to the current page), `end()`: `isManual(6)` is true.
  - `page_jump_sheet_test.dart`: rewrite the `'abc'` case as `'returns null for letters (filtered by the formatter)'`. Add `'accepts Arabic-Indic digits'`: input `'٤٢'` → 42. Add `'accepts Extended Arabic-Indic digits'`: input `'۶۰۴'` → 604.

- [ ] **Step 2: Run and see them fail**
  Run `flutter test test/core/helper\ functions test/features/surah/presentation/utils/page_bounds_test.dart test/features/surah/presentation/utils/follow_playback_test.dart test/features/surah/presentation/pages/mushaf/page_turn_tracker_test.dart test/features/quran_playback/domain/services/quran_meta_service_test.dart test/features/quran_playback/domain/services/playback_range_validator_test.dart test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart`. Expected: compile errors (missing symbols), the ٤٢ case returns null, and the juz pins fail on 62/121/201/502. `playback_range_validator_test` is already green; it is in the command so the `parseCounter` change is checked in Step 4.

- [ ] **Step 3: Implement**
  - `toAsciiDigits`: fold U+0660–0669 and U+06F0–06F9 to `0`–`9` and leave every other character alone. `PlaybackRangeValidator.parseCounter` becomes `final n = toAsciiDigits(raw); return n.isEmpty ? null : int.tryParse(n);`.
  - `PageJumpSheet`: replace `FilteringTextInputFormatter.digitsOnly` with `FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]'))`. `_submit` parses `int.tryParse(toAsciiDigits(raw))`. The hint becomes `'${1.toLocalized(context)} – ${604.toLocalized(context)}'`.
  - `resolveRunningSurah` uses only bounds with `ayah > 0`, never `quran.getPageData`. The rules, in order:
    1. If `selected` is present among the page's ayahs, return its surah. Map `selected.ayah == 0` to ayah 1 for the presence check.
    2. Else if `playing` is present, return its surah. Map `playing.ayah == 0` to ayah 1 for the presence check.
    3. Else if `openedSurah` has a bound on the page, return it.
    4. Else return the surah with the largest sum of `bound.lines.length` over its bounds; a tie goes to the lower surah.
    5. Return null if there is no `ayah > 0` bound.
  - `pagePlaybackRange`: the first and last bound with `ayah > 0`, in list order. Return null if there is none.
  - `QuranMetaServiceImpl.getPageMeta`: compute the position from a private `_lastAyahOfPage(page)`, the last `quran.getPageData(page)` entry with `end > 0`, as `(surah, end)`. Use it for both `juz` (`quran.getJuzNumber`) and the rub search. `surah` stays the first ayah's surah. `QuranPageService` is unchanged, so `_StubPageService` keeps compiling.
  - **Fallback (spec item 20):** the 29 juz-start rows in `_rubBoundaries` already match the spec list, so a failing pin points at the last-ayah lookup. Fix that first. If a hizb pin still cannot pass, keep the `juz` and `getPageNumber` asserts, drop only the `hizb` assert for that page, and say in the task report: "S3 head must show only الجزء".
  - Rules: add `toAsciiDigits(String)` to the helper list in `core-utilities.md` ("folds Arabic-Indic and Extended Arabic-Indic digits to ASCII before parsing user input"). Add `page_bounds.dart` (`resolveRunningSurah`, `pagePlaybackRange`) and `follow_playback.dart` (`nextFollowAction`, `followAfterManualTurn`) to the `surah` utils line in `feature-widgets.md`.

- [ ] **Step 4: Run the scoped tests (same command), expect PASS. Then run `flutter analyze --no-fatal-infos` and `flutter test`.**

- [ ] **Step 5: Commit**
```bash
git add "lib/core/helper functions/numeral_helpers.dart" lib/features/quran_playback/domain/services/playback_range_validator.dart lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart lib/features/surah/presentation/utils/page_bounds.dart lib/features/surah/presentation/utils/follow_playback.dart lib/features/surah/presentation/pages/mushaf/page_turn_tracker.dart lib/features/quran_playback/domain/services/quran_meta_service.dart .claude/rules/core-utilities.md .claude/rules/feature-widgets.md "test/core/helper functions/numeral_helpers_test.dart" test/features/surah/presentation/utils/page_bounds_test.dart test/features/surah/presentation/utils/follow_playback_test.dart test/features/surah/presentation/pages/mushaf/page_turn_tracker_test.dart test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart test/features/quran_playback/domain/services/quran_meta_service_test.dart
git commit -m "fix(mushaf): Arabic-Indic page jump, bounds and follow rules, juz at last ayah" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Paper colours, names and contrast gates (spec §2)

**Files:**
- Modify: `lib/features/surah/presentation/utils/mushaf_paper_colors.dart`
- Create: `lib/features/surah/presentation/utils/enum_localization.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart:61-84`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify: `test/features/surah/presentation/utils/mushaf_paper_colors_test.dart` (deliberate rewrite)
- Create: `test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
- Modify: `.claude/rules/feature-widgets.md` (surah utils line)

**Interfaces:**
- Produces: `MushafPaperColors.ink2` is `Color.alphaBlend(ink.withValues(alpha: 0.78), background)`. `MushafPaperColors.leaf` is `Color.alphaBlend(ink.withValues(alpha: 0.06), background)`. Both are getters.
- Produces: `extension MushafPaperLocalization on MushafPaper { String localized(BuildContext context) }`.
- Removes: `MushafPaperX.label`, which has no callers.

- [ ] **Step 1: Write failing tests**
  - `mushaf_paper_colors_test.dart` is a deliberate rewrite of the old hex pins. It asserts the six background/ink/accent triples exactly:

    | Paper | background | ink | accent |
    |---|---|---|---|
    | cream | `0xFFFDF7E8` | `0xFF1B1A17` | `0xFF9A7B3C` |
    | sepia | `0xFFF3E6C9` | `0xFF2B2116` | `0xFF8A5A2B` |
    | green | `0xFFEEF3E8` | `0xFF18231B` | `0xFF2F6E55` |
    | gray | `0xFFFAFAF7` | `0xFF161616` | `0xFF1F5E7A` |
    | night | `0xFF141210` | `0xFFECE3CF` | `0xFFC9A45A` |
    | slateNight | `0xFF0F141A` | `0xFFDCE5EC` | `0xFF6E9CC4` |

    Keep the "exactly six" test, delete the `label` test, and add `MushafPaper.values.map((p) => p.name)` equals `['cream','sepia','green','gray','night','slateNight']` (persisted names unchanged).
  - `mushaf_paper_contrast_test.dart`: copy the `contrast(a, b)` helper from `test/config/theme/app_palette_contrast_test.dart`. For every paper:
    - ink on background ≥ 7
    - `ink2` on background ≥ 4.5
    - accent on background ≥ 3
    - ink on `alphaBlend(accent@0.20, bg)` ≥ 4.5
    - ink on `alphaBlend(ink@0.15, bg)` ≥ 4.5
    - ink on both tints stacked ≥ 4.5

    Expected values with the spec hexes, all passing: cream 16.3 / 8.2 / 3.7, sepia 12.7 / 6.8 / 4.7, green 14.4 / 7.3 / 5.4, gray 17.3 / 8.8 / 6.8, night 14.6 / 9.2 / 8.0, slateNight 14.5 / 9.1 / 6.4. Tinted ink stays ≥ 9.5. If a gate fails, nudge only lightness and record the final hex in the task report.
  - `reading_settings_sheet_test.dart`: `'paper swatches are named'`. In `Locale('ar')` it finds `كريمي`, `سيبيا`, `أخضر`, `أبيض`, `ليلي` and `ليلي أزرق`. In `Locale('en')` it finds `White`. The selected swatch's `Semantics` has `selected: true`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**
  - Replace the hexes in `mushaf_paper_colors.dart`, add `ink2` and `leaf`, and delete `label`.
  - Add the strings to both ARBs and `PendingS`:

    | Key | ar | en |
    |---|---|---|
    | `mushaf_paper_cream` | 'كريمي' | 'Cream' |
    | `mushaf_paper_sepia` | 'سيبيا' | 'Sepia' |
    | `mushaf_paper_green` | 'أخضر' | 'Green' |
    | `mushaf_paper_gray` | 'أبيض' | 'White' |
    | `mushaf_paper_night` | 'ليلي' | 'Night' |
    | `mushaf_paper_slateNight` | 'ليلي أزرق' | 'Blue night' |

  - `enum_localization.dart`: a `switch` over `MushafPaper` that returns `PendingS.of(context).mushaf_paper_*`.
  - Reading sheet: wrap each swatch in `Semantics(button: true, selected: selected, label: p.localized(context))`. Under each swatch put a caption `Text(p.localized(context), style: TS.medium12, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)` coloured `scheme.onSurfaceVariant`. Keep the `reading-paper-${p.name}` keys on the tap target.
  - Add `enum_localization.dart` (`MushafPaper.localized`) to the surah utils line in `feature-widgets.md`.

- [ ] **Step 4: Run the scoped tests, then `flutter test test/core/localization/pending_s_test.dart`, analyze, and the full `flutter test`. Expected: PASS.**

- [ ] **Step 5: Commit**
```bash
git add lib/features/surah/presentation/utils/mushaf_paper_colors.dart lib/features/surah/presentation/utils/enum_localization.dart lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/utils/mushaf_paper_colors_test.dart test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart .claude/rules/feature-widgets.md
git commit -m "feat(mushaf): printed-mushaf paper colours with named swatches and contrast gates" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Playback errors, `requestedAyah`, Equatable state, download cleanup

Ledger items 6 (engine) and 14.

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart:116-224,356-367`
- Modify: `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart:50-89`
- Modify: `test/features/quran_playback/playback_state_test.dart`, `test/features/quran_playback/presentation/cubit/playback_state_test.dart`
- Modify: `test/features/quran_playback/playback_cubit_test.dart`
- Create: `test/features/quran_playback/data/repositories/quran_playback_repo_impl_test.dart`

**Interfaces:**
- Produces on `PlaybackState`:
  - The class `extends Equatable`, and `props` lists every field.
  - New field `AyahIdentifier? requestedAyah`.
  - `copyWith(..., AyahIdentifier? requestedAyah, bool clearRequested = false, bool clearError = false)`.
  - `error` now **persists**: `error: clearError ? null : (error ?? this.error)`.
- Produces on `PlaybackCubit`: `Future<void> retry()`.
- Behaviour:
  - `playSelected` and `playRange` put `requestedAyah` (the normalised start ayah) into their existing first emit, so it lands synchronously with `isLoading: true`.
  - `_playAyah` gains `emit(state.copyWith(requestedAyah: ayah));` as its first statement after the `isClosed` check. This is how auto-advance, repeats, skips and `retry` update it. On the `playSelected` / `playRange` paths Equatable drops this second, equal emit. The only existing `expect:` lists in `playback_cubit_test.dart` are `pause`, `setSpeed` and idle `setReciter`, none of which reach `_playAyah`, so no existing emission list changes; if Step 1 finds one, update it and name it in the report.
  - `playSelected`, `playRange`, `retry`, `skipNext`, `skipPrevious` and `stop` pass `clearError: true`. A skip is a new play (Deliberate reading 5). Task 4 adds the clamp to the skips; here they only emit `clearError: true` before `_playAyah`.
  - `stop` also passes `clearRequested: true`.
  - A failed prepare, a failed `playPreparedAudio` or a failed `playPreparedAudioSequence` emits `isPlaying: false, isLoading: false, isPlayingBasmala: false, error: failure.message`.
  - `error` stays a raw `String`. The widget builds the localized copy, which names `requestedAyah ?? currentAyah` (Task 7).

- [ ] **Step 1: Make `PlaybackState` Equatable first, then run the whole playback and surah test directories**
  Add `extends Equatable` and `props`, and change nothing else. Run `flutter test test/features/quran_playback test/features/surah`. Equal states are now deduplicated, so fix any blocTest emission list that shifts in the same commit, and say which in the report.

- [ ] **Step 2: Write failing tests**
  - State tests, all in `test/features/quran_playback/playback_state_test.dart` (the defaults/copyWith file; `presentation/cubit/playback_state_test.dart` holds the range and repeat tests and gets Task 4's `canSkip*` table):
    - `copyWith keeps error unless clearError` rewrites the old wipe-on-copy behaviour deliberately.
    - `copyWith clearRequested drops requestedAyah`.
    - `two default states are equal`.
  - `playback_cubit_test.dart`:
    - `playSelected emits requestedAyah and isLoading synchronously`: the first emission has `requestedAyah == 2:5` and `isLoading == true`.
    - `first play fails offline`: `prepareAyahAudio` returns `Left(NetworkFailure(...))` (`core/errors/failure.dart`). The last state has `requestedAyah 2:5`, `currentAyah == null`, `error != null`, `isLoading == false`, and `notifyAyahChanged` is never called.
    - `error survives an unrelated emit`: after the failure, `setEachAyahRepeat(2)` keeps `error`.
    - `retry clears error and replays requestedAyah`: prepare returns Left, then Right. After `retry()`, `notifyAyahChanged(2:5)` is called once and `error == null`.
    - `playPreparedAudio Left feeds error`, plus the same for `playPreparedAudioSequence` (ayah 2:1, so the basmala path runs).
    - `stop clears requestedAyah and error`.
    - `skipNext clears a stale error`: start from a failed state (`error: 'x'`, `currentAyah: 2:5`). After `skipNext()` succeeds for 2:6, `error == null`.
    - `a repeat failure after a skip shows again`: two different emissions carry a non-null `error`, with a null between them.
    - `advancing to an ayah whose preload failed surfaces the error naming it`. Use a `StreamController<void>` for `onAudioCompleted`. Start the state at `currentAyah 2:5, isAutoPlaying: true`, stub `seq.getNextAyah` → 2:6, and have prepare for 2:6 return Left. Fire completion, then expect `requestedAyah == 2:6` and `error != null`.
  - Repository test `quran_playback_repo_impl_test.dart`. Mock `AudioPlayer`, `QuranPlaybackRemoteDataSource` and `QuranPlaybackLocalDataSource` (`extends Mock implements …`), and use a temp `Directory`:
    - `failed download is not reused and leaves no partial file`. The first `downloadAudio` writes bytes to the save path and then throws `DioException(requestOptions: RequestOptions())`; the second returns the path. Expect the first call `isLeft()` with `File(path).existsSync() == false` afterwards, and the second call `isRight()`.
    - `concurrent prepares share one download`: stub `downloadAudio` to return a `Completer<String>`'s future. Call `prepareAyahAudio` twice with no `await` between the calls (keep both futures), then complete the completer with the save path, await both futures, expect both `isRight()`, and `verify(() => remote.downloadAudio(any(), any())).called(1)`.

- [ ] **Step 3: Run** `flutter test test/features/quran_playback`. Expected: the new tests FAIL.

- [ ] **Step 4: Implement**
  - `prepareAyahAudio`: today the in-flight entry is registered only after `await file.parent.create(...)` (`quran_playback_repo_impl.dart:65-77`), so two prepares started in the same tick both miss the map and both download. Register it before the first `await`: after the cache and in-flight checks, build one future and store it synchronously,
    ```dart
    final future = () async {
      await file.parent.create(recursive: true);
      return remote.downloadAudio(url, filePath);
    }();
    _inFlightDownloads[url] = future;
    ```
    then `try { final downloadedPath = await future; local.cacheAudioMetadata(url, downloadedPath); return Right(downloadedPath); } catch (_) { if (file.existsSync()) file.deleteSync(); rethrow; } finally { _inFlightDownloads.remove(url); }`. The outer `on DioException` / `catch` map to `Left` as today. Only the call that started the download deletes the file and removes the entry; a caller that found the entry just awaits it inside the same outer `try`.
  - The cubit changes as listed under Interfaces.
  - The next-ayah preload failure reaches `error` like this: `preloadAyahs` keeps its `void` signature. The `finally` cleanup means a failed preload no longer poisons the in-flight map, so when `_handleNextAyah` advances, `_playAyah(next)` downloads again. If that fails too, the failure is emitted with `requestedAyah == next`. No preload-time emit names the wrong ayah.
  - `retry()`: return if `requestedAyah` is null. Otherwise emit `clearError: true, isLoading: true` and call `_playAyah(requestedAyah!)`. Range and repeat state are untouched.
  - Every emit after an `await` checks `isClosed` first, as today.

- [ ] **Step 5: Run** `flutter test test/features/quran_playback test/features/surah`, then analyze and the full suite. Expected: PASS.

- [ ] **Step 6: Commit**
```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_state.dart lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart test/features/quran_playback/playback_state_test.dart test/features/quran_playback/presentation/cubit/playback_state_test.dart test/features/quran_playback/playback_cubit_test.dart test/features/quran_playback/data/repositories/quran_playback_repo_impl_test.dart
git commit -m "fix(playback): persistent errors, requestedAyah, retry, no poisoned downloads" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
Add to the `git add` any surah test whose emission list Step 1 changed.

---

### Task 4: Range end, skip clamp, «تشغيل السورة» as a range

Ledger items 3 (engine), 8 (engine) and 10 (state).

**Files:**
- Modify: `lib/features/quran_playback/domain/entities/ayah_identifier.dart`
- Modify: `lib/features/quran_playback/domain/services/aya_sequence_service.dart:6-28`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart:285-299,356-367`
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart:61-66`
- Modify: `test/features/quran_playback/aya_sequence_service_test.dart`, `test/features/quran_playback/presentation/cubit/playback_state_test.dart`, `test/features/quran_playback/playback_cubit_test.dart`
- Modify: `test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart` (deliberate rewrite)

**Interfaces:**
- Produces: `AyahIdentifier implements Comparable<AyahIdentifier>`, with `int compareTo(AyahIdentifier other)` ordering by surah, then ayah.
- Produces: `AyahSequenceService.getNextAyah` returns null when an end is given and `current >= end`, not only on exact equality.
- Produces on `PlaybackState` (no `<` / `>` operators are added to `AyahIdentifier`; use `compareTo`):
  ```dart
  bool get canSkipNext =>
      currentAyah != null &&
      (rangeEnd == null
          ? currentAyah != const AyahIdentifier(surah: 114, ayah: 6)
          : currentAyah!.compareTo(rangeEnd!) < 0);
  bool get canSkipPrevious =>
      currentAyah != null &&
      (rangeStart == null
          ? currentAyah != const AyahIdentifier(surah: 1, ayah: 1)
          : currentAyah!.compareTo(rangeStart!) > 0);
  ```
- Behaviour: `stop()` clears the range (`clearRange: true`, and `_endSurah` / `_endAyah` set to null). `playRange` accepts any `start <= end` across surahs, as the engine already does. The single-surah rule stays in `PlaybackRangeValidator` for user edits only.

- [ ] **Step 1: Write failing tests**
  - `aya_sequence_service_test.dart`:
    - `next stops past the range end`: current 2:8, end 2:7 → null.
    - `next crosses surahs inside a cross-surah range`: current 4:176, end 5:2 → 5:1.
    - `next at the end of the mushaf`: current 114:6, no end → null.
  - State: a `canSkipNext` / `canSkipPrevious` table.
    - idle → false/false
    - 1:1 with no range → next true, previous false
    - 114:6 with no range → next false
    - range 2:5–2:7 at 2:5 → previous false, next true
    - at 2:7 → next false
    - at 2:6 → both true
  - Cubit:
    - `skipNext at the range end is a no-op` (`verifyNever prepareAyahAudio`).
    - `skipPrevious at the range start is a no-op`.
    - `skipNext passes the range end to getNextAyah`: verify `seq.getNextAyah(current: 2:5, endSurah: 2, endAyah: 7)`.
    - `stop clears rangeStart and rangeEnd`.
    - `playRange keeps a cross-surah range`: start 4:176 and end 5:2 are both kept in state.
  - `surah_list_tile_test.dart`, rewritten: `'play button plays the whole surah as a range'`. The fake records `playRange` and expects start 2:1 and end 2:286. Delete the `playFromAyah` override from the fake.

- [ ] **Step 2: Run** `flutter test test/features/quran_playback test/features/surah/presentation/pages/surah_list`. Expected: FAIL.

- [ ] **Step 3: Implement**
  - `skipNext`: `if (!state.canSkipNext) return;`, then `getNextAyah(current:, endSurah: state.rangeEnd?.surah, endAyah: state.rangeEnd?.ayah)`. Existing mocks stubbed with only `current:` still match when the range is null.
  - `skipPrevious`: `if (!state.canSkipPrevious) return;`.
  - Tile: `playRange(start: AyahIdentifier(surah: surah.number, ayah: 1), end: AyahIdentifier(surah: surah.number, ayah: surah.numberOfAyahs))`, then `_openMushaf(context)`. Task 6 changes `_openMushaf`'s args.

- [ ] **Step 4: Run** the scoped tests, analyze, and the full suite. Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/quran_playback/domain/entities/ayah_identifier.dart lib/features/quran_playback/domain/services/aya_sequence_service.dart lib/features/quran_playback/presentation/cubit/playback/playback_state.dart lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart test/features/quran_playback/aya_sequence_service_test.dart test/features/quran_playback/presentation/cubit/playback_state_test.dart test/features/quran_playback/playback_cubit_test.dart test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart
git commit -m "fix(playback): ranges end where they say, skips clamp to the range, surah play is a range" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5a: `MushafCubit` state split, `MushafArgs` arrival state, renames

Ledger items 4 and 5 (state and rule), plus §1A in the cubit and router. The rename and every consumer go in **one commit**. `MushafPage` only gets the renames and a literal `byUser: true` at its three `setPage` call sites here; Task 5b wires the turn tracker and the follow listener. Between the two commits the reader behaves as today.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_args.dart`
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`, `mushaf_cubit.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart`
- Modify: `lib/config/router/app_router.dart:161-197,223-227`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, renames only:
  - the constructor; `widget.initialPage` becomes `widget.args.page` (lines 68, 102, 123)
  - `readCurrent` (84): `s.highlightedAyah` becomes `s.selectedAyah`
  - the post-frame last-read restore (97-104): `highlightedAyah` → `selectedAyah`, `toggleHighlight` → `toggleSelection` (Task 6 deletes the block)
  - `_onScroll` (179), `_onJumpToPage` (278) and `onPageChanged` (468): `setPage(page, byUser: true)`
  - the browse-bar builder (357, 361-362): `highlightedAyah` → `selectedAyah`
  - `_onPlayPage` (256): `toggleHighlight` → `toggleSelection`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart:118-157,219-240,302-327` (rename only; the `AyahHighlightPainter(highlightedAyah: …)` argument at 146 keeps its name)
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart:46-48,70-79` (rename only)
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart:33-39` (`origin: MushafOrigin.jump`, `openedSurah: result.surah`; moved here from Task 6 so search keeps its focus between tasks)
- Modify: `.claude/rules/routing-and-navigation.md:24` (`MushafArgs` carries `origin`; a bare `int` is `normal`)
- Modify (rewrite to the new API): `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart`, `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart`, `test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart` (it tests `MushafCubit`), `test/features/surah/presentation/cubit/mushaf_chrome_test.dart`
- Modify (fakes and renames): `test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`

**Interfaces:**
- Produces: `enum MushafOrigin { normal, jump }`.
- Produces: `class MushafArgs { final int page; final AyahIdentifier? focusAyah; final int? openedSurah; final MushafOrigin origin; const MushafArgs({required this.page, this.focusAyah, this.openedSurah, this.origin = MushafOrigin.normal}); factory MushafArgs.focus(AyahIdentifier ayah) }`.
  - `MushafArgs.focus(a)` = page `quran.getPageNumber(a.surah, a.ayah == 0 ? 1 : a.ayah)`, `focusAyah: a`, `openedSurah: a.surah`, `origin: jump`. The 0 → 1 mapping keeps a banner bookmark off the phantom page (4:0 → 77, not 76); `MushafState.initial` then selects nothing for it.
- Produces: `MushafState` with `currentPage`, `selectedAyah` (replaces `highlightedAyah`), `playingAyah`, `followPlayback` (default `true`), `openedSurah`, `pageAyahs` (`List<AyahBoundEntity>`, default `const []`), `highlightedAyahCenterY`, `isOverlayPinned` and `chromeVisible`. Every field is in `props`.
  - `copyWith` takes `clearSelected` in place of `clearHighlighted`. `clearHighlightedCenterY` keeps its name.
  - `int? get runningSurah => resolveRunningSurah(ayahs: pageAyahs, selected: selectedAyah, playing: playingAyah, openedSurah: openedSurah)`.
  - `factory MushafState.initial(MushafArgs args)`: `selectedAyah` is `args.focusAyah` only when `origin == jump` and `focusAyah.ayah > 0`.
- Produces on `MushafCubit({required MushafArgs args, required ValueNotifier<AyahIdentifier?> currentAyahNotifier, required QuranPageService pageService, required GetMushafPage getMushafPage})`:
  - The constructor starts the same `pageAyahs` load as `setPage` for `args.page` (no clearing emit; the state starts empty).
  - `void setPage(int page, {required bool byUser})`
  - `void toggleSelection(AyahIdentifier ayah)` and `void clearSelection()`, renamed from `toggleHighlight` / `clearHighlight`
  - `void resumeFollow()`
  - `int? get playingPage`: null when there is no playing ayah. Otherwise `pageService.getPageForAyah(s, a == 0 ? 1 : a)`.
  - `pinOverlay`, `unpinOverlay` (still clears the selection), `toggleChrome`, `setChrome` and `setHighlightBounds` are unchanged. `debugNotifier` stays.
- Produces: `MushafPage({super.key, required this.args})` with `final MushafArgs args`. `MushafPage.initialPage` is removed. Router builders: `sl<MushafCubit>(param1: args)` and `MushafPage(args: args)`. The router-side `toggleHighlight(focus)` is deleted because `MushafState.initial` handles focus.

**Truth tables (each row is pinned in Task 1):**

`nextFollowAction`:

| followPlayback | playingPage | currentPage | result |
|---|---|---|---|
| true | null | 50 | null |
| true | 50 | 50 | null |
| true | 51 | 50 | 51 |
| false | 51 | 50 | null |

`followAfterManualTurn`:

| followPlayback | playingPage | newPage | result | Note |
|---|---|---|---|---|
| any | null | any | unchanged | |
| true | 50 | 51 | false | turned away by hand |
| false | 50 | 49 | false | |
| false | 50 | 50 | true | landing by hand on the playing page counts as «العودة إلى الآية المتلوّة» |
| true | 50 | 50 | true | |

`setPage(page, byUser:)`:
- Both variants first emit, in one `copyWith`, the new `currentPage` and `pageAyahs: const []`, so the old page's bounds never outlive the turn (the top bar shows `''` and `_onPlayPage` is a no-op until the load lands).
- `byUser: true` also clears `selectedAyah` (today's swipe behaviour) and sets `followPlayback = followAfterManualTurn(...)` in that emit.
- `byUser: false` keeps selection and follow (item 4).
- Both then load `pageAyahs` for `page` through `getMushafPage`. After the await: `if (isClosed || state.currentPage != page) return;`. A `Left` result leaves `pageAyahs` empty.

`_onPlayingAyahChanged`:
- A change from null to non-null sets `followPlayback: true` (a new play).
- The selection follows the playing ayah when they were equal, as today.
- Null clears `playingAyah` only.

`resumeFollow()` emits `followPlayback: true` and nothing else.

- [ ] **Step 1: Write failing tests**
  Build every cubit with a `_StubMushafRepo` that returns `MushafPageEntity(pageNumber: p, ayahs: <bounds from JSON or const []>)` (or a `Completer` per page for the race), a page service and `MushafArgs`. The stub page service may return a constant, except in the `playingPage` test, which uses the real `QuranPageServiceImpl()`.
  - `mushaf_image_cubit_test.dart` (arrival, selection and bounds):
    - `initial: normal origin selects nothing`
    - `initial: jump with focus 2:255 selects it`
    - `initial: jump with focus 2:0 selects nothing`
    - `initial: openedSurah kept`
    - `setPage(byUser: false) keeps selection and follow`
    - `setPage(byUser: true) away from the playing page clears selection and sets follow false`
    - `toggleSelection` sets, clears on the same ayah and replaces on another (the three existing `toggleHighlight` cases, renamed)
    - the two existing `CurrentAyahNotifier` cases, renamed
    - `pageAyahs load on init and on setPage`
    - `setPage clears pageAyahs until the load completes`: from a loaded page 5, `setPage(6, byUser: true)` with page 6's completer pending → `pageAyahs` is empty; complete it → page 6's bounds
    - **race:** `setPage(5)` then `setPage(6)`; complete 6, then 5; `pageAyahs` is page 6's
    - `runningSurah on p.293 with openedSurah 18 is 18` (bounds from JSON)
    - `playingPage maps (4,0) to 77`, with `QuranPageServiceImpl()`
  - `mushaf_cubit_auto_follow_test.dart` (follow):
    - `setPage(byUser: true) onto the playing page sets follow true`
    - `resumeFollow sets follow true`
    - `in-place jump away while playing`: from page 50 with the playing page at 50 and follow true, `setPage(60, byUser: true)` clears the selection and sets follow false
    - `notifier null → A sets follow true`
    - the three existing auto-follow and no-auto-follow cases, renamed to `selectedAyah`
  - `mushaf_cubit_clear_highlight_test.dart`: its two `clearHighlight` cases become `clearSelection` cases.
  - `mushaf_chrome_test.dart`: the new constructor, `toggleHighlight` → `toggleSelection` and `highlightedAyah` → `selectedAyah` (lines 35, 38).

- [ ] **Step 2: Run** `flutter test test/features/surah`. Expected: compile errors or FAIL.

- [ ] **Step 3: Implement**
  - **Cubit and state:** implement per the tables. DI: `sl.registerFactoryParam<MushafCubit, MushafArgs, void>((args, _) => MushafCubit(args: args, currentAyahNotifier: sl<CurrentAyahNotifier>(), pageService: sl(), getMushafPage: sl()))`. `_mushafArgsFrom` keeps its shape. A bare `int` becomes `MushafArgs(page: extra)`, which is `normal` by default.
  - **`MushafPage`:** the renames listed under Files. The follow listener and `auto_swap_helper.dart` stay as they are until Task 5b.
  - **Fakes:**
    - Both `_FakeMushaf` classes (overlay test, dispose test) gain `@override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);`.
    - Both re-sign their `void setPage(int p)` override (`ayah_playback_overlay_test.dart:23`, `mushaf_page_dispose_test.dart:55`) as `@override void setPage(int p, {required bool byUser}) {}`: the old signature no longer compiles, and a no-op keeps today's behaviour where `noSuchMethod` would throw.
    - Rename `clearHighlight` → `clearSelection` and `toggleHighlight` → `toggleSelection` in both fakes, and `clearHighlighted:` → `clearSelected:` in the overlay fake (lines 17 and 30). The dispose fake's `highlightedAyah:` (and its `highlighted` field) become `selectedAyah:` / `selected`.
    - The dispose test uses `MushafPage(args: const MushafArgs(page: 7))` and `MushafState(currentPage: 7, selectedAyah: 2:5)`, and its expectation stays (page 7, ayah 2:5, one stop).
    - In the overlay test `highlightedAyah:` becomes `selectedAyah:`. Task 7 rewrites its behaviour.
  - Rules: in `routing-and-navigation.md:24`, say that `MushafArgs` carries `origin` (`normal` | `jump`) and that `_mushafArgsFrom` maps a bare `int` to `normal`.

- [ ] **Step 4: Run** `flutter test test/features/surah test/config`, then analyze and the full suite. Expected: PASS. Then run `grep -rnE "highlightedAyah\b|toggleHighlight|clearHighlight\b|clearHighlighted\b" lib test`. Expected matches, all of which stay until S3: `AyahHighlightPainter`'s own `highlightedAyah` field and constructor parameter, and its call-site argument in `mushaf_page_view.dart:146` (the search is case-sensitive, so `prevHighlightedAyah` and `_shownHighlightedAyah` do not match). `clearHighlightedCenterY` on `MushafState` does not match this pattern and stays. Anything else is a missed rename.

- [ ] **Step 5: Commit**
```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_args.dart lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart lib/features/surah/presentation/pages/mushaf/mushaf_di.dart lib/config/router/app_router.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart .claude/rules/routing-and-navigation.md test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart test/features/surah/presentation/cubit/mushaf_chrome_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
git commit -m "refactor(mushaf): split selection from playback, arrival args, bounds in state" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5b: Turn tracker, follow listener, in-place jump

Ledger items 4 and 5 in `MushafPage`, per the "Three kinds of page turn" table.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, covering:
  - `onPageChanged` (468) and `_onScroll` (173-182)
  - the `_onPlayingAyahChanged` listener (205-234) and its `BlocListener.listenWhen` (294)
  - `_onJumpToPage` (267-279)
  - the two mode-switch re-syncs (421-430, 457-462)
- Delete: `lib/features/surah/presentation/pages/mushaf/auto_swap_helper.dart`, `test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart`

**Interfaces:**
- Consumes: `nextFollowAction`, `followAfterManualTurn` and `PageTurnTracker` (Task 1), and `setPage(byUser:)`, `playingPage` and `followPlayback` (Task 5a).

- [ ] **Step 1: Implement**
  - Add a field `final _turns = PageTurnTracker();`.
  - Page mode: `onPageChanged: (i) => _mushafCubit.setPage(i + 1, byUser: _turns.isManual(i + 1))`.
  - Scroll mode: `_onScroll` does the same with its computed page.
  - The follow listener becomes `listenWhen: (a, b) => a.playingAyah != b.playingAyah || (!a.followPlayback && b.followPlayback)`. Its listener computes `nextFollowAction(followPlayback: s.followPlayback, currentPage: s.currentPage, playingPage: _mushafCubit.playingPage)`. When the result is non-null, it calls `_turns.begin(target)`, then `animateToPage(target - 1, …).whenComplete(_turns.end)`; in scroll mode it uses `animateTo(...).whenComplete(_turns.end)`.
  - `_onJumpToPage` follows the "Three kinds of page turn" table. It calls `_turns.begin(page)` before `jumpToPage` / `jumpTo`, then `_mushafCubit.setPage(page, byUser: true)` (a reader-initiated turn: it clears the selection and can drop follow), then `WidgetsBinding.instance.addPostFrameCallback((_) => _turns.end())`.
  - The two mode-switch re-syncs (scroll `jumpTo` at 421-430, page `jumpToPage` at 457-462) are wrapped in `_turns.begin(_mushafCubit.state.currentPage)` … post-frame `_turns.end()`. Their echoes are then `byUser: false`, so they do not disarm the last-read guard in Task 6.
  - Delete `auto_swap_helper.dart` and its test (§3.8 folds it into `nextFollowAction`).

- [ ] **Step 2: Run** `flutter test test/features/surah`, then analyze and the full suite. Expected: PASS. The rules are pinned by Task 1's pure tests and Task 5a's cubit tests, so this task adds no test. Then `grep -rn "computeAutoSwapTargetIndex" lib test` finds nothing.

- [ ] **Step 3: Commit**
```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/auto_swap_helper.dart test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart
git commit -m "fix(mushaf): follow playback only while following; manual turns tracked apart from follow turns" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
`git add` on the two deleted paths stages their deletion.

---

### Task 6: Arrival callers and the last-read guard

Ledger items 13 and 17, plus the §1A caller table.

**Files:**
- Modify: `lib/features/surah/domain/entities/last_read.dart`
- Modify: `lib/features/surah/data/models/last_read_hive_model.dart`, regenerating `last_read_hive_model.g.dart`
- Modify: `lib/features/surah/data/repositories/last_read_repository_impl.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/last_read_saver.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, covering:
  - saver construction (79-95)
  - delete the post-frame last-read restore (97-104)
  - `_onJumpToPage`
  - `onPageChanged` / `_onScroll`
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart:21-22`
- Modify: `lib/features/bookmarks/presentation/pages/bookmarks_page.dart:152-155,202`
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart:147` (`_JumpTile`)
- Modify: `test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart`, `test/features/surah/data/repositories/last_read_repository_impl_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`, `test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart`
- Create: `test/features/surah/presentation/pages/mushaf/mushaf_args_test.dart`

**Interfaces:**
- Consumes: `MushafArgs`, `MushafOrigin` and `MushafArgs.focus` (Task 5a), and `PageTurnTracker` (Task 1) with the `_turns` field (Task 5b).
- Produces: `LastRead({required int page, AyahIdentifier? ayah, DateTime? updatedAt})` with `updatedAt` in `props`. `LastReadHiveModel` gains `@HiveField(3) DateTime? updatedAt` (typeId 5 unchanged; old records read null).
- Produces on `LastReadSaver({required LastRead Function() readCurrent, required Future<void> Function(LastRead) persist, required MushafOrigin origin, DateTime Function() now = DateTime.now, Duration debounce = const Duration(milliseconds: 800), Duration dwell = const Duration(seconds: 20)})`:
  - `bool get guarded` is `origin == jump` at construction.
  - When `origin == jump`, the constructor starts the dwell timer. A reader who stays on the arrival page is saved after 20 s even if the cubit never emits a page change (for example when the bounds load is a `Left` or an empty list and Equatable drops the emit).
  - `void schedule()`. When guarded, it restarts the dwell timer and never persists. Otherwise it is the debounce as today.
  - `void flush()`. When guarded, it cancels the debounce, leaves the dwell timer running and does not persist. Otherwise it persists now. (The app-pause path keeps counting the dwell; the dispose path calls `dispose()` right after.)
  - `void onManualTurn()` sets `guarded = false` and cancels the dwell timer. The page listener's `schedule()` then debounces the write.
  - `void rearm()` sets `guarded = true` and restarts the dwell timer.
  - When the dwell timer fires: `guarded = false`, then persist immediately.
  - `void dispose()` cancels both timers.
  - Every persist writes `LastRead(page: c.page, ayah: c.ayah, updatedAt: now())`, where `c = readCurrent()`. The saver stamps `updatedAt`, not the repository. hive_ce's built-in `DateTimeAdapter` stores milliseconds and reads back a local `DateTimeWithoutTZ`, so `updatedAt` is kept at millisecond precision and only a local whole-millisecond value round-trips to an equal `LastRead`.

**Caller table (§1A):**

| Caller | args |
|---|---|
| `surah_list_tile.dart` `_openMushaf` (also the `SurahListTile` in surah search results, Deliberate reading 6) | `MushafArgs(page: surah.pageNumber, openedSurah: surah.number)` |
| `ayah_result_tile.dart` | already done in Task 5a: `MushafArgs(page: result.page, focusAyah: …, openedSurah: result.surah, origin: MushafOrigin.jump)` |
| bookmarks `_QuranBookmarkTile` | `MushafArgs.focus(ayah)` (item 13) |
| bookmarks `_PageBookmarkTile` | `MushafArgs(page: page, origin: MushafOrigin.jump)` (no focus ayah) |
| search `_JumpTile` (page and juz suggestions, `search_results_view.dart:147`) | `MushafArgs(page: suggestion.page, origin: MushafOrigin.jump)` (spec §1A "Search results"; no focus ayah, so no `openedSurah`) |
| home `last_read_card.dart`, `core/widgets/last_quran_read.dart`, `start_reading_card.dart`, `juz_browse_list.dart`, `page_jumper_grid.dart` | unchanged bare `int` (normal) |
| `PageJumpSheet` (in place) | no new route. `_onJumpToPage` calls `_lastReadSaver.rearm()` |

- [ ] **Step 1: Write failing tests**
  - `last_read_saver_test.dart`: the three existing tests pass `origin: MushafOrigin.normal`, and their persisted values carry `updatedAt`. Assert `page`, `ayah` and `updatedAt` fields rather than whole-entity equality. Add these with `fakeAsync`:
    Each `jump` case constructs the saver with `origin: MushafOrigin.jump` at t = 0, which starts the dwell.
    - `jump: dispose-path flush does not write`: `flush()`, `dispose()`, elapse 30 s → no write.
    - `jump: pause-path flush does not write`: `flush()`, elapse 1 s → no write; elapse to 20 s → one write (the dwell kept running).
    - `jump: schedule does not write, even after the debounce`: `schedule()`, elapse 1 s → no write.
    - `jump: 20 s dwell writes once with updatedAt from the clock`: call nothing, elapse 19 s → no write, elapse to 20 s → one write, elapse to 60 s → still one.
    - `jump: playback page change restarts the dwell`: elapse 15 s, `schedule()`, elapse to 20 s → no write, elapse to 35 s → one write.
    - `jump: manual turn then schedule writes after the debounce`: elapse 5 s, `onManualTurn()`, `schedule()`, elapse 800 ms → one write; elapse to 30 s → still one (the dwell was cancelled).
    - `normal: rearm guards again`: `origin: normal`, `rearm()`, `flush()` → no write; elapse 20 s → one write.
    - `updatedAt comes from the injected clock`: `origin: normal`, `now: () => DateTime(2026, 11, 21, 9, 40)`, `flush()` → the write's `updatedAt` equals it.
  - Repository test: `save then get round-trips updatedAt` with `updatedAt: DateTime(2026, 11, 21, 9, 40)` (local, whole milliseconds; not `DateTime.now()` or `DateTime.utc(...)`, which do not compare equal after the round trip), plus `old record without updatedAt reads null`: put a `LastReadHiveModel(page: 3)` directly and expect `updatedAt` to be null.
  - `mushaf_args_test.dart`:
    - `MushafArgs.focus(2:255)` has page 42, `focusAyah` 2:255, `openedSurah` 2 and origin `jump`.
    - `MushafArgs.focus(AyahIdentifier(surah: 4, ayah: 0))` has page 77 (not the phantom 76), and `MushafState.initial` of it has `selectedAyah == null`.
    - The default origin is `normal`.
  - `surah_list_tile_test.dart`: capture `state.extra` in the `/mushaf` route builder. Expect `MushafArgs` with page 2, `openedSurah` 2 and origin `normal`, for both the tile tap and the play button.
  - `mushaf_page_dispose_test.dart`:
    - Assert `saved.page == 7`, `saved.ayah == 2:5`, `saved.updatedAt != null` and `stopCalls == 1`.
    - New case `jump arrival: dispose does not overwrite last read`: with `MushafArgs(page: 7, origin: MushafOrigin.jump)`, `repo.saved` is null and `stopCalls` is 1.

- [ ] **Step 2: Run** `flutter test test/features/surah`. Expected: FAIL.

- [ ] **Step 3: Implement**
  - Entity, model and repository as specified. Then run `dart run build_runner build --delete-conflicting-outputs`. Stage only `last_read_hive_model.g.dart`. If the generator touched any other generated file, `git restore` it unless its diff is required by this change.
  - `MushafPage`:
    - Build the saver with `origin: widget.args.origin`.
    - `readCurrent` reads `s.selectedAyah ?? _playbackCubit.state.currentAyah`.
    - In `onPageChanged` / `_onScroll`, compute `final manual = _turns.isManual(page);`, call `_lastReadSaver.onManualTurn()` when manual, then `setPage(page, byUser: manual)`. The existing page-stream listener keeps calling `schedule()`.
    - The in-place jump calls `rearm()` and never `onManualTurn()` (its echo is suppressed by the tracker).
    - Delete the post-frame restore that selected the last-read ayah.
    - `_onJumpToPage` calls `_lastReadSaver.rearm()`.
  - Callers per the table.

- [ ] **Step 4: Run** `flutter test test/features/surah test/features/bookmarks test/features/home`, then analyze and the full suite. Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/surah/domain/entities/last_read.dart lib/features/surah/data/models/last_read_hive_model.dart lib/features/surah/data/models/last_read_hive_model.g.dart lib/features/surah/data/repositories/last_read_repository_impl.dart lib/features/surah/presentation/pages/mushaf/last_read_saver.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart lib/features/bookmarks/presentation/pages/bookmarks_page.dart lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart test/features/surah/data/repositories/last_read_repository_impl_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart test/features/surah/presentation/pages/mushaf/mushaf_args_test.dart
git commit -m "fix(mushaf): jumps and peeks no longer overwrite last read; bookmarks reopen focused" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Player overlay and repeat options fixed in place

Ledger items 2, 6 (UI), 8 (options), 9, 10 (UI) and 11, plus the item 5 SnackBar.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`
- Modify: `lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`: the browse-bar builder (353-363)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart` (deliberate rewrites listed below)
- Modify: `test/features/quran_playback/presentation/widgets/playback_repeat_options_test.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart` (browse-bar case; it already pumps a full `MushafPage`)

**Interfaces:**
- Consumes: `PlaybackState.requestedAyah`, `error` and `retry()` (Task 3), `canSkipNext` and `canSkipPrevious` (Task 4), and `MushafState.selectedAyah`, `followPlayback`, `playingAyah`, `MushafCubit.resumeFollow()` and `playingPage` (Task 5a).
- New strings:

  | Key | ar | en |
  |---|---|---|
  | `mushaf_endRecitation` | 'إنهاء التلاوة' | 'End recitation' |
  | `mushaf_retry` | 'إعادة المحاولة' | 'Try again' |
  | `mushaf_audioError(String ayah)` | 'تعذّر تشغيل الآية $ayah' | 'Couldn\'t play ayah $ayah' |
  | `mushaf_nowReciting(String surah, String ayah, String page)` | 'يُتلى الآن: $surah $ayah، صفحة $page' | 'Now reciting: $surah $ayah, page $page' |
  | `mushaf_returnToReciting` | 'العودة إلى الآية المتلوّة' | 'Back to the recited ayah' |
  | `playback_repeatEachAyah` | 'تكرار كل آية' | 'Repeat each ayah' |
  | `playback_repeatPassage` | 'تكرار المقطع' | 'Repeat the passage' |
  | `playback_crossSurahRange(String from, String to)` | 'من $from إلى $to' | 'From $from to $to' |

  `playback_crossSurahRange` takes two preformatted ends so its signature stays on one line (Global Constraints). The caller passes `'$name ${ayah.toLocalized(context)}'` for each end, with `name` from `getSurahNameArabic` / `getSurahName` per `context.isArabic`. The ARB placeholders are `from` and `to`.

**Behaviour to pin:**
- **Visibility:** `selectedAyah != null || isOverlayPinned || (requestedAyah ?? currentAyah) != null`. This is the union, so tap-an-ayah-then-play still works and a recitation cannot be hidden. Keep the outer `BlocBuilder<MushafCubit>`, which provides the stable sheet context. Inside it, a `BlocSelector<PlaybackCubit, PlaybackState, bool>` gives `active = (requestedAyah ?? currentAyah) != null`.
- **Target:** `selectedAyah ?? requestedAyah ?? currentAyah`.
- **Rebuild rules.** The inner builders must rebuild on every field they now read, or a failed first play leaves a blank title and a range change leaves stale ⏮/⏭:
  - The target `BlocBuilder<PlaybackCubit, PlaybackState>` (today line 95): `buildWhen: (a, b) => a.currentAyah != b.currentAyah || a.requestedAyah != b.requestedAyah`.
  - The transport `BlocBuilder` (today lines 192-196) keeps its four conditions and adds `|| a.rangeStart != b.rangeStart || a.rangeEnd != b.rangeEnd || a.requestedAyah != b.requestedAyah`.
- **Leading button:**
  - While `active`, it is `Icons.stop` with tooltip `mushaf_endRecitation`. It calls `playback.stop()`, then `mushaf.unpinOverlay()`.
  - While idle, it is today's `Icons.expand_more` (`playback_close`), which calls `unpinOverlay()`.
  - Swipe-down dismisses only while idle.
- **Title:** `S.of(context).ayah_label(name, n.toLocalized(context))`.
  - `name` is `quran.getSurahNameArabic(s)` when `context.isArabic`, else `quran.getSurahName(s)`.
  - `n` is the ayah, with ayah 0 shown as 1 (playback starts there), so the title never reads «الآية ٠».
- **⏮ / ⏭:** enabled iff `canSkipPrevious` / `canSkipNext`. Replace `_isFirst` / `_isLast`. Each tap calls the skip, then `context.read<MushafCubit>().resumeFollow()` (Deliberate reading 8).
- **Play button:** after it calls `playRange`, it calls `context.read<MushafCubit>().resumeFollow()`.
- **Browse bar (`mushaf_page.dart:353-363`).** The player and the browse bar share the bottom of the `Stack`, and today the browse bar hides only for `highlightedAyah != null || isOverlayPinned`. Once the player also shows for `requestedAyah ?? currentAyah` (a page play, or an arrival from «تشغيل السورة»), both would draw. Wrap the browse bar's `SafeArea` in a `BlocSelector<PlaybackCubit, PlaybackState, bool>(selector: (p) => (p.requestedAyah ?? p.currentAyah) != null, …)` inside the existing `BlocBuilder<MushafCubit>`, and compute `playerVisible = state.selectedAyah != null || state.isOverlayPinned || active`, the same union as the overlay.
- **Error SnackBar:**
  - A `BlocListener<PlaybackCubit, PlaybackState>` with `listenWhen: (a, b) => b.error != null && a.error != b.error`.
  - Content: `PendingS.current.mushaf_audioError((b.requestedAyah ?? b.currentAyah)!.ayah.toLocalized(context))`.
  - `SnackBarAction(label: PendingS.current.mushaf_retry, onPressed: playback.retry)`.
- **Follow SnackBar:**
  - A `BlocListener<MushafCubit, MushafState>` with `listenWhen: (a, b) => a.followPlayback && !b.followPlayback && b.playingAyah != null`.
  - Content: `mushaf_nowReciting(surahName, ayah.toLocalized(context), mushaf.playingPage!.toLocalized(context))`.
  - Action `mushaf_returnToReciting` → `resumeFollow()`.
  - Both listeners wrap the overlay's returned `Positioned` child inside the `Stack`.
- **`PlaybackRepeatOptions`:**
  - It gains `final VoidCallback? onNewPlay` (`const PlaybackRepeatOptions({super.key, this.onNewPlay})`). The range-from editor calls `onNewPlay?.call()` after its `playRange`; the range-to editor does not (Deliberate reading 8). The widget stays in `quran_playback` and never reads `MushafCubit`. `_OptionsSheet` gains the same field and passes it down. `_openOptionsSheet(stableCtx)` captures `final mushaf = stableCtx.read<MushafCubit>();` before `showModalBottomSheet` (the sheet's subtree only provides `PlaybackCubit`) and builds `_OptionsSheet(onNewPlay: mushaf.resumeFollow)`.
  - Two ∞ toggles, keys `repeat-infinite-each` and `repeat-infinite-range`, one beside each repeat counter. `_InfiniteToggle` takes the key as a parameter (`required this.keyValue`, `key: ValueKey(keyValue)`) instead of today's hard-coded `'repeat-infinite'`. Each is `on` iff `infiniteRepeat && infiniteTarget == itsTarget`. A tap calls `setInfiniteRepeat(!thisOn, itsTarget)`.
  - Layout: the single repeat `Row` becomes two, so nothing overflows at 360 dp: `Row(spacing: 10, children: [Expanded(repeat-each counter), _InfiniteToggle(repeat-infinite-each)])`, then `SizedBox(height: 10)`, then `Row(spacing: 10, children: [Expanded(repeat-range counter), _InfiniteToggle(repeat-infinite-range)])`.
  - The counter labels become `playback_repeatEachAyah` and `playback_repeatPassage`, which replaces the duplicate «النطاق».
  - When `rangeStart != null && rangeEnd != null && rangeStart.surah != rangeEnd.surah`, hide `range-from` and `range-to` and show `Text(PendingS.of(context).playback_crossSurahRange(...), style: TS.medium14)`, with names and Arabic-Indic digits.

- [ ] **Step 1: Write failing tests (overlay test file, deliberate rewrites)**
  - `'hidden when idle with nothing selected or pinned'` replaces `'hidden when highlightedAyah is null'` and keeps its opacity and pointer asserts.
  - `'visible while audio plays with nothing selected'`: `PlaybackState(currentAyah: _target, isPlaying: true)` gives opacity 1.
  - `'visible while paused with nothing selected'`.
  - `'visible when the first play failed'`: `requestedAyah: _target, error: 'x'`.
  - `'stop button ends the recitation and hides the player'` replaces lines 206–221. Tap `find.byTooltip('End recitation')` and expect `p.stopped`, `m.state.selectedAyah == null` and opacity 0 after settle.
  - `'collapse button only appears while idle'`: idle → `Icons.expand_more`, playing → `Icons.stop` with no `expand_more`. This replaces `'overlay always shows expand_more'`.
  - `'pinned overlay: collapse unpins when idle'` replaces the pinned `expand_more` test, using an idle playback state.
  - `'pinned overlay falls back to currentAyah'` and `'shows label + play button'` now expect `'Surah Al Baqarah, Ayah 5'`.
  - `'title uses the surah name and Arabic-Indic digits'` in `Locale('ar')` expects `'سورة ${quran.getSurahNameArabic(2)}، الآية ٥'`.
  - `'skip buttons disabled when idle'` and `'skip next disabled at the range end'`, using `PlaybackState(currentAyah: 2:7, rangeStart: 2:5, rangeEnd: 2:7, isPlaying: true)`.
  - `'skip buttons follow a range change'`: pump with `currentAyah: 2:7, rangeStart: 2:5, rangeEnd: 2:7, isPlaying: true` (⏭ disabled), emit the same state with `rangeEnd: 2:10`, pump, and expect ⏭ enabled.
  - `'skip next re-arms follow'`: from `currentAyah: 2:5, isPlaying: true`, tap ⏭ and expect `m.resumed`.
  - `'title appears when the first play fails'`: pump idle with nothing selected, then emit `PlaybackState(requestedAyah: 2:5, error: 'x')` (`currentAyah` null), pump, and expect `'Surah Al Baqarah, Ayah 5'`.
  - `'audio error shows a SnackBar with retry'`. Emit an error state, expect `'Couldn\'t play ayah 5'`, tap `'Try again'`, and expect `p.retried`. Add `retry()` to `_FakePlayback`.
  - `'turning away shows now-reciting with a way back'`. The fake mushaf emits `followPlayback: false, playingAyah: 2:5`, and `playingPage` is stubbed through a fake override. Tap `'Back to the recited ayah'` and expect `m.resumed`.
  - Keep `play → playRange` and `paused → resume` as they are, and add `resumeFollow` recording to the fake. Keep the loading spinner test, which S3 replaces.
  - Repeat options: the four-counter test now finds `repeat-infinite-each` and `repeat-infinite-range`, with no `repeat-infinite`.
    - `'∞ beside each-ayah targets eachAyah'`: verify `setInfiniteRepeat(true, RepeatTarget.eachAyah)`.
    - `'∞ beside the passage targets range'`.
    - `'cross-surah range is read-only'`: `Locale('ar')`, range 4:176–5:2, expect `'من النساء ١٧٦ إلى المائدة ٢'` using `quran.getSurahNameArabic`, and `range-from` finds nothing.
    - `'range-from edit is a new play'`: pump `PlaybackRepeatOptions(onNewPlay: () => called++)`, tap `range-from`'s `Icons.add`, and expect `playRange` recorded and `called == 1`. Tapping `range-to`'s `Icons.add` leaves `called` at 1.
  - `mushaf_page_dispose_test.dart`, new case `'browse bar hides while a recitation is active'`: `MushafState(currentPage: 7, chromeVisible: true)` with `PlaybackState(requestedAyah: 2:5, isLoading: true)` → the `AnimatedOpacity` that is the nearest ancestor of `MushafBrowseBar` has opacity 0. With `const PlaybackState()` it has opacity 1.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart test/features/quran_playback/presentation/widgets test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** per "Behaviour to pin", plus the strings.

- [ ] **Step 4: Run** the scoped tests, `pending_s_test`, `typography_ratchet_test`, analyze, and the full suite. Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart test/features/quran_playback/presentation/widgets/playback_repeat_options_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
git commit -m "fix(playback): player stays while reciting, stop ends it, errors and follow surface" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Reader page fixes (running surah, whole-page play, banner actions, page-load retry)

Ledger items 1 (UI), 8 (play page), 12 and 15.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`: the top-bar builder (307-351) and `_onPlayPage` (244-265)
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`: the entity load (35, 46-51) and the `FutureBuilder` error branch. `_handleLongPress` is unchanged: it forwards the hit ayah, and the ayah-0 branch lives in `AyahActionPopover.show`.
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart`
- Modify: `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart:28`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/ayah_action_popover_test.dart`
- Modify: `test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`
- Create: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart`

**Interfaces:**
- Consumes: `MushafState.runningSurah`, `pageAyahs` and `resumeFollow()` (Task 5a), `pagePlaybackRange` (Task 1), and `mushaf_retry` (Task 7).
- New strings:

  | Key | ar | en |
  |---|---|---|
  | `mushaf_pageLoadFailed` | 'تعذّر تحميل الصفحة' | 'Couldn\'t load the page' |
  | `mushaf_playFromSurahStart` | 'استماع من بداية السورة' | 'Listen from the start of the surah' |

**Behaviour to pin:**
- **Top bar (item 1):**
  - `buildWhen` adds `currentPage`, `selectedAyah`, `playingAyah`, `pageAyahs` and `openedSurah`.
  - The surah name comes from `state.runningSurah`: `getSurahNameArabic` or `getSurahName` per `context.isArabic`, and `''` while null, i.e. bounds not loaded yet or an empty stub page.
  - `resolvePrintedChrome` is no longer used by the top bar. It stays for `MushafPrintedChrome` until S3.
- **`_onPlayPage` (item 8):**
  - `final range = pagePlaybackRange(_mushafCubit.state.pageAyahs); if (range == null) return; _mushafCubit.resumeFollow(); _playbackCubit.playRange(start: range.start, end: range.end);`.
  - It no longer selects an ayah or pins the overlay: the player shows through `requestedAyah` (Task 7).
- **Banner ayah (item 12):**
  - `AyahActionPopover.show` with `ayah.ayah == 0` shows a single `_ActionButton(icon: Icons.play_arrow, label: mushaf_playFromSurahStart)`.
  - It calls `playRange(start: (s,1), end: (s, quran.getVerseCount(s)))`, then `mushafCubit.resumeFollow()`, then dismisses.
  - The banner shows no tafsir, translation, bookmark or share actions.
  - `show` captures `PlaybackCubit` from the triggering context alongside the existing captures.
  - `BookmarkCubit.toggle` returns early when `ayah.ayah == 0`, so a bookmark on ayah 0 is impossible below the UI too.
- **Page-load failure (item 15):**
  - `_entityFuture` becomes a non-final field set by `_load()`.
  - In the `FutureBuilder`, `snapshot.hasError` renders, over the paper background, a centred `Column(spacing: 8)` with:
    - `Text(PendingS.of(context).mushaf_pageLoadFailed, style: TS.medium14.copyWith(color: paperColors.ink))`
    - `TextButton(onPressed: () => setState(() => _entityFuture = _load()), child: Text(PendingS.of(context).mushaf_retry, style: TS.medium14))`
  - The tap layer is not built in that state.

- [ ] **Step 1: Write failing tests**
  - `ayah_action_popover_test.dart`: keep the two placement tests. Add a widget test in `Locale('en')` with `BookmarkCubit`, `MushafCubit` (fake with `noSuchMethod`) and `PlaybackCubit` (recording fake) providers:
    - `'banner long-press offers only listen from the start'`: show for (2,0) → `'Listen from the start of the surah'` is found, and `'Bookmark'` and `'Share'` find nothing. Tapping it records `playRange(2:1, 2:286)`.
    - `'ayah long-press keeps its four actions'` for (2,5).
  - `bookmark_cubit_test.dart`: `'toggle ignores ayah 0'` → `verifyNever(toggleBookmark(...))`, and the state is unchanged.
  - `mushaf_page_view_load_error_test.dart`: set up sl and providers as `mushaf_page_dispose_test.dart` does. `GetMushafPage` wraps a repo whose first call returns `Left(CacheFailure('x'))` and second returns `Right(MushafPageEntity(pageNumber: 1, ayahs: const []))`. Pump `MushafPageView(pageNumber: 1)` and expect `'Couldn\'t load the page'`. Tap `'Try again'`, pump, and expect it gone.
  - Running surah and whole-page play: their rules are pinned in Task 1 (`resolveRunningSurah`, `pagePlaybackRange`) and Task 5a (`runningSurah` getter). This step adds no new `MushafPage` widget test, and the dispose test keeps passing with the empty stub page.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf test/features/bookmarks`. Expected: FAIL.

- [ ] **Step 3: Implement** per "Behaviour to pin", plus the strings.

- [ ] **Step 4: Run** the scoped tests, `pending_s_test`, `typography_ratchet_test`, analyze, and the full suite. Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/ayah_action_popover_test.dart test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart
git commit -m "fix(mushaf): right surah in the top bar, whole-page play, banner-only actions, page-load retry" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Ledger coverage

| Item | Task | Item | Task |
|---|---|---|---|
| 1 running surah | 1, 5a, 8 | 11 ∞ per counter | 7 |
| 2 stop ends recitation | 7 | 12 ayah 0 actions | 8 |
| 3 surah play as range, clamp, stop clears range | 4, 7 | 13 bookmark focus | 6 |
| 4 player survives auto page turn | 5a, 5b, 7 | 14 Equatable state | 3 |
| 5 follow rule + SnackBar | 5a, 5b, 7 | 15 page-load retry | 8 |
| 6 requestedAyah, persistent error, retry, download cleanup | 3, 7 | 16 sajda | deferred (spec) |
| 7 ٠–٩ page jump | 1 | 17 last-read guard + updatedAt | 6 |
| 8 whole-page play, cross-surah read-only | 1, 4, 7, 8 | 18–19 | S4 |
| 9 player title | 7 | 20 juz/hizb at last ayah | 1 |
| 10 ⏮/⏭ disabled | 4, 7 | §2 paper colours | 2 |
