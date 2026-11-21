# Mushaf S3 (reader shell: running head, foot band, ayah leaf, player leaf, القائمة, العرض) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hide-on-tap reader chrome with an always-visible running head and foot band printed on the paper, one labelled ayah leaf and one player leaf in the same non-modal slot, the «القائمة» and «العرض» sheets, a notice chip, keep-awake, and the corrected sajda map.

**Architecture:** Pure rules in `surah/presentation/utils/` (`listenRange`, `playbackScope`, `leafSlide`, `readerNotice`, `resolveMenuQuery`) decide what the shell shows. `MushafCubit` gains `jumpFrom`, `jumpTo` and `select`, and loses `chromeVisible`, `isOverlayPinned` and `highlightedAyahCenterY`. `MushafPage` becomes a `Column` (head, page area, foot) whose page area stacks the page view under one overlay column (notice chip, then the leaf slot). Leaf visibility is derived: `selectedAyah != null` shows `AyahLeaf`, else `(requestedAyah ?? currentAyah) != null` shows `PlayerLeaf`. The five S1 widgets, the printed QCF chrome and their tests are deleted and replaced by tested successors.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), flutter_bloc + bloc_test, mocktail, equatable, hive_ce, hugeicons 4.4.0, share_plus, `wakelock_plus` (new, 1.x), the vendored `quran` package (`quran-1.4.1/`).

**Spec:** `docs/superpowers/specs/2026-11-21-mushaf-leaf-ribbon-design.md`: §3 in full (3.1–3.8, scroll mode, the §3.8 deletions), the S3 parts of ledger items 5 and 6, ledger item 16 (the owner reported it, so S3 fixes it now), D6's S3 entry points, §1A in-place jumps, and the §7 S3 rows. Where the spec and this plan disagree, the spec wins, except for the **Deliberate readings** below, where the plan governs. Raise any other disagreement in the task report.

## Global Constraints

