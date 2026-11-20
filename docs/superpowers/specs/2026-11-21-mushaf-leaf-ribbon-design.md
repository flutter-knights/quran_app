# Mushaf reader «الورقة والشريط» (Leaf & Ribbon): build spec

Date: 2026-11-21. Owner brief (verbatim intent): build the final design from the v2 design run, fix every known bug in the reader, tell the user clearly how to download a surah, add a media notification for the current recitation, re-tune the paper colours to look like a real printed mushaf, review whether the design is the best for users, QA it, and take every default decision without asking.

Design source (gitignored, local only, optional reference): `/Users/sameh/Documents/flutter_projects/quran_app/docs/design-audit/mushaf-v2/reading/final-spec.md`, `final-reading.html`, `final-sheets.html`, `.../mushaf-v2/_docs/contract.md` §6–8, `.../mushaf-v2/_research/00-current-screen-audit.md` (the bug ledger, verified at `d6431167` = today's `main`). Builds run in this checkout so the files are reachable; this spec restates everything a builder needs, and where it and the design files disagree, this spec wins.

## Problem, goals, non-goals

Problem: the reader hides its controls behind taps, loses the player on page turns, names the wrong surah on 64 of 114 surahs, plays past range ends, fails silently offline, overwrites the reading position on every peek, and offers no download, media control, or meaning of an ayah.

Goals: fix the 20 ledger bugs; always-visible chrome; one labelled leaf for every ayah action; recitation with a media notification that outlives the screen; a visible, explained surah download; three named فواصل plus saved ayat; Tafsir al-Muyassar in the leaf; papers that read like print.

Non-goals: wird plans, page zoom, translation, word meanings, notes (D4); reflowed text; word tap; sajda markers; moving the audio cache out of the documents directory; a page-bookmark control after S3 (§5).

## 0. Decisions taken by default (owner delegated all)

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Tafsir source | **Online with a Hive cache**: `GET https://api.alquran.cloud/v1/page/{p}/ar.muyassar` (verified live 2026-11-21; `data.ayahs[]` carry `surah.number`, `numberInSurah`, `text`) fills the cache for a whole page in one call when the leaf opens. A missing ayah falls back to `GET /v1/ayah/{s}:{a}/ar.muyassar`. Offline and uncached → inline message + retry, never a dead end. | No licence for bundling can be obtained tonight; one call per page keeps load low. Bundling stays a later swap behind the same repository. |
| D2 | Ship order | Five slices in order, each its own PR, stacked so the next slice builds on the previous one: **S1** logic bugs + paper colours → **S2** listening → **S3** reader shell, ayah leaf, player leaf, القائمة, العرض → **S4** فواصل, saved ayat, أماكني, migration → **S5** tafsir. The builder opens each PR when analyze and test are clean and stops; **the owner merges** (CLAUDE.md). | Each PR is a finished, reviewable slice if the night runs out. |
| D3 | First tap for existing users | «المعنى» (the compact leaf with a tafsir line) for everyone. Until S5 lands the compact leaf shows no tafsir line and no «قريبًا». The «الخيارات» setting hides the line. | The design's core; the leaf is labelled, so change aversion is low. |
| D4 | Wird plans, page zoom, translation, word meanings, notes | Not built. S5 shows them as a static row of disabled chips with a quiet «لاحقًا» badge. Zoom is dropped from «العرض». | Spec marks wird phase 2; zoom fixes no reported bug. |
| D5 | Audio after leaving the reader | **Keeps playing** with the media notification; stopped by «إنهاء التلاوة», the notification's stop, or the app being killed. | Media control only makes sense if audio can outlive the screen. |
| D6 | «تنزيل السورة» | Downloads every ayah of a surah (plus 1:1 for the basmala when the surah ∉ {1, 9}) for the **current reciter** into the existing audio cache, with progress, cancel, delete, and a «محفوظة للاستماع دون إنترنت» state. Entry points: S2 the surah index tile + a one-time SnackBar hint; S3 adds the player leaf chip and the «القائمة» surah row. | The owner asked that users *know how* to download; S2 is usable on its own. |
| D7 | Paper colours | Re-tuned to printed-mushaf references (§2). The six enum cases and their persisted names do not change. | Persisted setting. |
| D8 | Localization | New strings go in both ARBs **and** in `lib/core/localization/pending_s.dart` (`PendingS`); use `PendingS.of(context)` / `PendingS.current`. `test/core/localization/pending_s_test.dart` accepts only `String get x => _ar ? '…' : '…';` and methods whose parameters are all `String` (format numbers before passing them, e.g. «جارٍ التنزيل ٤٠٪» takes a preformatted percent). English values are literal translations written by the builder. Never edit `lib/generated/`, never run `intl_utils:generate`. | `lib/generated` is regenerated only by the IDE extension. |

## Alternatives considered

| Decision | Rejected option | Trade-off |
|---|---|---|
| Reader layout (design run v2) | Variant C (dock) / E (full sheet) / today's hide-on-tap | C shrinks the page 26–45 %; E shrinks it up to 61 % and has no page-turn buttons; hide-on-tap is the source of bugs 2, 4 and the "where are the controls" audit finding. |
| Ayah actions | Keep `AyahActionPopover` / a modal sheet | The popover floats over text and tracks `highlightedAyahCenterY` (fragile on scale); a modal sheet blocks page turns while an ayah is open. |
| Tafsir (D1) | Bundled Muyassar JSON / quran.com API | Bundling: licence unresolved (contract §8.3) and ~3 MB in the APK; quran.com needs a client id and returns HTML. |
| Background audio (D5) | `just_audio_background` / stop on leave | `just_audio_background` owns the player and fights the existing shared player and adhan service; stopping on leave makes a media notification pointless. |
| Bookmarks (S4) | Extend the two `Box<List>` boxes | Bare `'s:a'` strings and page ints cannot carry slot, name or dates; one typed box with one migration is simpler than two schema bumps. |
| Page bookmarks (S4) | Keep a `kind: page` record | Nothing would create one after migration; a saved ayah at the page's first ayah reopens the same page. |
| State (§3.7) | Keep `highlightedAyah` doing selection + focus + playing | That coupling is bugs 4 and 5. |
| فواصل on the page | A bookmark icon in the top bar | An icon cannot show three positions at once; ribbons show where each فاصل is without a tap. |

## 1. Bug ledger (each gets a failing test first)

Slice: items 1–17 and 20 are **S1**; 18–19 are **S4**. S1 keeps today's widgets (`MushafTopBar`, `MushafBrowseBar`, `AyahPlaybackOverlay`, `AyahActionPopover`, `PageJumpSheet`) and fixes them in place; it builds no S3 widget.

1. Running head / top bar names the previous surah on 64 of 114 surahs. Rule: the surah of the selected or playing ayah on this page, else `openedSurah` (§1A) when it is on this page, else the surah with the most bounds lines on the page (tie: the earlier surah). Pure `resolveRunningSurah` over the page's bounds JSON (ayah > 0 only, never `pageData`: it lists phantom next-surah headers on 18 pages). Tests: p.293 opened الكهف → «الكهف»; p.604 → «الناس»; p.106 (4:176 then 5:1–2) nothing opened → «المائدة»; p.76 (3:195–200, phantom header) → «آل عمران»; p.207 (9:123–129) → «التوبة».
2. Player close does not stop audio. There is an explicit «إنهاء التلاوة» that calls `stop()`; the overlay shows while `PlaybackState.requestedAyah ?? currentAyah` is non-null, so hiding it while audio plays is impossible (the test at `ayah_playback_overlay_test.dart:206-221` that pins the bug is rewritten deliberately).
3. «تشغيل السورة» opens with no player and plays past the surah end. It plays the surah as a range (start→last ayah) and the reader shows the player on arrival. `stop()` clears `rangeStart`/`rangeEnd`. `skipNext`/`skipPrevious` clamp to the range when one is set (no-op at the bounds, ⏮/⏭ disabled there); today they call `getNextAyah` with no end and, once outside the range, the exact-equality end check in `aya_sequence_service.dart` never fires.
4. The player disappears at the first automatic page turn. Selection, playing ayah and player visibility are separate state (§3.7 S1 line); a page turn caused by playback never clears them.
5. Pull-back during recitation: auto page-follow happens only while `followPlayback` is true. It becomes false when the reader turns a page by hand away from the playing ayah, and true again on «العودة إلى الآية المتلوّة» or any new play. Pure `nextFollowAction`. S1: state + rule; S3 draws «يُتلى الآن: …، صفحة …».
6. Silent audio errors. `PlaybackState` gains `requestedAyah` (set synchronously in `playSelected`, `playRange` and every `_playAyah` call, so auto-advance and repeats update it; cleared only by `stop()`, which the range end already calls through `PlaybackStepKind.stop`) and a persistent `error`: `copyWith` keeps `error` unless `clearError: true`, which only retry, stop and a new play pass. Error copy names `requestedAyah ?? currentAyah`. The ignored `Either` results of `playPreparedAudio` / `playPreparedAudioSequence` and preload failures for the next ayah feed `error`. Prerequisite: `QuranPlaybackRepoImpl.prepareAyahAudio` removes the `_inFlightDownloads` entry in a `finally` and deletes the partial file on failure (today a failed future stays in the map, so retry fails until restart). Tests: first play fails offline → overlay visible with error; first download fails, retry succeeds. S1 shows the error in a SnackBar with «إعادة المحاولة»; S3 shows it inline.
7. Page jump rejects ٠–٩. One pure top-level `toAsciiDigits(String)` in `core/helper functions/numeral_helpers.dart` folding U+0660–0669 and U+06F0–06F9; `PlaybackRangeValidator.parseCounter` delegates to it. `page_jump_sheet.dart:65` drops `FilteringTextInputFormatter.digitsOnly` for a formatter that allows both digit sets; `page_jump_sheet_test.dart:45-47` is rewritten.
8. Play page on multi-surah pages plays only the first surah's tail (p.106 plays one ayah). Pure `pagePlaybackRange(page)` from the bounds JSON: first ayah > 0 → last ayah, across surahs. `playRange` accepts a cross-surah range (the engine already crosses surahs; the validator's single-surah rule applies to user edits only). When `rangeStart.surah != rangeEnd.surah`, `PlaybackRepeatOptions` shows the range read-only («من النساء ١٧٦ إلى المائدة ٢») and hides the from/to editors. Tests: p.76 → 3:195–3:200, p.106 → 4:176–5:2, p.207 → 9:123–9:129, p.604 → 112:1–114:6.
9. Mini-player title shows the surah number in Latin digits → surah name + Arabic-Indic digits.
10. ⏮/⏭ look enabled but do nothing when idle → disabled when there is no current ayah (and at range bounds, item 3).
11. ∞ repeat cannot target each ayah → the ∞ toggle applies to the counter it sits beside («تكرار كل آية» or «تكرار المقطع» in `PlaybackRepeatOptions`).
12. Ayah 0 (banner/basmala) can be bookmarked and shared → it gets the banner actions only (§3.3); bookmarking and sharing are impossible.
13. A bookmarked ayah reopens without focus → bookmarks pass `MushafArgs(page, focusAyah, origin: jump)`.
14. `PlaybackState` is not `Equatable` → it is.
15. A page-load failure leaves dead taps with no UI → the page shows an inline «تعذّر تحميل الصفحة» + «إعادة المحاولة».
16. Sajda map is wrong in 5 places. **Deferred**: `isSajdahVerse` lives in the vendored `quran-1.4.1/lib/sajdah_verses.dart` and nothing in `lib/` calls it. Fix it with the first sajda marker (positions: 7:206, 13:15, 16:50, 17:109, 19:58, 22:18, 22:77, 25:60, 27:26, 32:15, 38:24, 41:38, 53:62, 84:21, 96:19).
17. Last read is overwritten by any visit. **Guarded** in `LastReadSaver` (no new class): it takes the arrival `origin` (§1A) and an injectable clock. For `jump`, both `schedule()` and `flush()` (page change, app pause, dispose) skip `persist` until the reader turns a page by hand or stays 20 s on one page; playback-driven page turns do not count; an in-place jump (S3 «القائمة», notice chip) re-arms the guard. `normal` writes as today. `persist` also writes `updatedAt` (new `@HiveField(3) DateTime? updatedAt` on `LastReadHiveModel`, typeId 5; old records read null). Tests: dispose-after-jump and pause-after-jump do not write; 20 s dwell writes.
18. (S4) Bookmarks page: no delete in the list and a hard-coded arrow → one row-menu widget «إزالة» with undo in `bookmarks/presentation/pages/widgets/`, `forwardArrowIcon`; S4's saved-ayat rows reuse it.
19. (S4) Terminology drift: «حفظ» / «الإشارات» / «إشارات مرجعية» / «المحفوظات» → «فاصل/الفواصل», «الآيات المحفوظة», «حفظ الآية», «أماكني».
20. The running head shows الحزب, so `QuranMetaService.getPageMeta` must be right first. Its `_rubBoundaries` table is copied from Tanzil, so the oracle is the printed Madinah mushaf: extend `quran_meta_service_test.dart` with the 30 juz-start pages (juz 2→22, 3→42, 4→62, 5→82, 6→102, 7→121, 8→142, 9→162, 10→182, 11→201, 12→222, 13→242, 14→262, 15→282, 16→302, 17→322, 18→342, 19→362, 20→382, 21→402, 22→422, 23→442, 24→462, 25→482, 26→502, 27→522, 28→542, 29→562, 30→582; each juz starts hizb 2·juz−1). The oracle is checked against the bounds JSON: juz 4, 7, 11 and 26 start mid-page (pp. 62, 121, 201, 502), so the test pins the juz-start ayahs (2:142, 2:253, 3:93, 4:24, 4:148, 5:82, 6:111, 7:88, 8:41, 9:93, 11:6, 12:53, 15:1, 17:1, 18:75, 21:1, 23:1, 25:21, 27:56, 29:46, 33:31, 36:28, 39:32, 41:47, 46:1, 51:31, 58:1, 67:1, 78:1) and their pages. The head shows the juz and hizb in effect at the page's last ayah, as the print does. If a mismatch cannot be fixed, the head shows only الجزء.

