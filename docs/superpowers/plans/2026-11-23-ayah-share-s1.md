# Ayah share S1 (image card, tafsir card, share sheet, entry points) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share one ayah as a PNG cut from the mushaf's own page images (surah frame, faded basmala, printed lines, rosette) in the reader's paper colours, optionally with Tafsir al-Muyassar underneath, from a share sheet opened by the study leaf and the saved-ayah row menu.

**Architecture:** Bounds-only geometry (grid lines, header slot, overlap-aware edges, rosette accent rule) lives once in `surah/presentation/utils/mushaf_grid.dart`. A new `features/ayah_share/` holds the domain content + use case, a pure card layout that turns bounds into plain src/dst rects, a renderer that cuts small crops once per ayah and recomposes them on every toggle into PNG bytes, `AyahShareCubit`, and `AyahShareSheet` whose preview shows exactly the bytes that get shared.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), `dart:ui` (`PictureRecorder`, `drawImageRect`, `toByteData`), flutter_bloc + bloc_test, equatable, dartz, dio `CancelToken`, share_plus 13 (`ShareParams`, `XFile.fromData`, `fileNameOverrides`), skeletonizer 3, hugeicons 4, the vendored `quran` package.

**Spec:** `docs/superpowers/specs/2026-11-23-ayah-share-design.md`: D1–D3, D6–D9, D11, §2, §3 in full, §5 seams 1–6, §6 (S1 parts), Appendix A. Where spec and plan disagree the spec wins, except the **Deliberate readings** below.

**The plan and spec are self-contained.** The layout rules were ported from a Python prototype (`card_proto.py`: `edges`, `line_src`, `grid_band`, `header_source`, `header_box`, `line_items`, `compose`) that lived in a session scratchpad and may no longer exist. Its names appear below for orientation only and are non-normative: every rule an implementer needs is restated in this plan, and the numbers in the tests are the acceptance criteria.

## Global Constraints

