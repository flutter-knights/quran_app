# Ayah share «مشاركة الآية»: build spec

Date: 2026-11-23 (revised after the Goldfish spec review the same day). Owner brief: share an ayah as an image that looks like the printed mushaf (reference: a cream card with the ornamented surah-name frame, a faded basmala, the ayah in the mushaf's own printed lines ending in its numbered rosette); optionally add Tafsir al-Muyassar under the ayah in slightly smaller text that shrinks to fit; and share the card with the recitation as a short video ("reel"). The owner asked for the best choice on reel scope and delegated every other decision. Builds run in the worktree `/Users/sameh/Documents/flutter_projects/quran_app-ayah-share`.

Evidence behind this spec (local scratch, not committed): a feasibility study and a recon run, including a Python prototype of the card that renders every edge case from the bundled assets (`…/scratchpad/recon/card_proto.py`) and a build spike of the video package on this toolchain (`…/scratchpad/recon/video/`). This spec restates everything a builder needs; it does not depend on those files.

## Problem, goals, non-goals

Problem: today the only share is plain text (`AyahStudyLeaf._share`, `lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart:207`), and it even repeats the basmala in front of ayah 1. People share ayat as images and short videos, so the app sends them elsewhere.

Goals:
1. **Image card**: one ayah drawn from the mushaf's own page images, with the surah frame and faded basmala, in the reader's paper colours.
2. **Tafsir card**: the same card with Tafsir al-Muyassar under the ayah, in a smaller text size that steps down further for long tafsir.
3. **Reel**: a 1080×1920 MP4 of one or more consecutive ayat, each ayah's card shown while the current reciter recites it.
4. A share sheet whose preview shows the exact bytes that get shared (image mode: the card PNG; reel mode: the first frame PNG).

Non-goals: translations on the card; word-by-word; custom backgrounds or photos; choosing a reciter inside the share sheet (it uses the reader's reciter); saving to the photo gallery (the OS share sheet already offers "Save image"/"Save video"); direct Instagram/TikTok SDK integrations; changing `AyahStrip` or the bounds generator (follow-ups, §9).

Anti-goals (a failure even if it works): a card that does not look like the printed mushaf; text rendered in a fallback font instead of the page glyphs; a share that blocks the reader or freezes the UI; a reel whose audio drifts from the card.

## 0. Decisions taken by default (owner delegated all)

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | How the ayah is drawn | **Crop the bundled page PNGs** (ink `AssetsDir.mushafPage(page)` + accent `AssetsDir.mushafPageAccent(page)`) using the bounds JSON, never typeset text. | Owner picked the printed-mushaf look. The runtime text is Tanzil "Simple" spelling, not Uthmani, and the 604 QCF page fonts are not bundled. The prototype matches the reference. |
| D2 | Surah frame and basmala | Cropped at runtime **by grid geometry** from the surah's start page, trimmed to the band's alpha bounding box. No hard-coded art, widths or positions of today's frame. Basmala opacity is normalised from the crop's peak alpha. | Another session is regenerating the header art (narrower frame, semi-transparent basmala). Geometry-based crops pick up the new art with no code change, and the basmala must not fade twice. |
| D3 | Tafsir size | Tafsir text **two tokens below** the study leaf body (`TS.regular16` → `TS.regular14`, skipping `regular15` on purpose); past 600 characters it steps down to `TS.regular12`. The image card grows in height to fit the whole tafsir; nothing is cut in the image (a card taller than 4096 px is exported at a smaller scale, §3.2). | Owner: "shrink or make tafsir text be small some bit". |
| D4 | Reel scope ("show the best") | Start ayah = the selected ayah. The user can extend to the following ayat of the same surah with a stepper, up to **10 ayat and 60 s of audio** (whichever comes first; the basmala audio counts). The cap only limits extending: the default count of 1 is never blocked, so a single ayah longer than 60 s (e.g. 2:282) makes a longer reel that is passed along as is. Each ayah shows its own card while it is recited. Basmala audio (1:1) plays before ayah 1 of every surah except 1 and 9, over the first ayah's card. | One ayah covers most shares; short runs (e.g. 2:255–257, Al-Ikhlas) are what people post. 60 s keeps the file accepted by Instagram Reels/Stories (via the share sheet), WhatsApp Status, and TikTok. |
| D5 | Video engine | **`pro_video_editor: 2.54.0`, pinned exactly** (BSD-3, uses Media3 on Android and AVFoundation on iOS, no native FFmpeg). | Spike on this toolchain: Android debug + release and iOS device + simulator builds pass with no Gradle changes; all `androidx.media3` modules resolve to 1.11.1 (just_audio's 1.4.1 is lifted, see risk 6) and just_audio playlists still play and seek; +0.63 MB arm64 APK. FFmpegKit is discontinued; its forks add 8–15 MB. |
| D6 | Entry points | (a) The study leaf's share button (`ayah_study_leaf.dart:94-96`) opens the share sheet instead of sharing text. (b) A «مشاركة» item in the saved-ayah row menu (`PlaceRowMenu`, used by the Bookmarks page and the «أماكني» sheet). The quick panel (`AyahLeaf`) gets nothing. Ayah 0 (the banner) never offers share. | [`2026-11-21-mushaf-leaf-ribbon-design.md`](2026-11-21-mushaf-leaf-ribbon-design.md) placed share in the study header on purpose; a fifth quick-panel tile would crowd the row. Saved ayat are ayat people want to pass on. |
| D7 | Plain text share | Kept as a secondary «نص فقط» button in the sheet; the basmala-in-front-of-ayah-1 bug is fixed: for ayah 1 of surahs 2–114 except 9, drop the first four whitespace-separated words of `quran.getVerse` and trim. Never match on `quran.basmala`: it is spelled differently (ٱ, no tatweel) from the bundled Tanzil Simple prefix «بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ», so `startsWith` strips nothing. 1:1 and 9:1 stay as they are. | Some chats prefer text; the bug is the same one the card must avoid. All 112 affected verse-1 entries share that four-word prefix. |
| D8 | Paper | The card uses the reader's paper (`SettingsCubit.state.settingsModel.mushafPaper`, colours via `MushafPaperX.colors`). The sheet offers the six papers as swatches; the choice is ephemeral (not persisted). | Matches what the user is reading; night papers make dark cards. |
| D9 | Attribution and card language | Image card: no footer (matches the reference). Tafsir card: the heading «التفسير الميسر» (existing key `tafsir_muyassar`) above the tafsir. Reel: a small footer line with the reciter's name and the ayah reference. Text drawn on cards and reels is always Arabic (`PendingS.forLanguage('ar')`, Arabic reciter and surah names, Arabic-Indic digits); the share text follows the app locale. | Quran Foundation terms ask for credit on social videos; the reference image has no footer; the card copies an Arabic mushaf. |
| D10 | Ship order | Two slices, two PRs. **S1** image + tafsir card + sheet + entry points (PR into `main`). **S2** reel (stacked PR into S1's branch). The owner merges both. | S1 is useful alone and carries no new dependency; S2 adds the video package and an iOS Info.plist key. |
| D11 | Localization | New strings go in both ARBs and in `lib/core/localization/pending_s.dart` (`PendingS`), used through `PendingS.of(context)` / `PendingS.current`; `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`, never run `intl_utils:generate`. Reuse existing keys (`tafsir_muyassar`, `tafsir_loadFailed`, `ayah_label`, `share_failed`). | `lib/generated` regenerates only on IDE save (precedent: [`2026-11-21-mushaf-leaf-ribbon-design.md`](2026-11-21-mushaf-leaf-ribbon-design.md)). |

## Alternatives considered

| Decision | Rejected option | Trade-off |
|---|---|---|
| D1 ayah drawing | Typeset with Amiri / Scheherazade New | Flexible line breaks, but "Simple" spelling (not Uthmani), never rendered-checked, and does not look like the reference. |
| D1 | Bundle the 604 QCF page fonts and typeset | Exact Uthmani glyphs, but 604 more font files (size not measured), no clear licence, and a second rendering path, while the page PNGs are already bundled and match the reference. |
| D1 | Reuse `AyahStrip` as is | Caps at 3 lines (642 ayat need 4–15), paints only the ink layer (no rosettes), one page only (no header/basmala), and slices rosettes at ayah boundaries. |
| D1/D2 | Fix the bounds in the generator (snap tolerance, rect boundary through a rosette) | The right long-term fix, but the header session owns the in-flight regeneration of `assets/mushaf/**`. Handed over in §9; until then the correction rules live once, in the shared `mushaf_grid.dart`. |
| D2 | Draw the frame with a Dart painter | The other session may publish one later (`surah_frame_painter.dart`, not final); waiting would block S1. Crops follow the art automatically. |
| D2 | Draw frame + basmala from the bundled `QCF2BSML` font | The frame glyph and basmala are in it, but the surah name and the ترتيبها/آياتها ovals come from other fonts and generator-only placement constants. Crops stay the single source of truth while the header art is regenerated. |
| D5 video | `ffmpeg_kit_flutter_new_min` 4.0.0 | LGPL, +8–15 MB per platform, fresh fork; kept as the fallback if `pro_video_editor` regresses. |
| D5 | Native AVAssetWriter + MediaCodec via Pigeon | Most control, but two native code bases to maintain for one feature. |
| D4 | Single ayah only | Simpler, but short runs are the common reel and the package syncs per-ayah tracks exactly. |
| Preview surface | A new route | Every mushaf overlay is a modal sheet; a sheet also works from the Bookmarks page without touching the router. |
| Placement | House it under `surah/presentation/pages/mushaf/widgets/share/` | Adds no feature edge (bookmarks already reads `surah` presentation), but `surah` is already the largest feature and S2 would put a video dependency and an encode pipeline inside it. `ayah_share` isolates that at the cost of one declared two-way edge (§5). |
| Placement | Pass paper colours into the sheet by constructor (the `TafsirSection` pattern) | The swatches need all six papers, and `ayah_share` already reads `surah`'s grid util, so constructor injection removes no edge; it reads `mushaf_paper_colors.dart` the way `bookmarks` does. |

## 1. Glossary

- **Share card**: the image of one ayah (optionally with tafsir) at 1080 px width.
- **Mushaf grid**: the shared, bounds-only geometry of a page (grid lines, header slot, overlap-aware edges, rosette accent rule), in `surah`.
- **Card layout**: the card-only geometry that turns content into source/destination slices for the header, basmala and ayah rows.
- **Header slot**: the grid band holding a surah's frame; **basmala unit**: the `ayah: 0` entry of a surah start.
- **Row**: one printed mushaf line (or the part of it that belongs to the ayah) placed on the card.
- **Rosette**: the ayah-end number medallion, drawn in the accent layer.
- **Crops**: the small `ui.Image`s cut from the page PNGs for one ayah; made once, recomposed on every toggle.
- **Reel**: the MP4 made of one share card per ayah, each held for its ayah's recitation.
- **Reel segment**: one ayah in a reel: its content, its audio file(s), and its measured duration.

## 2. Asset facts the layout relies on (verified against all 604 bounds files)

- Page PNGs are 1536×2795 RGBA alpha masks (black RGB). The **ink** layer holds text, basmala, the surah name and the oval label text; sajda/hizb marks are inside glyphs. The **accent** layer holds only the header frame and the rosettes.
- **Units**: bounds rects are normalised. Every rule in §3.1 works in **page px**: `x·1536`, `y·2795`, using the PNG size (`mushafPageSize`). The grid constants come from the generator (`test/tools/generate_mushaf_assets_test.dart:54-61, 145-151`), which used `pageH = 2795.52`: `TOP = 0.058·pageH = 162.14 px`, `LH = pageH·(1−0.058−0.033)/15 = 169.41 px`, 15 lines; line *i* spans `[TOP+i·LH, TOP+(i+1)·LH]`. The half-pixel gap between 2795 and 2795.52 is absorbed by the rounding below; the prototype uses exactly this pair.
- A rect's grid line is `round(((y+h)·2795 − TOP)/LH) − 1`. Rect tops sit ~20 px below the grid on line 0 (that rect is trimmed, h≈0.057) and 4–9 px below on other lines.
- **Text column**: `[0.1043, 0.8975]` of the page width, the modal left and right edges of full justified lines across pages 3–604. Column width `COL = 0.7932·1536 ≈ 1218 page px`.
- No ayah spans two pages. Lines per ayah: max 15 (2:282, page 48); 642 ayat have 4+ lines.
- Every surah except 1 and 9 has exactly one basmala unit (one centred rect, same page as ayah 1). Surah 1's basmala is ayah 1 itself; surah 9 has none.
- The header slot is the grid line above the basmala unit (above ayah 1 for surahs 1 and 9). For 18 surahs (4, 10, 22, 23, 24, 26, 27, 32, 33, 37, 38, 45, 47, 53, 60, 64, 65, 80) the basmala is on grid line 0 and the header is on the **previous page, grid line 14**. A page can hold several headers (e.g. 602); pick by the surah's own basmala/ayah 1.
- Rosettes: the rosette is the last glyph of the ayah, inside its last-line rect at the RTL end. In 1,103 places the boundary between two ayat cuts a rosette by up to 24 px (a sliver of the previous ayah's rosette appears at the right edge of the next ayah's first rect). 24 same-line rects overlap by up to 60 px (generator edge snap). 570 ayat end on a line holding only the rosette (a rect 50–90 px wide). Both are generator defects (§9); §3.1 corrects them in one place.
- The header frame's top rule can bleed one pixel row into the rect of the line above it (e.g. 4:176 on page 106).

## 3. The share card (S1)

### 3.1 Layout (pure Dart, no image work)

Two pieces:

- **`lib/features/surah/presentation/utils/mushaf_grid.dart`** (shared, bounds-only, beside `reader_rules.dart` and `ayah_strip_layout.dart`, so `AyahStrip` can adopt it later without importing `ayah_share`): the grid constants and `gridLineOf(rect)`; `headerSlot(surah, startPageBounds, previousPageBounds)` → (page, grid line); overlap-aware row edges for a rect given its same-line neighbours; the rosette accent rule. This is the single correction point for the §2 generator defects.
- **`lib/features/ayah_share/presentation/utils/share_card_layout.dart`** (card-only): `ShareCardContent` + header bbox (from the renderer) → slices (layer, page, src rect in page px, dst rect in card px) for header, basmala and ayah rows, plus the card height.

Rules, in words (calibrated numbers in Appendix A):

1. **Edges**: on each of the ayah's lines, if a neighbour rect on the same line overlaps, trust the narrower rect and clip the wider one at its edge. Outer edges (no neighbour on that side) get a small pad.
2. **Source rows**: x from those edges. The row cell (placement, pitch, accent) is one line height starting at the rect's own top (grid line 0: ending at the rect's bottom). The ink is cut from the line's whole grid band plus a margin above and below, then masked to the line's own ink: marks rise above the rect top (3:123's «صلى» straddles it) and the next line's marks rise into the cell (under 2:136's last row), so a plain rectangle either clips a mark or draws a foreign tip. Ownership is per connected ink component: one that starts well above the band edge belongs to the line above, one that reaches well below it to the line below, and a small mark floating between takes the side of its nearest decided neighbour. Checked against per-line renders of all 604 pages: no own pixel dropped, no foreign pixel kept.
3. **Rosette-only tail**: a last line whose core width (the clipped rect width before the outer pad) is under the tail threshold moves onto the left end of the previous row. If the widest row then exceeds the column width (`COL`) by more than the tolerance, the whole card's text scale shrinks to fit that row.
4. **Accent** (rosettes) is drawn only on the ayah's last row, with its source clamped to that line's grid band (so rosettes of neighbouring lines never leak). An interior left edge (a neighbour follows) extends the accent crop to keep the ayah's own rosette bleed; an interior right edge clears the foreign sliver. Body ink is never extended sideways.
5. **Stacking**: rows stack at one row pitch with no extra gap, right-aligned to the right margin (a partial first or last fragment stays right-aligned, reading as a continuing RTL paragraph). A single-row ayah is centred. On pages 1–2 (centred layout) every row is centred.
6. **Header**: the header slot's band, padded, tightened at runtime to the alpha bounding box of max(ink, accent) (the renderer measures it), scaled no larger than the text scale and centred. **Basmala** (skipped for surahs 1 and 9): the basmala unit's rect, ink only, cut and masked like an ayah row (rule 2) so the next line's marks neither show under it nor inflate its peak, slightly smaller, centred, at an opacity normalised from the masked crop's peak alpha.
7. **Height**: top and bottom padding, a minimum height, content centred vertically when shorter. With header and basmala: 1 row → 628, clamped to the 670 minimum; 3 rows 888; 15 rows 2450.

Dst rects are in 1080-px card space.

### 3.2 Rendering (`share_card_renderer.dart`)

- **Crops, once per ayah**: the injectable loader (`Future<ui.Image> Function(String asset)`, called with `AssetsDir.mushafPage(page)` / `AssetsDir.mushafPageAccent(page)`) decodes one page at a time at full 1536 px (no `ResizeImage`). The renderer cuts the needed regions into small `ui.Image`s (`PictureRecorder` → `toImage`), measures the header bbox and the basmala's peak alpha, and disposes the page. At most three pages are touched (ayah page, header page, basmala page; the header page differs from the basmala page for the 18 surahs above). Peak memory ≈ one decoded page (17 MB) plus crops. The result, `ShareCardCrops`, is kept by the cubit and disposed in its `close()`.
- **Compose, on every toggle** (paper, tafsir): paper background, ink crops tinted with `ColorFilter.mode(colors.ink, BlendMode.srcIn)`, accent crops with `colors.accent`, then the tafsir block, then PNG export (`toByteData(format: png)`). A toggle never decodes a page again.
- **Transforms**: crops are drawn with the identity transform at their dst rects. Only the text (tafsir heading and body, reel footer) is laid out at a **logical width of 360** with `TS.*` tokens and drawn inside `canvas.scale(3)` (`W/360`), so no `fontSize:` is added (the typography ratchet must not rise).
- **Max height**: if the composed height `h` exceeds 4096 px (a guard: some low-end GPUs cap textures there; not measured on this app), the whole card is drawn at scale `4096/h`, so the PNG is narrower than 1080 and nothing is cut.
- The only output is the PNG bytes. The preview shows those same bytes (§3.5), so preview = output by construction.

### 3.3 Card content (domain)

`GetShareCardContent(ayah)` returns `Either<Failure, ShareCardContent>` holding raw bounds only, no grid math and no tafsir: the ayah identifier; the ayah's page and that page's full `AyahBoundEntity` list (its own rects plus every same-line neighbour); the surah's start page (`QuranPageService.getPageForAyah(surah, 1)`) and its list; and the list of the page before the start page (null on page 1), which the layout needs when the header sits there. It reads bounds through `GetMushafPage` (bundled JSON, no network) and pages through `quran_playback`'s `QuranPageService`. The mushaf grid picks the header slot; seam 3 tests only fetching.

**Tafsir** is loaded separately by the cubit, through the tafsir feature's `GetAyahTafsir`, lazily the first time the switch turns on, with its own `CancelToken` (a new one on retry; cancelled in `close()`). The card never waits for it in image mode with the switch off.

**Al-Fatiha 1:1 introduction**: the Muyassar text for 1:1 opens with a surah introduction: «سورة الفاتحة سميت هذه السورة بالفاتحة؛ لأنه يفتتح بها القرآن العظيم، وتسمى المثاني؛ لأنها تقرأ في كل ركعة، ولها أسماء أخر.» followed by the tafsir proper, starting «أبتدئ قراءة القرآن باسم الله مستعينا به». The tafsir feature gets a `Tafsir.body` getter: for 1:1, when the text starts with «سورة الفاتحة», drop everything up to and including the first «. »; otherwise `body == text`. The card uses `body`. The study leaf's `TafsirSection` keeps `text` on purpose, because the introduction reads naturally above the first ayah while studying. A unit test pins the strip with that sentence as a fixture.

### 3.4 Tafsir block

Below the ayah: a thin accent rule with a small centred diamond (like `OrnamentDivider`), the heading `tafsir_muyassar` («التفسير الميسر», Arabic per D9) in `TS.bold14` (accent colour), then the tafsir `body` right-aligned, RTL, in `colors.ink2`. Body token: `TS.regular14` with height 1.8 (the study leaf uses 1.95; the card is tighter on purpose). If the tafsir is longer than 600 characters, use `TS.regular12` with height 1.8 instead. Side margins equal the card margin. The image card grows to fit the full text. The block takes an optional `maxHeight`, used only by the reel (§4.1).

### 3.5 Share sheet (`AyahShareSheet`)

A modal bottom sheet (`showModalBottomSheet`, `showDragHandle`, `isScrollControlled`, `useSafeArea`, surface `context.colorScheme.surface`) with a static `show(context, {required AyahIdentifier ayah})`, creating its own `AyahShareCubit` (`registerFactoryParam` keyed by the ayah). Its body sits in its own `ScaffoldMessenger(child: Scaffold(backgroundColor: Colors.transparent, …))`, like `PlacesSheet`, so SnackBars show above the modal barrier. Top to bottom:

1. Preview: `Image.memory(cardBytes, gaplessPlayback: true)` scaled to the sheet width (scrolls if tall), on a subtle paper-edge shadow (`context.cardShadow()`); the shadow is preview-only, not in the PNG.
2. `AppSegmentedSelector`: «صورة» / «مقطع بالتلاوة» (S2 adds the second segment; S1 ships the selector with the image option only or hides it — builder's call, but no dead control).
3. `AppSettingsTile` with a switch: «إضافة التفسير الميسر», default **off**. Turning it on while the tafsir is not loaded starts the load: the slim progress bar shows over the preview, which keeps showing the card without tafsir, and «مشاركة» stays enabled and shares that card until the tafsir arrives and the card is recomposed. Turning the switch off cancels the load. On failure the switch returns to off and shows the subtitle `tafsir_loadFailed` with a retry that re-requests only the tafsir.
4. Six paper swatches (round dots in each paper's background with an ink ring), default the reader's paper.
5. `ActionButtonsRow`: `ActionBtn.primary` «مشاركة» (`HugeIcons.strokeRoundedShare08`, as in the study leaf) and `ActionBtn` «نص فقط» (a HugeIcons text icon, builder's pick).

Loading: a paper-coloured placeholder card inside `Skeletonizer` while content, crops and the first compose are prepared (bundled assets only, no network). A recompose after a toggle shows the slim `LinearProgressIndicator` over the visible preview (the loading-states exception) and disables the buttons. Errors: content or render failure → inline message + retry; the OS share throws → SnackBar `S.share_failed` in the sheet's own messenger. The share call runs in the sheet's `BlocListener` (cubits never touch `BuildContext`) and passes `sharePositionOrigin` from the button's `RenderBox` (iPad). The PNG goes out as `ShareParams(files: [XFile.fromData(bytes, mimeType: 'image/png')], fileNameOverrides: ['ayah_<s>_<a>.png'], text: ayah_label, sharePositionOrigin: …)` (`XFile.fromData`'s `name` is ignored on io, so the override is what names the file). The share text is `ayah_label` («سورة الأنعام، الآية ٣١»).

Entry points:
- Study leaf: the share button calls `AyahShareSheet.show(context, ayah: ayah)`.
- `PlaceRowMenu` gains a required `onShare` (a `MenuItemButton` keyed `place-share`, «مشاركة»); its one call site, `_SavedRow` in `places_groups.dart`, passes `() => AyahShareSheet.show(context, ayah: place.ayah)`. From «أماكني» the share sheet stacks on top of the places sheet; closing it returns there.

### 3.6 State

`AyahShareCubit` with one Equatable state object (`copyWith`):

- `status` (loading | ready | failed), `content`, `paper`, `format` (image | reel), `error`.
- `includeTafsir`, `tafsirStatus` (idle | loading | ready | failed), `tafsir` (the `body` text or null).
- `cardBytes` (`Uint8List?`, **not** in `props`) and `renderId` (int, in `props`, incremented per finished compose), so emits never deep-compare megabytes.
- `export` (idle | rendering | sharing | done | failed) for S1; S2 adds `preparing`, `encoding`, `reelCount`, `reelSegments`, `progress`.

Every compose captures `++_renderGeneration`; a result whose generation is no longer current is dropped (same pattern as `PlaybackCubit._playGeneration`), so the preview and the share always use the latest render. `ShareCardCrops` is a cubit field, not state; `close()` disposes it and cancels the tafsir `CancelToken`. Every `emit` after an `await` is guarded by `if (isClosed) return;`.

## 4. The reel (S2)

### 4.1 Composition

- Canvas 1080×1920 in the card's paper colour, footer at the bottom. `available = 1920 − footerH`, where `footerH` is the laid-out footer height plus its padding.
- Per ayah: (1) lay out the card without tafsir; if it is taller than `available`, scale it down to fit and omit the tafsir (only 2:282 and one 11-row ayah are this tall). (2) Otherwise, with the switch on, give the tafsir block `maxHeight` = the remaining height, in `TS.regular12`. If the whole tafsir does not fit, cut at the last full sentence (ending in «.») that fits and append «…»; if fewer than three lines fit, omit the tafsir for that ayah. The result is centred vertically.
- Footer, bottom-centred, `TS.regular10` (logical, inside the ×3 scale), `colors.ink2`, always Arabic (D9): «<reciter name> · سورة <surah> <first>–<last>» with Arabic-Indic digits.
- Frames are rendered as PNG bytes per segment and handed to the repository; presentation writes no files.

### 4.2 Audio and segments

- Reciter: `context.read<PlaybackCubit>().state.reciter` (the one the reader is listening to), read by the sheet when the reel segment is selected and passed to the cubit.
- Selecting «مقطع بالتلاوة» prepares the start ayah: `GetShareCardContent` for it, its audio through a prepare-only use case `PrepareAyahAudio` (the existing `PlayAyahUseCase` also plays and must not be used), plus the basmala 1:1 audio before ayah 1 when the surah ∉ {1, 9}, then measures durations with `ReelRepository.audioDuration`. Each «+» does the same for the next ayah: the slim progress bar shows, «+» stays disabled while it runs, and the segment is added only after it is measured. Downloaded or cached surahs work offline.
- With the tafsir switch on, each segment also loads its tafsir; a per-ayah tafsir failure renders that card without tafsir.
- State keeps `reelSegments: List<ReelSegment>` (content, tafsir, audio paths, duration). Durations are measured on the device that renders, so no re-check happens at export.
- Never join MP3 files byte-for-byte (the joined file reports the first file's duration).

### 4.3 Encoding (`ReelRepository`)

- Domain interface `ReelRepository`: `Future<Either<Failure, Duration>> audioDuration(String path)`, `Future<Either<Failure, String>> compose(ReelRequest request)`, a progress stream (0–1), `cancel()`, and `discard(path)`, which deletes a finished reel's slot (a path outside `ayah_share/reels/<n>/` is ignored, so a late discard never touches a newer reel). `ReelRequest` carries per-segment frame bytes (`Uint8List`), audio paths and durations. Use cases `PrepareAyahAudio` and `ComposeAyahReel` sit on it.
- Data implementation `ReelRepositoryImpl` over `pro_video_editor` owns all plugin and file I/O: it writes frames under `getApplicationSupportDirectory()/ayah_share/` (not the temp dir, which the system may purge mid-render), runs two passes (stop-motion frames to a silent MP4, then the audio tracks added), deletes frames and the silent file in a `finally`, and deletes previous reels when a new one starts. The cubit discards a finished reel once the share sheet returns (share_plus has copied or handed off the file by then), and discards one that lands after a cancel or after the sheet closed, so no MP4 outlives its share. The request → render-data mapping is a pure function in the data layer and carries the unit tests; there is no extra adapter.
- **Sync rule**: card switch times come from cumulative audio offsets, never per-segment rounding. With `o_0 = 0` and `o_{i+1} = o_i + d_i` (segment 0 includes the basmala), card *i* covers `[snap(o_i), snap(o_{i+1}))`, where `snap(t) = round(t/step)·step`. Android: frameRate 5, `step = 0.2 s`, one `StopMotionFrame` per card with that duration. iOS ignores frameRate and turns each frame into one sample, so each card becomes `floor(D_i)` frames of 1 s plus one remainder frame of `D_i − floor(D_i)` (skipped when under 1/30 s), `D_i` being the card's snapped span and `step = 1/30 s`. The spike verified only whole 1 s repeats; seam 7 first checks on the simulator that a sub-second remainder frame keeps its duration. If it does not, iOS snaps card boundaries to whole seconds instead (`step = 1 s`, tolerance ≤ 1 s, the final frame extended to the audio end). Audio tracks start at the exact `o_j`. The video's total equals the audio total within one step. The mapping test asserts `|card switch − o_i| ≤ step` for every boundary of a 10-ayah request with fractional durations, on both platform mappings. Plugin call shapes: Appendix B.
- Output: H.264 + AAC MP4, `moov` first. Android stores 1920×1080 with a 90° rotation flag; S2 QA checks it plays upright on the real share targets.
- Progress: pass 1 maps to 0–0.5, pass 2 to 0.5–1. `cancel()` cancels whichever pass is running. The plugin's `RenderCanceledException` maps to a distinct `ReelCancelledFailure` (new, in `core/errors/failure.dart`); partial outputs are deleted.
- Share as `XFile(path, mimeType: 'video/mp4')`, file name `ayah_<s>_<a1>-<a2>.mp4` (`ayah_<s>_<a>.mp4` for one ayah). Share text: `ayah_label` for one ayah, a new `ayah_range_label` («سورة {surah}، الآيات {from}–{to}») for several.

### 4.4 Reel controls in the sheet

- Preview: the first frame's PNG (1080×1920, footer included), drawn by `reel_frame_painter`, shown like the image preview.
- A stepper «عدد الآيات» (− n +): «+» is disabled at the surah end, at 10, while the next ayah is being prepared, and when adding the next ayah would pass 60 s. When the start ayah alone passes 60 s, a one-line caption says some apps may trim clips longer than 60 s. A caption with the reciter name.
- While encoding: progress with a cancel button; the screen is kept awake with `ScreenWake.hold(cubit, on: true)`, released in a `finally`.
- Failures: audio download → SnackBar «تعذّر تحميل التلاوة» (sheet messenger), image option stays. Encode failure (including the app being backgrounded mid-export) → inline message with retry, image option stays. Cancel → back to idle, files deleted, no SnackBar.
- `AyahShareCubit.close()` also calls `ReelRepository.cancel()`, which deletes the request's files.

### 4.5 Platform

- `pubspec.yaml`: `pro_video_editor: 2.54.0` (exact). No Gradle changes (Media3 resolves to 1.11.1 everywhere).
- Inspect the merged Android manifest (`build/app/intermediates/merged_manifest/`) and record its permissions in the PR; remove any media permission the plugin adds with `tools:node="remove"`.
- `ios/Runner/Info.plist`: `NSPhotoLibraryUsageDescription` (the plugin links PhotoKit; App Store Connect rejects the build without the key even though the app never prompts). English text: "Used only if you choose to save a shared ayah video."; Arabic in a new `ios/Runner/ar.lproj/InfoPlist.strings` registered in the Xcode project's known regions. Run `pod install` so `ios/Podfile.lock` is updated and committed.

## 5. Feature placement and seams

New feature `lib/features/ayah_share/` (rule: one feature folder per capability; it orchestrates surah, tafsir, quran_playback and settings).

```
lib/features/ayah_share/
├── ayah_share_di.dart                 initAyahShare(), after initMushaf/initTafsir/initPlayback
├── domain/
│   ├── entities/share_card_content.dart, reel_request.dart (S2), reel_segment.dart (S2)
│   ├── repositories/reel_repository.dart (S2)
│   └── usecases/get_share_card_content.dart, prepare_ayah_audio.dart (S2), compose_ayah_reel.dart (S2)
├── data/repositories/reel_repository_impl.dart (S2)
└── presentation/
    ├── cubit/ayah_share_cubit.dart, ayah_share_state.dart
    ├── utils/share_card_layout.dart, share_card_renderer.dart, ayah_share_text.dart, reel_frame_painter.dart (S2)
    └── widgets/ayah_share_sheet.dart, share_card_preview.dart, paper_swatches.dart
lib/features/surah/presentation/utils/mushaf_grid.dart     shared bounds geometry (§3.1)
lib/features/tafsir/domain/entities/tafsir.dart            + body getter (§3.3)
```

- Use cases, renderer and repository: lazy singletons. Cubit: `registerFactoryParam<AyahShareCubit, AyahIdentifier, void>`.
- `feature-widgets.md` changes:
  - The "no pages" sentence: "`quran_playback`, `tafsir` and `ayah_share` have no pages, so their widgets sit in `presentation/widgets/`."
  - A new exception line naming both directions: "`ayah_share` exports `AyahShareSheet` (opened by `surah`'s study leaf and `bookmarks`' saved rows; it takes the ayah by constructor). Deliberate two-way coupling: `ayah_share` reads `surah`'s mushaf domain (`GetMushafPage`, `AyahBoundEntity`, `NormalizedRect`), `mushaf_paper_colors.dart` (`MushafPaperX` for the card and swatches) and `mushaf_grid.dart`; it also reads `tafsir`'s domain (`GetAyahTafsir`, `Tafsir`) and `quran_playback`'s domain (`QuranPageService`, `Reciter`, S2 audio), `SettingsCubit` for the paper and `PlaybackCubit.state.reciter` for the reel."
  - `mushaf_grid.dart` joins the `surah` presentation-utils list; `share_card_layout.dart`, `share_card_renderer.dart`, `ayah_share_text.dart` and `reel_frame_painter.dart` get an `ayah_share` line.
- `ayahShareText` moves to `ayah_share/presentation/utils/ayah_share_text.dart` with the D7 fix. In `test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart`, lines 280–336 (the `share` group) are rewritten: the share button opens the sheet. The `ayahShareText` test moves to `test/features/ayah_share/presentation/utils/ayah_share_text_test.dart` with the basmala cases: 2:1 → «الم», 112:1 stripped, 1:1 and 9:1 unchanged.

Seams = plan task boundaries (carry these into the plan, in this order):

| Seam | Slice | Testable alone by |
|---|---|---|
| 1. Mushaf grid (`mushaf_grid.dart`): grid line, header slot, overlap-aware edges, rosette accent rule | S1 | unit tests over real bounds JSON: the 18 previous-page headers, surahs 1 and 9, page 602, 91:10/91:11 overlap |
| 2. Card layout (`share_card_layout.dart`): rows, rosette tail merge, alignment, heights | S1 | unit tests: 6:31, 2:282 (15 rows), 16:127 tail, a single-row ayah (clamped to the minimum height), pages 1–2 centred |
| 3. Domain content + use case (`ShareCardContent`, `GetShareCardContent`) and `Tafsir.body` | S1 | use case tests with fake repos (start page, previous page, page 1); `Tafsir.body` with the 1:1 fixture |
| 4. Renderer (crops once, header bbox trim, basmala alpha normalisation, compose, tafsir block, 4096 cap, PNG export) | S1 | `tester.runAsync` with synthetic images via the injected loader; recording-canvas painter tests; a long synthetic tafsir stays ≤ 4096 px |
| 5. Cubit + state (lazy tafsir, retry, render generation, crops disposal) | S1 | bloc tests with fakes |
| 6. Sheet + preview + swatches + text share move + entry points (study leaf, `PlaceRowMenu.onShare`) + strings + DI + feature-widgets.md | S1 | widget tests with the share MethodChannel mock, a `path_provider` channel mock (`XFile.fromData` writes a temp file), `GetIt` stubs; a SnackBar is findable while the sheet is open |
| 7. Package + platform (pubspec, merged manifest, Info.plist + ar.lproj, Podfile.lock) + `ReelRepository` + impl | S2 | unit tests of the pure request → render-data mapping, including the sync tolerance on both platforms |
| 8. Reel frames (1080×1920 painter, footer, tafsir fit and cut) + `PrepareAyahAudio` + durations + basmala prepend + caps | S2 | unit/painter tests; cubit tests for a start ayah over 60 s (count 1 allowed, «+» disabled) |
| 9. Sheet reel mode (selector, stepper, first-frame preview, progress, cancel, share) | S2 | widget + cubit tests |

## 6. Tests and verification

- Unit tests read the real bounds JSON from disk (precedent: `test/tools/verify_mushaf_assets_test.dart`); add a corpus test that lays out all 6,236 ayat and asserts: no exception, every height finite, max rows 15, header found for all 114 surahs.
- No golden tests (repo convention).
- `flutter analyze --no-fatal-infos` and the full `flutter test` stay clean against `main`; the typography ratchet must not rise.
- Manual QA (S1 and S2 PRs): emulator-5554 screenshots of the sheet and shared files for 6:31, 1:1, 2:255, 2:282 with tafsir, 9:1, 4:1 (previous-page header: checks frame placement only, see risk 4), one night paper, and share from «أماكني». The spike replaced the real app on emulator-5554 and the iPhone 17 Pro simulator: reinstall before QA.
- S2 extra QA:
  - On one real Android phone and one real iPhone, a 60 s, 10-ayah reel; record the encode time in the PR.
  - The Android reel shared to WhatsApp Status and Instagram plays upright.
  - The Media3 lift (risk 6): play a surah range with the basmala sequence, seek, background with the media notification, interrupt with a call or the adhan (audio focus), download a surah and play it offline. Any regression blocks S2 and falls back to `ffmpeg_kit_flutter_new_min`.

## 7. Risks and open items for the owner

1. **Tafsir licence**: no public grant to redistribute Tafsir al-Muyassar text (Tanzil: non-commercial; King Fahd Complex: no statement found). The tafsir card puts it in shared images. Ship decision is the owner's; the switch defaults to off.
2. **Reciter audio terms**: audio comes from `mirrors.quranicaudio.com`, probably under Quran Foundation terms, which allow user shares of short clips with credit (the reel footer credits the reciter). The terms also cap automatic caching at 1 week; the existing playback cache keeps files forever (pre-existing, out of scope).
3. **Real-device speed**: emulator renders took 8 s for a 45 s range at frameRate 5 with a software encoder; real phones were not measured (S2 QA records them). The iOS one-second frames made adding audio slower on the simulator (13.3 s vs 1.4 s for 39 s of audio).
4. **Header art change**: the regenerated header (other session) changes art and width inside the slot; geometry crops follow it. S1 does not wait for that session: the page-end headers of the 18 surahs currently show empty ترتيبها/آياتها ovals (generator bug, reported), an accepted known defect in shared cards for those surahs until the regenerated art lands.
5. `pro_video_editor` releases often (5 in 10 days); keep the exact pin.
6. **Media3 lift**: S2 moves the app's recitation player (just_audio) from Media3 1.4.1 to 1.11.1. The spike only checked playlist play and seek; audio_service, the media notification, audio focus and downloads were not exercised. Covered by the S2 QA list in §6.
7. **Very tall cards**: a picture taller than the GPU texture limit can fail or come back blank on low-end phones; §3.2 caps the export at 4096 px by scaling.

## 8. Builder's latitude

Exact widget composition of the sheet, swatch visuals, the «نص فقط» icon, copy wording (Arabic first, English literal), file names inside the listed folders, test file layout, and whether S1 hides or omits the reel segment.

## 9. Follow-ups (not in this build)

- Hand the bounds fix to the header session: snap tolerance (`_horizontalSnapTolerancePx = 60`, `test/tools/generate_mushaf_assets_test.dart:89`) and rect boundaries that cut rosettes. Once regenerated bounds land, delete the correction rules from `mushaf_grid.dart`.
- Let `AyahStrip` use `mushaf_grid.dart`'s edges and accent rule (it probably shows the same rosette slivers).
- The surah-header regeneration plans an optional `"headers": [{"surah","x","y","w","h"}]` array in regenerated bounds JSON. Once it lands on `main`, read it when present and keep the grid + bbox scan as the fallback.
- Pass `sharePositionOrigin` in `HadithView._onShare` too.

## Appendix A. Prototype-calibrated constants (source of truth until encoded in seam 1–2 tests)

All in page px unless marked card px. `W = 1080`, margin `M = 72` (card px).

| Rule | Constant |
|---|---|
| Text scale | `s = (W − 2M)/COL ≈ 0.768`; row pitch `p = LH·s ≈ 130.1` card px |
| Outer edge pad (rule 1) | 48 |
| Source rows (rule 2) | cell `[y, y+LH]`, grid line 0 `[y+h−LH, y+h]`; ink `[band.top−60, band.bottom+60]` masked by `keepLineInk` (alpha > 0, 8-connected components; starts > 25 above a band edge → line above, ends > 10 below it → line below, otherwise the nearest decided component) |
| Rosette tail (rule 3) | core width < 100; refit when the widest row > 1.02·`COL`, then `s = (W−2M)/widest` |
| Accent interior edges (rule 4) | extend 28 left; clear the rightmost 28 |
| Header band (rule 6) | `[floor(TOP+idx·LH)−3, floor(TOP+(idx+1)·LH)+3]`, bbox at alpha > 8; scale `hs = min(s, (W−112)/bboxWidth)`; top padding 72; gap after `0.55·p` |
| Basmala (rule 6) | scale `0.78·s`; opacity `min(1, 0.42·255/peakAlpha)` of the ink colour; gap after `0.45·p` |
| Height (rule 7) | bottom padding 80; minimum `0.62·W ≈ 670`; with header and basmala `≈ 498 + 130.1·rows` |

## Appendix B. Plugin call shapes (S2, from the spike)

- Pass 1: `renderStopMotionToFile(silentPath, StopMotionRenderData(frames: [StopMotionFrame(image: EditorLayerImage.file(frame), duration: …)…], frameRate: 5, resolution: Size(1080, 1920), fit: StopMotionFit.cover))`.
- Pass 2: `renderVideoToFile(outPath, VideoRenderData(videoSegments: [VideoSegment(video: EditorVideo.file(silent))], audioTracks: [VideoAudioTrack(path: mp3_j, startTime: o_j)…], shouldOptimizeForNetworkUse: true))`.
- Durations: `ProVideoEditor.instance.getMetadata(EditorVideo.file(mp3))`, `audioDuration` falling back to `duration`. iOS measures 45–55 ms shorter than Android for the same file, so measure on the rendering device.
- Progress per pass from `progressStreamById(id)`; cancel with `ProVideoEditor.instance.cancel(id)`; a cancelled render completes with `RenderCanceledException`.