### 1A. Arrival contract (S1)

`MushafArgs {page, focusAyah?, openedSurah?, origin: normal | jump}`; `_mushafArgsFrom` (both `mushafPath` and `mushafImagePath`) maps a bare `int` to `normal`. `normal` writes last-read as today and selects nothing (the post-frame last-read restore no longer selects the ayah, so no leaf opens on arrival); `jump` selects `focusAyah` when given (S3: with the leaf open) and is guarded (item 17).

| Caller | origin | openedSurah |
|---|---|---|
| Home last-read card, `last_quran_read.dart`, start-reading card | normal | — |
| Surah list tile | normal | that surah |
| Juz list, page grid | normal | — |
| Search results, `ayah_result_tile.dart`, bookmarks, فاصل, tafsir | jump | focus ayah's surah |
| Notification tap (S2) | jump, no `focusAyah` (the player shows, not the ayah leaf) | playing surah |

## 2. Paper colours (S1)

Printed references: the King Fahd Complex Madinah print (warm ivory paper, near-black ink, gilt-and-teal frame), older Egyptian/Shamarly prints (aged paper, brown-black ink), and night reading apps. Pages are two single-tint masks (body = `ink`, frame/rosettes/banners = `accent`) over `background`.

| Paper (name kept) | background | ink | accent | Reference |
|---|---|---|---|---|
| cream «كريمي» | `#FDF7E8` | `#1B1A17` | `#9A7B3C` gilt | Madinah print |
| sepia «سيبيا» | `#F3E6C9` | `#2B2116` | `#8A5A2B` brown-gold | aged print |
| green «أخضر» | `#EEF3E8` | `#18231B` | `#2F6E55` Madinah teal-green | green-frame print |
| gray «رمادي» → shown as «أبيض» | `#FAFAF7` | `#161616` | `#1F5E7A` blue | white offset print |
| night «ليلي» | `#141210` | `#ECE3CF` | `#C9A45A` | night, warm |
| slateNight «ليلي أزرق» | `#0F141A` | `#DCE5EC` | `#6E9CC4` | night, cool |

