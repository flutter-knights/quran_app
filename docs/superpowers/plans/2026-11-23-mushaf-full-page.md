# Mushaf Full-Page Reading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the mushaf page take as much of the phone as possible: crop the page's blank printed bands so it runs to the full screen width (phase 1, ×1.10 text, chrome unchanged), then offer an opt-in immersive mode that hides the foot and slims the head (phase 2, ×1.17 text).

**Architecture:** The 604 page PNGs and bounds JSONs stay as they are; no regeneration. A `PageCrop` value (normalised insets of the 1536×2795 page) decides which window of the page is shown. `MushafPageView` lays the full page out at the size that makes the window fill its box and clips it, so the highlight painter and hit test keep working in page space; the margin overlays (saved dots, فواصل ribbons) and the reader's slide maths map page coordinates into the box through the crop. The crop comes from two new settings: `MushafPageFit` (fill / print) and `autoHideChrome`.

**Tech Stack:** Flutter 3.47.8, flutter_bloc + HydratedCubit (`SettingsCubit`), equatable, flutter_test.

**Spec:** `docs/design-audit/mushaf/surah-header/final-spec.md` §2–3 (git-ignored design folder, same machine), with the judges' reasoning in `judge-impl.md` / `judge-ux.md` and the layout audit in `_docs/mobile-reference.md` beside it. Mockups: `final-reading.html` states `phase1-*`, `phase2-*`. Builds on the surah-header branch (`feature/mushaf-surah-header`, PR for commits 7a307a02 + 616ed6d9): the header frame now sits inside the text column, which is what lets the side crop exist.

## Global Constraints

