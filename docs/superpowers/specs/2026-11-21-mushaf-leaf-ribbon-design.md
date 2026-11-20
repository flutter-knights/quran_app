# Mushaf reader «الورقة والشريط» (Leaf & Ribbon): build spec

Date: 2026-11-21. Owner brief (verbatim intent): build the final design from the v2 design run, fix every known bug in the reader, tell the user clearly how to download a surah, add a media notification for the current recitation, re-tune the paper colours to look like a real printed mushaf, review whether the design is the best for users, QA it, and take every default decision without asking.

Design source (gitignored, local only): `docs/design-audit/mushaf-v2/reading/final-spec.md`, `final-reading.html`, `final-sheets.html`, `docs/design-audit/mushaf-v2/_docs/contract.md` §7–8, `docs/design-audit/mushaf-v2/_research/00-current-screen-audit.md` (the bug ledger, verified at `d6431167` = today's `main`). This spec restates everything a builder needs; where it and the design files disagree, this spec wins.

## 0. Decisions taken by default (owner delegated all)

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Tafsir source | **Online with a Hive cache**: `GET https://api.alquran.cloud/v1/ayah/{s}:{a}/ar.muyassar` → `data.text`. Cached per ayah forever; the current page's ayat are prefetched when the leaf opens. Offline and uncached → inline message + retry, never a dead end. | No licence for bundling can be obtained tonight; the endpoint is free and verified live (2026-11-21). Bundling stays a later swap behind the same repository. |
| D2 | Ship order | Five slices, each its own PR, merged when green: **S1** logic bugs + paper colours → **S2** listening (media notification, background audio, surah download) → **S3** reader shell, ayah leaf, player leaf, القائمة, العرض → **S4** فواصل, saved ayat, أماكني, migration → **S5** tafsir. | `main` holds finished slices if the night runs out. |
| D3 | First tap for existing users | «المعنى» (the compact leaf with a tafsir line) for everyone. Until S5 lands the compact leaf shows no tafsir line and no «قريبًا». The «الخيارات» setting hides the line. | The design's core; the leaf is labelled, so change aversion is low. |
| D4 | Wird plans, page zoom, translation, word meanings, notes | Not built. Their chips show in the leaf's section registry as disabled with a quiet «لاحقًا» badge (S5). Zoom is dropped from «العرض». | Spec marks wird phase 2; zoom is not required to fix any reported bug. |
| D5 | Audio after leaving the reader | **Keeps playing** with the media notification; stopped by «إنهاء التلاوة», the notification's stop, or the app being killed. | Media control only makes sense if audio can outlive the screen. |
| D6 | «تنزيل السورة» | Downloads every ayah of a surah for the **current reciter** into the existing audio cache, with progress and a «محفوظة للاستماع دون إنترنت» state. Entry points: the player leaf (while a surah plays), the surah row in «القائمة», and a one-time hint after the first online playback: «يمكنك تنزيل السورة لتستمع دون إنترنت». | The owner asked that users *know how* to download; three visible entries + one hint. |
| D7 | Paper colours | Re-tuned to printed-mushaf references (see §2). The six enum cases and their persisted names do not change. | Persisted setting. |
| D8 | Localization | New strings go in both ARBs **and** in `lib/core/localization/pending_s.dart` (`PendingS`), the repo's declared bridge while `lib/generated` waits for the owner's IDE save. `test/core/localization/pending_s_test.dart` keeps them in sync. Never edit `lib/generated/`, never run `intl_utils:generate`. | `lib/generated` is regenerated only by the IDE extension. |

## 1. Bug ledger (S1 unless noted; each gets a failing test first)

1. Running head / top bar names the previous surah on 64 of 114 surahs. Rule: the surah of the selected or playing ayah on this page, else the surah the reader opened (when it is on this page), else the surah with the most bounds lines on the page. Pure function, tested on p.293 (الكهف opened → «الكهف»), p.604 (الناس), p.106.
2. Player close does not stop audio. There is an explicit «إنهاء التلاوة» that calls `stop()`; hiding the player while audio plays is impossible (the test at `ayah_playback_overlay_test.dart:206-221` that pins the bug is rewritten deliberately).
3. «تشغيل السورة» opens with no player and plays past the surah end. It plays the surah as a range (start→last ayah) and the reader shows the player on arrival.
4. The player disappears at the first automatic page turn. Selection, playing ayah and player visibility are separate state; a page turn caused by playback never clears them.
5. Pull-back during recitation: auto page-follow happens only while the reader is "following" (the shown page holds the previous playing ayah). Once the reader browses away, the page stays and the player shows «يُتلى الآن: …، صفحة …» + «العودة إلى الآية المتلوّة» (S3 draws it; S1 adds the state and the follow rule).
6. Silent audio errors. `PlaybackState` carries a persistent `error` (cleared only by retry/stop/new play); the player shows it with «إعادة المحاولة» and «إنهاء التلاوة» (S1: state + a SnackBar fallback; S3: inline in the player leaf).
7. Page jump rejects ٠–٩. One pure normaliser (`toAsciiDigits`) in `core/helper functions/numeral_helpers.dart`, reused by the range validator.
8. Play page on multi-surah pages plays only the first surah's tail (p.106 plays one ayah). «استماع الصفحة كاملة» plays the page's first ayah → last ayah across surahs (the engine already crosses surahs; the range end is the page's last ayah).
9. Mini-player title shows the surah number in Latin digits → surah name + Arabic-Indic digits.
10. ⏮/⏭ look enabled but do nothing when idle → disabled when there is no current ayah.
11. ∞ repeat cannot target each ayah → the ∞ toggle applies to whichever counter it sits beside.
12. Ayah 0 (banner/basmala) can be bookmarked and shared → it gets the banner actions only (§3.3); bookmarking and sharing are impossible.
13. A bookmarked ayah reopens without focus → bookmarks pass `MushafArgs(page, focusAyah)`.
14. `PlaybackState` is not `Equatable` → it is.
15. A page-load failure leaves dead taps with no UI → the page shows an inline «تعذّر تحميل الصفحة» + «إعادة المحاولة».
16. Sajda map is wrong in 5 places (and cannot hold two in surah 22). Replace with a set of the 15 positions from the vendored Tanzil text: 7:206, 13:15, 16:50, 17:109, 19:58, 22:18, 22:77, 25:60, 27:26, 32:15, 38:24, 41:38, 53:62, 84:21, 96:19. `isSajdahVerse` keeps its signature. Nothing draws a sajda marker.
17. Last read is overwritten by any visit (bookmark peek, search hit, jump). **Guarded**: a session opened by a jump (search, bookmark, فاصل, index, tafsir) does not write «متابعة القراءة» until the reader turns a page or stays 20 s on one page. A normal open (home card, surah list) writes as today. Pure `LastReadGuard` with a fake clock.
18. Bookmarks page: no delete in the list and a hard-coded arrow → row menu «إزالة» with undo, `forwardArrowIcon` (S4 replaces this page's Qur'an sections).
19. Terminology drift: «حفظ» / «الإشارات» / «إشارات مرجعية» / «المحفوظات» → «فاصل/الفواصل», «الآيات المحفوظة», «حفظ الآية», «أماكني» (S4 renames the visible strings).
20. Hizb is shown in the running head → `QuranMetaService.getPageMeta` is verified against the Tanzil hizb-quarter table by a test before it is used (fix it if wrong).

## 2. Paper colours (S1)

Printed references: the King Fahd Complex Madinah print (warm ivory paper, near-black ink, gilt-and-teal frame), older Egyptian/Shamarly prints (aged paper, brown-black ink), and night reading apps. Pages are two single-tint masks (body = `ink`, frame/rosettes/banners = `accent`) over `background`, so "real mushaf" means these three values per paper.

| Paper (name kept) | background | ink | accent | Reference |
|---|---|---|---|---|
| cream «كريمي» | `#FDF7E8` | `#1B1A17` | `#9A7B3C` gilt | Madinah print |
| sepia «سيبيا» | `#F3E6C9` | `#2B2116` | `#8A5A2B` brown-gold | aged print |
| green «أخضر» | `#EEF3E8` | `#18231B` | `#2F6E55` Madinah teal-green | green-frame print |
| gray «رمادي» → shown as «أبيض» | `#FAFAF7` | `#161616` | `#1F5E7A` blue | white offset print |
| night «ليلي» | `#141210` | `#ECE3CF` | `#C9A45A` | night, warm |
| slateNight «ليلي أزرق» | `#0F141A` | `#DCE5EC` | `#6E9CC4` | night, cool |

Gates (a test computes them): ink on background ≥ 7:1 (AAA body text) on every paper; accent on background ≥ 3:1; the selection highlight (accent ≤ 18% over paper) keeps ink ≥ 4.5:1. If a value misses a gate, the builder nudges lightness only and records the final hex in the PR. The gray paper keeps its enum case `gray` and its persisted value; only its label changes to «أبيض».

## 3. Reader shell (S3)

The page box never changes size or position between states or text scales, except the bounded slide in §3.3.

### 3.1 Running head, 48 px (max 64 at large text), printed on the paper
Start: back (mirrored `backArrowIcon`, tooltip «رجوع», 48 px). Then the surah name per §1.1, `TS.bold16` in paper ink. Centre: the page number inside an eight-point **khatam** (`KhatamMedallion` `CustomPainter` in paper accent, sized by a `TextPainter`, max 64 px wide), number `TS.bold14` in ink, Arabic-Indic digits. End: «الجزء ٣، الحزب ٥» `TS.medium14` in `ink-2` (ink at 78% over paper). A double hairline rule in accent under the head. Tapping the surah or juz text opens «القائمة». It replaces `mushaf_top_bar.dart` and the printed-chrome glyph header in page mode (the QCF glyph chrome is removed from the shell; scroll mode shows the same head).

### 3.2 Foot band, 64 px, on the paper
`‹` previous page (48 px, start side) · «استماع» (filled, `colorScheme.primary`) · «القائمة» (tonal, leaf colour = ink 6% over paper) · `›` next page (48 px, end side; "next" points to the reading direction). Pills ≥ 56 px tall, icon + label `TS.semiBold14`. A **notice chip** slot floats above the pills, never over text: «العودة إلى صفحة ٥٠» after a jump (until the next manual page turn; tap returns) and the first-open hint «اضغط على أي آية لترى معناها وأزرارها» + «فهمت» (once; `hintSeen` setting).
Controls at rest: back, ‹, استماع, القائمة, › (+ the فواصل cluster from S4). It replaces `mushaf_browse_bar.dart`. Chrome is always visible: no hide-on-tap state (`chromeVisible` is removed).

### 3.3 Ayah leaf (non-modal, grows up from the foot band)
One tap on an ayah selects it and raises the leaf at its **compact detent** (sized by the text scaler, ≈ 168 px at 1×, replacing the foot band while open). Long-press does the same. Closing: tap the same ayah, «إغلاق», drag down, system Back, a tap on blank paper; a page swipe closes it too.
- Title row «آل عمران، الآية ٧» `TS.bold16` + «إغلاق» (48 px).
- Action row, 4 labelled columns with hairline separators: «استماع من هنا» (the only filled one), «تفسير الآية» (S5; before S5 this slot is «مشاركة»), «فاصل» (S4; before S4 «حفظ الآية» toggles the existing ayah bookmark), «حفظ الآية» (S4; before S4 «مشاركة»). The builder of each slice fills the row with exactly four real, working actions. «مشاركة» shares «نص الآية» + «— سورة آل عمران، الآية ٧» in Arabic-Indic digits.
- One line of tafsir lead ending «…» (S5; hidden when the setting is «الخيارات»).
- **Bounded slide**: the page translates up by at most the leaf height only when the selected ayah's bounds would sit under the leaf.
- **Banner (ayah 0)** variant: title «سورة المائدة», caption «مدنية، ١٢٠ آية»; primary «استماع من بداية السورة»; secondary «استماع الصفحة كاملة»; no share, no bookmark, never «الآية ٠».

### 3.4 Player leaf (takes the compact detent's place)
Title «آل عمران، الآية ٤» + «القارئ، حتى نهاية السورة». Controls «السابقة» · «إيقاف مؤقت»/«متابعة» (primary, 56 px) · «التالية». Row 2: repeat chip «التكرار: …» (≥ 48 px, opens the existing `PlaybackRepeatOptions` in a sheet «خيارات التلاوة» with reciter, speed, range) and «إنهاء التلاوة» (stops). Download chip «تنزيل السورة» → progress «جارٍ التنزيل ٤٠٪» → «محفوظة للاستماع دون إنترنت» (S2 builds the cubit; S3 places it). States: **listening-away** (reader on another page: «يُتلى الآن: آل عمران ١٢، صفحة ٥١» + filled «العودة إلى الآية المتلوّة»); **audio-error** (`Semantics(liveRegion)`): «تعذّر تشغيل الآية ١٣» + «تحقق من الاتصال بالإنترنت، ثم أعِد المحاولة» + «إعادة المحاولة» + «إنهاء التلاوة»; **loading**: a slim progress bar over the leaf (allowed exception in `loading-states.md`).
«استماع» in the foot plays from the selected ayah, else the page's first non-banner ayah, to the end of that surah.

### 3.5 «القائمة» sheet (modal, app colours `context.colorScheme`)
Three tiles: «أماكني» (S4; before S4 it opens the existing bookmarks page), «العرض», «استماع الصفحة كاملة». A search field «اسم سورة أو رقم صفحة» accepting ٠–٩ and 0–9 with a live result row («صفحة ٥٨٢، النبأ، الجزء ٣٠» + «انتقال») and inline error «اكتب رقمًا من ١ إلى ٦٠٤». `AppSegmentedSelector` «السور / الأجزاء»; rows ≥ 56 px: number disc, name, «مدنية، ٢٠٠ آية»، «صفحة ٥٠», «أنت هنا» badge (`AppStatusBadge`) on the current surah/juz, and a download state icon button per surah row (S2 cubit: «تنزيل» / progress / «محفوظة»). Jumps happen in place (same reader, `jumpFrom` recorded for the notice chip and the last-read guard). Replaces `page_jump_sheet.dart`.

### 3.6 «العرض» sheet (no scrim; the page above is the live preview)
«لون الورق»: six tiles drawn as mini pages (paper fill, two ink lines, accent frame) with names. «السطوع» slider (floor 0.6). «طريقة القراءة» صفحة / تمرير (`AppSegmentedSelector`). «عند الضغط على الآية» المعنى / الخيارات (S5 hides it until tafsir exists). «إبقاء الشاشة مضيئة» switch (`wakelock_plus`, default on while the reader is open). «تم» ≥ 48×48. Extends `reading_settings_sheet.dart`.

### 3.7 State split
`MushafState`: `currentPage`, `selectedAyah`, `playingAyah`, `followPlayback` (bool), `jumpFrom` (int?), `openedSurah` (int?). Removed: `highlightedAyah`, `chromeVisible`, `isOverlayPinned`, `highlightedAyahCenterY`. Player visible ⇔ `PlaybackCubit` has a current ayah (playing, paused, loading or errored). Leaf visible ⇔ `selectedAyah != null` and no player. `AyahPlaybackOverlay`, `AyahActionPopover`, `MushafTopBar`, `MushafBrowseBar`, `PageJumpSheet` are deleted with their tests, replaced by tested successors.

## 4. Listening (S2)

- **Media notification / lock screen**: `audio_service` (`^0.18.19`) with a `QuranAudioHandler extends BaseAudioHandler` that bridges the shared `just_audio` player state out and routes play, pause, stop, skipToNext, skipToPrevious, seek in to `PlaybackCubit` (follow `docs/superpowers/plans/2026-06-13-playback-phase-b1-media-controls.md`, updated for today's code). `MediaItem` per ayah: title «آل عمران، الآية ٤», artist = reciter's Arabic name, album «القرآن الكريم»; art = the app icon. Android: `MainActivity` extends `AudioServiceActivity` keeping `PrayerStripPlugin`; manifest `AudioService` service + `MediaButtonReceiver`; must coexist with the adhan service. iOS: `UIBackgroundModes: audio`. The notification shows previous / pause-play / next / stop; tapping it opens the app.
- **Background**: leaving the reader no longer stops audio (D5). Re-entering the reader on the playing page shows the player.
- **Surah download** (D6): `QuranPlaybackRepo.downloadSurah(surah, reciter) → Stream<double>` reusing the cache and the 2-concurrent download limit; `isSurahDownloaded(surah, reciter)`. An app-wide `SurahDownloadCubit` (lazy singleton, in `main.dart`) holds per-(reciter,surah) state `notDownloaded | downloading(progress) | downloaded | failed`; cancel supported. Failures map to `Failure`, shown as «تعذّر التنزيل، أعِد المحاولة».

## 5. فواصل, saved ayat, أماكني (S4)

- Model: `PlaceRecordModel` (Hive typeId **6**, box `places`): `{id, kind: ayah|page, surah?, ayah?, page, slot?, name?, createdAt, updatedAt}`. `slot ∈ {0,1,2}` = فاصل «الورد» «الحفظ» «المراجعة» (renamable); no slot = saved ayah.
- **Migration** (idempotent, tested twice-run): ayah bookmarks → saved ayat; page bookmarks → saved entries of kind page (first ayah of the page); old boxes are left intact and never written again; a flag in the `places` box marks completion.
- `FasilCubit` (3 slots; move with undo), `SavedAyatCubit` (dated list, add/remove with undo). Both app-wide (they replace `BookmarkCubit`/`PageBookmarkCubit` for the Qur'an; hadith bookmarks untouched).
- **On the page**: a ribbon cluster (up to three 12 px silk ribbons, swallowtail ends, one 1 px stitch line) hangs from under the running head at the page's outer top corner, as ONE 48×56 button «الفواصل». Order fixed. Tap → **فاصل chooser** (sheet): three rows = colour chip + name + position «آل عمران ٦، صفحة ٥٠» + «انتقال» (+ «نقل إلى هنا» when an ayah is selected). On a page holding a فاصل, its ribbon ends in a labelled tail tab at its ayah's first line («الحفظ» `TS.bold14`, ≥ 48 px hit; end shapes: الورد swallowtail, الحفظ pointed, المراجعة square).
- Ribbon colours (fixed hue per فاصل, light/dark variant): الورد maroon `#8A2F3B` / `#E39AA2`; الحفظ blue `#1F5A8A` / `#8EBBE3`; المراجعة ochre `#8A6410` / `#E2B85C`. A test checks on all six papers: contrast ≥ 3:1 vs paper; text on ribbon ≥ 4.5:1; the builder nudges lightness if a gate fails.
- «فاصل» in the leaf → chooser preselects the slot on this page, else the nearest preceding, else the last used → «نقل الحفظ إلى هنا». SnackBar «نُقل فاصل الحفظ إلى البقرة ٥» + «تراجع». «حفظ الآية» → SnackBar «حُفظت الآية ٥ من البقرة» + «تراجع»; a saved ayah shows a small dot in the start margin.
- **«أماكني» sheet**: (1) «متابعة القراءة» card: «آل عمران ٧، صفحة ٥٠» + time + caption «تُحفظ وحدها حيث تقرأ، ولا تغيّرها الانتقالات» + «متابعة»; (2) «الفواصل» three rows (swatch, name, position, «نُقل أمس ٩:٤٠ م», «انتقال», «تسمية»); (3) «الآيات المحفوظة» with count, rows = surah/ayah + «حُفظت ١٤ نوفمبر» + chevron, row menu «إزالة» with undo. The Bookmarks page's Qur'an sections show the same groups.

## 6. Tafsir (S5)

`features/tafsir/` (domain entity `Tafsir{surah, ayah, text, book}`, `TafsirRepository`, `GetAyahTafsir`, remote data source on the existing `Dio`, Hive `Box<String>('tafsirCache')` keyed `muyassar:s:a`, `TafsirCubit` per reader). The compact leaf shows the first line + «…». The **full detent** (drag up or «تفسير الآية»): an **ayah strip** cropped from the page image (`drawImageRect` on the bounds line rects, tinted ink on paper) + «المصحف خلفك على هذه الآية»; the section chips registry: «التفسير» (selected) · «الترجمة» · «معاني الكلمات» · «ملاحظتي» (disabled, «لاحقًا»); book row «التفسير الميسر» + caption «يُحمَّل من الإنترنت ثم يُحفظ على الجهاز»; body `TS.regular16` line-height 1.95; «الآية السابقة» / «الآية التالية» (the page behind follows; selection moves); «العودة إلى المصحف». Loading = skeletonized paragraph; error = «تعذّر تحميل التفسير» + «إعادة المحاولة».

## 7. Seams (task boundaries for the plans)

- Pure functions, each with unit tests: `resolveRunningSurah`, `LastReadGuard`, `toAsciiDigits`, `pagePlaybackRange`, `nextFollowAction` (follow vs stay), sajda set, paper contrast gates, ribbon contrast gates, `PlaceMigration`, `chooserPreselect`.
- Cubits: `MushafCubit` (state split), `PlaybackCubit` (stop/error/range/idle), `SurahDownloadCubit`, `FasilCubit`, `SavedAyatCubit`, `TafsirCubit`, `SettingsCubit` (+ `tapAction`, `hintSeen`, `keepScreenOn`).
- Widgets (each with a widget test): `RunningHead`, `KhatamMedallion`, `ReaderFoot`, `NoticeChip`, `AyahLeaf`, `PlayerLeaf`, `MenuSheet`, `DisplaySheet`, `FasilRibbonCluster`, `FasilChooser`, `PlacesSheet`, `TafsirSection`, `AyahStrip`.
- Platform: `QuranAudioHandler`, Android manifest/activity, iOS plist.

## 8. Done means

Per slice: `dart format` on touched files, `flutter analyze --no-fatal-infos` with no new issues vs `main`, `flutter test` green, code review (Standards + Spec axes) with every finding fixed or argued, PR merged. After S5: an emulator QA pass (emulator-5554) over the flows in §1, §3–§6 with screenshots, `adb shell dumpsys media_session` showing the session, and a written verdict on whether the design serves ordinary readers.