All hexes and derived tokens live in `lib/features/surah/presentation/utils/mushaf_paper_colors.dart` (a hex file `theming.md` allows): `ink2` (ink at 78 % over background), `leaf` (ink at 6 % over background), and in S4 `ribbon(FasilSlot)`. Paper names move to both ARBs + `PendingS` through a `localized(context)` extension in `lib/features/surah/presentation/utils/enum_localization.dart`; `MushafPaperX.label` is deleted. The gray paper keeps its enum case `gray` and its persisted value.

Gates (a test computes them on every paper): ink on background ≥ 7:1; `ink2` on background ≥ 4.5:1; accent on background ≥ 3:1; with today's `AyahHighlightPainter` tints composited (highlight accent 0.20, playing ink 0.15), ink stays ≥ 4.5:1. If a value misses a gate, the builder nudges lightness only and records the final hex in the PR.

## 3. Reader shell (S3)

The page box keeps the image's true aspect 1536/2795 (no stretch; today's `BoxFit.fill` stretches 5–12 %) and never changes size or position between states or text scales, except the bounded slide in §3.3. Highlights keep today's tint painter.

### 3.1 Running head, 48 px (max 64 at large text), printed on the paper
Start: back (`HugeIcon(backArrowIcon(context))`, tooltip «رجوع», 48 px). Then the surah name per §1.1, `TS.bold16` in paper ink. Centre: the page number inside an eight-point **khatam** (two overlapping squares, one rotated 45°; `KhatamMedallion` `CustomPainter` in paper accent, sized by a `TextPainter`, max 64 px wide), number `TS.bold14` in ink, Arabic-Indic digits. End: «الجزء ٣، الحزب ٥» `TS.medium14` in `ink2`. A double hairline rule in accent under the head. Tapping the surah or juz text opens «القائمة». It replaces `mushaf_top_bar.dart` and, in page mode, the QCF glyph header drawn by `mushaf_printed_chrome.dart` (deleted with `printed_chrome_resolver.dart`).