- Page image space: 1536×2795, `mushafPageAspect = 1536 / 2795` (`lib/features/surah/presentation/utils/reader_rules.dart:11-14`). Never change it; never regenerate assets in this plan.
- Crop windows (normalised page fractions, copied from the spec):
  - `PageCrop.none`: 0 / 0 / 0 / 0 (setting «مقاس المصحف المطبوع»; today's look).
  - `PageCrop.bands`: top 0.0565, bottom 0.0325, left 0, right 0 (phase 1 default, «ملء الشاشة»).
  - `PageCrop.immersive`: top 0.0565, bottom 0.0325, left 0.035, right 0.035 (phase 2, auto-hide on and fit = fill).
- Expected sizes on 390×844 (template insets 47/34): phase 1 line pitch ≈ 43 px, text column ≈ 308 px; phase 2 chrome hidden pitch ≈ 46.2 px, column ≈ 331.6 px.
- Tap-to-select stays exactly as shipped (`LeafTapAction`, `mushaf_page_view_tap_test.dart`). Auto-hide never steals the single tap.
- Chrome actions are never lost: back, surah, page medallion, juz/hizb, previous/next, «استماع», «القائمة», فواصل cluster and tails, saved dots.
- Every user-facing string goes in both `lib/l10n/intl_ar.arb` and `intl_en.arb` and in `lib/core/localization/pending_s.dart` (the generated `S` only regenerates on IDE save; `PendingS` bridges it, and its test keeps the three in sync). Copy: «مقاس الصفحة» / "Page size", «ملء الشاشة» / "Fill the screen", «مقاس المصحف المطبوع» / "Printed size", «إخفاء الأدوات تلقائيًا» / "Hide controls automatically", «إظهار الأدوات» / "Show controls".
- `Settings.minPageBrightness` goes 0.6 → 0.7 (spec §3: at 0.6 the 60 % basmala drops to 2.70:1 on night papers).
- Project rules apply: no comments, no redundant type annotations, `TS.*` typography, `context.colorScheme` / `MushafPaperX` colours, `PositionedDirectional`, `analyze` and `test` clean before the PR.

## Review Focus

- **Ink under the crop.** Any page whose verse or header ink falls outside a crop window would be cut. Task 1 adds a test that walks all 604 bounds JSONs (ayah lines and the new `headers` rects) and asserts they sit inside `PageCrop.immersive`.
- **Landscape and scroll mode.** Landscape forces scroll mode (`mushaf_page.dart:306-310`); scroll items must use the same crop aspect, or the list's `itemExtent` and `_slideScrollTo` drift from the drawn pages. Task 4 pins `itemExtent == width / crop.aspect + 4`.
- **Switching the setting while a page is open.** Changing «مقاس الصفحة» or auto-hide mid-read must keep the same page and selection and not throw from a stale `PageController`. Task 2's display-sheet test and Task 5's shell test switch the setting with a page open.
- **Leaf/notice slide with a taller page.** In immersive mode the last lines sit under the foot handle or the leaf; `leafSlide` must measure from the box, not the page. Task 4 tests `leafSlide` with a crop.
- **Old saved brightness.** A user who saved 0.6 must come back clamped to 0.7, not crash or reset to 1.0. Task 6 tests the model read.

---

### Task 1: `PageCrop`

**Files:**
- Create: `lib/features/surah/presentation/utils/page_crop.dart`
- Test: `test/features/surah/presentation/utils/page_crop_test.dart`
- Modify: `.claude/rules/feature-widgets.md` (add `page_crop.dart` to the `surah` utils list)

**Interfaces:**
- Produces: `class PageCrop extends Equatable` with `const PageCrop({double left = 0, double top = 0, double right = 0, double bottom = 0})`, `static const none`, `static const bands`, `static const immersive`, `double get aspect`, `double toBoxX(double pageX)`, `double toBoxY(double pageY)`, `Offset toPage(Offset local, Size box)`, `Rect pageRectIn(Size box)` (the full page's rect in box coordinates, negative offsets for cropped sides).

- [ ] **Step 1: Write the failing tests**

```dart
test('none keeps the printed aspect', () => expect(PageCrop.none.aspect, closeTo(mushafPageAspect, 1e-9)));
test('bands widens the box to 0.5496 / 0.911', () => expect(PageCrop.bands.aspect, closeTo(mushafPageAspect / 0.911, 1e-6)));
test('the window edges map to 0 and 1', () {
  expect(PageCrop.bands.toBoxY(0.0565), closeTo(0, 1e-9));
  expect(PageCrop.bands.toBoxY(0.9675), closeTo(1, 1e-9));
  expect(PageCrop.immersive.toBoxX(0.035), closeTo(0, 1e-9));
});
test('toPage inverts toBox', () {
  const box = Size(390, 646.6);
  final local = Offset(PageCrop.immersive.toBoxX(0.3) * box.width, PageCrop.immersive.toBoxY(0.6) * box.height);
  final page = PageCrop.immersive.toPage(local, box);
  expect(page.dx, closeTo(0.3, 1e-9));
  expect(page.dy, closeTo(0.6, 1e-9));
});
test('pageRectIn scales the page so the window fills the box', () {
  final r = PageCrop.bands.pageRectIn(const Size(390, 646.6));
  expect(r.top, closeTo(-0.0565 * r.height, 1e-6));
  expect(r.height * 0.911, closeTo(646.6, 1e-6));
});
test('no ayah line or header frame on any page falls outside the immersive window', () {
  for (var p = 1; p <= 604; p++) {
    final json = jsonDecode(File('assets/mushaf/bounds/page_${p.toString().padLeft(3, '0')}.json').readAsStringSync());
    final rects = [
      for (final a in json['ayahs']) ...a['lines'],
      ...?json['headers'],
    ];
    for (final r in rects) {
      expect(r['x'], greaterThanOrEqualTo(PageCrop.immersive.left), reason: 'page $p');
      expect(r['x'] + r['w'], lessThanOrEqualTo(1 - PageCrop.immersive.right), reason: 'page $p');
      expect(r['y'], greaterThanOrEqualTo(PageCrop.immersive.top), reason: 'page $p');
      expect(r['y'] + r['h'], lessThanOrEqualTo(1 - PageCrop.immersive.bottom), reason: 'page $p');
    }
  }
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/surah/presentation/utils/page_crop_test.dart`
Expected: FAIL, `page_crop.dart` not found.

- [ ] **Step 3: Implement `PageCrop`** with the three constants above; `aspect = mushafPageAspect * (1 - left - right) / (1 - top - bottom)`; `props` lists the four insets. If the last test fails on a page, report the page and the rect; do not shrink the windows without checking the mockup (`final-reading.html`).

- [ ] **Step 4: Run to verify they pass**, same command. Expected: PASS.

- [ ] **Step 5: Commit** `feat(mushaf): PageCrop, the shown window of a mushaf page`.

### Task 2: page-size setting and display-sheet row

**Files:**
- Create: `lib/core/constants/mushaf_page_fit.dart` (`enum MushafPageFit { fill, print }`)
- Modify: `lib/features/settings/domain/entities/settings.dart` (field `pageFit`, default `MushafPageFit.fill`), `lib/features/settings/data/models/settings_model.dart` (constructor, `copyWith`, `fromMap` with the `readingMode` pattern at `:111`, `toMap` key `'pageFit'`), `lib/features/settings/presentation/cubit/settings_cubit.dart` (`void updatePageFit(MushafPageFit fit)`), `lib/features/surah/presentation/utils/enum_localization.dart` (`MushafPageFit.localized`), `lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart` (an `AppSegmentedSelector<MushafPageFit>` row titled «مقاس الصفحة», after the reading-mode row), ARB ×2 + `pending_s.dart`.
- Create: `lib/features/surah/presentation/utils/page_crop.dart` gains `PageCrop pageCropFor({required MushafPageFit fit, required bool autoHideChrome})` (fill+hide → immersive, fill → bands, print → none). Until Task 5, call it with `autoHideChrome: false`.
- Test: `test/features/settings/data/models/settings_model_test.dart`, `test/features/settings/presentation/cubit/settings_cubit_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart`, `page_crop_test.dart`.

**Interfaces:**
- Consumes: `PageCrop` (Task 1).
- Produces: `Settings.pageFit`, `SettingsCubit.updatePageFit`, `pageCropFor`.

- [ ] **Step 1: Write the failing tests**: model round-trips `pageFit: print`; an unknown or missing `'pageFit'` reads as `fill`; `updatePageFit(MushafPageFit.print)` emits it; the display sheet shows «مقاس الصفحة» with both options and tapping «مقاس المصحف المطبوع» calls the cubit; `pageCropFor(fit: fill, autoHideChrome: false) == PageCrop.bands`, `(print, any) == PageCrop.none`, `(fill, true) == PageCrop.immersive`.
- [ ] **Step 2: Run** `flutter test test/features/settings test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart test/features/surah/presentation/utils/page_crop_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** per the file list.
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): page size setting (fill the screen / printed size)`.

### Task 3: `MushafPageView` draws the cropped window

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart`, `mushaf_page_view_margin_test.dart`, `mushaf_page_view_places_test.dart`, new `mushaf_page_view_crop_test.dart`

**Interfaces:**
- Consumes: `PageCrop`, `pageCropFor`, `Settings.pageFit`.
- Produces: `MushafPageView` reads the crop from `SettingsCubit` (it already watches settings at `:97`); its outer box is `AspectRatio(crop.aspect)`.

- [ ] **Step 1: Write the failing tests** in `mushaf_page_view_crop_test.dart` (pump at 390 wide with fit = fill):
  - the view's size is `390 × 390 / PageCrop.bands.aspect`;
  - tapping at the box point of an ayah's first line (`crop.toBoxX/Y` of the line centre) selects that ayah;
  - a saved dot's top equals `crop.toBoxY(line.y + line.h / 2) * boxHeight - 3`;
  - the فواصل cluster sits at the box's top-end corner (`top: 0`) and `FasilGeometry.margin == boxWidth * crop.toBoxX(pageTextLeftOf(ayahs))`;
  - with fit = print the size and every position equal today's (existing tests unchanged).
- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets`. Expected: the new file FAILS, the old ones pass.
- [ ] **Step 3: Implement**: outer `AspectRatio(crop.aspect)` → `LayoutBuilder` → `ClipRect` → `Stack`. The paper, both `Image.asset` layers, the brightness scrim, the highlight painter and the gesture detector move into a `Positioned.fromRect(crop.pageRectIn(box))` child, so the highlight and `_hitTest` stay in page space unchanged. `_SavedDots` and `_FasilLayer` stay in box space and map through the crop (`toBoxY` for tops, `toBoxX` for the text margin). The error branch uses the same `AspectRatio(crop.aspect)`.
- [ ] **Step 4: Run** the widgets folder. Expected: PASS.
- [ ] **Step 5: Commit** `feat(mushaf): the page view shows the PageCrop window`.

### Task 4: reader slide and scroll maths through the crop

**Files:**
- Modify: `lib/features/surah/presentation/utils/reader_rules.dart` (`leafSlide` gains `PageCrop crop = PageCrop.none`; the page height becomes `min(area.height, area.width / crop.aspect)` and `lineBottom` is mapped with `crop.toBoxY`), `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` (pass the crop to `leafSlide` at `:899-934` and `:917-921`; scroll `itemExtent` at `:807` = `width / crop.aspect + 4`; `_slideScrollTo` and the offsets at `:174, :234-238, :428-434` use `crop.toBoxY`).
- Test: `test/features/surah/presentation/utils/reader_rules_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_follow_test.dart`.

**Interfaces:**
- Consumes: `PageCrop`, `pageCropFor`.
- Produces: `leafSlide({required Size area, required double lineBottom, required double overlay, PageCrop crop = PageCrop.none})`.

- [ ] **Step 1: Write the failing tests**: `leafSlide(area: Size(390, 651), lineBottom: 0.9675, overlay: 200, crop: PageCrop.bands)` slides by exactly the overlap of the box's bottom edge with the overlay; the existing `PageCrop.none` cases keep their values; in scroll mode with fit = fill the list's `itemExtent == 390 / PageCrop.bands.aspect + 4` and following playback to a line lands it at the same on-screen y as the painter draws it.
- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/pages/mushaf`. Expected: FAIL.
- [ ] **Step 3: Implement** per the file list.
- [ ] **Step 4: Run** the same command, then the whole suite `flutter test`. Expected: PASS.
- [ ] **Step 5: Verify on the emulator** (`flutter run -d emulator-5554`): pages 1, 106, 128, 443, 604 in page and scroll mode, cream and night; select the last ayah on a page and open the leaf; place a فاصل. Save screenshots for the PR.
- [ ] **Step 6: Commit** `feat(mushaf): reader slide and scroll follow the cropped page`. Phase 1 is shippable here; open the PR if the owner wants phase 1 alone.

### Task 5: opt-in immersive chrome (phase 2)

**Files:**
- Modify: settings entity/model/cubit (`bool autoHideChrome = false`, `updateAutoHideChrome(bool)`, model key `'autoHideChrome'` read with `_readBool(…, false)`), `display_sheet.dart` (an `AppSettingsTile` switch «إخفاء الأدوات تلقائيًا», enabled only when fit = fill), `mushaf_page.dart` (chrome visibility), `page_crop.dart` call sites (pass the real `autoHideChrome`).
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/running_line.dart` (`RunningLine`: 48 px band, surah · page · juz in `colors.ink2`, `TS.medium12`, centred, no actions), `lib/features/surah/presentation/pages/mushaf/widgets/chrome_handle.dart` (`ChromeHandle`: a 48 px tall bottom strip with a short paper-ink pill and semantics label «إظهار الأدوات»).
- Test: settings tests, `display_sheet_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`, new `running_line_test.dart`, `chrome_handle_test.dart`.

**Interfaces:**
- Consumes: `pageCropFor` (Task 2), the cropped view (Task 3), `leafSlide(crop:)` (Task 4).
- Produces: `Settings.autoHideChrome`, `SettingsCubit.updateAutoHideChrome`, `RunningLine`, `ChromeHandle`.

- [ ] **Step 1: Write the failing tests**:
  - auto-hide off: head and foot exactly as today (existing shell tests unchanged);
  - auto-hide on: after a page settles the foot is hidden and `ChromeHandle` shows; tapping the handle brings the foot back; the head is `RunningLine` showing the surah, the page number and the juz;
  - auto-hide on: a single tap on an ayah still selects it and opens the leaf (no chrome toggle);
  - the foot comes back while a leaf (`AyahLeaf` or `PlayerLeaf`) is open and while playback is active;
  - turning the setting on and off with a page open keeps the same page and selection;
  - the switch is disabled when fit = print.
- [ ] **Step 2: Run** `flutter test test/features/settings test/features/surah/presentation/pages/mushaf`. Expected: FAIL.
- [ ] **Step 3: Implement**: in `MushafPage`, a local `ValueNotifier<bool> _chromeShown` (ephemeral UI state, not in a cubit); the foot is wrapped in `AnimatedSlide` + `AnimatedOpacity` (200 ms, `Curves.easeInOut`) and replaced by `ChromeHandle` when hidden; hide on `PageView` settle (`onPageChanged`) and show on handle tap, leaf open, or playback. When hidden, the reading area grows into the foot's space, so the page crop becomes `PageCrop.immersive` and the overlay height for `leafSlide` is the handle's 48 px.
- [ ] **Step 4: Run** the same command, then `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(mushaf): opt-in immersive reading hides the foot and slims the head`.

### Task 6: brightness floor 0.7

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart:60` (`minPageBrightness = 0.7`).
- Test: `test/features/settings/data/models/settings_model_test.dart`, `test/features/settings/presentation/cubit/settings_cubit_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_brightness_test.dart`.

- [ ] **Step 1: Write the failing tests**: a stored `'pageBrightness': 0.6` reads back as 0.7; `updatePageBrightness(0.5)` emits 0.7; the display-sheet slider's `min` is 0.7.
- [ ] **Step 2: Run** `flutter test test/features/settings test/features/surah/presentation/pages/mushaf/widgets`. Expected: FAIL.
- [ ] **Step 3: Implement**: change the constant (the model and cubit already clamp to it).
- [ ] **Step 4: Run** the same command. Expected: PASS.
- [ ] **Step 5: Commit** `fix(settings): page brightness floor 0.7 keeps the basmala readable on night papers`.

### Finish

- [ ] `flutter analyze` (no new issues against main's 69 infos) and `flutter test` all green.
- [ ] Emulator screenshots: before / phase 1 / phase 2 (shown and hidden), cream and night, pages 106 and 604.
- [ ] Branch `feature/mushaf-full-page` from `origin/main` after the header PR is merged; `gh pr create --base main`; leave the merge to the owner.

## Open decisions for the owner (from the spec)

1. Ship phase 2's auto-hide at all, or stop after Task 4 (×1.10, no behaviour change)? The plan keeps Task 5 separate so either works.
2. Brightness floor 0.7 for all papers (Task 6), or paper-aware floors instead?
3. Ring medallion size in the header (A's ring is half the rosette; the reference's is closer to equal): a follow-up to `surah_frame.dart`, not part of this plan.
