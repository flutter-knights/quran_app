# Ayah share «مشاركة الآية»: build spec

Date: 2026-11-23. Owner brief: share an ayah as an image that looks like the printed mushaf (reference: a cream card with the ornamented surah-name frame, a faded basmala, the ayah in the mushaf's own printed lines ending in its numbered rosette); optionally add Tafsir al-Muyassar under the ayah in slightly smaller text that shrinks to fit; and share the card with the recitation as a short video ("reel"). The owner asked for the best choice on reel scope and delegated every other decision. Builds run in the worktree `/Users/sameh/Documents/flutter_projects/quran_app-ayah-share`.

Evidence behind this spec (local scratch, not committed): a feasibility study and a recon run, including a Python prototype of the card that renders every edge case from the bundled assets (`…/scratchpad/recon/card_proto.py`) and a build spike of the video package on this toolchain (`…/scratchpad/recon/video/`). This spec restates everything a builder needs; it does not depend on those files.

## Problem, goals, non-goals

Problem: today the only share is plain text (`AyahStudyLeaf._share`, `lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart:207`), and it even repeats the basmala in front of ayah 1. People share ayat as images and short videos, so the app sends them elsewhere.

Goals:
1. **Image card**: one ayah drawn from the mushaf's own page images, with the surah frame and faded basmala, in the reader's paper colours.
2. **Tafsir card**: the same card with Tafsir al-Muyassar under the ayah, in a smaller text size that steps down further for long tafsir.
3. **Reel**: a 1080×1920 MP4 of one or more consecutive ayat, each ayah's card shown while the current reciter recites it.
4. A share sheet with a live preview that is pixel-identical to what gets shared.

Non-goals: translations on the card; word-by-word; custom backgrounds or photos; choosing a reciter inside the share sheet (it uses the reader's reciter); saving to the photo gallery (the OS share sheet already offers "Save image"/"Save video"); direct Instagram/TikTok SDK integrations; fixing `AyahStrip`'s rosette slivers (follow-up, see §9).

Anti-goals (a failure even if it works): a card that does not look like the printed mushaf; text rendered in a fallback font instead of the page glyphs; a share that blocks the reader or freezes the UI; a reel whose audio drifts from the card.

## 0. Decisions taken by default (owner delegated all)

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | How the ayah is drawn | **Crop the bundled page PNGs** (`assets/mushaf/pages/page_NNN.png` ink + `page_NNN_accent.png` accent) using the bounds JSON, never typeset text. | Owner picked the printed-mushaf look. The runtime text is Tanzil "Simple" spelling, not Uthmani, and the 604 QCF page fonts are not bundled. The prototype matches the reference. |
| D2 | Surah frame and basmala | Cropped at runtime **by grid geometry** from the surah's start page, trimmed to the band's alpha bounding box. No hard-coded art, widths or positions of today's frame. Basmala opacity is normalised from the crop's peak alpha. | Another session is regenerating the header art (narrower frame, semi-transparent basmala). Geometry-based crops pick up the new art with no code change, and the basmala must not fade twice. |
| D3 | Tafsir size | Tafsir text one token smaller than the study leaf body; for long tafsir it steps down once more (§3.4). The image card grows in height to fit the whole tafsir; nothing is cut in the image. | Owner: "shrink or make tafsir text be small some bit". |
| D4 | Reel scope ("show the best") | Start ayah = the selected ayah. The user can extend to the following ayat of the same surah with a stepper, up to **10 ayat and 60 s of audio** (whichever comes first). Each ayah shows its own card while it is recited. Basmala audio (1:1) plays before ayah 1 of every surah except 1 and 9, over the first ayah's card. Default = 1 ayah. | One ayah covers most shares; short runs (e.g. 2:255–257, Al-Ikhlas) are what people post. 60 s keeps the file accepted by Instagram Reels/Stories (via the share sheet), WhatsApp Status, and TikTok. |
| D5 | Video engine | **`pro_video_editor: 2.54.0`, pinned exactly** (BSD-3, uses Media3 on Android and AVFoundation on iOS, no native FFmpeg). | Spike on this toolchain: Android debug + release and iOS device + simulator builds pass with no Gradle changes; all `androidx.media3` modules resolve to 1.11.1 (just_audio's 1.4.1 is lifted) and just_audio playlists still play and seek; +0.63 MB arm64 APK. FFmpegKit is discontinued; its forks add 8–15 MB. |
| D6 | Entry points | (a) The study leaf's share button (`ayah_study_leaf.dart:94-96`) opens the share sheet instead of sharing text. (b) A «مشاركة» item in the saved-ayah row menu (`PlaceRowMenu`, used by the Bookmarks page and the «أماكني» sheet). The quick panel (`AyahLeaf`) gets nothing. Ayah 0 (the banner) never offers share. | Spec 2026-11-21 placed share in the study header on purpose; a fifth quick-panel tile would crowd the row. Saved ayat are ayat people want to pass on. |
| D7 | Plain text share | Kept as a secondary «نص فقط» button in the sheet; the basmala-in-front-of-ayah-1 bug is fixed (strip the basmala prefix for surahs 2–114 except 9; keep 1:1 as is). | Some chats prefer text; the bug is the same one the card must avoid. |
| D8 | Paper | The card uses the reader's paper (`SettingsCubit.state.settingsModel.mushafPaper.colors`). The sheet offers the six papers as swatches; the choice is ephemeral (not persisted). | Matches what the user is reading; night papers make dark cards. |
| D9 | Attribution | Image card: no footer (matches the reference). Tafsir card: the heading «التفسير الميسر» above the tafsir. Reel: a small footer line with the reciter's name and the ayah reference. | Quran Foundation terms ask for credit on social videos; the reference image has no footer. |
| D10 | Ship order | Two slices, two PRs. **S1** image + tafsir card + sheet + entry points (PR into `main`). **S2** reel (stacked PR into S1's branch). The owner merges both. | S1 is useful alone and carries no new dependency; S2 adds the video package and an iOS Info.plist key. |
| D11 | Localization | New strings go in both ARBs and in `lib/core/localization/pending_s.dart` (`PendingS`), used through `PendingS.of(context)` / `PendingS.current`; `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`, never run `intl_utils:generate`. | `lib/generated` regenerates only on IDE save (precedent: Leaf & Ribbon build). |

## Alternatives considered

| Decision | Rejected option | Trade-off |
|---|---|---|
| D1 ayah drawing | Typeset with Amiri / Scheherazade New | Flexible line breaks, but "Simple" spelling (not Uthmani), never rendered-checked, and does not look like the reference. |
| D1 | Reuse `AyahStrip` as is | Caps at 3 lines (642 ayat need 4–15), paints only the ink layer (no rosettes), one page only (no header/basmala), and slices rosettes at ayah boundaries. |
| D2 | Draw the frame with a Dart painter | The other session may publish one later (`surah_frame_painter.dart`, not final); waiting would block S1. Crops follow the art automatically. |
| D5 video | `ffmpeg_kit_flutter_new_min` 4.0.0 | LGPL, +8–15 MB per platform, fresh fork; kept as the fallback if `pro_video_editor` regresses. |
| D5 | Native AVAssetWriter + MediaCodec via Pigeon | Most control, but two native code bases to maintain for one feature. |
| D4 | Single ayah only | Simpler, but short runs are the common reel and the package syncs per-ayah tracks exactly. |
| Preview surface | A new route | Every mushaf overlay is a modal sheet; a sheet also works from the Bookmarks page without touching the router. |

## 1. Glossary

- **Share card**: the image of one ayah (optionally with tafsir) at 1080 px width.
- **Card layout**: the pure geometry that turns bounds rects into source/destination slices for the header, basmala and ayah rows.
- **Header slot**: the grid band holding a surah's frame; **basmala unit**: the `ayah: 0` entry of a surah start.
- **Row**: one printed mushaf line (or the part of it that belongs to the ayah) placed on the card.
- **Rosette**: the ayah-end number medallion, drawn in the accent layer.
- **Reel**: the MP4 made of one share card per ayah, each held for its ayah's recitation.
- **Reel segment**: one ayah in a reel: its card image, its audio file(s), and its duration.

## 2. Asset facts the layout relies on (verified against all 604 bounds files)

- Page PNGs are 1536×2795 RGBA alpha masks (black RGB). The **ink** layer holds text, basmala, the surah name and the oval label text; sajda/hizb marks are inside glyphs. The **accent** layer holds only the header frame and the rosettes.
- Generator grid (`test/tools/generate_mushaf_assets_test.dart:54-61, 145-151`): `pageH = 2795.52`, `TOP = 0.058·pageH = 162.14 px`, line height `LH = pageH·(1−0.058−0.033)/15 = 169.41 px`, 15 lines; line *i* spans `[TOP+i·LH, TOP+(i+1)·LH]`. A bounds rect's grid line is `round(((y+h)·2795 − TOP)/LH) − 1`. Rect tops sit ~20 px below the grid on line 0 (that rect is trimmed, h≈0.057) and 4–9 px below on other lines.
- No ayah spans two pages. Lines per ayah: max 15 (2:282, page 48); 642 ayat have 4+ lines.
- Every surah except 1 and 9 has exactly one basmala unit (one centred rect, same page as ayah 1). Surah 1's basmala is ayah 1 itself; surah 9 has none.
- The header slot is the grid line above the basmala unit (above ayah 1 for surahs 1 and 9). For 18 surahs (4, 10, 22, 23, 24, 26, 27, 32, 33, 37, 38, 45, 47, 53, 60, 64, 65, 80) the basmala is on grid line 0 and the header is on the **previous page, grid line 14**. A page can hold several headers (e.g. 602); pick by the surah's own basmala/ayah 1.
- Rosettes: the rosette is the last glyph of the ayah, inside its last-line rect at the RTL end. In 1,103 places the boundary between two ayat cuts a rosette by up to 24 px (a sliver of the previous ayah's rosette appears at the right edge of the next ayah's first rect). 24 same-line rects overlap by up to 60 px (generator edge snap). 570 ayat end on a line holding only the rosette (a rect 50–90 px wide).
- The header frame's top rule can bleed one pixel row into the rect of the line above it (e.g. 4:176 on page 106).

## 3. The share card (S1)

### 3.1 Layout (pure geometry, `share_card_layout.dart`)

Card width `W = 1080`, side margin `M = 72`. Text scale `s = (W − 2M)/(0.7932·1536) ≈ 0.768`; row pitch `p = LH·s ≈ 130.1`.

Ayah rows:
1. Take the ayah's line rects in order. On each line, horizontal edges are **overlap-aware**: if a neighbour rect on the same line overlaps, trust the narrower rect and clip the wider one at its edge.
2. Source rect per line: x from those edges, outer edges (no neighbour on that line) padded 48 page px; vertical `[y, y+LH]`, except grid line 0 which uses `[y+h−LH, y+h]`.
3. A **rosette-only tail** (core width < 100 page px on the ayah's last line) is moved onto the left end of the previous row instead of standing on its own row. If the widest row then exceeds 1.02 column widths, use `s = (W−2M)/widest` for the whole card.
4. Accent (rosettes) is drawn only on the ayah's last row, with source rows clamped to that line's grid band. If that row's left edge is interior (a neighbour follows), extend the accent crop 28 page px left (the own rosette's bleed); if its right edge is interior, clear accent in the rightmost 28 page px (the foreign sliver). Body ink is never extended.
5. Rows stack at `rowIndex·p` with no extra gap, right-aligned to `W−M` (a partial first or last fragment stays right-aligned, reading as a continuing RTL paragraph). A single-row ayah is centred. On pages 1–2 (centred layout) every row is centred.

Header: band `[floor(TOP+idx·LH)−3, floor(TOP+(idx+1)·LH)+3]` on the header page, tightened at runtime to the alpha>8 bounding box of max(ink, accent). Scale `hs = min(s, (W−112)/bboxWidth)`, centred, top padding 72, then a gap of `0.55·p`.

Basmala (skipped for surahs 1 and 9): the basmala unit's rect, ink layer only, scale `0.78·s`, centred, drawn at opacity `min(1, 0.42·255/peakAlpha)` of the ink colour, then a gap of `0.45·p`.

Bottom padding 80. Minimum card height `0.62·W`, content centred vertically when shorter. Height with header and basmala ≈ `498 + 130.1·rows` (1 row 628, 3 rows 888, 15 rows 2450).

The layout function is pure Dart over `NormalizedRect` lists and a page size; it returns slices (src/dst rects per layer and page) and the total height. Header bounding-box trimming needs pixels, so it is a separate step in the renderer that returns a src rect the layout consumes.

### 3.2 Rendering (`share_card_renderer.dart`)

- Decode one page image at a time at full 1536 px (no `ResizeImage`), crop the needed regions into small `ui.Image`s (`PictureRecorder` → `toImage`), dispose the full page, then compose. At most three pages are touched (ayah page, header page, basmala page; the header page differs from the basmala page for the 18 surahs above). Peak memory ≈ one decoded page (17 MB) plus crops.
- Compose on a `PictureRecorder` canvas: paper background, ink crops tinted with `ColorFilter.mode(colors.ink, BlendMode.srcIn)`, accent crops with `colors.accent`, then the tafsir block. Export PNG bytes (`toByteData(format: png)`).
- The preview draws the same composed `ui.Image` scaled to the sheet width, so preview = output.
- Text (tafsir heading and body) is laid out at a **logical width of 360** with `TS.*` tokens and drawn under a canvas scale of `W/360 = 3`, so no `fontSize:` is added (the typography ratchet is at its cap). Page crops are drawn under the same transform at their real resolution.
- Image loading goes through an injectable loader (`Future<ui.Image> Function(String asset)`) so tests can pass small synthetic images.

### 3.3 Card content (domain)

`GetShareCardContent(ayah)` returns a `ShareCardContent`: the ayah identifier, its page and line rects, the header page and header grid line index, the basmala rect and page (or null), and an optional tafsir text. It uses `GetMushafPage` for the bounds (up to three pages), `QuranPageService.getPageForAyah`, and `GetAyahTafsir` with its own `CancelToken`. A tafsir failure still returns content with `tafsir: null` and a `tafsirFailed` flag. Only Al-Fatiha 1:1's tafsir starts with a surah introduction («سورة الفاتحة سميت…»); strip that one prefix.

### 3.4 Tafsir block

Below the ayah: a thin accent rule with a small centred diamond (like `OrnamentDivider`), the heading «التفسير الميسر» in `TS.bold14` (accent colour), then the tafsir body right-aligned, RTL, in the paper ink at reduced emphasis (ink with alpha ~0.85). Body token: `TS.regular14` with height 1.8 (one step below the study leaf's `TS.regular16`). If the tafsir is longer than 600 characters, use `TS.regular12` with height 1.8 instead. Side margins equal `M`. The image card grows to fit the full text.

### 3.5 Share sheet (`AyahShareSheet`)

A modal bottom sheet (`showModalBottomSheet`, `showDragHandle`, `isScrollControlled`, `useSafeArea`, surface `context.colorScheme.surface`) with a static `show(context, {required AyahIdentifier ayah})`, creating its own `AyahShareCubit` (`registerFactoryParam` keyed by the ayah). Top to bottom:

1. Live preview of the card (scrolls if tall), on a subtle paper-edge shadow (`context.cardShadow()`); the shadow is preview-only, not in the PNG.
2. `AppSegmentedSelector`: «صورة» / «مقطع بالتلاوة» (S2 adds the second segment; S1 ships the selector with the image option only or hides it — builder's call, but no dead control).
3. `AppSettingsTile` with a switch: «إضافة التفسير الميسر», default **off**. When the tafsir failed: subtitle `tafsir_loadFailed` and a retry; image share stays enabled.
4. Six paper swatches (round dots in each paper's background with an ink ring), default the reader's paper.
5. `ActionButtonsRow`: `ActionBtn.primary` «مشاركة» and `ActionBtn` «نص فقط».

Loading: a paper-coloured placeholder card inside `Skeletonizer` while content and the first render are prepared. Re-render after a toggle shows a slim `LinearProgressIndicator` over the visible preview (the loading-states exception) and disables the buttons. Errors: render failure → inline message + retry; share sheet throws → SnackBar `S.share_failed`. The share call runs in the sheet's `BlocListener` (cubits never touch `BuildContext`) and passes `sharePositionOrigin` from the button's `RenderBox` (iPad). The PNG goes out as `XFile.fromData(bytes, mimeType: 'image/png', name: 'ayah_<s>_<a>.png')` with the text `ayah_label` («سورة الأنعام، الآية ٣١») as the share text.

### 3.6 State

`AyahShareCubit` with one Equatable state object (`copyWith`): `status` (loading | ready | failed), `content`, `includeTafsir`, `paper`, `format` (image | reel), `reelCount` (S2), `export` (idle | rendering | encoding | done | failed), `progress` (S2), `cardBytes`, `error`. Every `emit` after an `await` is guarded by `if (isClosed) return;`.

## 4. The reel (S2)

### 4.1 Composition

- Canvas 1080×1920 in the card's paper colour. The card (with tafsir if switched on) is centred vertically; if taller than 1920 − footer, it is scaled down to fit (only 2:282 and one 11-row ayah exceed 1799 px without tafsir). On the reel, tafsir longer than what fits is cut at a line boundary and ends with «…».
- Footer, bottom-centred, ~0.7 of the tafsir body size, ink at reduced emphasis: «<reciter name> · <surah> <first>–<last>» with Arabic-Indic digits.
- One frame image per ayah, written to `getTemporaryDirectory()/ayah_share/`.

### 4.2 Audio

- `prepareAyahAudio(ayah, reciter)` per ayah (a prepare-only use case `PrepareAyahAudio` wraps the repository; the existing `PlayAyahUseCase` also plays and must not be used). Downloaded or cached surahs work offline.
- Basmala 1:1 audio is prepended before ayah 1 when the surah ∉ {1, 9}, shown over the first ayah's card.
- Durations come from `ProVideoEditor.instance.getMetadata(EditorVideo.file(mp3))` (`audioDuration`, falling back to `duration`), measured on the device that renders.
- Never join MP3 files byte-for-byte (the joined file reports the first file's duration).

### 4.3 Encoding (`ReelComposer`)

- Domain interface `ReelComposer` with `Future<Either<Failure, String>> compose(ReelRequest request)` plus a progress stream and `cancel()`; data implementation `ProVideoReelComposer` over `pro_video_editor`.
- Two passes: `renderStopMotionToFile(silentPath, StopMotionRenderData(frames: [StopMotionFrame(image: EditorLayerImage.file(card_i), duration: dur_i)…], frameRate: 5, resolution: Size(1080, 1920), fit: StopMotionFit.cover))`, then `renderVideoToFile(outPath, VideoRenderData(videoSegments: [VideoSegment(video: EditorVideo.file(silent))], audioTracks: [VideoAudioTrack(path: mp3_j, startTime: offset_j)…], shouldOptimizeForNetworkUse: true))`. Delete the silent file and frame PNGs afterwards; delete previous reels when a new share starts.
- **iOS**: a single still becomes a one-frame MP4, so on iOS each card is repeated as a frame every 1 s (uniform 30 fps track). Android uses frameRate 5 (frameRate 1 overruns the audio by ~0.45 s).
- Output: H.264 + AAC MP4, `moov` first. Android stores 1920×1080 with a 90° rotation flag (players show it upright).
- Progress from `progressStreamById(id)`, shown in the sheet with a cancel button (`ProVideoEditor.instance.cancel(id)`).
- Share as `XFile(path, mimeType: 'video/mp4')`.

### 4.4 Reel controls in the sheet

When «مقطع بالتلاوة» is selected: a stepper «عدد الآيات» (− n +), disabled at the surah end, at 10, or when the next ayah would push the audio past 60 s (the count is checked after durations are known; if the cap is exceeded after preparing, the last ayah is dropped and a short notice says why). A caption with the reciter name. Audio download failure → SnackBar «تعذّر تحميل التلاوة» and the image option stays available.

### 4.5 Platform

- `pubspec.yaml`: `pro_video_editor: 2.54.0` (exact). No Gradle changes (Media3 resolves to 1.11.1 everywhere).
- `ios/Runner/Info.plist`: `NSPhotoLibraryUsageDescription` (the plugin links PhotoKit; App Store Connect rejects the build without the key even though the app never prompts). Text: "Used only if you choose to save a shared ayah video." Run `pod install` so `ios/Podfile.lock` is updated and committed.

## 5. Feature placement and seams

New feature `lib/features/ayah_share/` (rule: one feature folder per capability; it orchestrates surah, tafsir, quran_playback and settings).

```
lib/features/ayah_share/
├── ayah_share_di.dart                 initAyahShare(), after initMushaf/initTafsir/initPlayback
├── domain/
│   ├── entities/share_card_content.dart
│   ├── entities/reel_request.dart     (S2)
│   ├── repositories/reel_composer.dart (S2)
│   └── usecases/get_share_card_content.dart, prepare_ayah_audio.dart (S2), compose_ayah_reel.dart (S2)
├── data/repositories/pro_video_reel_composer.dart (S2)
└── presentation/
    ├── cubit/ayah_share_cubit.dart, ayah_share_state.dart
    ├── utils/share_card_layout.dart, share_card_renderer.dart, reel_frame_painter.dart (S2)
    └── widgets/ayah_share_sheet.dart, share_card_preview.dart, paper_swatches.dart
```

- Use cases, renderer and composer: lazy singletons. Cubit: `registerFactoryParam<AyahShareCubit, AyahIdentifier, void>`.
- `feature-widgets.md` gets an exception line: "ayah_share exports `AyahShareSheet` (opened by surah's study leaf and bookmarks' saved rows); it takes the ayah by constructor and reads paper and reciter from `SettingsCubit`."
- `ayahShareText` moves to `lib/features/ayah_share/presentation/utils/ayah_share_text.dart` with the basmala fix (D7); `ayah_study_leaf_test.dart:280-335` is rewritten for the new behaviour (the share button opens the sheet; text share is tested in the sheet).

Seams = plan task boundaries (carry these into the plan, in this order):

| Seam | Slice | Testable alone by |
|---|---|---|
| 1. Grid + header/basmala lookup over bounds (`share_card_layout.dart` part 1) | S1 | unit tests over real bounds JSON: the 18 previous-page headers, surahs 1 and 9, page 602 |
| 2. Row layout: overlap-aware edges, rosette tail merge, accent rules, alignment, heights | S1 | unit tests: 6:31, 2:282 (15 rows), 91:10/91:11 overlap, 16:127 tail, a single-row ayah, pages 1–2 centred |
| 3. Domain content + use case (`ShareCardContent`, `GetShareCardContent`, tafsir prefix strip) | S1 | use case tests with fake repos, tafsir failure path |
| 4. Renderer (crops, header bbox trim, basmala alpha normalisation, tafsir block, PNG export) | S1 | `tester.runAsync` with synthetic images via the injected loader; recording-canvas painter tests |
| 5. Cubit + state | S1 | bloc tests with fakes |
| 6. Sheet + preview + swatches + text share move + entry points (study leaf, saved-row menu) + strings + DI + feature-widgets.md line | S1 | widget tests with the share MethodChannel mock and `GetIt` stubs |
| 7. Package + platform (pubspec, Info.plist, Podfile.lock) + `ReelComposer` interface + data impl | S2 | unit tests of the request→render-data mapping (plugin behind a thin adapter that tests replace) |
| 8. Reel frames (1080×1920 painter, footer, tafsir cut) + `PrepareAyahAudio` + durations + basmala prepend + caps | S2 | unit/painter tests |
| 9. Sheet reel mode (selector, stepper, progress, cancel, share) | S2 | widget + cubit tests |

## 6. Tests and verification

- Unit tests read the real bounds JSON from disk (precedent: `test/tools/verify_mushaf_assets_test.dart`); add a corpus test that lays out all 6,236 ayat and asserts: no exception, every height finite, max rows 15, header found for all 114 surahs.
- No golden tests (repo convention).
- `flutter analyze --no-fatal-infos` and the full `flutter test` stay clean against `main`; the typography ratchet must not rise.
- Manual QA (S1 and S2 PRs): emulator-5554 screenshots of the sheet and shared files for 6:31, 1:1, 2:255, 2:282 with tafsir, 9:1, 4:1 (previous-page header), one night paper. The spike replaced the real app on emulator-5554 and the iPhone 17 Pro simulator: reinstall before QA.

## 7. Risks and open items for the owner

1. **Tafsir licence**: no public grant to redistribute Tafsir al-Muyassar text (Tanzil: non-commercial; King Fahd Complex: no statement found). The tafsir card puts it in shared images. Ship decision is the owner's; the switch defaults to off.
2. **Reciter audio terms**: audio comes from `mirrors.quranicaudio.com`, probably under Quran Foundation terms, which allow user shares of short clips with credit (the reel footer credits the reciter). The terms also cap automatic caching at 1 week; the existing playback cache keeps files forever (pre-existing, out of scope).
3. **Real-device speed**: emulator renders took 8 s for a 45 s range at frameRate 5 with a software encoder; real phones were not measured.
4. **Header art change**: the regenerated header (other session) changes art and width inside the slot; geometry crops follow it. Page-end headers of the 18 surahs currently show empty ترتيبها/آياتها ovals (generator bug, reported to that session).
5. `pro_video_editor` releases often (5 in 10 days); keep the exact pin.

## 8. Builder's latitude

Exact widget composition of the sheet, swatch visuals, copy wording (Arabic first, English literal), file names inside the listed folders, test file layout, and whether S1 hides or omits the reel segment.

## 9. Follow-ups (not in this build)

- Apply the overlap-aware edges and accent rules to `AyahStrip` (it probably shows the same rosette slivers).
- A bounds `header` unit emitted by the generator would replace the runtime bbox scan.
- Pass `sharePositionOrigin` in `HadithView._onShare` too.