- Worktree `/Users/sameh/Documents/flutter_projects/quran_app-ayah-share`, branch `feature/ayah-share`. Never switch branches, never touch `main` or `/Users/sameh/Documents/flutter_projects/quran_app`, never push, rebase or amend.
- Commits: stage explicit paths only (never `git add -A` / `git add .`), only files the task changed. Message `feat|fix|refactor|test|docs(ayah-share): …` ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No comments and no doc comments in new or changed code. No redundant type annotations. Lean code. Existing comments stay.
- Strings: each new key goes in `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb` and as `String get key => _ar ? '…' : '…';` in `lib/core/localization/pending_s.dart`; read with `PendingS.of(context)` in `build`, `PendingS.current` / `S.current` in callbacks. `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`, never run `intl_utils:generate`. Reuse `S.share` «مشاركة», `S.share_failed`, `S.ayah_label`, `S.playback_close`, `PendingS.tafsir_muyassar`, `PendingS.tafsir_loadFailed`, `PendingS.mushaf_retry`, `PendingS.display_paper`. Arabic-Indic digits via `toLocalized(context)`.
- Card text is always Arabic (`PendingS.forLanguage('ar')`); the share text follows the app locale (D9).
- Colours: card and swatches via `MushafPaperX` / `MushafPaperColors`; sheet chrome via `context.colorScheme`; no hex outside the files `theming.md` allows. Text only `TS.*` with `.copyWith(height:, color:)`; the renderer builds `TextSpan(style: TS.x.copyWith(...))`, never `TextStyle(`, `fontSize:`, `fontWeight:` or `fontFamily:` (`test/config/theme/typography_ratchet_test.dart` must not rise). Icons: HugeIcons.
- Layers: `ayah_share/domain/` is pure Dart (may import `surah`/`quran_playback` domain and `core/errors/failure.dart`). Presentation never imports `data/`. Use cases, renderer: lazy singletons; cubit: `registerFactoryParam<AyahShareCubit, AyahIdentifier, void>`.
- Cubit: `if (isClosed) return;` before every emit after an `await`; Equatable state with every field but `cardBytes` in `props`; no `BuildContext` in the cubit; the OS share runs in the sheet's `BlocListener`.
- Loading: skeleton for the first card, slim `LinearProgressIndicator` only over a visible preview. A visible skeleton or progress bar never settles: tests `pump()` instead of `pumpAndSettle()` while one shows.
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`; never modify `assets/mushaf/**`. No iOS build in S1.
- Every task formats exactly the `.dart` paths in its `git add` line with `dart format <paths>` (never a directory, `.`, `lib`, `test` or `lib/generated/**`).
- Every task's verify step ends with `flutter test` and `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings, ≤ 69 infos; all tests pass, 1 skipped. Running totals from 1660: Task 1 → 1671, 2 → 1681, 3 → 1690, 4 → 1702, 5 → 1721, 6 → 1727, 7 → 1741, 8 → 1741. If the start differs, keep the deltas.
- Test fixtures read real bounds from disk: `MushafPageModel.fromJson(jsonDecode(File('assets/mushaf/bounds/page_${page.toString().padLeft(3, '0')}.json').readAsStringSync()))`, as `test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart:48` does (file names are the page zero-padded to three digits); page numbers come from `quran.getPageNumber`. No golden tests.
- Never hand-type diacritised Quran text in a test: build expected verse strings from the `quran` package (`quran.getVerse`), since a typed literal can differ in mark order (shadda/fatha) from the bundled text.

## Deliberate readings (the plan governs here)

1. **Layout takes raw pieces, not `ShareCardContent`.** Seam 2 precedes the entity (seam 3), so `shareCardLayout` takes `ayah`, `page`, `pageBounds`, `startPage`, `startPageBounds` and the measured header; the renderer (seam 4) unpacks the content into it.
2. **No previous-page bounds in `ShareCardContent`.** §3.3 lists them, but nothing reads them: a header pushed off the start page is always grid line 14 of `startPage − 1` (verified for all 18 surahs), and the renderer needs that page's PNGs, not its bounds. The use case fetches at most two bounds files.
3. **S1 state carries only what the S1 sheet reads.** No `format`, `content` or `error` fields and no «صورة / مقطع بالتلاوة» selector (spec §3.5 item 2 allows omitting it; S2 adds selector, `format` and the reel fields). Content and crops are private cubit fields.
4. **Paper comes from `sl<SettingsCubit>()` inside the DI factory**, keeping the factory param `void` as §3.5 names it; hosts that open the sheet need no `SettingsCubit` provider, only a GetIt stub of the cubit factory.
5. **Tafsir tokens are isolated.** `TafsirRepositoryImpl` keys its in-flight page future by `CancelToken` (`Expando`), so the share cubit's own token never joins or cancels the study leaf's `TafsirCubit` request; switching the tafsir off cancels only the share's token (Task 5 pins it on the fake).
6. **Every slice is a plain rect.** The accent rule (grid-band clamp, 28 px kept left of an interior left edge, 28 px dropped at an interior right edge) is expressed as its own accent src/dst rect, and the ink of the last line never takes the bleed; the renderer does no masking. Header crops are cut from the measured band crops, so each header-page layer is decoded once for the header.
7. **Not ported from the prototype:** `center-first` alignment, the tafsir placeholder bars (§3.4 governs the real block), the fixed 0.42 basmala opacity (normalised from the crop's peak alpha, D2). The tafsir block has no `maxHeight` in S1 (reel only).
8. **Tafsir heading is centred** under the rule's diamond; the body is right-aligned RTL (§8 latitude).
9. **Text share stays a callback.** «نص فقط» shares from the button's `onPressed` with a try/catch SnackBar (a side effect in a callback, as today's study leaf does); only the image share goes through cubit state. Both buttons are disabled while `busy` (§3.5).
10. **Ayah 0 never reaches the sheet without a guard.** The study layer opens only for `ayah != 0` (`mushaf_page.dart:1166`), `SavedAyatCubit.save` rejects ayah 0, and `place_migration.dart` / `first_ayah_of_page.dart` never produce it, so no entry point needs its own check.
11. **`feature-widgets.md` names S1's edges only.** The spec's exception line also lists `Reciter`, S2 audio and `PlaybackCubit.state.reciter` (S2 adds them with the reel); S1 adds `enum_localization.dart` (`MushafPaper.localized`) for the swatch labels.
12. **Tafsir text width is 312 logical px, not 360.** The tafsir heading and body lay out at `(1080 − 2·72) / 3 = 312` logical px inside `canvas.scale(3)` (the 360 logical canvas minus 2 × 24 margin), so their side margins equal the 72 px card margin (§3.4). §3.2's "logical width of 360" is the canvas width, not the text width.
13. **`PaperSwatches` is new, not `_PaperTile` promoted.** `display_sheet.dart`'s private `_PaperTile` has the same semantics but is a 54 px tall labelled tile; the share sheet needs round 36 px dots in 48 px targets (§3.5 item 4) with the label only in semantics. Nothing moves to core; merging the two is a possible follow-up, not S1 work.

## Review Focus

1. **Night papers.** A card on `night` / `slateNight` must come out dark with light ink, never a cream card with dark text. Task 4 pins the night background pixel.
2. **Double tap on «مشاركة».** A second request while the first share is open must not open a second OS sheet. Task 5 pins it.
3. **Closing the sheet mid-work.** Crops that finish after `close()` must be disposed, and no emit may follow. Task 5 pins it.
4. **English UI.** The share text is the English `ayah_label`; the card stays Arabic. Task 7 pins the share text.
5. **Fast tafsir switch on → off → on.** The cancelled first load must never land after the second starts. Task 5 pins it.

---

### Task 1: Mushaf grid (seam 1)

**Files:**
- Create: `lib/features/surah/presentation/utils/mushaf_grid.dart`
- Create (tests): `test/features/surah/mushaf_bounds_fixture.dart`, `test/features/surah/presentation/utils/mushaf_grid_test.dart`

**Interfaces:**
- Consumes: `NormalizedRect`, `AyahBoundEntity`, `AyahIdentifier`, `mushafPageSize` (1536×2795, `reader_rules.dart`).
- Produces (page px everywhere):
  - `const mushafGridTop = 1536 * 1.82 * 0.058;` (162.14016), `const mushafLineHeight = 1536 * 1.82 * (1 - 0.058 - 0.033) / 15;` (169.408512), `const mushafColumnWidth = (0.8975 - 0.1043) * 1536;` (≈ 1218.36), `const mushafOuterPad = 48.0;`, `const mushafRosetteBleed = 28.0;`.
  - `typedef MushafLine = ({int page, int line});`, `typedef RowEdges = ({double left, double right, bool leftOpen, bool rightOpen});`
  - `int gridLineOf(NormalizedRect rect)` = `(((rect.y + rect.h) * 2795 - mushafGridTop) / mushafLineHeight).round() - 1`.
  - `({int top, int bottom}) gridBand(int line)` = floors of `mushafGridTop + line * LH` and `+ (line + 1) * LH`.
  - `Rect headerBand(int line)` = `Rect.fromLTRB(0, floor(TOP + line·LH) − 3, 1536, floor(TOP + (line+1)·LH) + 3)`.
  - `MushafLine headerSlot({required int surah, required int startPage, required List<AyahBoundEntity> startPageBounds})`: anchor = the `(surah, 0)` entry, else `(surah, 1)`; `line = gridLineOf(anchor.lines.first) - 1`; `line < 0` → `(page: startPage - 1, line: 14)`, else `(page: startPage, line: line)`.
  - `RowEdges rowEdges(NormalizedRect rect, List<NormalizedRect> pageRects)` (port below).
  - `Rect rowSource(NormalizedRect rect, RowEdges edges)`: x from `edges.left − (leftOpen ? 48 : 0)` to `edges.right + (rightOpen ? 48 : 0)`; top = `gridLineOf(rect) == 0 ? (y + h)·2795 − LH : y·2795`; bottom = top + LH; every edge `.roundToDouble()` (the prototype's `int(round(v))`).
  - `Rect accentSource(NormalizedRect rect, RowEdges edges)`: from `src = rowSource(...)`: left `leftOpen ? src.left : src.left − 28`, right `rightOpen ? src.right : src.right − 28`, top `max(src.top, band.top)`, bottom `min(src.bottom, band.bottom)` with `band = gridBand(gridLineOf(rect))`.
  - Test fixture: `List<AyahBoundEntity> boundsOf(int page)` (cached, `MushafPageModel.fromJson` over the file) and `List<NormalizedRect> linesOf(int surah, int ayah)`.

`rowEdges` is the prototype's `edges` (asymmetric clip tests on the rect's original x and w; the right test reads the already-clipped `x1`):

```dart
RowEdges rowEdges(NormalizedRect rect, List<NormalizedRect> pageRects) {
  const tol = 0.002;
  final line = gridLineOf(rect);
  var x0 = rect.x;
  var x1 = rect.x + rect.w;
  final centre = (x0 + x1) / 2;
  var leftOpen = true;
  var rightOpen = true;
  for (final o in pageRects) {
    if (o == rect || gridLineOf(o) != line) continue;
    if ((o.x + o.x + o.w) / 2 > centre) {
      if (o.x <= x1 + tol) {
        rightOpen = false;
        if (o.x >= rect.x && o.w < rect.w) x1 = math.min(x1, o.x);
      }
    } else if (o.x + o.w >= rect.x - tol) {
      leftOpen = false;
      if (o.x + o.w <= rect.x + rect.w && o.w < rect.w) {
        x0 = math.max(x0, o.x + o.w);
      }
    }
  }
  final w = mushafPageSize.width;
  return (left: x0 * w, right: x1 * w, leftOpen: leftOpen, rightOpen: rightOpen);
}
```

- [ ] **Step 1: Write the failing tests** (`mushaf_grid_test.dart`, all over real bounds)
  - `'grid constants match the generator'`: `mushafGridTop` closeTo 162.14 (1e-3), `mushafLineHeight` closeTo 169.41 (1e-2), `mushafColumnWidth` closeTo 1218.36 (1e-2).
  - `'2:282 fills grid lines 0 to 14'`: `linesOf(2, 282).map(gridLineOf)` == `[0..14]`.
  - `'the 18 page-top surahs take line 14 of the previous page'`: for `[4, 10, 22, 23, 24, 26, 27, 32, 33, 37, 38, 45, 47, 53, 60, 64, 65, 80]`, `headerSlot` == `(page: start − 1, line: 14)` with `start = quran.getPageNumber(s, 1)`; for surah 4: `(page: 76, line: 14)`.
  - `'surahs 1 and 9 sit above ayah 1'`: 1 → `(page: 1, line: 0)`, 9 → `(page: 187, line: 0)`.
  - `'each header on page 602 belongs to its own surah'`: 106 → `(602, 0)`, 107 → `(602, 5)`, 108 → `(602, 11)`.
  - `'every surah has a header slot in the grid'`: all 114, `line` in `0..14`, `page` is start or start − 1, and exactly the 18 above use start − 1.
  - `'91:11 is clipped at the narrower rosette rect of 91:10'`: on page 595, `rowEdges(linesOf(91, 11).single, all page rects)` → `right` closeTo `0.8657 * 1536` (0.5), `leftOpen` false, `rightOpen` false; 91:10's last rect → `leftOpen` false, `rightOpen` true.
  - `'a full line is open on both sides'`: 2:282 line 5 → both open, `left` closeTo `0.1043 * 1536` (0.5).
  - `'rowSource pads open edges to whole pixels'`: 6:31 second rect (page 131) → `Rect.fromLTRB(112, 1017, 1425, 1186)`.
  - `'rowSource on line 0 ends at the rect bottom'`: 2:282 first rect → `top` 172, `bottom` 341.
  - `'accentSource keeps the rosette bleed and drops the foreign sliver'`: 91:11 → `Rect.fromLTRB(786, 1355, 1302, 1517)`; 6:31 last rect → `Rect.fromLTRB(619, 1186, 1425, 1347)`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/mushaf_grid_test.dart`. Expected: FAIL (`mushaf_grid.dart` missing).

- [ ] **Step 3: Implement** `mushaf_grid.dart` with the signatures above.

- [ ] **Step 4: Verify** `flutter test test/features/surah/presentation/utils/mushaf_grid_test.dart`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +11 → 1671.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/surah/presentation/utils/mushaf_grid.dart test/features/surah/mushaf_bounds_fixture.dart test/features/surah/presentation/utils/mushaf_grid_test.dart
git add lib/features/surah/presentation/utils/mushaf_grid.dart test/features/surah/mushaf_bounds_fixture.dart test/features/surah/presentation/utils/mushaf_grid_test.dart
git commit -m "feat(ayah-share): shared mushaf grid with header slot, overlap edges and rosette accent rule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Card layout (seam 2)

**Files:**
- Create: `lib/features/ayah_share/presentation/utils/share_card_layout.dart`
- Create (tests): `test/features/ayah_share/share_card_fixture.dart`, `test/features/ayah_share/presentation/utils/share_card_layout_test.dart`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces (card px, width 1080):
  - Constants: `shareCardWidth = 1080.0`, `shareCardMargin = 72.0`, `shareCardMaxHeight = 4096.0`, `shareCardTafsirGap = 0.55`, `shareCardBasmalaOpacity = 0.42`; private: top pad 72, bottom pad 80, header margin 56, header gap .55, basmala scale .78, basmala gap .45, min height `0.62 * 1080`, tail max 100, refit 1.02.
  - `enum ShareCardLayer { ink, accent, basmala }` (`basmala` reads the ink asset and is drawn faded).
  - `class ShareCardSlice extends Equatable { const ShareCardSlice({required this.layer, required this.page, required this.src, required this.dst}); final ShareCardLayer layer; final int page; final Rect src; final Rect dst; @override List<Object> get props => [layer, page, src, dst]; }`
  - `typedef ShareCardRow = ({double coreLeft, double coreRight, double top});` (the row's text extent in card px without pads; on the row that carries a merged tail, `coreLeft` is the tail's left edge, so `coreRight − coreLeft = w_i` below).
  - `class ShareCardLayout { const ShareCardLayout({required this.slices, required this.rows, required this.scale, required this.headerScale, required this.textBottom, required this.mergedTail}); final List<ShareCardSlice> slices; final List<ShareCardRow> rows; final double scale; final double headerScale; final double textBottom; final bool mergedTail; double get pitch => mushafLineHeight * scale; }`; `slices` in draw order: header ink, header accent, basmala (if any), then each row in order as ink, then (last row only) tail ink, then the accent slice.
  - `ShareCardLayout shareCardLayout({required AyahIdentifier ayah, required int page, required List<AyahBoundEntity> pageBounds, required int startPage, required List<AyahBoundEntity> startPageBounds, required ({int page, Rect box}) header})`; slices are top-anchored (no vertical centring).
  - `({int height, double dy}) shareCardFrame(double contentBottom)`: `content = contentBottom + 80`, `height = max(content, 0.62 * 1080).round()`, `dy = (height − content) / 2`.
  - Test fixture: `ShareCardLayout layoutFor(int surah, int ayah)` building the args from `boundsOf` / `quran.getPageNumber` / `headerSlot`, with the header box `headerBoxFixture(line) = Rect.fromLTRB(54, headerBand(line).top + 4, 1481, headerBand(line).top + 172)` (today's measured frame: line 0 → `54, 163, 1481, 331`).

Algorithm (the prototype's `line_items` + `compose`, minus `center-first` and the bars):

```dart
final pageRects = [for (final b in pageBounds) ...b.lines];
final pieces = [
  for (final rect in pageBounds.firstWhere((b) => b.ayah == ayah).lines)
    _piece(rect, rowEdges(rect, pageRects)),
];
final tail =
    pieces.length > 1 && pieces.last.core < 100 && pieces.last.edges.rightOpen
    ? pieces.removeLast()
    : null;
final widths = [
  for (final (i, p) in pieces.indexed)
    p.core + (i == pieces.length - 1 ? tail?.core ?? 0 : 0),
];
final widest = widths.reduce(math.max);
final scale =
    936 / (widest > mushafColumnWidth * 1.02 ? widest : mushafColumnWidth);
```

`_piece(rect, edges)` returns `({NormalizedRect rect, RowEdges edges, Rect src, double core})` with `src = rowSource(rect, edges)` and `core = src.width − (leftOpen ? 48 : 0) − (rightOpen ? 48 : 0)` (the prototype's core: the whole-pixel crop minus its pads). A merged tail rides on the last remaining row.

Placement:
- `y = 72`. Header: `hs = min(scale, 968 / box.width)`; dst `Rect.fromLTWH((1080 − box.width·hs) / 2, y, box.width·hs, box.height·hs)` for an ink and an accent slice with `src = box`, `page = header.page`; `y += box.height·hs + 0.55·pitch`.
- Basmala unless surah is 1 or 9: the `(surah, 0)` rect in `startPageBounds`, `src = rowSource(rect, (left: x·1536, right: (x+w)·1536, leftOpen: false, rightOpen: false))` (raw rect, no edges, no pad); `bs = 0.78·scale`; dst centred at `y`, size `src.size · bs`; layer `basmala`, page `startPage`; `y += LH·bs + 0.45·pitch`.
- Row i at `top = y + i·pitch`; `centred = page <= 2 || rows == 1`; `w_i = (core_i + (i == rows − 1 ? tail?.core ?? 0 : 0))·scale` (the tail widens only the row that carries it); `right_i = centred ? (1080 + w_i) / 2 : 1080 − 72`; the piece's own `pieceLeft_i = right_i − core_i·scale`; the merged tail's `tailLeft = pieceLeft_last − tail.core·scale`. The row record is `(coreLeft: right_i − w_i, coreRight: right_i, top: top)`, so on the tail row `coreLeft == tailLeft`.
- Each piece maps page px to card px by `x ↦ leftCard + (x − (src.left + (leftOpen ? 48 : 0)))·scale`, `y ↦ top + (y − src.top)·scale`, with `leftCard = pieceLeft_i` for a row piece and `tailLeft` for the tail (its own `src` and `leftOpen`). Ink slice: `src` → mapped dst. The ayah's last rect (the tail when merged) also gets an accent slice: `accentSource(rect, edges)` → mapped dst. No other accent.
- `textBottom = y + rows·pitch`.

- [ ] **Step 1: Write the failing tests** (`share_card_layout_test.dart`; heights read `shareCardFrame(layout.textBottom).height`)
  - `'6:31 lays out three right-aligned rows at height 888'`: 3 rows, `scale` closeTo 0.7682 (1e-3), height 888 (±1), every `row.coreRight` closeTo 1008 (0.5).
  - `'2:282 stacks fifteen rows at height 2450'`.
  - `'16:127 carries its rosette tail on the previous row and refits'`: 2 rows, `mergedTail` true, `scale` closeTo 0.737 (1e-3), height 738 (±1); the one accent slice sits in the last row (`dst.top >= rows.last.top`, `dst.bottom <= rows.last.top + pitch + 1`) at its left end (`dst.left < rows.last.coreLeft`, `dst.right < rows.last.coreLeft + 0.2 * (rows.last.coreRight - rows.last.coreLeft)`); the tail widens the row: `rows.last.coreLeft` closeTo 72 and `rows.last.coreRight` closeTo 1008 (0.5) (tail excluded would give ≈ 113), and the leftmost last-row ink slice (the tail, `leftOpen` false on page 281) has `dst.left` closeTo `rows.last.coreLeft` (0.5).
  - `'a one-row ayah is centred at the minimum height'`: 108:1 → 1 row, `(coreLeft + coreRight) / 2` closeTo 540 (0.5), height 670.
  - `'pages 1 and 2 centre every row'`: 2:2 → 2 rows, each centred on 540; 1:1 → height 670.
  - `'surahs 1 and 9 have no basmala'`: no `basmala` slice for 1:1 and 9:1; 6:31 has one, centred (`dst.left + dst.right` closeTo 1080), `dst.width` closeTo `src.width · 0.78 · scale`, `page` 128.
  - `'only the ayah's last line has an accent slice'`: 6:31 → exactly one row accent slice, page 131, `src == accentSource(last rect, its edges)`.
  - `'the header is centred and no larger than the text'`: 6:31 header slices: two (ink, accent), `src == headerBoxFixture(0)`, `headerScale` closeTo 0.6783 (1e-3), dst top 72, `dst.left + dst.right` closeTo 1080; 4:1 header page 76.
  - `'shareCardFrame centres short content'`: `shareCardFrame(400)` → `(height: 670, dy: 95)`; `shareCardFrame(1000).dy` == 0.
  - `'every ayah lays out'`: all 6,236 ayat (`quran.getVerseCount`) → no throw, finite heights, max rows 15, a header slice for every surah.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/utils/share_card_layout_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** `share_card_layout.dart`.

- [ ] **Step 4: Verify** the scoped test, then `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; +10 → 1681.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/utils/share_card_layout.dart test/features/ayah_share/share_card_fixture.dart test/features/ayah_share/presentation/utils/share_card_layout_test.dart
git add lib/features/ayah_share/presentation/utils/share_card_layout.dart test/features/ayah_share/share_card_fixture.dart test/features/ayah_share/presentation/utils/share_card_layout_test.dart
git commit -m "feat(ayah-share): share card layout from mushaf bounds

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Card content, use case and `Tafsir.body` (seam 3)

**Files:**
- Create: `lib/features/ayah_share/domain/entities/share_card_content.dart`, `lib/features/ayah_share/domain/usecases/get_share_card_content.dart`
- Modify: `lib/features/tafsir/domain/entities/tafsir.dart`
- Create (tests): `test/features/ayah_share/domain/usecases/get_share_card_content_test.dart`, `test/features/tafsir/domain/entities/tafsir_test.dart`

**Interfaces:**
- Consumes: `GetMushafPage`, `MushafRepository`, `MushafPageEntity`, `AyahBoundEntity`, `QuranPageService`, `NotFoundFailure`.
- Produces:
  - `class ShareCardContent extends Equatable { const ShareCardContent({required this.ayah, required this.page, required this.pageBounds, required this.startPage, required this.startPageBounds}); final AyahIdentifier ayah; final int page; final List<AyahBoundEntity> pageBounds; final int startPage; final List<AyahBoundEntity> startPageBounds; @override List<Object> get props => [ayah, page, pageBounds, startPage, startPageBounds]; }`
  - `class GetShareCardContent { GetShareCardContent({required GetMushafPage getMushafPage, required QuranPageService pageService}); Future<Either<Failure, ShareCardContent>> call(AyahIdentifier ayah); }`: `page = getPageForAyah(ayah.surah, ayah.ayah)`, `startPage = getPageForAyah(ayah.surah, 1)`; fetches `page`, and `startPage` only when it differs; an ayah absent from its page's bounds → `Left(NotFoundFailure('${ayah.surah}:${ayah.ayah}'))` (braces needed for the property access; a plain local would be `'$s:$a'`, never `'${s}:${a}'`, which trips `unnecessary_brace_in_string_interps`); a repository `Left` passes through as the same instance.
  - `Tafsir.body`: for 1:1 whose text starts with «سورة الفاتحة» and whose `indexOf('. ')` is not −1, everything after the first `'. '`, trimmed; in every other case (including no `'. '`), `text`. (`TafsirSection` keeps `text`.)

- [ ] **Step 1: Write the failing tests** (a `_FakeMushafRepo implements MushafRepository` that serves `boundsOf(page)` and records `pages`; `QuranPageServiceImpl`)
  - `'returns the ayah page and the surah start page'`: 6:31 → `page` 131, `startPage` 128, both bounds lists non-empty, `pages` == `[131, 128]`.
  - `'fetches a page once when the ayah is on the start page'`: 112:1 → `pages` == `[604]`, `startPageBounds` identical to `pageBounds`.
  - `'page 1 works'`: 1:1 → `page` 1, `startPage` 1.
  - `'an ayah missing from its bounds is a failure'`: repo serves an empty page → `isLeft`.
  - `'a bounds failure is returned as is'`: `const failure = CacheFailure('x');` the repo returns `Left(failure)` → `result.fold((f) => identical(f, failure), (_) => false)` is true (`Failure` has no value equality, so two `Left(CacheFailure('x'))` are never `==`).
  - `tafsir_test.dart`: `'body drops the Al-Fatiha introduction'` with the fixture `'سورة الفاتحة سميت هذه السورة بالفاتحة؛ لأنه يفتتح بها القرآن العظيم، وتسمى المثاني؛ لأنها تقرأ في كل ركعة، ولها أسماء أخر. أبتدئ قراءة القرآن باسم الله مستعينا به'` → body starts with `'أبتدئ قراءة القرآن باسم الله مستعينا به'`; `'body is the text for any other ayah'` (the same text on 2:1 stays whole); `'1:1 without the introduction stays whole'`; `'1:1 with the introduction but no full stop stays whole'` (`'سورة الفاتحة سميت هذه السورة بالفاتحة'` → body == text).

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/domain test/features/tafsir/domain`. Expected: FAIL.

- [ ] **Step 3: Implement** the entity, use case and getter.

- [ ] **Step 4: Verify** the scoped tests, then `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; +9 → 1690.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/domain/entities/share_card_content.dart lib/features/ayah_share/domain/usecases/get_share_card_content.dart lib/features/tafsir/domain/entities/tafsir.dart test/features/ayah_share/domain/usecases/get_share_card_content_test.dart test/features/tafsir/domain/entities/tafsir_test.dart
git add lib/features/ayah_share/domain/entities/share_card_content.dart lib/features/ayah_share/domain/usecases/get_share_card_content.dart lib/features/tafsir/domain/entities/tafsir.dart test/features/ayah_share/domain/usecases/get_share_card_content_test.dart test/features/tafsir/domain/entities/tafsir_test.dart
git commit -m "feat(ayah-share): share card content use case and tafsir body without the Fatiha intro

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Renderer (seam 4)

**Files:**
- Create: `lib/features/ayah_share/presentation/utils/share_card_renderer.dart`
- Create (tests): `test/features/ayah_share/presentation/utils/share_card_renderer_test.dart`
- Modify (tests): `test/features/ayah_share/share_card_fixture.dart` (add `ShareCardContent contentFor(int surah, int ayah)`: page and start page from `quran.getPageNumber`, bounds from `boundsOf`)

**Interfaces:**
- Consumes: Tasks 1–3; `AssetsDir.mushafPage` / `mushafPageAccent`; `MushafPaperColors`; `TS`; `PendingS.forLanguage('ar').tafsir_muyassar`.
- Produces:
  - `typedef ShareImageLoader = Future<ui.Image> Function(String asset);` and `Future<ui.Image> loadAssetImage(String asset)` (`rootBundle.load` → `ui.instantiateImageCodec` at full size → first frame, codec disposed).
  - `class ShareCardCrops { ShareCardCrops({required this.layout, required this.pieces, required this.basmalaOpacity}); final ShareCardLayout layout; final List<({ShareCardSlice slice, ui.Image image})> pieces; final double basmalaOpacity; void dispose(); }` (not final, so tests can count disposals).
  - `class ShareCardRenderer { ShareCardRenderer({ShareImageLoader loadImage = loadAssetImage}); Future<ShareCardCrops> prepare(ShareCardContent content); Future<Uint8List> compose(ShareCardCrops crops, {required MushafPaperColors colors, String? tafsir}); }`
  - `Rect? alphaBounds(List<ByteData> layers, int width, int height)`: box of pixels whose max alpha over the layers is > 8, null when none.
  - `int peakAlpha(ByteData rgba)`.
  - `TextStyle tafsirBodyStyle(String body)` = `(body.length > 600 ? TS.regular12 : TS.regular14).copyWith(height: 1.8)`.

`prepare`, in this order:
1. `slot = headerSlot(...)`, `band = headerBand(slot.line)`. Decode the header page's ink, cut the band (`PictureRecorder` + `drawImageRect` + `toImage`), dispose the page; same for its accent.
2. `box = alphaBounds([inkBand, accentBand] as rawRgba) ?? band` (shifted into page px). Cut the header ink and accent crops from the band crops, dispose the band crops.
3. `layout = shareCardLayout(..., header: (page: slot.page, box: box))`.
4. For the remaining slices (all but `layout.slices[0..1]`, the header pair) grouped by asset (`basmala` and `ink` → `mushafPage`, `accent` → `mushafPageAccent`): decode one asset, cut its slices at their (whole-pixel) src, dispose it, next. At most three pages are touched.
5. `basmalaOpacity = min(1, 0.42 · 255 / peakAlpha(basmala crop))` (0.42 when there is no basmala or the peak is 0).

`compose`: if `tafsir != null`, lay out two `TextPainter`s at logical width `(1080 − 2·72) / 3 = 312`: heading `TS.bold14` in `colors.accent`, centred; body `tafsirBodyStyle(tafsir)` in `colors.ink2`, `TextAlign.right`, `TextDirection.rtl`; block height `heading + 8 + body` (logical). `tafsirTop = textBottom + 0.55·pitch`; `contentBottom = tafsir == null ? textBottom : tafsirTop + 36 + 3·block`. `frame = shareCardFrame(contentBottom)`; `k = frame.height > 4096 ? 4096 / frame.height : 1`. Record: `scale(k)`; paper background over `1080 × height`; `translate(0, dy)`; each piece `drawImageRect(image, full, slice.dst, Paint()..filterQuality = FilterQuality.high..colorFilter = ColorFilter.mode(c, BlendMode.srcIn))` with `c` = `ink`, `accent`, or `ink.withValues(alpha: basmalaOpacity)`; then the rule (2 px lines from `72 + 120` to `540 − 22` and `540 + 22` to `1080 − 72 − 120` at `tafsirTop`, `accent` alpha 150/255) and the diamond (half-diagonal 9, alpha 200/255); then `save/translate(72, tafsirTop + 36)/scale(3)`, paint heading and body, `restore`. `toImage((1080·k).round(), (height·k).round())` → PNG bytes; dispose image and painters. No page decode.

- [ ] **Step 1: Write the failing tests** (pixel work inside `tester.runAsync`; the loader paints synthetic 1536×2795 pages with `PictureRecorder` and keeps every image it returns and every asset it was asked for; content from `contentFor`; never assert tafsir pixel heights, tests do not render Cairo)

  Synthetic loader contract: every asset is a fully transparent 1536×2795 page unless the test names it below. The header-trim and night tests paint only `mushafPage(128)`, opaque, inside the given rect; every `mushafPageAccent(n)` stays transparent (so the header accent drawn over the ink's dst adds nothing). The basmala test paints only `mushafPage(128)`, at alpha 128, inside 6:0's `rowSource` rect (raw rect, both edges closed). All other tests use the all-transparent loader.
  - `'alphaBounds finds the inked box'`: an 8×4 RGBA buffer with alpha 9 at (2,1) and (5,2) → `Rect.fromLTRB(2, 1, 6, 3)`; alpha 8 only → null.
  - `'alphaBounds takes the max over layers'`: ink empty, accent inked → the accent box.
  - `'tafsirBodyStyle steps down past 600 characters'`: 600 chars → `fontSize` 14, 601 → 12, both `height` 1.8.
  - `'prepare touches only the header, basmala and ayah pages and disposes them'` (6:31): asked assets ⊆ `{mushafPage(128), mushafPageAccent(128), mushafPage(131), mushafPageAccent(131)}` and every returned page has `debugDisposed` true.
  - `'prepare trims the header to its inked box'`: synthetic ink opaque only in `Rect.fromLTRB(200, band.top + 20, 1300, band.bottom − 20)` of page 128 → the header slices' `src` equals that rect.
  - `'prepare normalises the basmala opacity'`: 6:0's rect area painted at alpha 128 → `basmalaOpacity` closeTo `0.42 * 255 / 128` (0.01); 9:1 → 0.42.
  - `'compose exports a 1080-wide PNG at the layout height'`: decode the bytes (`ui.instantiateImageCodec`) → 1080 × `shareCardFrame(layout.textBottom).height` (888 for 6:31).
  - `'a recompose never loads a page again'`: compose on cream, then sepia → loader call count unchanged.
  - `'a night paper card is dark with light ink'` (the loader of the header-trim test, whose header box is fully opaque ink): compose 6:31 on `MushafPaper.night.colors`, decode, read `rawRgba` → pixel (0, 0) is `0x14, 0x12, 0x10, 0xFF`, and the pixel at the header ink slice's `dst.center` shifted by `shareCardFrame(textBottom).dy` is within ±2 of `0xEC, 0xE3, 0xCF` (proves the `srcIn` tint; this stands in for the spec's recording-canvas painter test).
  - `'the tafsir makes the card taller'`: height with a 200-char tafsir > height without.
  - `'a very long card is scaled to 4096 px high'`: 2:282 with `'كلمة ' * 3000` → decoded height 4096, width < 1080.
  - `'dispose releases every crop'`: after `crops.dispose()`, every `piece.image.debugDisposed`.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/utils/share_card_renderer_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** `share_card_renderer.dart`.

- [ ] **Step 4: Verify** the scoped test, then `flutter test test/config/theme/typography_ratchet_test.dart`, `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; +12 → 1702; ratchet unchanged.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/utils/share_card_renderer.dart test/features/ayah_share/share_card_fixture.dart test/features/ayah_share/presentation/utils/share_card_renderer_test.dart
git add lib/features/ayah_share/presentation/utils/share_card_renderer.dart test/features/ayah_share/share_card_fixture.dart test/features/ayah_share/presentation/utils/share_card_renderer_test.dart
git commit -m "feat(ayah-share): share card renderer, crops once, recompose per toggle, tafsir block, 4096 cap

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: AyahShareCubit and state (seam 5)

**Files:**
- Create: `lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart`, `lib/features/ayah_share/presentation/cubit/ayah_share_state.dart` (`part of`)
- Create (tests): `test/features/ayah_share/ayah_share_fakes.dart`, `test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart`

**Interfaces:**
- Consumes: `GetShareCardContent`, `ShareCardContent` (Task 3), `ShareCardRenderer`, `ShareCardCrops` (Task 4), `GetAyahTafsir`, `Tafsir.body`, `MushafPaper`, `MushafPaperX.colors`.
- Produces:
  - `enum ShareCardStatus { loading, ready, failed }`, `enum ShareTafsirStatus { idle, loading, ready, failed }`, `enum ShareExport { idle, rendering, sharing, done, failed }`.
  - `final class AyahShareState extends Equatable { const AyahShareState({required this.paper, this.status = ShareCardStatus.loading, this.includeTafsir = false, this.tafsirStatus = ShareTafsirStatus.idle, this.tafsir, this.cardBytes, this.renderId = 0, this.export = ShareExport.idle}); … bool get busy => export == ShareExport.rendering || export == ShareExport.sharing; bool get progress => export == ShareExport.rendering || tafsirStatus == ShareTafsirStatus.loading; AyahShareState copyWith(...); }` with `props` = every field except `cardBytes`.
  - `class AyahShareCubit extends Cubit<AyahShareState> { AyahShareCubit({required this.ayah, required MushafPaper paper, required GetShareCardContent getContent, required ShareCardRenderer renderer, required GetAyahTafsir getTafsir}); final AyahIdentifier ayah; Future<void> load(); void setPaper(MushafPaper paper); void setIncludeTafsir(bool on); void retryTafsir(); void requestShare(); void shareFinished({required bool ok}); }`
  - Fakes (`ayah_share_fakes.dart`): `FakeGetShareCardContent implements GetShareCardContent` (result or `Completer`, records `requests`); `FakeShareCardRenderer implements ShareCardRenderer` (`prepare` returns a `CountingCrops` or awaits a `Completer`, or throws when `failPrepare`; `compose` records `(colors, tafsir)` and returns `Uint8List.fromList(onePixelPng)` unless a queued `Completer` is given, throws when `failCompose`); `CountingCrops extends ShareCardCrops` counting `dispose` (built with `const ShareCardLayout(slices: [], rows: [], scale: 1, headerScale: 1, textBottom: 0, mergedTail: false)`, `pieces: const []`, `basmalaOpacity: 0.42`); `FakeGetAyahTafsir implements GetAyahTafsir` (queued `Completer<Either<Failure, Tafsir>>`s, records each `CancelToken`); `const onePixelPng` = `base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=')` (as a getter or `final`).

Behaviour:
- `load()`: dispose old crops; emit `status: loading`; content → `Left` emits `failed`; `prepare` (try/catch) → failure emits `failed`; a crops result arriving after `close()` is disposed and dropped; then `_compose()`.
- `_compose()`: if `export == sharing`, set `_composeDeferred = true` and return (no generation bump, no emit: a recompose never runs while the OS share is open, so `export` stays `sharing` and `busy` stays true). Otherwise `gen = ++_renderGeneration`; emit `export: rendering` when a card is already showing; `bytes = await renderer.compose(crops, colors: paper.colors, tafsir: includeTafsir && tafsirStatus == ready ? tafsir : null)`; return if closed or `gen != _renderGeneration`; emit `status: ready, cardBytes: bytes, renderId: renderId + 1, export: idle`. On exception: return if closed or `gen != _renderGeneration`; else emit `status: failed, export: idle`. Every generation bump is followed by its own compose, so a superseded `rendering` is always settled by the newer one.
- `setPaper`: same paper → nothing; else emit and `_compose()`.
- Guard: `setIncludeTafsir` and `retryTafsir` return at once while `state.status != ShareCardStatus.ready` (ready implies content and crops exist; the sheet also disables the switch and the retry button then, see Task 7).
- `setIncludeTafsir(true)`: emit `includeTafsir: true`; tafsir ready → `_compose()`; else `_loadTafsir()`. `setIncludeTafsir(false)`: cancel and drop the token; emit `includeTafsir: false` (and `tafsirStatus: idle` if it was loading); if `tafsirStatus == ready`, `_compose()` (the shown card or the in-flight compose may carry the tafsir; the generation bump drops an in-flight tafsir compose).
- `_loadTafsir()`: new `CancelToken` (old one cancelled); emit `tafsirStatus: loading`; await `getTafsir(surah: ayah.surah, ayah: ayah.ayah, page: _content.page, cancelToken: token)`; return if closed or `token` is no longer current; `Left` → `includeTafsir: false, tafsirStatus: failed`; `Right(t)` → `tafsir: t.body, tafsirStatus: ready`, then `_compose()` if still on. `retryTafsir()` = `setIncludeTafsir(true)`.
- `requestShare()`: only when `status == ready`, `cardBytes != null` and `!busy` → `export: sharing`. Tafsir loading does not block it.
- `shareFinished(ok:)`: `if (isClosed) return;` then only when `export == sharing`: emit `export: ok ? done : failed`; then, if `_composeDeferred`, clear it and `_compose()`. Any other export value is left alone.
- `close()`: cancel the token, dispose crops, `super.close()`.

- [ ] **Step 1: Write the failing tests** (`bloc_test` or plain `test`; `cardBytes` is outside `props`, so assert `renderId` and read `cubit.state.cardBytes`)
  - `'load prepares the crops and emits the first card'`: states end `ready`, `renderId` 1, `cardBytes` non-null, one prepare, one compose with `tafsir` null and the cream colours.
  - `'a content failure emits failed'`.
  - `'a render failure emits failed and load recovers'`: `failCompose` then clear and `load()` → `ready`.
  - `'a paper change recomposes without preparing again'`: `setPaper(night)` → prepare count 1, compose count 2 with night colours, `renderId` 2.
  - `'a stale compose never replaces a newer one'`: queue two compose completers, `setPaper(sepia)` then `setPaper(night)`; complete night's, then sepia's → final `paper` night, `cardBytes` equals night's bytes, `renderId` 2 (sepia's late result dropped); then `setPaper(sepia)` and `setPaper(night)` again with completers, complete night's, then sepia's with an error → `status` stays `ready`, `export` idle (a stale failure is dropped too).
  - `'turning the tafsir on loads it once and recomposes with its body'`: Fatiha 1:1 fixture → compose receives the body; switching off and on again makes no second tafsir call.
  - `'while the tafsir loads the plain card stays shareable'`: switch on (pending) → `progress` true, `busy` false; `requestShare()` → `export: sharing`.
  - `'turning the tafsir off mid-load cancels it and never emits failed'`: the recorded token `isCancelled`; completing it with `Left` emits nothing; `tafsirStatus` idle.
  - `'a cancelled tafsir load never lands after a new one starts'`: on → off → on; complete the second with text B, then the first with text A → `tafsir` B.
  - `'a tafsir failure turns the switch off and retry asks again'`: `Left` → `includeTafsir` false, `tafsirStatus` failed; `retryTafsir()` → a second call.
  - `'share is ignored while a recompose runs'`: compose pending after `setPaper` → `requestShare()` leaves `export: rendering`.
  - `'a second share request while sharing is ignored'`: `requestShare()` twice → one transition to `sharing`.
  - `'shareFinished reports done or failed'`.
  - `'tafsir toggles before the card is ready are ignored'`: prepare held by a completer → `setIncludeTafsir(true)` and `retryTafsir()` → no tafsir call, no throw, `includeTafsir` false.
  - `'a tafsir that lands mid-share waits for the share to finish'`: ready, switch on (tafsir pending), `requestShare()`, complete the tafsir → no new compose, `export` sharing, `busy` true, a second `requestShare()` changes nothing; `shareFinished(ok: true)` → `export` done, then a compose with the body runs and `renderId` rises by 1.
  - `'shareFinished outside a share is ignored'`: compose pending after `setPaper` (`export` rendering) → `shareFinished(ok: true)` leaves `export` rendering.
  - `'turning the tafsir off while its compose is pending shows the plain card'`: tafsir completes, its compose held by a completer, `setIncludeTafsir(false)`, complete the held compose → the last recorded compose has `tafsir == null`, `cardBytes` comes from it, and `renderId` is 2 (first card, then the plain recompose; the superseded tafsir compose never counts).
  - `'close disposes the crops and cancels the tafsir'`.
  - `'crops that arrive after close are disposed'`: prepare pending, `close()`, complete prepare → its crops disposed, no emit, no compose.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/cubit`. Expected: FAIL.

- [ ] **Step 3: Implement** the cubit and state.

- [ ] **Step 4: Verify** the scoped test, then `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; +19 → 1721.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart lib/features/ayah_share/presentation/cubit/ayah_share_state.dart test/features/ayah_share/ayah_share_fakes.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart
git add lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart lib/features/ayah_share/presentation/cubit/ayah_share_state.dart test/features/ayah_share/ayah_share_fakes.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart
git commit -m "feat(ayah-share): AyahShareCubit with lazy tafsir, render generations and crop disposal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Text share fix, strings and DI (seam 6, part 1)

**Files:**
- Create: `lib/features/ayah_share/presentation/utils/ayah_share_text.dart`, `lib/features/ayah_share/ayah_share_di.dart`
- Modify: `lib/core/di/dependency_injection.dart` (call `initAyahShare()` right after `await initPlayback();`), `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Create (tests): `test/features/ayah_share/presentation/utils/ayah_share_text_test.dart`, `test/features/ayah_share/ayah_share_di_test.dart`

**Interfaces:**
- Consumes: Tasks 3–5; `surahDisplayName`, `toLocalized`, `S.ayah_label`, `SettingsCubit`.
- Produces:
  - `String ayahVerseText(AyahIdentifier ayah)`: `quran.getVerse`; for ayah 1 of surahs 2–114 except 9, drop the first four whitespace-separated words and trim (never match on `quran.basmala`).
  - `String ayahShareText(BuildContext context, AyahIdentifier ayah)` = `'${ayahVerseText(ayah)} — ${S.of(context).ayah_label(surahDisplayName(context, ayah.surah), ayah.ayah.toLocalized(context))}'`. The study leaf's own copy is removed in Task 8.
  - `void initAyahShare()`: `registerLazySingleton(() => GetShareCardContent(getMushafPage: sl(), pageService: sl()))`, `registerLazySingleton(() => ShareCardRenderer())`, `registerFactoryParam<AyahShareCubit, AyahIdentifier, void>((ayah, _) => AyahShareCubit(ayah: ayah, paper: sl<SettingsCubit>().state.settingsModel.mushafPaper, getContent: sl(), renderer: sl(), getTafsir: sl()))`.
  - Strings (ARB value = PendingS value, word for word):

| Key | ar | en |
|---|---|---|
| `ayahShare_title` | مشاركة الآية | Share ayah |
| `ayahShare_addTafsir` | إضافة التفسير الميسر | Add Al-Tafsir al-Muyassar |
| `ayahShare_textOnly` | نص فقط | Text only |
| `ayahShare_renderFailed` | تعذّر تجهيز الصورة | Couldn't prepare the image |

  (`Couldn\'t` escaped in `pending_s.dart`.)

- [ ] **Step 1: Write the failing tests**
  Expected verse strings come from the package, never typed: `final verse112 = quran.getVerse(112, 1).split(' ').skip(4).join(' ');` `final basmalaPrefix = quran.getVerse(2, 1).split(' ').take(4).join(' ');` and `final basmalaWord = basmalaPrefix.split(' ').first;` (never `quran.getVerse(1, 1)`: it is the Uthmani spelling, which no surah 2–114 verse 1 starts with).
  - `'2:1 drops the basmala'`: `ayahVerseText(2:1)` == `'الم'` (no marks; code points U+0627 U+0644 U+0645, verified equal to the package).
  - `'112:1 drops the basmala'`: == `verse112`.
  - `'1:1 and 9:1 stay whole'`: equal `quran.getVerse(1, 1)` and `quran.getVerse(9, 1)`.
  - `'no verse 1 keeps the basmala'`: for surahs 2–114 except 9, the raw `quran.getVerse(surah, 1)` starts with `basmalaPrefix` (real precondition), and `ayahVerseText` does not start with `basmalaWord` and equals `raw.split(' ').skip(4).join(' ')`.
  - `'ayahShareText quotes the verse and names it'` (widget, `Locale('ar')`): 112:1 → `'$verse112 — سورة الإخلاص، الآية ١'`.
  - `'initAyahShare builds a cubit on the reader paper'` (`ayah_share_di_test.dart`, after the `qibla_di_test.dart` pattern): register `GetMushafPage` over a stub repo, `sl.registerLazySingleton<QuranPageService>(QuranPageServiceImpl.new)`, `GetAyahTafsir` over a stub repo, and as `SettingsCubit` a night-paper settings fake declared in the test file, `class _NightSettings extends FakeSettings { _NightSettings() { emit(SettingsState(state.settingsModel.copyWith(mushafPaper: MushafPaper.night))); } }` (a subclass, because `emit` is protected and cannot be cascaded from outside; `FakeSettings` from `mushaf_page_harness.dart` defaults to cream, which is also the likeliest accidental default); `initAyahShare()`; `final cubit = sl<AyahShareCubit>(param1: const AyahIdentifier(surah: 6, ayah: 31))`, `addTearDown(cubit.close)` → `ayah` 6:31, `state.paper` night; `tearDown(sl.reset)`.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/utils/ayah_share_text_test.dart test/features/ayah_share/ayah_share_di_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** the util, the DI file and call, the four strings in both ARBs and `PendingS`.

- [ ] **Step 4: Verify** the scoped tests and `flutter test test/core/localization/pending_s_test.dart`, then `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; +6 → 1727.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/utils/ayah_share_text.dart lib/features/ayah_share/ayah_share_di.dart lib/core/di/dependency_injection.dart lib/core/localization/pending_s.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart test/features/ayah_share/ayah_share_di_test.dart
git add lib/features/ayah_share/presentation/utils/ayah_share_text.dart lib/features/ayah_share/ayah_share_di.dart lib/core/di/dependency_injection.dart lib/core/localization/pending_s.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb test/features/ayah_share/presentation/utils/ayah_share_text_test.dart test/features/ayah_share/ayah_share_di_test.dart
git commit -m "feat(ayah-share): text share without the repeated basmala, strings and DI

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Share sheet, preview and paper swatches (seam 6, part 2)

**Files:**
- Create: `lib/features/ayah_share/presentation/widgets/ayah_share_sheet.dart`, `lib/features/ayah_share/presentation/widgets/share_card_preview.dart`, `lib/features/ayah_share/presentation/widgets/paper_swatches.dart`
- Modify (tests): `test/features/ayah_share/ayah_share_fakes.dart` (add `registerFakeAyahShare`)
- Create (tests): `test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart`, `test/features/ayah_share/presentation/widgets/paper_swatches_test.dart`

**Interfaces:**
- Consumes: `AyahShareCubit` / `AyahShareState` (Task 5), `ayahShareText`, strings, DI (Task 6); core `ActionButtonsRow`, `ActionBtn.primary`, `ActionBtn`, `AppSettingsTile`; `MushafPaperX`, `MushafPaperLocalization.localized` (`surah/presentation/utils/enum_localization.dart`); `context.cardShadow()`.
- Produces:
  - `class AyahShareSheet extends StatefulWidget { const AyahShareSheet({super.key, required this.ayah, required this.controller}); static Future<void> show(BuildContext context, {required AyahIdentifier ayah}); }`. `show` = `showModalBottomSheet<void>(isScrollControlled: true, showDragHandle: true, useSafeArea: true, backgroundColor: context.colorScheme.surface, builder: (_) => BlocProvider(create: (_) => sl<AyahShareCubit>(param1: ayah)..load(), child: DraggableScrollableSheet(expand: false, initialChildSize: 0.85, builder: (_, c) => AyahShareSheet(ayah: ayah, controller: c))))`. The state holds `final _shareKey = GlobalKey();` and `final _textKey = GlobalKey();`, and one helper `Rect? _originOf(GlobalKey key)` (the key's `RenderBox`, `localToGlobal(Offset.zero) & size`, null if unmounted) used by both shares.
  - `class ShareCardPreview extends StatelessWidget { const ShareCardPreview({super.key, required this.bytes, required this.paper, required this.progress, required this.semanticLabel}); }`: `bytes == null` → `Skeletonizer(child: Skeleton.leaf(child: AspectRatio(aspectRatio: 1080 / 888, child: DecoratedBox(paper background, radius 12))))`; else a `DecoratedBox(boxShadow: context.cardShadow())` around `ClipRRect` + `Image.memory(bytes, key: const ValueKey('share-preview-image'), gaplessPlayback: true, width: double.infinity, fit: BoxFit.fitWidth, semanticLabel: …)`, with `LinearProgressIndicator(minHeight: 2)` on top while `progress`.
  - `class PaperSwatches extends StatelessWidget { const PaperSwatches({super.key, required this.selected, required this.onSelected, this.enabled = true}); final MushafPaper selected; final ValueChanged<MushafPaper> onSelected; final bool enabled; }`: a `Wrap` of six 48×48 targets keyed `share-paper-<name>`, each a 36 px circle in `paper.colors.background` with a 1 px `paper.colors.ink` ring, the selected one inside a 2 px `context.colorScheme.primary` ring; `Semantics(button: true, selected:, label: paper.localized(context))`.
  - Test helper (in `ayah_share_fakes.dart`): `typedef FakeAyahShare = ({FakeGetShareCardContent content, FakeShareCardRenderer renderer, FakeGetAyahTafsir tafsir});` and `FakeAyahShare registerFakeAyahShare({FakeGetShareCardContent? content, FakeShareCardRenderer? renderer, FakeGetAyahTafsir? tafsir, MushafPaper paper = MushafPaper.cream})`, which defaults each fake (content: a `Right` with empty bounds for the requested ayah), registers `sl.registerFactoryParam<AyahShareCubit, AyahIdentifier, void>((ayah, _) => AyahShareCubit(ayah: ayah, paper: paper, getContent: content, renderer: renderer, getTafsir: tafsir))` and returns the three fakes; callers add `addTearDown(sl.reset)`.

Sheet body: `ScaffoldMessenger(child: Scaffold(backgroundColor: Colors.transparent, body: <listener>(child: ListView(controller, padding 16, children: …))))`, top to bottom:
Each item rebuilds through its own `BlocSelector<AyahShareCubit, AyahShareState, …>` (`state-management-patterns.md`); the record types below are the selected values, and a builder that needs a field outside its record reads `context.read<AyahShareCubit>().state`.
1. Row: `ayahShare_title` (`TS.bold16`) and a `TextButton` `S.playback_close` with `onPressed: () => Navigator.of(context).pop()`. No selector.
2. Selector on `(ShareCardStatus, int, MushafPaper, bool)` = `(status, renderId, paper, progress)`; the builder reads `context.read<AyahShareCubit>().state.cardBytes`. `status == failed` → `ayahShare_renderFailed` (`TS.medium14`) + `TextButton.icon(key: const ValueKey('share-retry'), icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh), label: Text(mushaf_retry), onPressed: cubit.load)`; otherwise `ShareCardPreview` (`semanticLabel` = `ayah_label`).
3. Selector on `(status, includeTafsir, tafsirStatus)`: `AppSettingsTile(title: ayahShare_addTafsir, subtitle: tafsirStatus == failed ? tafsir_loadFailed : null, enabled: status == ready, onTap: toggle, trailing: Row[if failed IconButton(key: const ValueKey('share-tafsir-retry'), tooltip: mushaf_retry, icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh), onPressed: status == ready ? cubit.retryTafsir : null), Switch(key: const ValueKey('share-tafsir'), value: includeTafsir, onChanged: status == ready ? cubit.setIncludeTafsir : null)])`. `AppSettingsTile.enabled` only dims the row and drops the tile's own `onTap` (`app_settings_tile.dart:62-69`); the trailing controls stay live unless their own callbacks are null, hence the explicit guards (the cubit guards too, Task 5).
4. Selector on `(status, paper)`: `display_paper` label (`TS.medium14`) and `PaperSwatches(selected: paper, onSelected: cubit.setPaper, enabled: status == ready)`.
5. Selector on `(status, busy)`: `ActionButtonsRow(children: [ActionBtn.primary(key: _shareKey, icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare08), label: S.share, onPressed: status == ready && !busy ? cubit.requestShare : null), KeyedSubtree(key: _textKey, child: ActionBtn(key: const ValueKey('share-text'), icon: const HugeIcon(icon: HugeIcons.strokeRoundedText), label: ayahShare_textOnly, onPressed: busy ? null : _shareText))])`. Tests find the primary button by `find.widgetWithText(ActionBtn, S.share)` (it carries only the GlobalKey) and the text button by `ValueKey('share-text')`.

Listener (`BlocListener`, `listenWhen: (a, b) => a.export != b.export`), placed under the inner `Scaffold` so SnackBars land in the sheet's messenger:
- `sharing` → before any await capture `final cubit = context.read<AyahShareCubit>();`, the bytes, the label text `S.current.ayah_label(surahDisplayName(context, ayah.surah), ayah.ayah.toLocalized(context))` and `_originOf(_shareKey)`; then `await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'image/png')], fileNameOverrides: ['ayah_${ayah.surah}_${ayah.ayah}.png'], text: label, sharePositionOrigin: origin))`; then `cubit.shareFinished(ok: true)`, or `ok: false` on any throw (`shareFinished` itself returns when the cubit is closed, so a sheet dismissed during the OS share never emits after close, and `context` is never read after the await).
- `failed` → `SnackBar(content: Text(S.current.share_failed, style: TS.regular14))`.
- `_shareText`: before the await capture `final messenger = ScaffoldMessenger.of(_textKey.currentContext!)` (the button's context sits under the sheet's inner `ScaffoldMessenger`; the State's own `context` is above it and would put the SnackBar behind the sheet), `final text = ayahShareText(context, ayah)` and `final origin = _originOf(_textKey)`; then `SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin))` in a try/catch that shows the same SnackBar through `messenger`.

- [ ] **Step 1: Write the failing tests** (`ayah_share_sheet_test.dart`: one harness `Future<void> open(WidgetTester tester, {AyahIdentifier ayah = const AyahIdentifier(surah: 6, ayah: 31), Locale locale = const Locale('ar'), double textScale = 1})` that pumps a `MaterialApp` with `S.delegate` + `GlobalMaterialLocalizations.delegates`, `locale`, a `MediaQuery` `TextScaler.linear(textScale)`, a 360×800 view and a button that calls `AyahShareSheet.show(context, ayah: ayah)`, then taps it; the 2:1, English and 2x tests pass their own arguments; `registerFakeAyahShare` per test; share channel `MethodChannel('dev.fluttercommunity.plus/share')` mock recording arguments; `MethodChannel('plugins.flutter.io/path_provider')` mock answering `getTemporaryDirectory` with `Directory.systemTemp.createTempSync().path`; the image share writes a real temp file through several real I/O awaits, so after tapping «مشاركة» drive it inside `tester.runAsync` with a bounded loop (at most 50 rounds) that alternates `await tester.pump()` with `await Future<void>.delayed(const Duration(milliseconds: 20))` until the share mock has recorded a call (or, for the failing share, until the SnackBar is found), then `pump()` once more outside; assert on widgets and channel arguments, never on decoded pixels)
  - `'opens with a skeleton, then the card preview'`: prepare held by a completer → `Skeletonizer` shown (pump, no settle); complete → `share-preview-image` shows `MemoryImage` with the fake bytes.
  - `'the tafsir switch loads it and keeps the plain card shareable'`: tafsir held → `LinearProgressIndicator` shown, the share button enabled; complete → compose received the body, progress gone.
  - `'a tafsir failure shows the message with a retry'`: `Left` → `تعذّر تحميل التفسير` and `share-tafsir-retry`; tap it → a second tafsir call.
  - `'a paper swatch recomposes on that paper'`: tap `share-paper-night` → last compose used night colours.
  - `'share hands the PNG with its name and the ayah label'`: channel args `paths` single ends with `ayah_6_31.png`, `mimeTypes` `['image/png']`, `text` `'سورة الأنعام، الآية ٣١'`, `originWidth` > 0.
  - `'in English the share text is the English label'`: `Locale('en')` → `text` == `'Surah ${quran.getSurahName(6)}, Ayah 31'`.
  - `'a failing share shows the message above the sheet'`: channel throws `PlatformException` → `تعذّر فتح نافذة المشاركة` found, and its `SnackBar` has a `BottomSheet` ancestor.
  - `'text only shares the verse without the basmala'`: `open(tester, ayah: const AyahIdentifier(surah: 2, ayah: 1))`, tap `share-text` → `text` starts with `'الم — '` and does not contain `quran.getVerse(2, 1).split(' ').first` (the Simple-spelling basmala word, not the Uthmani one from 1:1).
  - `'a failing text share shows the message above the sheet'`: channel throws `PlatformException`, tap `share-text` → `تعذّر فتح نافذة المشاركة` found, and its `SnackBar` has a `BottomSheet` ancestor.
  - `'buttons are disabled during a recompose'`: after the first card, queue a held compose and tap `share-paper-night` → the `ActionBtn` under `share-text` and `find.widgetWithText(ActionBtn, 'مشاركة')` both have null `onPressed` (pump, no settle: the progress bar shows); complete it → both enabled.
  - `'إغلاق closes the sheet'`: tap the `إغلاق` button, settle → no `AyahShareSheet`.
  - `'a render failure shows retry'`: `failCompose` → `تعذّر تجهيز الصورة`; clear it, tap `share-retry` → preview image.
  - `'fits at 2x text in 360 px'`: `open(tester, textScale: 2)` → `tester.takeException()` null.
  - `paper_swatches_test.dart` `'six 48 px swatches, the selected one announced selected'`: six `share-paper-*` keys, each ≥ 48×48, `sepia` semantics flagged selected, tap `cream` → `onSelected(cream)`.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/widgets`. Expected: FAIL.

- [ ] **Step 3: Implement** the three widgets and the test helper.

- [ ] **Step 4: Verify** the scoped tests, then `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; +14 → 1741.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/widgets/ayah_share_sheet.dart lib/features/ayah_share/presentation/widgets/share_card_preview.dart lib/features/ayah_share/presentation/widgets/paper_swatches.dart test/features/ayah_share/ayah_share_fakes.dart test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart test/features/ayah_share/presentation/widgets/paper_swatches_test.dart
git add lib/features/ayah_share/presentation/widgets/ayah_share_sheet.dart lib/features/ayah_share/presentation/widgets/share_card_preview.dart lib/features/ayah_share/presentation/widgets/paper_swatches.dart test/features/ayah_share/ayah_share_fakes.dart test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart test/features/ayah_share/presentation/widgets/paper_swatches_test.dart
git commit -m "feat(ayah-share): share sheet with live card preview, tafsir switch, paper swatches and text share

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Entry points, test rewrites and feature-widgets.md (seam 6, part 3)

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart` (delete `ayahShareText` and `_share`; the `study-share` button calls `AyahShareSheet.show(context, ayah: ayah)`; drop the now-unused `quran` and `share_plus` imports)
- Modify: `lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart` (required `onShare`; a first `MenuItemButton` keyed `place-share` with `S.of(context).share`, `TS.medium14`)
- Modify: `lib/features/bookmarks/presentation/pages/widgets/places_groups.dart` (`_SavedRow`: `PlaceRowMenu(onShare: () => AyahShareSheet.show(context, ayah: place.ayah), onRemove: …)`)
- Modify: `.claude/rules/feature-widgets.md`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart` (lines 280–336), `test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart`, `test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart`

**Interfaces:**
- Consumes: `AyahShareSheet.show` (Task 7), `registerFakeAyahShare` and its `FakeGetShareCardContent.requests` (Tasks 5, 7).
- Produces: `PlaceRowMenu({super.key, required this.onShare, required this.onRemove})`. The Bookmarks page and «أماكني» both reach it through `PlacesGroups`; from «أماكني» the share sheet stacks on the places sheet.

`feature-widgets.md` edits (wording from spec §5):
- The "no pages" sentence becomes: "`quran_playback`, `tafsir` and `ayah_share` have no pages, so their widgets sit in `presentation/widgets/`."
- The surah↔bookmarks coupling sub-bullet (the one starting "Deliberate two-way coupling: `surah` reads `bookmarks`") ends with "Don't add more."; reword that last sentence to "Besides `ayah_share` below, don't add more."
- Insert a new sub-bullet directly after that surah↔bookmarks sub-bullet (still under "Don't import a feature widget into another feature"; the file has no separate `bookmarks` bullet, the exports share one "Exception:" sub-bullet): "`ayah_share` exports `AyahShareSheet` (opened by `surah`'s study leaf and `bookmarks`' saved rows; it takes the ayah by constructor). Deliberate two-way coupling: `ayah_share` reads `surah`'s mushaf domain (`GetMushafPage`, `AyahBoundEntity`, `NormalizedRect`), `mushaf_paper_colors.dart` (`MushafPaperX` for the card and swatches), `enum_localization.dart` (`MushafPaper.localized` for the swatch labels) and `mushaf_grid.dart`; it also reads `tafsir`'s domain (`GetAyahTafsir`, `Tafsir`) and `quran_playback`'s domain (`QuranPageService`), and `SettingsCubit` for the paper."
- `surah` utils list gains "`mushaf_grid.dart` (`gridLineOf`, `gridBand`, `headerBand`, `headerSlot`, `rowEdges`, `rowSource`, `accentSource`: the page grid and the one place that corrects the bounds' overlap and rosette defects)".
- New utils bullet: "`ayah_share`: `share_card_layout.dart` (`shareCardLayout`, `shareCardFrame`: bounds → card slices and height), `share_card_renderer.dart` (`ShareCardRenderer`: crops once per ayah, composes PNG bytes per paper/tafsir), `ayah_share_text.dart` (`ayahVerseText`, `ayahShareText`: the verse without the repeated basmala)."

- [ ] **Step 1: Rewrite the tests that pin the old behaviour, add the new ones**
  - `ayah_study_leaf_test.dart`: delete `'share text quotes the ayah and names it'` (moved to Task 6) and the `share` group's two tests; add `'the share button opens the share sheet'`: `registerFakeAyahShare()` + `addTearDown(sl.reset)`, tap `study-share`, `pumpAndSettle` → `find.byType(AyahShareSheet)` one, fake content `requests` == `[_ayah]`. Remove imports left unused (`quran`, `services`).
  - `place_row_menu_test.dart`: pump `PlaceRowMenu(onShare: () => shared++, onRemove: () => removed++)`; add `'مشاركة calls onShare'` (open, tap `place-share`, `shared` 1, menu closed).
  - `places_sheet_test.dart`: add `'sharing a saved row opens the share sheet over أماكني'`: `registerFakeAyahShare()`, saved place 2:5, open the row menu, tap `place-share`, settle → `AyahShareSheet` and `PlacesSheet` both found. This also covers the Bookmarks page entry point (D6): `bookmarks_page.dart` and `places_sheet.dart` both render saved rows through `PlacesGroups`' single `_SavedRow`, which is the only place `onShare` is wired, so no `bookmarks_page_test.dart` change is needed.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/bookmarks/presentation/pages/widgets`. Expected: FAIL (no `onShare`, the share button still shares text).

- [ ] **Step 3: Implement** the three code changes and the `feature-widgets.md` edits. `grep -rn "ayahShareText" lib test` finds only `ayah_share` files.

- [ ] **Step 4: Verify** the scoped tests, then `flutter test`, `flutter analyze --no-fatal-infos`. Expected: PASS; net 0 (−3 removed, +3 added) → 1741.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart lib/features/bookmarks/presentation/pages/widgets/places_groups.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart lib/features/bookmarks/presentation/pages/widgets/places_groups.dart .claude/rules/feature-widgets.md test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart
git commit -m "feat(ayah-share): open the share sheet from the study leaf and saved-ayah rows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Out of slice

- S2: the reel (`pro_video_editor`, `ReelRepository`, frames, audio, stepper, the «صورة / مقطع بالتلاوة» selector, `format`, `ayah_range_label`, Info.plist).
- §9 follow-ups: bounds fix in the generator, `AyahStrip` adopting `mushaf_grid.dart`, the optional `headers` array, `sharePositionOrigin` in `HadithView._onShare`.
- Manual QA (§6) runs after Task 8 on emulator-5554 with a reinstall first; it is a workflow step, not a task.