### 3.2 Foot band, 64 px, on the paper, always visible
`‹` previous page (48 px, start side) · «استماع» (filled, `colorScheme.primary`) · «القائمة» (tonal, `leaf` colour) · `›` next page (48 px, end side; "next" points to the reading direction). Icons are HugeIcons (`backArrowIcon` / `forwardArrowIcon`). Pills ≥ 56 px tall, icon + label `TS.semi14`. A **notice chip** slot floats above the pills, never over text: «العودة إلى صفحة ٥٠» after a jump (until the next manual page turn; tap returns), the first-open hint «اضغط على أي آية لترى معناها وأزرارها» + «فهمت» (once; `hintSeen`), and from S3 the download hint (§4). The foot never hides, so ‹ › and «القائمة» stay reachable while a leaf or the player is up. It replaces `mushaf_browse_bar.dart`. No hide-on-tap state.

### 3.3 Ayah leaf (non-modal, rises above the foot band)
One tap on an ayah selects it and raises the leaf at its **compact detent** (sized by the text scaler, ≈ 168 px at 1×). Long-press does the same. Closing: tap the same ayah, «إغلاق», drag down, system Back, a tap on blank paper; a page swipe closes it too.
- Title row «آل عمران، الآية ٧» `TS.bold16` + «إغلاق» (48 px).
- Action row, labelled columns with hairline separators, «استماع من هنا» the only filled one; a widget test per slice checks the labels are distinct:

| Slice | Columns |
|---|---|
| S3 | «استماع من هنا» · «حفظ الآية» (existing ayah bookmark toggle) · «مشاركة» |
| S4 | «استماع من هنا» · «فاصل» · «حفظ الآية» · «مشاركة» |
| S5 | «استماع من هنا» · «تفسير الآية» · «فاصل» · «حفظ الآية»; «مشاركة» moves to the full detent's header (§6) |

  «مشاركة» shares «نص الآية» + «— سورة آل عمران، الآية ٧» in Arabic-Indic digits.
- One line of tafsir lead ending «…» (S5; hidden when `tapAction` is `options`).
- **Bounded slide**: the page translates up by at most the leaf height only when the selected ayah's bounds would sit under the leaf.
- **Banner (ayah 0)** variant: title «سورة المائدة», caption «مدنية، ١٢٠ آية»; primary «استماع من بداية السورة»; secondary «استماع الصفحة كاملة»; no share, no bookmark, never «الآية ٠».

### 3.4 Player leaf (same slot as the ayah leaf)
Title «آل عمران، الآية ٤» + «القارئ، حتى نهاية السورة» (or «حتى نهاية الصفحة» for a page range). Controls «السابقة» · «إيقاف مؤقت»/«متابعة» (primary, 56 px) · «التالية». Row 2: repeat chip «التكرار: …» (≥ 48 px, opens «خيارات التلاوة»: the reciter and speed pickers extracted from `ayah_playback_overlay.dart` (`_ReciterGrid`, `_SpeedGrid`, `_Chip`) into `lib/features/quran_playback/presentation/widgets/` with tests, plus `PlaybackRepeatOptions`) and «إنهاء التلاوة» (stops). Download chip «تنزيل السورة» → «جارٍ التنزيل ٤٠٪» (tap cancels) → «محفوظة للاستماع دون إنترنت». States: **listening-away** (`followPlayback` false: «يُتلى الآن: آل عمران ١٢، صفحة ٥١» + filled «العودة إلى الآية المتلوّة»); **audio-error** (`Semantics(liveRegion)`): «تعذّر تشغيل الآية ١٣» + «تحقق من الاتصال بالإنترنت، ثم أعِد المحاولة» + «إعادة المحاولة» + «إنهاء التلاوة»; **loading**: a slim progress bar over the leaf (allowed exception in `loading-states.md`).
«استماع» in the foot plays from the selected ayah, else the page's first non-banner ayah (bounds JSON), to the end of that surah; during a recitation it replaces the current one.

### 3.5 «القائمة» sheet (modal, app colours `context.colorScheme`)
Three tiles: «أماكني» (S4; before S4 it opens the existing bookmarks page), «العرض», «استماع الصفحة كاملة». A search field «اسم سورة أو رقم صفحة» accepting ٠–٩ and 0–9 (`toAsciiDigits`, no digits-only formatter) with a live result row («صفحة ٥٨٢، النبأ، الجزء ٣٠» + «انتقال») and inline error «اكتب رقمًا من ١ إلى ٦٠٤». `AppSegmentedSelector` «السور / الأجزاء»; rows ≥ 56 px: number disc, name, «مدنية، ٢٠٠ آية»، «صفحة ٥٠», «أنت هنا» badge (`AppStatusBadge`) on the current surah/juz, and the download icon button per surah row (shared with the S2 tile). Jumps happen in place (same reader, `jumpFrom` recorded for the notice chip; the guard re-arms). Replaces `page_jump_sheet.dart`.