- Work on `feature/mushaf-s3-shell`. Never switch branches, never touch `main`, never push, never rebase, never amend.
- Never stage, edit or revert `quran-1.4.1/analysis_options.yaml`, `quran-1.4.1/pubspec.lock`, `test/core/arabic_normalizer_test.dart`, `test/core/utils/calculation_method_for_country_test.dart` or `test/core/widgets/last_quran_read_test.dart`. In `quran-1.4.1/` only `lib/sajdah_verses.dart` may change.
- Commits: stage explicit paths only (never `git add -A` or `git add .`; deletions with `git rm`, renames with `git mv`). Conventional message (`feat|fix|refactor|test|build(scope): …`) ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No comments and no doc comments in new or changed code. No redundant type annotations. Lean code. A user comment inside lines a task replaces goes with them; one a task makes false gets the smallest correction, named in the report.
- New strings: add each to both `lib/l10n/intl_ar.arb` and `lib/l10n/intl_en.arb` (a `"@key": {"placeholders": {"x": {"type": "String"}}}` block per placeholder) and mirror it in `lib/core/localization/pending_s.dart` as `String get key => _ar ? '…' : '…';` or `String key(String a) => _ar ? '… $a' : '… $a';` (single quotes, `String` parameters only, at most three, signature on one line after `dart format`, numbers preformatted). Read with `PendingS.of(context)` in `build`, `PendingS.current` in callbacks. `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`; never run `intl_utils:generate`. Reuse an existing `S` key when its text is exactly the spec's text.
- Arabic numbers use Arabic-Indic digits via `toLocalized(context)` / `toIndicNumerals(localeCode)`.
- Colours: paper surfaces (head, foot, leaves, chip, page) read `MushafPaperX.colors` (`background`, `ink`, `ink2`, `accent`, `leaf`); app surfaces (القائمة, العرض, options sheet) and every primary action read `context.colorScheme`. Hex literals only where `theming.md` allows. Text styles only `TS.*`; `test/config/theme/typography_ratchet_test.dart` must not rise (Task 8c lowers its baseline).
- Icons (`icons.md`, one set per bar): the head, foot, ayah leaf and notice chip use HugeIcons (`backArrowIcon` / `forwardArrowIcon` for arrows); the player leaf, the playback options sheet and `SurahDownloadButton` keep Material `Icons.*`.
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`; never modify `assets/mushaf/**`.
- Every task ends at baseline or better: `flutter analyze --no-fatal-infos` = 0 errors, 0 warnings, ≤ 69 infos; `flutter test` = 1174 at start plus the tests this plan adds minus the tests it deletes, all pass, 1 skipped. `dart format` touched Dart files.
- Rule catalogues (`feature-widgets.md`, `core-utilities.md`, `theming.md`, `icons.md`) change in the task that changes what they describe.

## Deliberate readings (the plan governs here)

1. **The sajda fix leaves `quran.dart` untouched.** `isSajdahVerse` is `sajdahVerses[surahNumber] == verseNumber`, and a `Map<int, int>` cannot hold 22:18 and 22:77. `sajdah_verses.dart` keeps the name `sajdahVerses` but makes it a const index whose `[surah]` returns an object that compares equal to each sajda ayah of that surah (Task 2). `[]` returns `Object?`, so the comparison in `quran.dart` raises no `unrelated_type_equality_checks`.
2. **«عند الضغط على الآية» is not drawn in S3.** The spec hides it until S5, so S3 stores `tapAction` (Task 1) and draws no control for it.
3. **Long-press selects and never deselects** (`MushafCubit.select`). A tap toggles.
4. **Selecting an ayah marks `hintSeen`.** The reader has done what the hint teaches.
5. **«استماع من هنا» and the foot's «استماع» clear the selection**, so the player leaf takes the slot at once.
6. **The head's back leaves the reader; system Back closes an open leaf first** (`PopScope(canPop: selectedAyah == null)`).
7. **`jumpFrom` keeps the first origin across chained jumps**, and a jump back to it clears it. The return chip is `jumpTo(jumpFrom)`, which therefore clears it.
8. **Arrival with a recitation on another page starts listening-away.** `MushafCubit`'s constructor sets `followPlayback: false` when the playing page differs from the arrival page. The notification tap arrives on the playing page, so it still follows (§4).
9. **The notice chip and the leaf share one overlay column** bottom-anchored over the page area, directly above the foot band. One notice at a time: return-to-page, else the download hint, else the first-open hint. The bounded slide uses the whole column's measured height.
10. **Scroll mode slides by scrolling.** `Scrollable.ensureVisible` needs a per-ayah context the 604-item `ListView` does not have, so scroll mode calls `_scrollController.animateTo(offset + need)`, with the same result. The selected ayah is measured on its own page (`QuranPageService.getPageForAyah`), not on `currentPage`: one scroll item is taller than the viewport, so the ayat under the leaf are usually on `currentPage + 1`. That page's bounds are `state.pageAyahs` when it is the current page, else `sl<GetMushafPage>()(page)`. The slide also runs once on arrival with a selection (§1A `focusAyah`).
11. **The download hint chip downloads the playing surah when tapped** (S2 reading 7) and marks `downloadHintSeen`. «فهمت» only marks it.
12. **The player's primary button is disabled while loading.** A pause during loading is overwritten when `_playAyah` emits `isPlaying: true` (S2 reading 13).
13. **The player subtitle scope** is «حتى نهاية السورة» when the range runs from one surah to that surah's last ayah, «حتى نهاية الصفحة» when the range end is the last ayah of its page (including cross-surah page ranges), else the reciter's name alone.
14. **Speed chips use Arabic-Indic digits and the Arabic decimal separator** («١٫٢٥×»), fixing the audit's Latin «1.25x». `toLocalized` only swaps digits, so `speedLabel` (Task 6) also drops a trailing `.0` and turns `.` into U+066B «٫» in Arabic. The chips read «٠٫٥×», «٠٫٧٥×», «١×», «١٫٢٥×», «١٫٥×», «٢×» in Arabic and '0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×' in English.
15. **`ScreenWake.set` swallows platform errors**, so a device or test without the plugin keeps working.
16. **`SurahDownloadButton` gains `labelled: true`** for the player leaf chip instead of a second widget; the «القائمة» rows use the icon form.
17. **The download hint is missing between Task 8b and Task 9.** Task 8b takes `AyahPlaybackOverlay`, which owns the S2 SnackBar, out of the reader (8c deletes it); Task 9 brings the hint back as a chip.
18. **The head and the foot are fixed 64 px bands.** Spec §3.1 says the head is 48 px, 64 at large text, but §3 also says the page box never changes size or position between text scales. A head that grows from 48 to 64 shrinks the page area, so the head reserves its 64 px at every scale (a 60 px row over a 4 px double hairline); its contents fit by `maxLines: 1` with ellipsis and a capped khatam. The foot is the spec's 64 px, fixed; its pill labels scale down to fit. Only the leaves grow with the text scaler.
19. **Between Task 8a and Task 8b the S1 bars cannot be raised by a tap.** 8a gives taps their final meaning (hit toggles, blank clears), so nothing calls `setChrome(true)`; `chromeVisible` defaults to false. A tap still selects and opens the S1 overlay, and no test pins the old toggle. 8b replaces the bars.
20. **The page-bookmark toggle goes away in S3.** It lived only in `MushafBrowseBar`. The spec's non-goals list «a page-bookmark control after S3»; `MushafPageRibbon` stays on the page as before (S4 deletes it with the migration), and `PageBookmarkCubit` stays provided for it.
21. **An audio error hides the download hint** (S2 rule kept: «an audio error replaces the hint»). `readerNotice` takes `audioError` and returns no `DownloadHintNotice` while it is true; the player leaf's inline error is then the only notice about audio.
22. **«القائمة» search results take the page's juz at its last real ayah**, the rule `QuranMetaService.getPageMeta` uses for the running head, so the row «صفحة ٦٢، …، الجزء …» names the same juz as the head on the page it jumps to.

## Review Focus

1. **System Back with a leaf open.** The first Back closes the leaf, the second leaves the reader; the head's back always leaves, in one tap. Task 8b pins all three on a reader pushed over a base route.
2. **Re-entering the reader while a recitation plays elsewhere.** The player leaf shows listening-away and the page is not yanked on the next ayah. Task 3 pins the cubit rule; Task 8b pins the widget.
3. **A jump, then leaving.** After a «القائمة» jump or the return chip, disposing the reader must not overwrite last read (the guard re-arms), and a manual turn removes the chip. Task 9 pins both.
4. **Large text (1.3× and 2×).** The head and the foot stay 64 px (Deliberate reading 18), the leaves grow without overflow, and the page box keeps its size. Tasks 4, 5 and 6 pump each widget at `TextScaler.linear(2.0)` in 360 px and assert no exception; Task 8b compares the page `AspectRatio` size at 1× and 2×.
5. **Search input variants in «القائمة».** Mixed digit sets («٥8٢»), hamza-less names («الاسراء»), surrounding spaces, `0` and `605`. Task 2 pins each.

## Out of slice

- S4: فواصل ribbons and tail tabs, saved ayat, the «أماكني» sheet (S3's «أماكني» tile pushes `AppRouter.bookmarksPath`), the migration; `MushafPageRibbon` and `PageBookmarkCubit` stay on the page.
- S5: the tafsir lead line, «تفسير الآية», the full detent, the «عند الضغط على الآية» control.
- Design-only details the spec does not adopt: the margin pencil bar, the headphones seal, zoom, the first-open dashed outline. Highlights keep today's tint painter (§3).

---

### Task 1: Settings fields, brightness floor and keep-awake plumbing

**Files:**
- Create: `lib/core/constants/leaf_tap_action.dart`, `lib/core/utils/screen_wake.dart`
- Modify: `pubspec.yaml`, `pubspec.lock` (via `flutter pub add`)
- Modify: `lib/features/settings/domain/entities/settings.dart`, `lib/features/settings/data/models/settings_model.dart`, `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart` (slider `min`)
- Modify: `.claude/rules/core-utilities.md`
- Test: `test/features/settings/data/models/settings_model_test.dart`, `test/features/settings/presentation/cubit/settings_cubit_test.dart`

**Interfaces:**
- Produces: `enum LeafTapAction { meaning, options }`; `Settings.tapAction` (default `meaning`), `Settings.hintSeen` (default `false`), `Settings.keepScreenOn` (default `true`), `Settings.minPageBrightness == 0.6`; `SettingsCubit.updateTapAction(LeafTapAction)`, `SettingsCubit.markHintSeen()`, `SettingsCubit.updateKeepScreenOn(bool)`; `class ScreenWake { const ScreenWake(); Future<void> set(bool on); }`.

- [ ] **Step 1: Write the failing tests**

In `settings_model_test.dart`, rewrite the low-brightness assert (the floor moves to 0.6 per §3.6) and add a group:

```dart
expect(low.pageBrightness, 0.6);

group('reader settings', () {
  test('missing keys fall back to meaning, hint unseen, screen kept on', () {
    final m = SettingsModel.fromMap({'isArabic': true, 'isFormat12Hours': false});
    expect(m.tapAction, LeafTapAction.meaning);
    expect(m.hintSeen, isFalse);
    expect(m.keepScreenOn, isTrue);
  });
  test('a non-bool keepScreenOn falls back to on', () {
    final m = SettingsModel.fromMap({'isArabic': true, 'isFormat12Hours': false, 'keepScreenOn': 'yes'});
    expect(m.keepScreenOn, isTrue);
  });
  test('an unknown tapAction name falls back to meaning', () {
    final m = SettingsModel.fromMap({'isArabic': true, 'isFormat12Hours': false, 'tapAction': 'bogus'});
    expect(m.tapAction, LeafTapAction.meaning);
  });
  test('round-trips through toMap', () {
    final m = SettingsModel(isArabic: true, isFormat12Hours: false, tapAction: LeafTapAction.options, hintSeen: true, keepScreenOn: false);
    final back = SettingsModel.fromMap(m.toMap());
    expect((back.tapAction, back.hintSeen, back.keepScreenOn), (LeafTapAction.options, true, false));
    expect(m.toMap()['tapAction'], 'options');
  });
});
```

In `settings_cubit_test.dart`, rename and rewrite `'updatePageBrightness clamps to [0.3, 1.0]'` to `'updatePageBrightness clamps to [0.6, 1.0]'` (`updatePageBrightness(0.1)` → `0.6`; `0.7` stays `0.7`), and add `'markHintSeen sets the flag once'` (two calls, one emitted state), `'updateKeepScreenOn stores the switch'` (`false` → `keepScreenOn` false), `'updateTapAction stores the choice'`.

- [ ] **Step 2: Run** `flutter test test/features/settings`. Expected: FAIL (`tapAction` undefined).

- [ ] **Step 3: Implement**

- `flutter pub add wakelock_plus`. Expected: a `^1.x` constraint in `pubspec.yaml`, no downgrade of other packages.
- `leaf_tap_action.dart`: the enum, beside `mushaf_reading_mode.dart`.
- `Settings`: the three fields in the constructor, `copyWith` and `props`; `minPageBrightness = 0.6`. `SettingsModel`: `super.` params, `copyWith`, `fromMap` (`tapAction` by name with `orElse: () => LeafTapAction.meaning`; `hintSeen: _readBool(map['hintSeen'])`; `keepScreenOn: _readBool(map['keepScreenOn'], true)`, so a stored non-bool falls back instead of throwing and resetting every setting through `SettingsCubit.fromJson`), `toMap` (`'tapAction': tapAction.name`, `'hintSeen'`, `'keepScreenOn'`).
- `SettingsCubit`: the three methods, shaped like `markDownloadHintSeen` (no emit when unchanged).
- `ScreenWake.set(on)`: `try { await WakelockPlus.toggle(enable: on); } catch (_) {}`.
- `reading_settings_sheet.dart`: `Slider(min: Settings.minPageBrightness, …)` so a stored 0.6 never sits below the slider.
- `core-utilities.md` → `## Services`: one line for `ScreenWake` (`core/utils/screen_wake.dart`): keeps the screen on through `wakelock_plus`, never throws. `## Constants`: add `LeafTapAction` after `MushafReadingMode`.

- [ ] **Step 4: Run** `flutter test test/features/settings test/features/surah`, then `flutter analyze --no-fatal-infos`. Expected: PASS, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/constants/leaf_tap_action.dart lib/core/utils/screen_wake.dart lib/features/settings/domain/entities/settings.dart lib/features/settings/data/models/settings_model.dart lib/features/settings/presentation/cubit/settings_cubit.dart lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart .claude/rules/core-utilities.md test/features/settings/data/models/settings_model_test.dart test/features/settings/presentation/cubit/settings_cubit_test.dart
git commit -m "feat(settings): tapAction, hintSeen, keepScreenOn and a 0.6 brightness floor

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Pure reader rules, menu search and the sajda map

**Files:**
- Modify: `quran-1.4.1/lib/sajdah_verses.dart`
- Create: `lib/features/surah/presentation/utils/reader_rules.dart`, `lib/features/surah/presentation/utils/menu_query.dart`
- Modify: `.claude/rules/feature-widgets.md` (surah utils line)
- Test: `test/quran_package/sajdah_verses_test.dart`, `test/features/surah/presentation/utils/reader_rules_test.dart`, `test/features/surah/presentation/utils/menu_query_test.dart`

**Interfaces:**
- Produces (all top-level, pure):
  - `const sajdahPositions = <(int, int)>{…15}`; `quran.isSajdahVerse(s, a)` true exactly for them.
  - `({AyahIdentifier start, AyahIdentifier end})? listenRange({AyahIdentifier? selected, required List<AyahBoundEntity> ayahs})`
  - `enum PlaybackScope { none, surahEnd, pageEnd }`; `PlaybackScope playbackScope(AyahIdentifier? start, AyahIdentifier? end)`
  - `double? lineBottomOf(List<AyahBoundEntity> ayahs, AyahIdentifier? ayah)`; `double leafSlide({required Size area, required double lineBottom, required double overlay})`
  - `sealed class ReaderNotice extends Equatable` with `final class ReturnToPageNotice(int page)`, `final class DownloadHintNotice(int surah)`, `final class TapHintNotice()`; `ReaderNotice? readerNotice({int? jumpFrom, int? downloadHintSurah, required bool hintSeen, bool audioError = false})`
  - `sealed class MenuQuery extends Equatable` with `MenuQueryNone()`, `MenuQueryOutOfRange()`, `MenuQueryTarget({required int page, required int surah, required int juz})`; `MenuQuery resolveMenuQuery(String raw)`

- [ ] **Step 1: Write the failing tests**

`sajdah_verses_test.dart` (imports `package:quran/quran.dart` as `quran`):

```dart
const expected = {(7, 206), (13, 15), (16, 50), (17, 109), (19, 58), (22, 18), (22, 77), (25, 60), (27, 26), (32, 15), (38, 24), (41, 38), (53, 62), (84, 21), (96, 19)};
test('isSajdahVerse is true at exactly the 15 sajda ayat', () {
  final hits = <(int, int)>{};
  for (var s = 1; s <= 114; s++) {
    for (var a = 1; a <= quran.getVerseCount(s); a++) {
      if (quran.isSajdahVerse(s, a)) hits.add((s, a));
    }
  }
  expect(hits, expected);
});
test('the old wrong positions are not sajdas', () {
  for (final (s, a) in [(16, 49), (17, 107), (27, 25), (41, 37)]) {
    expect(quran.isSajdahVerse(s, a), isFalse, reason: '$s:$a');
  }
});
```

`reader_rules_test.dart` (bounds built as `AyahBoundEntity(ayah: …, lines: [NormalizedRect(x: 0, y: y, w: 1, h: 0.05)])`):
- `listenRange`: selected 3:7 → `(3:7, 3:200)`; selected banner 5:0 → `(5:1, 5:120)`; nothing selected on p.106 bounds (4:176, 5:0, 5:1, 5:2) → `(4:176, 4:176)`; nothing selected and no bounds → `null`.
- `playbackScope`: `(3:7, 3:200)` → `surahEnd`; `(4:176, 5:2)` → `pageEnd`; `(112:1, 114:6)` → `pageEnd`; `(2:6, 2:16)` → `pageEnd` (p.3 is 2:6–2:16 in `page_data.dart`); `(2:5, 2:20)` → `none`; `(null, null)` → `none`.
- `lineBottomOf`: an ayah with lines at y 0.40 and 0.45 (h 0.05) → `0.50`; an absent ayah → `null`.
- `leafSlide` with `overlay: 168`: in `Size(390, 651)` (page 357.8 × 651, top 0) `lineBottom: 0.5` → `0`, `lineBottom: 0.8` (bottom 520.8, visible bottom 483) → `closeTo(37.8, 0.01)`, `lineBottom: 1.0` → `closeTo(168, 0.01)`; in `Size(390, 800)` (page 390 × 709.7, top 45.2) `lineBottom: 0.95` → `closeTo(87.35, 0.05)`, `lineBottom: 0.5` → `0`.
- `readerNotice`: `jumpFrom: 50, downloadHintSurah: 3, hintSeen: false` → `ReturnToPageNotice(50)`; `downloadHintSurah: 3, hintSeen: false` → `DownloadHintNotice(3)`; `downloadHintSurah: 3, hintSeen: true, audioError: true` → `null`; `downloadHintSurah: 3, hintSeen: false, audioError: true` → `TapHintNotice()`; `jumpFrom: 50, audioError: true, hintSeen: true` → `ReturnToPageNotice(50)`; `hintSeen: false` → `TapHintNotice()`; `hintSeen: true` → `null`.

`menu_query_test.dart`:
- `''` and `'   '` → `MenuQueryNone()`; `'xyz'` → `MenuQueryNone()`.
- `'582'`, `'٥٨٢'`, `'٥8٢'`, `' 582 '` → `MenuQueryTarget(page: 582, surah: 78, juz: 30)`.
- `'0'`, `'605'`, `'٦٠٥'` → `MenuQueryOutOfRange()`.
- `'الكهف'` → `MenuQueryTarget(page: 293, surah: 18, juz: 15)`; `'الاسراء'` → surah 17, page `quran.getPageNumber(17, 1)`; `'kahf'` → surah 18.
- `'the juz matches the running head on mid-page juz starts'`: for each of `62, 121, 201, 502`, `(resolveMenuQuery('$p') as MenuQueryTarget).juz == QuranMetaServiceImpl(pageService: QuranPageServiceImpl()).getPageMeta(p).juz` (Deliberate reading 22).

- [ ] **Step 2: Run** `flutter test test/quran_package/sajdah_verses_test.dart test/features/surah/presentation/utils`. Expected: FAIL (new symbols undefined; sajda set wrong).

- [ ] **Step 3: Implement**

`sajdah_verses.dart` (Deliberate reading 1):

```dart
const sajdahPositions = {(7, 206), (13, 15), (16, 50), (17, 109), (19, 58), (22, 18), (22, 77), (25, 60), (27, 26), (32, 15), (38, 24), (41, 38), (53, 62), (84, 21), (96, 19)};

const sajdahVerses = SajdahVerses._();

final class SajdahVerses {
  const SajdahVerses._();
  Object? operator [](int surah) => _SurahSajdahs(surah);
}

final class _SurahSajdahs {
  const _SurahSajdahs(this.surah);
  final int surah;
  @override
  bool operator ==(Object other) => other is int && sajdahPositions.contains((surah, other));
  @override
  int get hashCode => surah.hashCode;
}
```

`reader_rules.dart`:
- `listenRange`: start = `selected` (ayah 0 → ayah 1 of that surah), else the first bound with `ayah > 0`; end = `AyahIdentifier(surah: start.surah, ayah: quran.getVerseCount(start.surah))`.
- `playbackScope`: `none` when either is null; `surahEnd` when `start.surah == end.surah && end.ayah == quran.getVerseCount(end.surah)`; `pageEnd` when `end` is the last entry of `quran.getPageData(quran.getPageNumber(end.surah, end.ayah))` (`last['surah'] == end.surah && last['end'] == end.ayah`); else `none`. Check `surahEnd` first.
- `lineBottomOf`: the max `y + h` over the matching bound's lines.
- `leafSlide`:

```dart
final pageHeight = math.min(area.height, area.width / mushafPageAspect);
final bottom = (area.height - pageHeight) / 2 + lineBottom * pageHeight;
return (bottom - (area.height - overlay)).clamp(0.0, overlay);
```

  `mushafPageAspect` is `1536 / 2795`; declare it here as a top-level `const` (Task 8a's page view imports it).
- `readerNotice`: the priority of Deliberate reading 9; `downloadHintSurah` counts only while `!audioError` (Deliberate reading 21).

`menu_query.dart`: trim; if `int.tryParse(toAsciiDigits(q))` parses, `1..604` → target for that page, else `MenuQueryOutOfRange()`. A page target's surah is the page's first real entry (the first `getPageData(page)` entry that is not `start == 0 && end == 0`); its juz is `quran.getJuzNumber(surah, end)` of the page's last entry with `end > 0`, the rule `QuranMetaServiceImpl._lastAyahOfPage` uses (Deliberate reading 22). Otherwise the first surah 1..114 whose `normalizeArabic(quran.getSurahNameArabic(s))` contains `normalizeArabic(q)`, or whose `quran.getSurahName(s).toLowerCase()` contains `q.toLowerCase()`, → `MenuQueryTarget(page: quran.getPageNumber(s, 1), surah: s, juz: <the juz of that page, same rule>)`; no match → `MenuQueryNone()`. One private `_target(int page, int surah)` builds both.

`feature-widgets.md` → surah utils: add `reader_rules.dart` (`listenRange`, `playbackScope`, `lineBottomOf`, `leafSlide`, `mushafPageAspect`, `readerNotice`) and `menu_query.dart` (`resolveMenuQuery`).

- [ ] **Step 4: Run** the Step 2 command, then `flutter analyze --no-fatal-infos` (no new issue in `quran-1.4.1/`). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add quran-1.4.1/lib/sajdah_verses.dart lib/features/surah/presentation/utils/reader_rules.dart lib/features/surah/presentation/utils/menu_query.dart .claude/rules/feature-widgets.md test/quran_package/sajdah_verses_test.dart test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/utils/menu_query_test.dart
git commit -m "fix(quran): the 15 sajda ayat, plus pure reader-shell rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: MushafCubit: `jumpFrom`, `jumpTo`, `select`, listening-away on arrival

**Files:**
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`, `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Test: `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart`

**Interfaces:**
- Produces: `MushafState.jumpFrom` (`int?`, in `props`), `copyWith(int? jumpFrom, bool clearJumpFrom = false)`; `MushafCubit.jumpTo(int page)`, `MushafCubit.select(AyahIdentifier ayah)`. `setPage(byUser: true)` clears `jumpFrom`; `setPage(byUser: false)` keeps it.

- [ ] **Step 1: Write the failing tests** (add to `mushaf_cubit_auto_follow_test.dart`; give its page-service stub a settable page per ayah if it has none)

```dart
group('in-place jumps', () {
  test('jumpTo records where the reader came from and clears selection', () {
    final c = cubit(page: 50)..toggleSelection(const AyahIdentifier(surah: 3, ayah: 7));
    c.jumpTo(582);
    expect((c.state.currentPage, c.state.jumpFrom, c.state.selectedAyah), (582, 50, null));
  });
  test('a second jump keeps the first origin', () {
    final c = cubit(page: 50)..jumpTo(582)..jumpTo(300);
    expect(c.state.jumpFrom, 50);
  });
  test('jumping back to the origin clears jumpFrom', () {
    final c = cubit(page: 50)..jumpTo(582)..jumpTo(50);
    expect(c.state.jumpFrom, isNull);
  });
  test('a manual turn clears jumpFrom, a follow turn keeps it', () {
    final c = cubit(page: 50)..jumpTo(582)..setPage(583, byUser: false);
    expect(c.state.jumpFrom, 50);
    c.setPage(584, byUser: true);
    expect(c.state.jumpFrom, isNull);
  });
});
test('select never deselects', () {
  final c = cubit(page: 2);
  const a = AyahIdentifier(surah: 2, ayah: 5);
  c..select(a)..select(a);
  expect(c.state.selectedAyah, a);
});
test('arriving while the playing ayah is on another page starts listening-away', () {
  final c = cubit(page: 52, playing: const AyahIdentifier(surah: 3, ayah: 12), playingPage: 51);
  expect(c.state.followPlayback, isFalse);
});
test('arriving on the playing page keeps following', () {
  final c = cubit(page: 51, playing: const AyahIdentifier(surah: 3, ayah: 12), playingPage: 51);
  expect(c.state.followPlayback, isTrue);
});
```

`cubit` is a new helper beside the file's existing `_cubit(_FakeNotifier n, {int page = 1, int playingPage = 1})` (line 34), which the existing tests keep using:

```dart
MushafCubit cubit({int page = 1, AyahIdentifier? playing, int playingPage = 1}) {
  final c = _cubit(_FakeNotifier()..value = playing, page: page, playingPage: playingPage);
  addTearDown(c.close);
  return c;
}
```

(`_FakeNotifier()` is `ValueNotifier<AyahIdentifier?>` with `super(null)`, so the cascade presets it before the constructor reads it.)

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/cubit`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `jumpTo(page)`: `final origin = state.jumpFrom ?? state.currentPage;` then the same emit as `setPage(page, byUser: true)` plus `jumpFrom: page == origin ? null : origin` (use `clearJumpFrom` for the null case), then `_loadPageAyahs(page)`. Share the byUser branch with `setPage` through one private helper so the two cannot drift.
- `select(ayah)`: emit only when `state.selectedAyah != ayah`.
- Constructor, after the first `_onPlayingAyahChanged()`: `if (playingPage != null && playingPage != state.currentPage) emit(state.copyWith(followPlayback: false));`.

- [ ] **Step 4: Run** `flutter test test/features/surah`. Expected: PASS (the S1 follow tests stay green).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart
git commit -m "feat(mushaf): in-place jumps remember their origin; arrival away from the recitation stops following

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: RunningHead, KhatamMedallion, ReaderFoot, NoticeChip

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/khatam_medallion.dart`, `running_head.dart`, `reader_foot.dart`, `notice_chip.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/khatam_medallion_test.dart`, `running_head_test.dart`, `reader_foot_test.dart`, `notice_chip_test.dart`

**Interfaces:**
- Produces:
  - `KhatamMedallion({required String label, required MushafPaperColors colors})`
  - `RunningHead({required String surahName, required int page, required int juz, required int hizb, required MushafPaperColors colors, required VoidCallback onBack, required VoidCallback onOpenMenu})`
  - `ReaderFoot({required MushafPaperColors colors, required VoidCallback? onPrevious, required VoidCallback? onNext, required VoidCallback? onListen, required VoidCallback onMenu})`
  - `NoticeChip({required String label, required VoidCallback onTap, required MushafPaperColors colors, String? actionLabel, VoidCallback? onAction})`
  - Strings (key: ar / en): `head_juzHizb(juz, hizb)`: «الجزء $juz، الحزب $hizb» / 'Juzʼ $juz, hizb $hizb'; `foot_listen`: «استماع» / 'Listen'; `foot_menu`: «القائمة» / 'Menu'; `foot_previousPage`: «الصفحة السابقة» / 'Previous page'; `foot_nextPage`: «الصفحة التالية» / 'Next page'; `notice_returnToPage(page)`: «العودة إلى صفحة $page» / 'Back to page $page'; `notice_tapHint`: «اضغط على أي آية لترى معناها وأزرارها» / 'Tap any ayah to see its meaning and actions'; `notice_gotIt`: «فهمت» / 'Got it'.
  - Keys: `head-back`, `head-surah`, `head-juz`, `foot-previous`, `foot-listen`, `foot-menu`, `foot-next`, `notice-chip`, `notice-action`.

- [ ] **Step 1: Write the failing tests** (pump inside `MaterialApp` with the `S` delegates, `locale: Locale('ar')`, colours `MushafPaper.cream.colors`)

- `khatam_medallion_test`: shows `'٦٠٤'`; its `RenderBox` width ≤ 56 at 1× and at `TextScaler.linear(2.0)`, with no exception at 2×; the `CustomPaint` painter repaints when the colour changes (`shouldRepaint` true for night vs cream).
- `running_head_test` (pumped in a 360 px wide `SizedBox` at the top of a `Column`): `surahName: 'آل عمران', page: 50, juz: 3, hizb: 5` shows «آل عمران», «٥٠» and «الجزء ٣، الحزب ٥»; tapping `head-back` calls `onBack`; tapping `head-surah` and `head-juz` each calls `onOpenMenu`; `tester.getSize(find.byType(RunningHead)).height == 64` at 1×, 1.3× and 2× (the hairline included) with `tester.takeException()` null; at 2× with `surahName: 'الأحزاب'` and `juz: 30, hizb: 60` the surah and juz `Text`s have `maxLines: 1`.
- `reader_foot_test` (360 px wide): the four controls exist with keys and tooltips «الصفحة السابقة» / «الصفحة التالية»; «استماع» and «القائمة» labels show; each tap calls its callback; `onPrevious: null` disables `foot-previous` (`IconButton.onPressed == null`) and `onListen: null` disables `foot-listen`; both pills are ≥ 56 px tall; `'fits at 2x text'`: at `TextScaler.linear(2.0)` the foot is 64 px tall and `tester.takeException()` is null.
- `notice_chip_test`: label shows; tapping the chip calls `onTap`; with `actionLabel: 'فهمت'` tapping `notice-action` calls `onAction` and not `onTap`; height ≥ 48; the chip carries `Semantics(liveRegion: true)`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `KhatamMedallion`: lay the label out with a `TextPainter` (`TS.bold14` in `colors.ink`, `MediaQuery.textScalerOf(context)`), side = `(math.max(w, h) + 20).clamp(36.0, 56.0)`, a `SizedBox.square(side)` `Stack` of `CustomPaint(painter: _KhatamPainter(colors.accent))` drawing two stroked squares (1.5 px), the second rotated 45° about the centre, and the label centred in a `SizedBox.square(side - 12)` through `FittedBox(fit: BoxFit.scaleDown)`, so a 2× label (about 52 px tall) shrinks into the capped medallion instead of spilling.
- `RunningHead` (Deliberate reading 18): `SizedBox(height: 64)` on `colors.background` holding a `Column`: `Expanded` row, then the double hairline inside the same 64 px (`SizedBox(height: 4)` with a 1 px `colors.accent` top and bottom `Border`, so two lines 2 px apart). The row: an `Expanded` start group (48 px `IconButton` with `HugeIcon(icon: backArrowIcon(context), color: colors.ink)`, tooltip `MaterialLocalizations.of(context).backButtonTooltip`; then a `Flexible` surah name `TS.bold16` ink, `maxLines: 1`, `overflow: TextOverflow.ellipsis`, tappable), the `KhatamMedallion` with `page.toLocalized(context)` (≤ 56 fits the 60 px row), and an `Expanded` end group (`head_juzHizb(juz.toLocalized(context), hizb.toLocalized(context))` in `TS.medium14` `colors.ink2`, end-aligned, `maxLines: 1`, `overflow: TextOverflow.ellipsis`, tappable). The 2× test measures `RunningHead` itself, which is the 64 px box.
- `ReaderFoot`: `SizedBox(height: 64)` on `colors.background`, `Padding(horizontal: 8)`, `Row(spacing: 8)`: `‹` `IconButton` (48, `backArrowIcon`) · `Expanded` `FilledButton.icon` «استماع» (`HugeIcons.strokeRoundedHeadphones`, `colorScheme.primary`) · `Expanded` `FilledButton.tonal` icon «القائمة» (`HugeIcons.strokeRoundedMenu01`, background `colors.leaf`, foreground `colors.ink`) · `›` `IconButton` (48, `forwardArrowIcon`). Pills `minimumSize: Size(0, 56)`; each label is `FittedBox(fit: BoxFit.scaleDown, child: Text(…, style: TS.semi14, maxLines: 1))`, so at 2× the label shrinks to its pill (about 112 px wide in 360) and the band keeps its 64 px.
- `NoticeChip`: `Semantics(liveRegion: true)` → a rounded pill (≥ 48 high) on `colors.leaf`, 1 px `colors.accent` border, label `TS.medium14` ink, the whole pill an `InkWell(onTap)`, plus a `TextButton` (`notice-action`, `colorScheme.primary`) when `actionLabel` is given.

- [ ] **Step 4: Run** the Step 2 command and `flutter test test/core/localization`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/khatam_medallion.dart lib/features/surah/presentation/pages/mushaf/widgets/running_head.dart lib/features/surah/presentation/pages/mushaf/widgets/reader_foot.dart lib/features/surah/presentation/pages/mushaf/widgets/notice_chip.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/khatam_medallion_test.dart test/features/surah/presentation/pages/mushaf/widgets/running_head_test.dart test/features/surah/presentation/pages/mushaf/widgets/reader_foot_test.dart test/features/surah/presentation/pages/mushaf/widgets/notice_chip_test.dart
git commit -m "feat(mushaf): running head with khatam, foot band and notice chip

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: AyahLeaf (ayah and banner variants, sajda badge, share)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`

**Interfaces:**
- Consumes: `BookmarkCubit.toggle(AyahIdentifier)`, `BookmarkState.contains`; `quran.isSajdahVerse` (Task 2); `PendingS.playback_mediaTitle`, `mushaf_playFromSurahStart`; `S.share`, `S.playback_close`, `S.ayah_label`, `S.makkiyya`, `S.madaniyya`, `S.ayahs_count`, `S.share_failed`.
- Produces:
  - `AyahLeaf({required AyahIdentifier ayah, required MushafPaperColors colors, required VoidCallback onClose, required VoidCallback onListenFromHere, required VoidCallback onListenFromSurahStart, required VoidCallback onListenPage})`
  - `String ayahShareText(BuildContext context, AyahIdentifier ayah)`
  - Strings: `leaf_listenFromHere`: «استماع من هنا» / 'Listen from here'; `leaf_saveAyah`: «حفظ الآية» / 'Save ayah'; `leaf_sajda`: «سجدة» / 'Sajda'; `mushaf_surahTitle(surah)`: «سورة $surah» / 'Surah $surah'; `mushaf_surahCaption(place, ayahs)`: «$place، $ayahs» / '$place, $ayahs'; `mushaf_playWholePage`: «استماع الصفحة كاملة» / 'Listen to the whole page'.
  - Keys: `leaf-close`, `leaf-listen`, `leaf-save`, `leaf-share`, `leaf-surah-start`, `leaf-page`.

- [ ] **Step 1: Write the failing tests** (`BookmarkCubit` as a `Cubit<BookmarkState>` fake that records `toggle`; Arabic locale)

- `'ayah leaf labels are distinct'`: for 3:7 the action row shows «استماع من هنا», «حفظ الآية», «مشاركة», and the three label texts form a set of size 3.
- `'title names the surah and ayah in Arabic-Indic digits'`: «آل عمران، الآية ٧».
- `'listen from here, close and save reach their handlers'`: tapping `leaf-listen` calls `onListenFromHere`; `leaf-close` calls `onClose`; `leaf-save` records `toggle(3:7)`.
- `'dragging down closes'`: `tester.fling(find.byType(AyahLeaf), const Offset(0, 300), 1000)` calls `onClose`.
- `'a sajda ayah carries the badge'`: 32:15 shows «سجدة»; 32:14 does not.
- `'the banner variant offers the surah actions only'`: for 5:0 the title is «سورة المائدة», the caption «مدنية، ١٢٠ آية»; `leaf-surah-start` («استماع من بداية السورة») and `leaf-page` («استماع الصفحة كاملة») call their handlers; «مشاركة», «حفظ الآية» and «الآية ٠» are absent.
- `'share text quotes the ayah and names it'`: `ayahShareText(context, 112:1)` equals `'${quran.getVerse(112, 1)} — سورة الإخلاص، الآية ١'`.
- `'fits at 2x text'`: 3:7 at `TextScaler.linear(2.0)` in a 360 px wide box → no exception.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

A `GestureDetector(onVerticalDragEnd: velocity > 300 → onClose)` around a `Material` on `colors.leaf` with a 1 px `colors.accent` top border, padding 16/12, `Column(mainAxisSize: min, spacing: 12)`:
- Title row: title `TS.bold16` ink (ayah > 0: `playback_mediaTitle(surahDisplayName, n)`; banner: `mushaf_surahTitle(name)` over the caption `mushaf_surahCaption(place, S.of(context).ayahs_count(count.toLocalized(context)))` in `TS.medium14` `colors.ink2` (`ayahs_count` takes `Object` and prints it as given, so the digits are localized first), place from `quran.getPlaceOfRevelation(s) == 'Makkah'`), then `AppStatusBadge(color: colors.accent, label: leaf_sajda, showDot: false)` when `quran.isSajdahVerse`, then a 48 px «إغلاق» `TextButton.icon` (`HugeIcons.strokeRoundedCancel01`, `leaf-close`).
- Ayah > 0: an `IntrinsicHeight` `Row` of three `Expanded` columns (`HugeIcon` over a `TS.semi14` label, ≥ 56 high) split by 1 px `colors.accent` `VerticalDivider`s. «استماع من هنا» is the only filled one (`colorScheme.primary` fill, `onPrimary` content, `HugeIcons.strokeRoundedPlay`). «حفظ الآية» is a `BlocSelector<BookmarkCubit, BookmarkState, bool>` on `contains(ayah)` (`strokeRoundedBookmarkCheck02` when saved, else `strokeRoundedBookmark02`). «مشاركة» (`strokeRoundedShare08`) calls `SharePlus.instance.share(ShareParams(text: ayahShareText(context, ayah)))` and on a throw shows the `S.share_failed` SnackBar.
- Banner: `FilledButton` «استماع من بداية السورة» and `OutlinedButton` «استماع الصفحة كاملة», both ≥ 48 high, in a `Row(spacing: 8)` of `Expanded`s.
- `ayahShareText`: `'${quran.getVerse(s, a)} — ${S.of(context).ayah_label(surahDisplayName(context, s), a.toLocalized(context))}'`.

- [ ] **Step 4: Run** the Step 2 command and `flutter test test/core/localization`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart
git commit -m "feat(mushaf): labelled ayah leaf with banner variant and sajda badge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: PlayerLeaf and the «خيارات التلاوة» sheet

**Files:**
- Create: `lib/features/quran_playback/presentation/widgets/playback_options_sheet.dart`
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/player_leaf.dart`
- Modify: `lib/features/quran_playback/presentation/widgets/surah_download_button.dart` (`labelled`)
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart` (drop `_ReciterGrid`, `_SpeedGrid`, `_Chip`, `_ReciterSheet`, `_OptionsSheet`, `_speeds`; both sheet openers call `PlaybackOptionsSheet.show`)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md` (exports)
- Modify: `test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart` (two tests follow the extracted sheet; Task 8c deletes the file)
- Test: `test/features/quran_playback/presentation/widgets/playback_options_sheet_test.dart`, `test/features/quran_playback/presentation/widgets/surah_download_button_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/player_leaf_test.dart`

**Interfaces:**
- Consumes: `playbackScope` (Task 2); `PlaybackCubit` (`pause`, `resume`, `retry`, `stop`, `skipNext`, `skipPrevious`, `setSpeed`, `setReciter`); `PlaybackState.canSkipNext/canSkipPrevious/skipOrigin`; `PendingS.mushaf_nowReciting`, `mushaf_returnToReciting`, `mushaf_audioError`, `mushaf_retry`, `mushaf_endRecitation`, `playback_mediaTitle`.
- Produces:
  - `PlaybackOptionsSheet({VoidCallback? onNewPlay})`, `static Future<void> show(BuildContext context, {VoidCallback? onNewPlay})`; public `ReciterGrid`, `SpeedGrid`, `OptionChip({required String label, required bool selected, required VoidCallback onTap})`; `String speedLabel(BuildContext context, double speed)` (top-level in the same file).
  - `SurahDownloadButton({super.key, required int surah, bool labelled = false})`.
  - `PlayerLeaf({required MushafPaperColors colors, required VoidCallback onReturnToPlaying, required VoidCallback onNewPlay, AyahIdentifier? awayAyah, int? awayPage})`
  - Strings: `player_untilSurahEnd(reciter)`: «$reciter، حتى نهاية السورة» / '$reciter, to the end of the surah'; `player_untilPageEnd(reciter)`: «$reciter، حتى نهاية الصفحة» / '$reciter, to the end of the page'; `player_previous`: «السابقة» / 'Previous'; `player_resume`: «متابعة» / 'Resume' (not `S.onb_continue`: same Arabic, but its English is 'Continue'); `player_repeat(value)`: «التكرار: $value» / 'Repeat: $value'; `player_repeatOnce`: «مرة واحدة» / 'once'; `player_repeatForever`: «بلا توقف» / 'endless'; `player_repeatCounts(ayah, passage)`: «الآية ×$ayah، المقطع ×$passage» / 'ayah ×$ayah, passage ×$passage'; `player_optionsTitle`: «خيارات التلاوة» / 'Recitation options'; `mushaf_audioErrorHint`: «تحقق من الاتصال بالإنترنت، ثم أعِد المحاولة» / 'Check your internet connection, then try again'. Pause reuses `S.playback_pause` («إيقاف مؤقت»); next reuses `PendingS.strip_next` («التالية» / 'Next', the same text in both languages).
  - Keys: `player-previous`, `player-toggle`, `player-next`, `player-repeat`, `player-end`, `player-retry`, `player-return`, `player-loading`.

- [ ] **Step 1: Write the failing tests**

`playback_options_sheet_test.dart` (fake `PlaybackCubit` recording calls): `'speed labels'`: in Arabic the six chips read «٠٫٥×», «٠٫٧٥×», «١×», «١٫٢٥×», «١٫٥×», «٢×»; in English '0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×'; tapping the «١٫٢٥×» chip calls `setSpeed(1.25)`; tapping a reciter's Arabic name calls `setReciter`; the title «خيارات التلاوة» shows; each `OptionChip` is ≥ 48 high; `PlaybackRepeatOptions` is present.

`surah_download_button_test.dart` (add): `labelled: true` shows «تنزيل السورة» when not downloaded, «جارٍ التنزيل ٤٠٪» at `SurahDownloading(0.4)` (tap records `cancel`), «محفوظة للاستماع دون إنترنت» when downloaded, «تعذّر التنزيل، أعِد المحاولة» when failed (tap records `download`).

`player_leaf_test.dart` (fake `PlaybackCubit` and `SurahDownloadCubit`, Arabic locale). Each one replaces an `ayah_playback_overlay_test.dart` case Task 8c deletes:
- `'title names the requested ayah in Arabic-Indic digits'`: `requestedAyah: 3:4` → «آل عمران، الآية ٤».
- `'subtitle names the reciter and the range scope'`: range 3:4–3:200 → `'${Reciter.alafasy.arabicName}، حتى نهاية السورة'`; range 4:176–5:2 → `'${Reciter.alafasy.arabicName}، حتى نهاية الصفحة'`; no range → the name alone.
- `'pause and resume'`: playing → `player-toggle` reads «إيقاف مؤقت» and calls `pause`; paused → «متابعة» and calls `resume`.
- `'loading shows a slim bar and disables the toggle'`: `isLoading: true` → `find.byKey(ValueKey('player-loading'))` is a `LinearProgressIndicator`; `player-toggle` disabled.
- `'skips are disabled when idle'`: `PlayerLeaf` pumped directly with `PlaybackState()` (`skipOrigin` null, so `canSkipNext` and `canSkipPrevious` are false) → `player-previous` and `player-next` have `onPressed == null` and nothing throws (the title is empty when `skipOrigin` is null; the shell never shows the leaf in that state).
- `'skip next is disabled at the range end'`: `currentAyah: 2:10, rangeStart: 2:5, rangeEnd: 2:10, isPlaying: true` → `player-next` disabled, `player-previous` enabled.
- `'a skip calls onNewPlay'`: `currentAyah: 2:6, rangeStart: 2:5, rangeEnd: 2:10, isPlaying: true`; tapping `player-next` records `skipNext` once and calls `onNewPlay` once; tapping `player-previous` records `skipPrevious` and calls `onNewPlay` again.
- `'a range edit in the options sheet calls onNewPlay'` (successor of the overlay's `'options sheet range edit re-arms follow'`): `rangeStart: 2:5, rangeEnd: 2:10`; tap `player-repeat`, `pumpAndSettle`, `ensureVisible(find.byKey(ValueKey('range-from')))`, tap its `Icons.add` → `onNewPlay` called once.
- `'end recitation stops'`: `player-end` calls `stop`.
- `'an audio error shows inline with retry and end'`: `error: 'x', requestedAyah: 3:13` → «تعذّر تشغيل الآية ١٣ من سورة آل عمران», «تحقق من الاتصال بالإنترنت، ثم أعِد المحاولة», `player-retry` calls `retry`, `player-end` calls `stop`, transport hidden, the error block carries `Semantics(liveRegion: true)`.
- `'listening-away shows where the recitation is and a way back'`: `awayAyah: 3:12, awayPage: 51` → «يُتلى الآن: آل عمران ١٢، صفحة ٥١»; `player-return` («العودة إلى الآية المتلوّة») calls `onReturnToPlaying`.
- `'the repeat chip summarises and opens the options sheet'`: `eachAyahRepeat: 3` → «التكرار: الآية ×٣، المقطع ×١»; default → «التكرار: مرة واحدة»; `infiniteRepeat` → «التكرار: بلا توقف»; tapping `player-repeat` opens «خيارات التلاوة».
- `'download chip follows the playing surah'`: a labelled `SurahDownloadButton` for surah 3 is present.
- `'fits at 2x text'`: no exception at `TextScaler.linear(2.0)` in 360 px.

- [ ] **Step 2: Run** `flutter test test/features/quran_playback/presentation/widgets test/features/surah/presentation/pages/mushaf/widgets/player_leaf_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `playback_options_sheet.dart`: move `_speeds`, `_ReciterGrid`, `_SpeedGrid` and `_Chip` out of the overlay as `ReciterGrid`, `SpeedGrid`, `OptionChip` (≥ 48 tap height; chip label `speedLabel(context, s)`). `speedLabel` (Deliberate reading 14):

```dart
String speedLabel(BuildContext context, double speed) {
  final raw = speed == speed.truncateToDouble() ? speed.toInt().toString() : speed.toString();
  return '${(context.isArabic ? raw.replaceAll('.', '٫') : raw).toLocalized(context)}×';
}
```
 `PlaybackOptionsSheet` = title, `S.reciter_label` + `ReciterGrid`, `S.playback_speed` + `SpeedGrid`, `PlaybackRepeatOptions(onNewPlay: onNewPlay)` in a `SingleChildScrollView`. `show` opens `showModalBottomSheet(showDragHandle: true, isScrollControlled: true)` with `BlocProvider.value(value: context.read<PlaybackCubit>())`. The overlay's two openers call it (its range-seeding code stays until Task 8c deletes the overlay).
- `SurahDownloadButton`: keep the status switch; `labelled` renders an `OutlinedButton.icon` (≥ 48 high) whose label is `surahDownload_download` / `surahDownload_progress(percent)` / `surahDownload_saved` / `surahDownload_failed` with the same taps.
- `PlayerLeaf`: a `BlocBuilder<PlaybackCubit, PlaybackState>` with a `buildWhen` over the fields it draws, on `colors.leaf` with the accent top border:
  - `isLoading` → `LinearProgressIndicator(key: ValueKey('player-loading'), minHeight: 2)` at the top.
  - `awayAyah != null` → a row: `mushaf_nowReciting(name, ayah, page)` + `FilledButton` `player-return`.
  - Title `playback_mediaTitle` of `skipOrigin` (`TS.bold16` ink); subtitle per `playbackScope(rangeStart, rangeEnd)` (`TS.medium14` `ink2`).
  - `error != null` → `Semantics(liveRegion: true)` block: `mushaf_audioError`, `mushaf_audioErrorHint`, `FilledButton` `player-retry`, `TextButton` `player-end`.
  - Else row 1, a `Row(spacing: 8)` whose three children are all `Expanded` (flex 1, 2, 1): `TextButton.icon` «السابقة» (`player-previous`, `Icons.skip_previous`, enabled by `canSkipPrevious`; tap → `skipPrevious()` then `onNewPlay()`), the 56 px primary `FilledButton.icon` (`player-toggle`; `isPlaying` → `pause`; else `resume`; disabled while `isLoading`), `TextButton.icon` «التالية» (`player-next`, `Icons.skip_next`, `canSkipNext`; tap → `skipNext()` then `onNewPlay()`). Every label is `FittedBox(fit: BoxFit.scaleDown, child: Text(…, style: TS.semi14, maxLines: 1))`, so at 2× in 360 px the labels shrink inside their share of the row instead of overflowing. Row 2 (`Wrap(spacing: 8)`): `ActionChip`-sized `OutlinedButton.icon` `player-repeat` (`Icons.repeat`, ≥ 48 high, opens `PlaybackOptionsSheet.show(context, onNewPlay: onNewPlay)`), `SurahDownloadButton(surah: skipOrigin.surah, labelled: true)`, `TextButton.icon` `player-end` (`Icons.stop`).
  - Repeat value: `infiniteRepeat` → `player_repeatForever`; `eachAyahRepeat > 1 || rangeRepeat > 1` → `player_repeatCounts(each, range)`; else `player_repeatOnce`.
- `feature-widgets.md` exception line: `quran_playback` exports `SurahDownloadButton` and `PlaybackOptionsSheet` (used by `surah`).

- `ayah_playback_overlay_test.dart`: in `'options sheet speed chip calls setSpeed'` (English locale) change `find.text('1.5x')` (line 875) to `find.text('1.5×')`; in `'options sheet range edit re-arms follow'` add `await tester.ensureVisible(find.byKey(const ValueKey('range-from')));` and `await tester.pumpAndSettle();` before the tap at line 893, because the sheet now opens with the reciter grid above the speed and repeat sections. The subtitle assertion `'١.٥x'` (line 791) is the overlay's own subtitle, which this task does not touch.

- [ ] **Step 4: Run** the Step 2 command, then `flutter test test/features/surah test/core/localization` (the overlay tests pass through the extracted sheet with the two edits above). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/widgets/playback_options_sheet.dart lib/features/quran_playback/presentation/widgets/surah_download_button.dart lib/features/surah/presentation/pages/mushaf/widgets/player_leaf.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/quran_playback/presentation/widgets/playback_options_sheet_test.dart test/features/quran_playback/presentation/widgets/surah_download_button_test.dart test/features/surah/presentation/pages/mushaf/widgets/player_leaf_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart
git commit -m "feat(playback): player leaf with inline error, listening-away and download chip

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: MenuSheet («القائمة») and DisplaySheet («العرض»)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/menu_sheet.dart`
- Rename: `git mv lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart`; `git mv test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` and `lib/features/settings/presentation/pages/settings_page.dart` (`ReadingSettingsSheet.show` → `DisplaySheet.show`; `settings_page_test.dart` too if it names the class)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/menu_sheet_test.dart`, `display_sheet_test.dart`

**Interfaces:**
- Consumes: `resolveMenuQuery`, `MenuQueryTarget` (Task 2); `SurahDownloadButton` (icon form); `JuzBrowseEntry`, `QuranBrowseService.juzEntries()`; `SettingsCubit.updateKeepScreenOn` (Task 1); `mushaf_surahCaption`, `mushaf_playWholePage` (Task 5).
- Produces:
  - `sealed class MenuAction { const MenuAction(); }` with `final class MenuJump(int page)`, `MenuOpenPlaces`, `MenuOpenDisplay`, `MenuPlayPage` (all `const`, `Equatable`).
  - `MenuSheet({required int currentPage, required int? currentSurah, required int currentJuz, required List<JuzBrowseEntry> juzEntries})`, `static Future<MenuAction?> show(BuildContext context, {required int currentPage, required int? currentSurah, required int currentJuz})`.
  - `DisplaySheet`, `static Future<void> show(BuildContext context)`.
  - Strings: `menu_places`: «أماكني» / 'My places'; `menu_display`: «العرض» / 'Display'; `menu_searchHint`: «اسم سورة أو رقم صفحة» / 'Surah name or page number'; `menu_pageResult(page, surah, juz)`: «صفحة $page، $surah، الجزء $juz» / 'Page $page, $surah, juzʼ $juz'; `menu_go`: «انتقال» / 'Go'; `menu_pageRangeError`: «اكتب رقمًا من ١ إلى ٦٠٤» / 'Enter a number from 1 to 604'; the «السور / الأجزاء» segments reuse `S.tab_surahs` («السور» / 'Surahs') and `S.tab_juz` («الأجزاء» / 'Juzʼ'), the index tabs' keys; `menu_youAreHere`: «أنت هنا» / 'You are here'; `mushaf_pageNumber(page)`: «صفحة $page» / 'Page $page'; `display_paper`: «لون الورق» / 'Paper colour'; `display_readingMode`: «طريقة القراءة» / 'Reading mode'; `display_keepScreenOn`: «إبقاء الشاشة مضيئة» / 'Keep the screen on'; `display_done`: «تم» / 'Done'.
  - Keys: `menu-tile-places`, `menu-tile-display`, `menu-tile-play`, `menu-search`, `menu-go`, `menu-surah-<n>`, `menu-juz-<n>`, `display-keep-awake`, `display-done`; the existing `reading-paper-<name>`, `reading-brightness-slider`, `reading-mode-toggle` keys stay.

- [ ] **Step 1: Write the failing tests**

`menu_sheet_test.dart` (pump `MenuSheet` inside a route opened by a button that awaits `showModalBottomSheet<MenuAction>` and stores the result; fakes for `PlaybackCubit` and `SurahDownloadCubit`; `juzEntries: QuranBrowseServiceImpl().juzEntries()`):
- each tile pops its action: `menu-tile-places` → `MenuOpenPlaces()`, `menu-tile-display` → `MenuOpenDisplay()`, `menu-tile-play` → `MenuPlayPage()`.
- `'typing ٥٨٢ shows the result row and jumps'`: «صفحة ٥٨٢، النبأ، الجزء ٣٠» shows; `menu-go` pops `MenuJump(582)`.
- `'an out-of-range number shows the inline error'`: `'٦٠٥'` → «اكتب رقمًا من ١ إلى ٦٠٤»; no `menu-go`.
- `'the search field accepts both digit sets'`: `enterText('٥8٢')` keeps the text (no digits-only formatter).
- `'surah rows mark the current surah and carry a download button'`: `currentSurah: 3` → `menu-surah-3` holds «أنت هنا», «مدنية، ٢٠٠ آية», «صفحة ٥٠» and a `SurahDownloadButton`; `await tester.scrollUntilVisible(find.byKey(const ValueKey('menu-surah-18')), 200)`, then tapping `menu-surah-18` pops `MenuJump(293)`.
- `'the juz tab marks the current juz'`: select «الأجزاء»; `menu-juz-30` (`currentJuz: 30`, reached with `scrollUntilVisible`) holds «أنت هنا»; tapping `menu-juz-2` pops `MenuJump(22)`.
- `'the sheet opens tall'`: through `MenuSheet.show`, the sheet's height is `0.85 ×` the 800 px test surface (proves `isScrollControlled: true`; without it the sheet caps at 9/16).
- every surah row is ≥ 56 high.

`display_sheet_test.dart` (renamed; keep its paper-name, selected-swatch, the two `'swatch captions are not truncated on a 360dp phone (en/ar)'` cases (lines 95-120), paper-tap, mode-tap and drag-fade tests, retargeted to `DisplaySheet`), and add:
- `'the brightness slider starts at the 0.6 floor'`: `Slider.min == Settings.minPageBrightness`.
- `'the keep-screen-on switch updates the setting'`: tapping `display-keep-awake` calls `updateKeepScreenOn(false)` when it was on.
- `'done closes the sheet and is at least 48 by 48'`.
- `'paper tiles draw a mini page and show a name of at least 14 px'`: six `CustomPaint`s under `reading-paper-*`; the names use `TS.medium14`.
- `'the title reads العرض and the sections are named'`: «العرض», «لون الورق», «السطوع», «طريقة القراءة».

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/menu_sheet_test.dart test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `MenuSheet.show`: `showModalBottomSheet<MenuAction>(context: context, isScrollControlled: true, showDragHandle: true, useSafeArea: true, builder: …)`. The sheet body is `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))` around `SizedBox(height: math.max(0.0, MediaQuery.sizeOf(context).height * 0.85 - MediaQuery.viewInsetsOf(context).bottom))`, so the keyboard pushes the search row and «انتقال» up and the list (the only `Expanded`) shrinks.
- `MenuSheet` (app colours): that `SizedBox` holds a `Column`: a `Row(spacing: 8)` of three `Expanded` tiles (`SurfaceCard`, icon over a `TS.semi14` label: `HugeIcons.strokeRoundedLocation01` «أماكني», `strokeRoundedSettings02` «العرض», `strokeRoundedHeadphones` `mushaf_playWholePage`); a `TextField` (`menu-search`, `keyboardType: TextInputType.text`, no input formatter, hint `menu_searchHint`) whose `onChanged` keeps a local `MenuQuery` in `State`; under it either the result row (`menu_pageResult` + `FilledButton` `menu-go`) for a `MenuQueryTarget`, the `menu_pageRangeError` text in `colorScheme.error` for `MenuQueryOutOfRange`, or nothing; `AppSegmentedSelector<bool>` (`S.tab_surahs` / `S.tab_juz`); an `Expanded` `ListView.builder` of rows (`ConstrainedBox(minHeight: 56)`: number disc (`n.toLocalized(context)`), name `TS.bold16`, caption `mushaf_surahCaption(place, S.of(context).ayahs_count(count.toLocalized(context)))` and `mushaf_pageNumber(page.toLocalized(context))` in `TS.medium14` `onSurfaceVariant`, `AppStatusBadge(color: colorScheme.primary, label: menu_youAreHere)` on the current one, and for surah rows `SurahDownloadButton(surah: n)`). Juz rows show `S.of(context).juz_label(n.toLocalized(context))`, `first – last` surah names and the first page. The result row is `menu_pageResult(page.toLocalized(context), surahDisplayName(context, surah), juz.toLocalized(context))`. (`ayahs_count` and `juz_label` take `Object` and print it as given, so every number is localized first.) A row tap pops `MenuJump(page)`. `show` reads `sl<QuranBrowseService>().juzEntries()` and wraps the sheet in `MultiBlocProvider` with `.value` for `PlaybackCubit` and `SurahDownloadCubit`.
- `DisplaySheet`: rename the class; title `menu_display`; section labels `display_paper`, `S.brightness`, `display_readingMode`; each swatch becomes `CustomPaint(painter: _PaperTilePainter(p.colors))` (fill `background`, a 1.5 px `accent` inset frame, two `ink` lines at 40 % and 60 % height) with the name in `TS.medium14`, `maxLines: 2`, `textAlign: TextAlign.center`, `softWrap: true` (so 'Blue night' and «ليلي أزرق» wrap to two lines in a 1/6-width column at 360 dp and the kept truncation tests pass; today's caption is `maxLines: 1` at `TS.medium12`); `SwitchListTile` `display-keep-awake` bound to `keepScreenOn`; a `FilledButton` `display-done` (`minimumSize: Size(48, 48)`) that pops. Keep `barrierColor: Colors.transparent` and the drag fade.

- [ ] **Step 4: Run** the Step 2 command, `flutter test test/features/settings test/features/surah test/core/localization`, and analyze. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/menu_sheet.dart lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/settings/presentation/pages/settings_page.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/menu_sheet_test.dart test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart
git commit -m "feat(mushaf): القائمة sheet with search and index, العرض sheet with keep-awake

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Add `test/features/settings/presentation/pages/settings_page_test.dart` to the `git add` only if Step 3 changed it. `git mv` already staged the old paths.)

---

### Task 8a: MushafPageView taps, the page's true aspect, the painter rename

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`, `ayah_highlight_painter.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` (scroll item height and the page-mode item only)
- Create: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart`

**Interfaces:**
- Consumes: `mushafPageAspect` (Task 2); `MushafCubit.select` (Task 3).
- Produces: `MushafPageView` taps: hit → `toggleSelection`, blank → `clearSelection`, long-press hit → `select` (no popover). `AyahHighlightPainter({required ayahs, required selectedAyah, required prevSelectedAyah, required playingAyah, required prevPlayingAyah, required selectedColor, required playingColor, required animationValue})`. The chrome fields, `_publishHighlightBounds` and the printed chrome stay until Task 8c (Deliberate reading 19).

- [ ] **Step 1: Write the failing tests**

`mushaf_page_view_tap_test.dart`: a private `Cubit<MushafState> implements MushafCubit` fake recording `toggleSelection`, `clearSelection` and `select`, plus a no-op `setHighlightBounds` (Task 8c removes it); a `SettingsCubit` fake; `sl` registers `GetMushafPage` over a stub repo returning bounds for 2:6 at y 0.1–0.15 on page 3. Pump `MushafPageView(pageNumber: 3)` in a 400×800 `MediaQuery`:
- `'a tap on an ayah toggles it'`: tap inside 2:6 → `toggleSelection(2:6)` recorded once.
- `'a tap on blank paper clears the selection'`: tap at y 0.9 → `clearSelection` recorded, no toggle.
- `'a long-press selects'`: long-press inside 2:6 → `select(2:6)` recorded, no toggle.
- `'the page keeps the image aspect'`: the `AspectRatio` under `MushafPageView` has `aspectRatio == mushafPageAspect`, and its rendered `Size` has `width / height` within 0.001 of `mushafPageAspect`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `_handleTap`: `final hit = _hitTest(local, c, ayahs); hit == null ? cubit.clearSelection() : cubit.toggleSelection(hit);`. Remove the `chromeVisible` check, `setChrome`, `unpinOverlay` and the `PlaybackCubit` read (and the user comments that go with those lines).
- `_handleLongPress`: `final hit = _hitTest(local, c, ayahs); if (hit != null) cubit.select(hit);`. Delete the popover anchor code and the `ayah_action_popover.dart` import.
- Both `AspectRatio(aspectRatio: 1 / 1.82)` (page and error box) → `mushafPageAspect`. The images keep `BoxFit.fill`; the box now has their own aspect, so nothing stretches.
- `AyahHighlightPainter`: `highlightedAyah` → `selectedAyah`, `prevHighlightedAyah` → `prevSelectedAyah`, `highlightColor` → `selectedColor` (fields, constructor, `shouldRepaint`, the one call site in `mushaf_page_view.dart`).
- `mushaf_page.dart`: `newPageHeight = availableWidth / mushafPageAspect` (was `* 1.82`); page mode `itemBuilder: (_, i) => Center(child: MushafPageView(pageNumber: i + 1))`.

- [ ] **Step 4: Run** `flutter test test/features/surah`, then `flutter analyze --no-fatal-infos`. Expected: PASS, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart
git commit -m "refactor(mushaf): a tap selects or clears and the page keeps its true aspect

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8b: The shared harness and the reader shell

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` (rewrite of `build` and the jump, play and turn handlers)
- Create: `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`, `mushaf_page_follow_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–7; `sl<QuranMetaService>().getPageMeta(page)` (`juz`, `hizb`).
- Produces: `MushafPage({super.key, required this.args})` drawing head, page area with the leaf slot, and foot. `AyahPlaybackOverlay`, `MushafTopBar`, `MushafBrowseBar` and `PageJumpSheet` are no longer referenced from `lib/` outside their own files (Task 8c deletes them).

- [ ] **Step 1: Write the failing tests**

`mushaf_page_harness.dart` (a test library; every name other files use is public, so nothing trips `library_private_types_in_public_api`):
- `FakeSettings extends Cubit<SettingsState> implements SettingsCubit`, `FakeSettings({MushafReadingMode mode = MushafReadingMode.page, bool hintSeen = true, bool downloadHintSeen = true, bool keepScreenOn = true})` (Arabic, `ColorPalette.neutralLight`). Records `markHintSeenCalls`, `markDownloadHintSeenCalls` and `keepScreenOnSet` (`List<bool>`); `markHintSeen`, `markDownloadHintSeen` and `updateKeepScreenOn` emit the field as the real cubit does. `hintSeen` defaults to true so tests that are not about the hint never see its chip.
- `FakeMushaf extends Cubit<MushafState> implements MushafCubit`: `push(MushafState)`, settable `playingPage`. Records `setPages` (`List<(int, bool)>`, page and `byUser`), `jumps` (`List<int>`), `selects`, `toggles` (`List<AyahIdentifier>`), `clearCalls`, `resumeCalls`. Each emits what the real cubit would: `setPage(p, byUser: true)` → `currentPage: p, clearSelected: true, clearJumpFrom: true`; `setPage(p, byUser: false)` → `currentPage: p`; `jumpTo(p)` → the origin rule of Task 3 (`jumpFrom` kept across chained jumps, cleared on return) with `clearSelected: true`; `select`, `toggleSelection`, `clearSelection` (today's no-op becomes a real clear) and `resumeFollow` (`followPlayback: true`). Until Task 8c it also overrides `setHighlightBounds` as a no-op. `noSuchMethod` forwards to `super` as today.
- `FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit`: `push(PlaybackState)`. Records `playRanges` (`List<(AyahIdentifier, AyahIdentifier)>`), `stopCalls`, `pauseCalls`, `resumeCalls`. `playRange` emits `requestedAyah: start, currentAyah: start, rangeStart: start, rangeEnd: end, isPlaying: true, clearError: true`; `stop` emits `clearCurrentAyah: true, isPlaying: false` as today.
- `FakeBookmarks extends Cubit<BookmarkState> implements BookmarkCubit` recording `toggles`; `FakeDownloads extends Cubit<SurahDownloadState> implements SurahDownloadCubit` (`super(const SurahDownloadState())`) recording `downloads` (`List<(Reciter, int)>`) and `cancels`.
- `StubLastReadRepo` (public, moved from the dispose test with its `saved` field); the page-service, mushaf-repo and page-bookmark stubs stay private.
- `void setUpMushafHarness({QuranPageService? pageService})`: unregister-then-register `QuranPageService` (default: today's stub), `QuranMetaService` (`QuranMetaServiceImpl(pageService: sl())`), `GetMushafPage` (stub repo, empty bounds) and `QuranBrowseService` (`QuranBrowseServiceImpl()`, which the menu needs).
- `typedef MushafHarness = ({FakePlayback playback, FakeSettings settings, FakeBookmarks bookmarks, FakeDownloads downloads, StubLastReadRepo repo});`
- `Future<MushafHarness> pumpMushafPage(WidgetTester tester, MushafArgs args, {required MushafCubit mushaf, FakePlayback? playback, FakeSettings? settings, LastRead? stored, bool pushed = false, double textScale = 1.0})`: 400×800 at DPR 1 (with `addTearDown(tester.view.reset)`); providers `SettingsCubit`, `MushafCubit`, `PlaybackCubit`, `LastReadCubit` (over the repo), `PageBookmarkCubit` (stub repo), `BookmarkCubit`, `SurahDownloadCubit`; Arabic locale with the `S` delegates; `MaterialApp.builder` applies `TextScaler.linear(textScale)`. `pushed: false` keeps today's shape (providers and `MushafPage` as `home`). `pushed: true` wraps the `MaterialApp` in the providers with `home: const SizedBox.shrink()`, then `tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => MushafPage(args: args)))` and `pumpAndSettle`, so a pop can remove the reader. `mushaf` is passed in, so the follow test can pass its real `_RecordingMushaf` and shell tests a `FakeMushaf` they keep a reference to.

`mushaf_page_shell_test.dart` (`setUp(setUpMushafHarness)`):
- `'head and foot are always visible'`: `RunningHead` and `ReaderFoot` present with nothing selected or playing (rewrites the old `browse bar` group, which pinned the hidden-controls bug).
- `'page-turn buttons stay while a recitation plays'`: `requestedAyah: 2:5, isPlaying: true` → `foot-previous` and `foot-next` enabled; tapping `foot-next` in page mode and settling records `(8, true)` in `mushaf.setPages`.
- `'the player leaf shows during a recitation'`: playing, nothing selected → `PlayerLeaf` present, no `AyahLeaf`.
- `'tap while playing swaps in the ayah leaf, closing returns to the player'`: playing, then `mushaf.push(state.copyWith(selectedAyah: 2:6))` → `AyahLeaf`; tap `leaf-close` → `PlayerLeaf`.
- `'tap while paused does the same'`: `isPaused: true, currentAyah: 2:5`.
- `'listen from here replaces the recitation and shows the player'`: selected 2:6, tap `leaf-listen` → `playRanges == [(2:6, 2:286)]`, selection cleared, `PlayerLeaf` present.
- `'the banner leaf plays the whole page and gives the slot to the player'`: `currentPage: 106`, `pageAyahs` for 4:176, 5:0, 5:1, 5:2, `selectedAyah: 5:0`; tap `leaf-page` → `playRanges == [(4:176, 5:2)]`, `clearCalls == 1`, `PlayerLeaf` present, no `AyahLeaf`.
- `'the foot listen plays the selected ayah to the surah end'` and, with nothing selected and page bounds 2:6–2:16, `'… from the page's first ayah'` → `playRanges == [(2:6, 2:286)]`.
- `'system back closes an open leaf first'` (`pushed: true`, selected 2:6): `await tester.binding.handlePopRoute()` and pump → `mushaf.clearCalls == 1`, no `AyahLeaf`, `find.byType(MushafPage)` finds one; a second `handlePopRoute()` and `pumpAndSettle` → `find.byType(MushafPage)` finds nothing.
- `'the head back leaves in one tap, even with a leaf open'` (`pushed: true`, selected 2:6): tap `head-back`, `pumpAndSettle` → `find.byType(MushafPage)` finds nothing.
- `'listening-away shows in the player leaf'`: `followPlayback: false, playingAyah: 3:12`, `mushaf.playingPage = 51` → «يُتلى الآن: آل عمران ١٢، صفحة ٥١»; `player-return` → `resumeCalls == 1`.
- `'menu jump moves in place once'`: tap `foot-menu`, `enterText(menu-search, '120')`, tap `menu-go` → `jumps == [120]`, `currentPage` 120, no `(_, true)` in `setPages`.
- `'menu display opens the display sheet'` (`DisplaySheet` found), `'menu play page plays the page range'` (bounds 2:6–2:16 → `playRanges == [(2:6, 2:16)]`). («أماكني» calls `context.push`, which needs a `GoRouter`; Task 7's menu test pins that the tile pops `MenuOpenPlaces()`.)
- `'the head names the running surah and the juz and hizb'`: page 50 → «آل عمران» and the `head_juzHizb` text of `getPageMeta(50)`.
- `'the page box keeps its size between text scales'`: pump at `textScale: 1.0`, read `tester.getSize(find.descendant(of: find.byType(MushafPageView), matching: find.byType(AspectRatio)).first)`; pump again at `2.0` → the same `Size`, and `tester.takeException()` is null.
- `'jump arrival with focusAyah shows the ayah leaf'`: `args = MushafArgs(page: 50, focusAyah: 3:7, origin: MushafOrigin.jump)`, `mushaf: FakeMushaf(MushafState.initial(args))` → `AyahLeaf` with «آل عمران، الآية ٧».

Rewrites:
- `mushaf_page_dispose_test.dart`: `setUp(setUpMushafHarness)`; `disposeOn` becomes a thin wrapper over `pumpMushafPage` (then `act`, then `pumpWidget(const MaterialApp(home: SizedBox.shrink()))`) and returns `(h.repo, h.playback)`. The two in-place jump tests, `'in-place jump: dispose does not overwrite last read'` (line 250) and `'an in-place jump saves the pre-jump page, not the target'` (line 299), go through `foot-menu` → `enterText(menu-search, …)` → `menu-go` instead of `mushaf-top-page` / `page-jump-go`. The `MushafState(…, chromeVisible: true)` arguments lose `chromeVisible`. Delete the `browse bar` group (its successors are the shell tests above) and the `mushaf_browse_bar.dart` import.
- `mushaf_page_follow_test.dart`: `setUp(() => setUpMushafHarness(pageService: _SurahIsPageService()))`; `pumpPage` calls `pumpMushafPage(tester, args, mushaf: mushaf)`, so the reader gets `BookmarkCubit`, `SurahDownloadCubit` and `QuranBrowseService` (the ayah leaf, player leaf and menu need them) and the harness `FakeSettings` (which answers `markHintSeen` and `markDownloadHintSeen` once Task 9 calls them). Delete the file's own `_FakeSettings`, `_FakePlayback`, stubs and provider list. `'a page jump emits exactly one manual setPage'` becomes `'a menu jump calls jumpTo once and no manual setPage'` (`_RecordingMushaf` overrides `jumpTo` to record and call `super`); drop `mushaf.setChrome(true)`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf`. Expected: FAIL (shell missing).

- [ ] **Step 3: Implement**

`MushafPage`:
- `build`: `PopScope(canPop: selectedAyah == null, onPopInvokedWithResult: (didPop, _) { if (!didPop) _mushafCubit.clearSelection(); })` (a `BlocSelector` on `selectedAyah`) → the existing follow `BlocListener` → `Scaffold(backgroundColor: paper.background)` → `SafeArea` → `Column`:
  1. `BlocBuilder<MushafCubit, MushafState>` (`buildWhen`: page, selected, playing, bounds) → `RunningHead(surahName: runningSurah name or '', page, juz/hizb from getPageMeta(currentPage), colors, onBack: () => Navigator.of(context).pop(), onOpenMenu: _openMenu)`. `pop()` (not `maybePop`) bypasses `PopScope`, so the head always leaves.
  2. `Expanded(Stack([Positioned.fill(reading area), PositionedDirectional(start: 0, end: 0, bottom: 0, child: _LeafSlot(...))]))`.
  3. `BlocBuilder` (page, selected, bounds) → `ReaderFoot(onPrevious: page > 1 ? () => _turnBy(-1) : null, onNext: page < 604 ? () => _turnBy(1) : null, onListen: listenRange(...) == null ? null : _onListen, onMenu: _openMenu)`.
- `_LeafSlot` (private, same file): `BlocSelector` on `selectedAyah` + `BlocSelector<PlaybackCubit, PlaybackState, bool>` on `(requestedAyah ?? currentAyah) != null` → `AnimatedSwitcher(200 ms)` of `AyahLeaf(key: ValueKey(selected), onClose: clearSelection, onListenFromHere: play to surah end + resumeFollow + clearSelection, onListenFromSurahStart: play (s:1)–(s:last) + resumeFollow + clearSelection, onListenPage: () { _onPlayPage(); _mushafCubit.clearSelection(); })`, else `PlayerLeaf(key: ValueKey('player'), awayAyah: !follow ? playingAyah : null, awayPage: _mushafCubit.playingPage, onReturnToPlaying: resumeFollow, onNewPlay: resumeFollow)` under a `BlocBuilder` on `followPlayback`/`playingAyah`, else `SizedBox.shrink()`. Every play action clears the selection so the player takes the slot (Deliberate reading 5).
- `_turnBy(delta)`: page mode `_pageController.animateToPage(current - 1 + delta, duration: 250 ms, curve: easeInOut)`; scroll mode `_scrollController.animateTo(_scrollOffsetFor(current + delta), …)`. Neither begins a `_turns` turn, so `_setPageFromView` sees them as manual.
- `_onListen`: `listenRange(selected, pageAyahs)` → `resumeFollow`, `playRange`, `clearSelection`.
- `_openMenu`: `final action = await MenuSheet.show(context, currentPage: state.currentPage, currentSurah: state.runningSurah, currentJuz: sl<QuranMetaService>().getPageMeta(state.currentPage).juz);`, then `if (!mounted) return;` and `switch (action)`: `MenuJump(:final page)` → `_jumpInPlace(page)`; `MenuOpenPlaces()` → `context.push(AppRouter.bookmarksPath)`; `MenuOpenDisplay()` → `DisplaySheet.show(context)`; `MenuPlayPage()` → `_onPlayPage()`; `null` → nothing.
- `_jumpInPlace(page)` (replaces `_onJumpToPage`), in this order: `_lastReadSaver.rearm()`; `final turn = _turns.begin(page)`; `_mushafCubit.jumpTo(page)` (before the controller moves, so `jumpFrom` reads the old page); `jumpToPage` / `jumpTo`; post-frame `_turns.end(turn)`.
- Delete `_BrowseBarSlot`, `const AyahPlaybackOverlay()`, the top bar and every browse-bar and page-jump reference, and the now-unused imports: `mushaf_top_bar.dart`, `mushaf_browse_bar.dart`, `ayah_playback_overlay.dart`, `page_jump_sheet.dart`, `page_bookmark_cubit.dart` and `page_bookmark_state.dart` (Deliberate reading 20: the page-bookmark toggle lived only in the browse bar; `MushafPageRibbon` keeps reading `PageBookmarkCubit` itself).

- [ ] **Step 4: Run** `flutter test test/features/surah test/core`, then `flutter analyze --no-fatal-infos`, then the full `flutter test`. Expected: PASS, ≤ 69 infos (no unused import left in `mushaf_page.dart`).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_follow_test.dart
git commit -m "feat(mushaf): always-visible head and foot, ayah and player leaves in one slot

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8c: Delete the S1 chrome, its state and its tests

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` (delete `_publishHighlightBounds`, `_isPageMode` and the printed-chrome block)
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`, `mushaf_cubit.dart` (remove `chromeVisible`, `isOverlayPinned`, `highlightedAyahCenterY`, `clearHighlightedCenterY`, `setHighlightBounds`, `toggleChrome`, `setChrome`, `unpinOverlay`)
- Delete (`git rm`): `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`, `ayah_action_popover.dart`, `mushaf_top_bar.dart`, `mushaf_browse_bar.dart`, `page_jump_sheet.dart`, `mushaf_printed_chrome.dart`, `mushaf_page_number_text.dart`, `lib/features/surah/presentation/utils/printed_chrome_resolver.dart`; tests `test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart`, `mushaf_top_bar_test.dart`, `mushaf_browse_bar_test.dart`, `page_jump_sheet_test.dart`, `mushaf_printed_chrome_test.dart`, `test/features/surah/presentation/pages/mushaf/ayah_action_popover_test.dart`, `test/features/surah/presentation/utils/printed_chrome_resolver_test.dart`, `test/features/surah/presentation/cubit/mushaf_chrome_test.dart`
- Modify: `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `widgets/mushaf_page_view_tap_test.dart` (drop the `setHighlightBounds` overrides), `widgets/mushaf_page_view_load_error_test.dart` (drop the `MushafPrintedChrome` import and assert), `test/config/theme/typography_ratchet_test.dart` (lower `_baseline`)
- Modify: `.claude/rules/feature-widgets.md` (drop `printed_chrome_resolver.dart`), `.claude/rules/theming.md` (drop the printed-chrome `QCF2BSML` exception; the font stays in `pubspec.yaml` for the asset generator), `.claude/rules/icons.md`

**Interfaces:**
- Produces: nothing new. The overlay's S2 download-hint tests go with `ayah_playback_overlay_test.dart`; their successors are Task 9's shell tests (Deliberate reading 17).

- [ ] **Step 1: Delete** the files with the `git rm` line in Step 5, then remove the fields and methods listed under Files from `MushafState` (constructor, `copyWith` including `clearHighlightedCenterY`, `props`) and `MushafCubit`, and the three blocks from `MushafPageView`. Drop the harness and tap-test `setHighlightBounds` overrides and any `chromeVisible:` argument left in a test.

- [ ] **Step 2: Rules and ratchet**

- `typography_ratchet_test.dart`: run it, then lower each `_baseline` entry to the total its `debugPrint` reports (the printed chrome held two `TextStyle(`, two `fontFamily:` and three `fontSize:`).
- `feature-widgets.md`: drop `printed_chrome_resolver.dart` from the surah utils line.
- `theming.md`: drop «and the mushaf's printed chrome uses the `QCF2BSML` glyph font» from the exceptions.
- `icons.md` line 3: replace «and Material `Icons.*` in the mushaf chrome, playback and a few settings widgets» with «HugeIcons also in the mushaf running head, foot band, ayah leaf and notice chip; Material `Icons.*` in the player leaf, the playback options sheet, `SurahDownloadButton` and a few settings widgets».

- [ ] **Step 3: Run** `flutter test test/features/surah test/config test/core`, then `flutter analyze --no-fatal-infos`, then the full `flutter test`. Expected: PASS, ≤ 69 infos, and `grep -rnE "chromeVisible|isOverlayPinned|highlightedAyahCenterY|AyahPlaybackOverlay|AyahActionPopover|MushafTopBar|MushafBrowseBar|PageJumpSheet|MushafPrintedChrome|resolvePrintedChrome|MushafPageNumberText|setHighlightBounds|popoverPlacement" lib test .claude` prints nothing.

- [ ] **Step 4: Commit**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart lib/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart lib/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome.dart lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_number_text.dart lib/features/surah/presentation/utils/printed_chrome_resolver.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar_test.dart test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_printed_chrome_test.dart test/features/surah/presentation/pages/mushaf/ayah_action_popover_test.dart test/features/surah/presentation/utils/printed_chrome_resolver_test.dart test/features/surah/presentation/cubit/mushaf_chrome_test.dart
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart test/config/theme/typography_ratchet_test.dart .claude/rules/feature-widgets.md .claude/rules/theming.md .claude/rules/icons.md
git commit -m "refactor(mushaf): delete the S1 chrome, printed header and their state

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(If Step 1 had to touch `mushaf_page_dispose_test.dart` or `mushaf_page_follow_test.dart` for a leftover `chromeVisible`, add them to the `git add`.)

---

### Task 9: Notice chip, bounded slide and keep-awake in the reader

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
- Test: `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`, `mushaf_page_dispose_test.dart`, `mushaf_page_harness.dart` (`FakeScreenWake extends ScreenWake` recording `calls` (`List<bool>`); `pumpMushafPage` passes it to `MushafPage` and `MushafHarness` gains `FakeScreenWake wake`). `mushaf_page_follow_test.dart` needs no change: it pumps through the harness since Task 8b, so it gets the fake wake and the harness `FakeSettings` (`markHintSeen`, `markDownloadHintSeen`).

**Interfaces:**
- Consumes: `readerNotice`, `leafSlide`, `lineBottomOf` (Task 2); `NoticeChip` (Task 4); `SettingsCubit.markHintSeen`, `markDownloadHintSeen`, `keepScreenOn` (Task 1); `SurahDownloadCubit.download(Reciter, int)`; `ScreenWake` (Task 1).
- Produces: `MushafPage({super.key, required this.args, this.screenWake = const ScreenWake()})`.

- [ ] **Step 1: Write the failing tests**

Shell test additions:
- `'after a menu jump the chip offers the way back'`: jump 7 → 120 → `notice-chip` reads «العودة إلى صفحة ٧»; tapping it calls `jumpTo(7)` and the chip goes.
- `'a manual turn removes the return chip'`: after the jump, `foot-next` → no `notice-chip`.
- `'first open shows the tap hint until فهمت'`: `hintSeen: false` → «اضغط على أي آية لترى معناها وأزرارها»; `notice-action` («فهمت») calls `markHintSeen`.
- `'selecting an ayah marks the hint seen'`.
- `'the download hint downloads the playing surah'` (successor of the overlay's `'its action downloads the playing surah'`): `playedFromNetwork: true, currentAyah: 3:4, downloadHintSeen: false` → «يمكنك تنزيل السورة لتستمع دون إنترنت»; tapping the chip records `download(reciter, 3)` and `markDownloadHintSeen`; `notice-action` only marks it seen.
- `'a seen download hint never shows'` (successor of `'a seen hint never shows again'`): the same playback with `downloadHintSeen: true` → no `notice-chip`, `markDownloadHintSeenCalls == 0`.
- `'opening the reader mid-stream still shows the download hint'` (successor of the overlay test of that name): pump with the playback already `playedFromNetwork: true` → the chip shows.
- `'an audio error hides the download hint'` (successor of `'an audio error replaces the hint'`, Deliberate reading 21): the chip shows, then `playback.push(state.copyWith(error: 'x', requestedAyah: 3:4))` → no `notice-chip`; the player leaf shows `player-retry`.
- `'an ayah under the leaf slides the page up, one above it does not'`: page mode, bounds for 2:20 with its last line at y 0.95 → after selecting it and settling, `tester.widget<Transform>(find.byKey(const ValueKey('page-slide'))).transform.getTranslation().y` is `< 0` and `≥ -overlayHeight` (the measured overlay column, `tester.getSize` of the leaf slot's column); 2:6 at y 0.1 → `0`. With the page raised, tapping `head-back`'s rect still reaches `RunningHead` (the slide is clipped to the page area).
- `'scroll mode: an ayah under the leaf scrolls by the need, one above it does not'`: `setUpMushafHarness(pageService: QuranPageServiceImpl())`, `FakeSettings(mode: MushafReadingMode.scroll)`, `currentPage: 3`, `pageAyahs` for 2:6 at y 0.1–0.15 and 2:16 at y 0.85–0.9. Record the `ListView`'s `ScrollPosition.pixels`, push `selectedAyah: 2:16`, settle → pixels grew by more than 0 and at most the overlay height, and `setPages` holds no `(_, true)`; clear, push `selectedAyah: 2:6`, settle → pixels unchanged.
- `'scroll mode: arrival with focusAyah slides once'`: `MushafArgs(page: 3, focusAyah: 2:16, origin: jump)`, `FakeMushaf(MushafState.initial(args).copyWith(pageAyahs: …))`, scroll mode → after settling the pixels are past the page 3 offset and `AyahLeaf` is present.
- `'keep-awake turns on at entry and off on dispose'`: fake records `[true]` after pump and `[true, false]` after the reader is replaced; `keepScreenOn: false` → no `true`; switching the setting off while open records `false`.

Dispose test addition: `'return chip: dispose does not overwrite last read'` (jump 7 → 300 via the menu, tap the chip, dispose → `repo.saved` is null).

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf`. Expected: FAIL.

- [ ] **Step 3: Implement**

- Overlay column: `_LeafSlot`'s parent becomes `_MeasuredSize(onChange: (s) => _overlayHeight.value = s.height, child: Column(mainAxisSize: min, children: [_NoticeSlot(...), _LeafSlot(...)]))`. `_MeasuredSize` is a private `SingleChildRenderObjectWidget` whose `RenderProxyBox.performLayout` posts `onChange(size)` in a post-frame callback when the size changes. `_overlayHeight` is a `ValueNotifier<double>` disposed in `dispose`.
- `_NoticeSlot`: inputs `jumpFrom` (`BlocSelector`), `hintSeen` and `downloadHintSeen` (`BlocSelector` on `SettingsCubit`), and from one `BlocSelector<PlaybackCubit, PlaybackState, (int?, bool)>` the pair `(playedFromNetwork && !downloadHintSeen ? skipOrigin?.surah : null, error != null)` → `readerNotice(jumpFrom:, downloadHintSurah:, hintSeen:, audioError:)` → `switch`:
  - `ReturnToPageNotice(:page)` → `NoticeChip(label: notice_returnToPage(page.toLocalized(context)), onTap: () => _jumpInPlace(page))`.
  - `DownloadHintNotice(:surah)` → `NoticeChip(label: surahDownload_hint, onTap: download(reciter, surah) + markDownloadHintSeen, actionLabel: notice_gotIt, onAction: markDownloadHintSeen)`.
  - `TapHintNotice()` → `NoticeChip(label: notice_tapHint, onTap: markHintSeen, actionLabel: notice_gotIt, onAction: markHintSeen)`.
  - `null` → `SizedBox.shrink()`.
  Wrap in `Padding(bottom: 8)` and `AnimatedSwitcher`.
- `BlocListener<MushafCubit, MushafState>` (`listenWhen: a.selectedAyah == null && b.selectedAyah != null`) → `markHintSeen()`.
- Slide, page mode: the reading area (the `Positioned.fill` child of the page-area `Stack`) becomes `ClipRect` → `ValueListenableBuilder(_overlayHeight)` + `BlocSelector` on `(selectedAyah, pageAyahs)` + the page area's `LayoutBuilder` size → `TweenAnimationBuilder<double>` (200 ms) → `Transform.translate(key: const ValueKey('page-slide'), offset: Offset(0, -slide), child: PageView)`, with `slide = leafSlide(area: size, lineBottom: lineBottomOf(...), overlay: height)` and `0` when `lineBottomOf` is null. The `ClipRect` keeps the raised page from painting over the running head or catching its taps.
- Slide, scroll mode (Deliberate reading 10): a `BlocListener` on `selectedAyah` going non-null calls `_slideScrollTo(ayah)`:

```dart
Future<void> _slideScrollTo(AyahIdentifier ayah) async {
  final page = sl<QuranPageService>().getPageForAyah(ayah.surah, math.max(ayah.ayah, 1));
  final state = _mushafCubit.state;
  final bounds = page == state.currentPage
      ? state.pageAyahs
      : (await sl<GetMushafPage>()(page)).fold((_) => const <AyahBoundEntity>[], (e) => e.ayahs);
  final lineBottom = lineBottomOf(bounds, ayah);
  if (!mounted || lineBottom == null || !_scrollController.hasClients || _mushafCubit.state.selectedAyah != ayah) return;
  final position = _scrollController.position;
  final bottom = _scrollOffsetFor(page) - position.pixels + lineBottom * _scrollPageHeight;
  final need = bottom - (position.viewportDimension - _overlayHeight.value);
  if (need <= 0) return;
  final turn = _turns.begin(_mushafCubit.state.currentPage);
  _scrollController
      .animateTo(position.pixels + need, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut)
      .whenComplete(() => _turns.end(turn));
}
```

  The `_turns` turn targets the current page, so `_setPageFromView` treats the scroll as a follow move, not a manual turn (the same shape as `_onFollowChanged`). Arrival: the `_MeasuredSize.onChange` handler sets `_overlayHeight.value`, and the first time it reports a height while scroll mode is on and `selectedAyah != null` (a private `bool _arrivalSlid`), it calls `_slideScrollTo(selectedAyah)` once; the `BlocListener` never fires for a selection that is already in the initial state.
- Keep-awake: `initState` → `if (settings.keepScreenOn) widget.screenWake.set(true)`; a `BlocListener<SettingsCubit, SettingsState>` on `keepScreenOn` → `widget.screenWake.set(value)`; `dispose` → `widget.screenWake.set(false)`.

- [ ] **Step 4: Run** `flutter test test/features/surah`, then `flutter analyze --no-fatal-infos` and the full `flutter test`. Expected: PASS, ≤ 69 infos, 1 skipped.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart
git commit -m "feat(mushaf): notice chip, bounded page slide and keep-awake in the reader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