### 3.6 «العرض» sheet (no scrim; the page above is the live preview)
«لون الورق»: six tiles drawn as mini pages (paper fill, two ink lines, accent frame) with names. «السطوع»: the existing page-brightness setting (a dim over the page); the floor rises to 0.6 by changing `Settings.minPageBrightness` (persisted values clamp on read) and the slider's `min` reads that constant. «طريقة القراءة» صفحة / تمرير (`AppSegmentedSelector`). «عند الضغط على الآية» المعنى / الخيارات (hidden until S5). «إبقاء الشاشة مضيئة» switch (adds `wakelock_plus`, latest 1.x; on at reader entry when set, off on dispose; default on). «تم» ≥ 48×48. Extends `reading_settings_sheet.dart`.

### 3.7 State split
**S1**: `MushafState` gains `selectedAyah` (replaces `highlightedAyah`), `followPlayback`, `jumpFrom`, `openedSurah`; `playingAyah` stays. `PlaybackState` gains `requestedAyah` (§1.6). **S3**: removes `chromeVisible`, `isOverlayPinned`, `highlightedAyahCenterY`.
Visibility (S3): **ayah leaf** ⇔ `selectedAyah != null`; else **player leaf** ⇔ `requestedAyah ?? currentAyah != null` (playing, paused, loading or errored). Tapping an ayah during a recitation swaps the player leaf for the ayah leaf (`AnimatedSwitcher`); closing it returns to the player; «استماع من هنا» replaces the current recitation. Re-entering the reader on any page shows the player (listening-away when the page differs). Widget tests: tap-while-playing, tap-while-paused, page-turn buttons present while playing.
S3 deletes `AyahPlaybackOverlay`, `AyahActionPopover`, `MushafTopBar`, `MushafBrowseBar`, `PageJumpSheet` with their tests, replaced by tested successors.

**Scroll mode** (and landscape, where scroll is forced): head and foot as in page mode; ‹ › scroll one page; the leaf, player and notice chip are the same; the bounded slide becomes `Scrollable.ensureVisible`; ribbons and tail tabs hang on each page item.

### 3.8 Fate of existing files (S3 unless noted)
Delete: the five widgets above, `mushaf_printed_chrome.dart`, `printed_chrome_resolver.dart`, `mushaf_page_number_text.dart`. Modify: `mushaf_page_view.dart` (tap = select, no chrome toggle), `ayah_highlight_painter.dart` (selection + playing tints only), `auto_swap_helper.dart` (folded into `nextFollowAction` in S1). Keep: `current_ayah_notifier.dart`, `MushafPageRibbon` (S3; deleted in S4). Rule catalogues (`feature-widgets.md`, `core-widgets.md`, `architecture.md` app-wide cubit list, `routing-and-navigation.md`) are updated in the slice that changes them.

## 4. Listening (S2)

- **Media notification / lock screen**: `audio_service` (latest 0.18.x via `flutter pub add`) with a `QuranAudioHandler extends BaseAudioHandler` that bridges the shared `just_audio` player state out and routes play, pause, stop, skipToNext, skipToPrevious, seek in to `PlaybackCubit`. `MediaItem` per ayah: title «آل عمران، الآية ٤», artist = reciter's Arabic name, album «القرآن الكريم», `artUri` = `android.resource://<package>/mipmap/ic_launcher` (iOS: omit). The notification shows previous / pause-play / next / stop; tapping it opens the reader with `MushafArgs(page: playingPage, openedSurah: playingSurah, origin: jump)` (no `focusAyah`, so the player leaf shows) and `followPlayback` true.
- **Deltas from `docs/superpowers/plans/2026-06-13-playback-phase-b1-media-controls.md`** (use it for the handler shape only): plain `flutter`, no FVM; there is no `just_audio_background` to remove, so Task 1 only adds `audio_service`; `MediaItem` fields as above; `MainActivity` extends `AudioServiceActivity` and keeps the existing `PrayerStripPlugin` registration in `configureFlutterEngine`; add the `AudioService` service + `MediaButtonReceiver` and check, not assume, the `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `WAKE_LOCK` permissions; iOS `UIBackgroundModes: audio`; device checks on emulator-5554.
- **Audio focus** (`audio_session`, `AudioSessionConfiguration.speech()`): on an interruption (the adhan's `AdhanPlaybackService`, a call) recitation pauses and does not auto-resume; on becoming noisy it pauses. Fake-handler test per rule.
- **Background** (D5): delete `_playbackCubit.stop()` in `mushaf_page.dart` dispose; rewrite `mushaf_page_dispose_test.dart` to assert playback continues.
- **Surah download** (D6): `QuranPlaybackRepo.downloadSurah(surah, reciter) → Stream<Either<Failure, double>>` enqueues each missing ayah (and 1:1 when surah ∉ {1, 9}) through `prepareAyahAudio` on the existing 2-slot queue, tagged with a batch id; playback prepares go ahead of queued download tasks. Cancel drops that batch's queued tasks, keeps finished files, and returns to `notDownloaded`. Partial failure → `failed`; retry resumes the missing ayat. On completion a `Box<bool>('surahDownloads')` key `reciter:surah` is set; `isSurahDownloaded` reads it (no per-ayah stats). `deleteSurahDownload` removes the files, cache entries and the record. Delete the unused `PlaybackCubit.preloadFullSurah`. App-wide `SurahDownloadCubit` (lazy singleton, provided in `main.dart`) holds per-(reciter, surah) `notDownloaded | downloading(progress) | downloaded | failed`; failures show «تعذّر التنزيل، أعِد المحاولة».
- **S2 entry points**: a download icon button on `surah_list_tile.dart` («تنزيل» → progress ring, tap cancels → «محفوظة»; tapping «محفوظة» offers «حذف التنزيل»). After the first ayah that streams rather than plays from cache, a one-time SnackBar «يمكنك تنزيل السورة لتستمع دون إنترنت» (`downloadHintSeen`); from S3 it shows as a notice chip.

## 5. فواصل, saved ayat, أماكني (S4)

- Code lives in `lib/features/bookmarks/` (domain entity `Place`, `PlacesRepository`, use cases; data `PlaceRecordModel`; presentation cubits). Model: Hive typeId **6**, box `places` opened in `config/hive_config.dart` with `Hive.openBox` (user data, not `_openCacheBox`): `{id, surah, ayah, page, slot?, name?, createdAt, updatedAt, migrated}`. `id` = `createdAt.microsecondsSinceEpoch` as a String. `slot ∈ {0,1,2}` = فاصل «الورد» «الحفظ» «المراجعة» (renamable via `name`); no slot = saved ayah.
- **Migration** (idempotent, tested twice-run): ayah bookmarks → saved ayat; page bookmarks → saved ayat at the page's first non-banner ayah (bounds JSON); `s:0` entries are dropped; `createdAt` = migration time minus list index µs (keeps order) with `migrated: true`, which hides the date. Counts are verified before the flag is set; the flag lives in `Box<bool>('places_meta')` key `migratedV1`. Old boxes are left intact and never written again.
- `FasilCubit` (3 slots; move with undo), `SavedAyatCubit` (dated list, add/remove with undo). Both app-wide in `main.dart`; they replace `BookmarkCubit`/`PageBookmarkCubit` for the Qur'an (removed from `main.dart`, `bookmarks_di.dart` and the reader); `MushafPageRibbon` is deleted; hadith bookmarks untouched.
- **On the page**: a ribbon cluster (up to three 12 px silk ribbons, swallowtail ends, one 1 px stitch line) hangs from under the running head at the page's outer top corner, as ONE 48×56 button «الفواصل». Order fixed; unset slots are not drawn. Tap → **فاصل chooser** (sheet): three rows = colour chip + name + position «آل عمران ٦، صفحة ٥٠» + «انتقال» (+ «نقل إلى هنا» when an ayah is selected); an unset slot shows «غير موضوع» (+ «ضع هنا» when an ayah is selected). On a page holding a فاصل, its ribbon ends in a labelled tail tab at its ayah's first line («الحفظ» `TS.bold14`, ≥ 48 px hit; end shapes: الورد swallowtail (V notch), الحفظ pointed (V point), المراجعة square).
- Ribbon colours (`MushafPaperX.ribbon(FasilSlot)` in `mushaf_paper_colors.dart`; dark variant on light papers, light variant when `paper.isDark`): الورد maroon `#8A2F3B` / `#E39AA2`; الحفظ blue `#1F5A8A` / `#8EBBE3`; المراجعة ochre `#8A6410` / `#E2B85C`. Tail-tab text = paper `background`. A test checks on all six papers: ribbon vs paper ≥ 3:1; tail text on ribbon ≥ 4.5:1; the builder nudges lightness if a gate fails.
- «فاصل» in the leaf → chooser preselects the slot on this page, else the nearest preceding, else the last used (`chooserPreselect`) → «نقل الحفظ إلى هنا». SnackBar «نُقل فاصل الحفظ إلى البقرة ٥» + «تراجع». «حفظ الآية» → SnackBar «حُفظت الآية ٥ من البقرة» + «تراجع»; a saved ayah shows a small dot in the start margin.
- **«أماكني» sheet**: (1) «متابعة القراءة» card: «آل عمران ٧، صفحة ٥٠» + time from `updatedAt` (hidden when null) + caption «تُحفظ وحدها حيث تقرأ، ولا تغيّرها الانتقالات» + «متابعة»; (2) «الفواصل» three rows (swatch, name, position, «نُقل أمس ٩:٤٠ م», «انتقال», «تسمية»); (3) «الآيات المحفوظة» with count, rows = surah/ayah + «حُفظت ١٤ نوفمبر» + chevron, the item-18 row menu. The Bookmarks page's Qur'an sections show the same groups.

## 6. Tafsir (S5)

`features/tafsir/` (domain entity `Tafsir{surah, ayah, text, book}`, `TafsirRepository`, `GetAyahTafsir`, remote data source on the existing `Dio` per D1 with a `CancelToken` cancelled on page change, `Box<String>('tafsirCache')` keyed `muyassar:s:a` opened with `_openCacheBox` in `config/hive_config.dart`, `tafsir_di.dart` called from `core/di/dependency_injection.dart`, `TafsirCubit` a factory provided in the mushaf route's `MultiBlocProvider`). `feature-widgets.md` gains the exception «tafsir exports `TafsirSection` to surah». The compact leaf shows the first line + «…». The **full detent** (drag up or «تفسير الآية»): header row with «مشاركة»; an **ayah strip** cropped from the page image (`drawImageRect` on the ayah's bounds line rects, tinted ink on paper, decoded at strip width) + «المصحف خلفك على هذه الآية»; a static chip row «التفسير» (selected) · «الترجمة» · «معاني الكلمات» · «ملاحظتي» (disabled, «لاحقًا»); book row «التفسير الميسر» + caption «يُحمَّل من الإنترنت ثم يُحفظ على الجهاز» + source «المصدر: التفسير الميسر، مجمع الملك فهد، عبر alquran.cloud»; body `TS.regular16` line-height 1.95; «الآية السابقة» / «الآية التالية» (the page behind follows; selection moves); «العودة إلى المصحف». Loading = skeletonized paragraph; error = «تعذّر تحميل التفسير» + «إعادة المحاولة».

## 7. Seams (task boundaries for the plans)

- Pure functions, each with unit tests: `resolveRunningSurah`, `LastReadSaver` guard, `toAsciiDigits`, `pagePlaybackRange`, `nextFollowAction`, range clamp, paper contrast gates, ribbon contrast gates, `PlaceMigration`, `chooserPreselect`.
- Cubits: `MushafCubit` (state split), `PlaybackCubit` (requestedAyah/error/range/clamp/idle), `SurahDownloadCubit`, `FasilCubit`, `SavedAyatCubit`, `TafsirCubit`, `SettingsCubit` (+ `tapAction: LeafTapAction {meaning, options}` persisted by name, default `meaning`; `hintSeen` and `downloadHintSeen` default false; `keepScreenOn` default true; each through `Settings` and `SettingsModel.toMap/fromMap` with a fallback when the key is missing).
- Widgets (each with a widget test): `RunningHead`, `KhatamMedallion`, `ReaderFoot`, `NoticeChip`, `AyahLeaf`, `PlayerLeaf`, `MenuSheet`, `DisplaySheet`, `FasilRibbonCluster`, `FasilChooser`, `PlacesSheet`, `TafsirSection`, `AyahStrip`, `SurahDownloadButton`.
- Platform: `QuranAudioHandler`, audio session, Android manifest/activity, iOS plist.

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| alquran.cloud outage, rate limit, or terms change | One call per page, cache forever, inline retry; the repository hides the source so bundling can replace it. |
| Muyassar licence unresolved (contract §8.3) | Source line in the full detent; text is fetched on demand, never shipped in the APK; listed for the owner in the S5 PR. |
| Recitation vs adhan / calls | Audio-session interruption pauses recitation without auto-resume; the adhan keeps its own channel and foreground-service type. |
| Migration drops or corrupts bookmarks | Old boxes are never written; counts verified before the flag; twice-run test. |
| Download storage growth | Per-surah delete; downloads are explicit. Files stay in the documents directory (iCloud backup on iOS is accepted, not fixed). |
| Memory: each decoded page ≈ 34 MB, ImageCache 100 MB | Ayah strips and mini-page tiles decode at display size (`cacheWidth`); tiles are drawn, not decoded images. |

## 9. Done means

Per slice: `dart format` on touched files, `flutter analyze --no-fatal-infos` with no new issues vs `main`, `flutter test` green, code review (repo standards and this spec) with every finding fixed or argued, the PR opened and left for the owner to merge. After S5: an emulator QA pass (emulator-5554) over the flows in §1, §3–§6 with screenshots, `adb shell dumpsys media_session` showing the session, and a written verdict on whether the design serves ordinary readers.
