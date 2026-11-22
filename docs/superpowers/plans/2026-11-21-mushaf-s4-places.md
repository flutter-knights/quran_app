# Mushaf S4 (فواصل ribbons, saved ayat, أماكني, bookmark migration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Qur'an ayah and page bookmarks with one typed `places` store: three named فواصل drawn as silk ribbons on the page, a dated list of saved ayat, the «أماكني» sheet and the same groups on the Bookmarks page, with a tested one-time migration of the old boxes.

**Architecture:** `features/bookmarks/` gains a `Place` entity (`slot != null` → فاصل, `slot == null` → saved ayah), `PlacesRepository`, a Hive `PlaceRecordModel` (typeId 6, box `places`) and a `PlaceMigration` that runs once in `main.dart` before the app-wide cubits exist. Two app-wide cubits, `FasilCubit` and `SavedAyatCubit`, read and write the store; pure rules (`chooserPreselect`, `placeWhen`, `fasilRibbon`) sit in `presentation/utils/`. The reader draws `FasilRibbonCluster`, tail tabs and the saved-ayah dot inside `MushafPageView` (so scroll mode gets them per page item), opens `FasilChooser` from the cluster, a tail or the leaf's «فاصل», and opens `PlacesSheet` from «القائمة». `BookmarkCubit`, `PageBookmarkCubit`, their data stack and `MushafPageRibbon` are deleted.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), flutter_bloc + bloc_test, mocktail, equatable, dartz, hive_ce + hive_ce_generator (build_runner), hugeicons 4.4.0, intl `DateFormat`, the vendored `quran` package.

**Spec:** `docs/superpowers/specs/2026-11-21-mushaf-leaf-ribbon-design.md`: §5 in full, ledger items 18 and 19 (§1), the S4 row of the §3.3 action table, the `ribbon(FasilSlot)` line of §2, the §3.5 «أماكني» tile, the §3.7 scroll-mode line on ribbons, and the S4 rows of §7 (`PlaceMigration`, `chooserPreselect`, ribbon contrast gates, `FasilCubit`, `SavedAyatCubit`, `FasilRibbonCluster`, `FasilChooser`, `PlacesSheet`). Where the spec and this plan disagree the spec wins, except for the **Deliberate readings** below, where the plan governs. Raise any other disagreement in the task report.

## Global Constraints

- Work on `feature/mushaf-s4-places`. Never switch branches, never touch `main`, never push, never rebase, never amend.
- Commits: stage explicit paths only (never `git add -A` / `git add .`; deletions with `git rm`). Never stage `quran-1.4.1/**`, `lib/generated/**`, or `ios/Podfile.lock`. Conventional message (`feat|fix|refactor|test(scope): …`) ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No comments and no doc comments in new or changed code. No redundant type annotations. Lean code. A user comment inside lines a task replaces goes with them.
- New strings: add each to both `lib/l10n/intl_ar.arb` and `lib/l10n/intl_en.arb` (a `"@key": {"placeholders": {"x": {"type": "String"}}}` block per placeholder) and mirror it in `lib/core/localization/pending_s.dart` as `String get key => _ar ? '…' : '…';` or `String key(String a) => _ar ? '… $a' : '… $a';` (single quotes, `String` parameters only, numbers preformatted). Read with `PendingS.of(context)` in `build`, `PendingS.current` in callbacks. `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`; never run `intl_utils:generate`; never change the value of an existing `S` key (the generated code would go stale). Reuse an existing key when its text is exactly the spec's: `S.undo` «تراجع», `S.playback_close` «إغلاق», `PendingS.menu_go` «انتقال», `PendingS.menu_places` «أماكني», `PendingS.player_resume` «متابعة», `PendingS.display_done` «تم», `PendingS.leaf_saveAyah` «حفظ الآية».
- Arabic numbers use Arabic-Indic digits via `toLocalized(context)` / `toIndicNumerals(localeCode)`.
- Colours: paper surfaces (page, ribbons, tails, dot, leaf) read `MushafPaperX` (`colors`, `ribbon`); app surfaces (chooser, places sheet, Bookmarks page) read `context.colorScheme`. Hex literals only in `mushaf_paper_colors.dart`. Text styles only `TS.*`; `test/config/theme/typography_ratchet_test.dart` must not rise.
- Icons: HugeIcons everywhere this slice draws (leaf, chooser, places sheet, Bookmarks page, row menu); arrows only via `forwardArrowIcon(context)` / `backArrowIcon(context)`.
- Layers: `domain/` stays pure Dart (no Flutter, no `S`); Hive models only in `data/models/`; presentation never imports `data/`. Repositories return `Either<Failure, T>` and catch every exception (`CacheException` → `CacheFailure`, anything else → `Failure.fromException(e)`).
- Cubits: `if (isClosed) return;` before every emit after an `await`; states `Equatable` with every field in `props`.
- Hadith bookmarks (`HadithBookmarkCubit`, `hadith_bookmarks` box) are not changed. Tafsir is S5.
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`; never modify `assets/mushaf/**`.
- `dart format` only the explicit `.dart` paths a task changed (never a directory, `.`, `lib`, `test` or `lib/generated/**`).
- Every task ends at baseline or better: `flutter analyze --no-fatal-infos` = 0 errors, 0 warnings, ≤ 69 infos; `flutter test` = 1311 at start plus the tests this plan adds minus the tests it deletes, all pass, 1 skipped.
- Rule catalogues (`architecture.md`, `feature-widgets.md`, `state-management-patterns.md`, `routing-and-navigation.md`, `icons.md`) and `CLAUDE.md`'s feature summary change in the task that changes what they describe.

## Deliberate readings (the plan governs here)

1. **Migration order.** The plan walks the ayah list (stored order) then the page list (stored order) as one sequence; item `i` gets `createdAt = now − i µs`. Saved ayat are shown newest first, so the migrated list reads in the old stored order.
2. **One saved ayah per ayah.** An ayah that appears twice (in both lists, or twice in one) is migrated once, at its first position. `SavedAyatCubit.save` of an ayah already saved returns null and changes nothing.
3. **A re-run without the flag replaces its own records.** `PlaceMigration.run` deletes every record with `migrated == true` before writing, so a crash between the writes and the flag can never duplicate. Records the reader created (`migrated == false`) are kept, and `run` drops any planned ayah that already has a reader record (`slot == null && !migrated`), so a save made after a failed run is never doubled.
4. **The migration runs once per launch until it succeeds**, in `_AppLoaderState._initAll` after `initGetIt()` and before `_ready = true`, so the app-wide cubits load after it. A failure leaves the flag unset; the app still starts.
5. **Old boxes stay open** (`ayah_bookmarks`, `page_bookmarks` in `hive_config.dart`) because the migration reads them; after Task 8 no code writes them.
6. **«تسمية» is offered on placed فواصل only** (the record holds the name). A blank or whitespace name resets to the default name (`name: null`).
7. **The cluster draws nothing when no فاصل is placed** (no empty button). The chooser stays reachable from the leaf's «فاصل».
8. **Ribbon geometry is physical, not directional.** Scroll mode (and landscape, which forces it) puts `MushafPageView` in a `ListView` that inherits the app's direction, so `PositionedDirectional` would flip under English. Every overlay in `MushafPageView` therefore uses `Positioned(left: …)` / `Positioned(right: …)`, and the Task 5 widgets measure from their own left edge: the cluster, strips and tails sit at the page's left edge, the saved-ayah dot at its right edge, in both modes and both languages. Slot index `k` (`FasilSlot.index`) has its ribbon at `x_k = 4 + 14·k` px from the left edge (wird 4, hifz 18, muraja 32; 12 wide), so an unset slot leaves a gap.
9. **Cluster, tails and strips** (design `docs/design-audit/mushaf-v2/reading/final-reading.html`, `.fasil` / `.ftail` / `.fbody`, lines 248-261). Cluster: `Positioned(left: 0, top: 0, width: 48, height: 56)`. Tail of slot `k`: `Positioned(left: 0, top: t, width: 48, height: fasilTailHeight)` (88); inside it the 22 px label sits at `left: max(0, x_k + 12 − 22)` (0, 8, 22, so it always covers its ribbon and stays inside the 48 px box), fills the 88 px height, and holds the name rotated (`RotatedBox(quarterTurns: 1)`, `maxLines: 1`, ellipsis) on the ribbon colour in paper `background`. The wanted top is the bottom of the ayah's first line rect × page height − 88. `layoutTailTops` (Task 4) clamps every top to ≥ 56 (below the cluster), stacks tabs whose boxes would overlap (sorted by wanted top, then slot index; each top ≥ the previous top + 88), and, when the last would pass the page bottom, pushes the stack up (last ≤ height − 88, each other ≤ the next − 88). Strip of slot `k`: `Positioned(left: x_k, top: 0, width: 12, height: t)` holding `FasilStrip`, which is `IgnorePointer` and never takes a tap. Stack order after the tap detector: dots, strips, tails, cluster. Tapping a tail opens the chooser preselecting that slot.
10. **Ochre is nudged.** On light papers المراجعة is `#835F0F`, not `#8A6410`: sepia background on `#8A6410` is 4.34:1 (< 4.5); `#835F0F` gives 4.70. All other ribbon values are the spec's. Record this in the PR.
11. **App-surface swatches follow the app palette**: `fasilRibbon(slot, dark: context.colorScheme.brightness == Brightness.dark)`, so a chip reads on the sheet, not on the paper.
12. **"Last used" = the placed slot with the greatest `updatedAt`.** With nothing placed `chooserPreselect` returns `FasilSlot.wird`.
13. **On this page with two فواصل**, `chooserPreselect` takes the last one at or before the selected ayah, else the first on the page.
14. **Placing a فاصل keeps the leaf open.** A first placement says «وُضع فاصل الحفظ عند البقرة ٥»; a move says «نُقل فاصل الحفظ إلى البقرة ٥». «تراجع» restores the previous record exactly (same `id`, `createdAt`, `name`), or deletes the record when the slot was unset.
15. **«حفظ الآية» toggles.** On a saved ayah it removes, with «أُزيلت الآية ٥ من البقرة» + «تراجع» (restore keeps `id` and `createdAt`).
16. **Navigation from أماكني.** In the reader every row jumps in place (`MushafCubit.jumpTo(page, focus: …)`, guard re-armed): a فاصل or saved ayah selects its ayah (leaf opens); «متابعة» jumps without a selection. On the Bookmarks page a فاصل or saved ayah pushes `MushafArgs.focus(ayah)`; «متابعة» pushes `extra: page` (normal origin), like the home card.
17. **Hadith rows on the Bookmarks page get only the arrow fix** (`forwardArrowIcon`); no row menu, since hadith bookmarks stay untouched.
18. **Terminology (item 19) changes callers, not ARB values.** The page title and the home quick-access label become `PendingS.menu_places` «أماكني»; new terms are new `PendingS` keys. `S.bookmarks_screen_title`, `S.bookmarks_pages_section`, `S.bookmarks_quran_section`, `S.no_bookmarks_yet`, `S.pageRemovedFromBookmarks` lose their callers; their ARB keys stay. The hadith view's «حفظ» is hadith and stays.
19. **Relative dates** use the local calendar day: same day «اليوم ٦:١٠ ص», previous day «أمس ٩:٤٠ م», older «١٤ نوفمبر», another year «١٤ نوفمبر ٢٠٢٥». A migrated record shows no date.
20. **The places sheet and the Bookmarks page share one widget, `PlacesGroups`.** The continue card hides when there is no last read; the saved group shows «لا توجد آيات محفوظة بعد» when empty; the three فاصل rows always show.
21. **Rename keeps `updatedAt`.** `rename` writes only `name` (or `clearName: true`), so renaming never makes a slot "last used" (reading 12), and «نُقل $when», which reads `place.updatedAt`, stays the move time.
22. **Continue card without an ayah.** When `LastRead.ayah` is null (old records, bare-page reads) the card reads «صفحة ٥٠» (`places_page`), never a guessed ayah.
23. **Place times follow the app's clock setting.** `placeWhen(…, use24h:)` gets `settingsModel.is24HourFormat` from `SettingsCubit`: `'H:mm'` when true, else `'h:mm a'` (the spec's «٩:٤٠ م»). `time_helpers.dart` is not reused: `format12h` needs a `BuildContext` and `to24hTime` ignores the locale.
24. **`jumpTo` with a focus.** A banner focus (`ayah == 0`) counts as no focus on both branches. Same page with a focus → `select(focus)` only (`jumpFrom` and `pageAyahs` unchanged). Same page without one → today's rule. Another page → today's jump, then `emit(state.copyWith(selectedAyah: focus))`.
25. **SnackBars raised in the places sheet show inside it.** The sheet body sits in its own `ScaffoldMessenger` + `Scaffold(backgroundColor: Colors.transparent)`, so «تراجع» is above the modal barrier. On the Bookmarks page the page's own messenger is the nearest one.
26. **Errors clear on the next successful write.** Every successful write in both cubits emits with `clearError: true`.

## Review Focus

1. **Old data that is odd.** Non-string ayah entries, `'5:0'`, `'2:'`, page entries stored as strings, a page whose bounds yield no ayah, the same ayah in both lists, and a crash before the flag. Task 2 pins each, plus a twice-run.
2. **The banner (ayah 0) is never a place.** `FasilCubit.move` and `SavedAyatCubit.save` ignore ayah 0; the banner leaf shows neither «فاصل» nor «حفظ الآية». Tasks 3 and 8 pin it.
3. **Undo after more changes.** Undo of a move restores the exact previous record even after a rename; undo of a removal restores `id` and `createdAt`. Task 3 pins both.
4. **No فاصل placed yet.** No cluster is drawn and no tap is swallowed at the corner; chooser rows read «غير موضوع» with no «انتقال». Tasks 5 and 6 pin it.
5. **Large text (2×) in 360 px.** The four-column leaf, the chooser and the places sheet lay out without overflow. Tasks 5, 7a and 8 pump each at `TextScaler.linear(2.0)` and assert no exception.
6. **Page overlays under either direction.** Scroll mode inherits the app's direction; the cluster, strips, tails and dot must not move under English. Tasks 5 and 6 pin it under both `Directionality`s, plus the tail clamp below the cluster and the stacking of tails on one line.

## Out of slice

- S5: tafsir, «تفسير الآية», the full detent; «مشاركة» stays in the S4 action row.
- Design-only details the spec does not adopt: ayah strips in saved rows, the chooser's «إدارة الفواصل» link, the banner's «نقل فاصل إلى بداية السورة», the margin pencil bar and the deutan ΔE tuning.

---

### Task 1: Place entity, Hive record, data source and repository

**Files:**
- Create: `lib/features/bookmarks/domain/entities/fasil_slot.dart`, `lib/features/bookmarks/domain/entities/place.dart`
- Create: `lib/features/bookmarks/domain/repositories/places_repository.dart`
- Create: `lib/features/bookmarks/domain/usecases/get_places.dart`, `save_place.dart`, `remove_place.dart`
- Create: `lib/features/bookmarks/data/models/place_record_model.dart` (+ generated `place_record_model.g.dart`)
- Create: `lib/features/bookmarks/data/datasources/local/places_local_data_source.dart`
- Create: `lib/features/bookmarks/data/repositories/places_repository_impl.dart`
- Modify: `lib/config/hive_config.dart`, `lib/hive_registrar.g.dart` (regenerated), `lib/features/bookmarks/bookmarks_di.dart`
- Create (tests): `test/features/bookmarks/data/models/place_record_model_test.dart`, `test/features/bookmarks/data/datasources/local/places_local_data_source_test.dart`, `test/features/bookmarks/data/repositories/places_repository_impl_test.dart`

**Interfaces:**
- Produces:
  - `enum FasilSlot { wird, hifz, muraja }` (index = stored `slot`).
  - `class Place extends Equatable { const Place({required String id, required AyahIdentifier ayah, required int page, FasilSlot? slot, String? name, required DateTime createdAt, required DateTime updatedAt, bool migrated = false}); Place copyWith({AyahIdentifier? ayah, int? page, String? name, bool clearName = false, DateTime? updatedAt}); }` with every field in `props`.
  - `abstract class PlacesRepository { Future<Either<Failure, List<Place>>> getAll(); Future<Either<Failure, Unit>> save(Place place); Future<Either<Failure, Unit>> remove(String id); }`
  - Use cases (bookmarks style, no `UseCase` base): `GetPlaces(repo).call()`, `SavePlace(repo).call(Place)`, `RemovePlace(repo).call(String id)`.
  - `@HiveType(typeId: 6) class PlaceRecordModel extends HiveObject` fields `@HiveField(0) String id`, `(1) int surah`, `(2) int ayah`, `(3) int page`, `(4) int? slot`, `(5) String? name`, `(6) DateTime createdAt`, `(7) DateTime updatedAt`, `(8) bool migrated`; `factory PlaceRecordModel.fromEntity(Place)`, `Place toEntity()`. A `slot` outside 0–2 maps to a saved ayah (`slot: null`).
  - `class PlacesLocalDataSource { PlacesLocalDataSource({required this.box}); final Box<PlaceRecordModel> box; List<Place> getAll(); Future<void> save(Place place); Future<void> remove(String id); }` keyed by `place.id`; write failures throw `CacheException`.
  - Boxes: `Hive.openBox<PlaceRecordModel>('places')`, `Hive.openBox<bool>('places_meta')` (user data, plain `Hive.openBox`, not `_openCacheBox`).
  - DI: `PlacesLocalDataSource`, `PlacesRepository`, `GetPlaces`, `SavePlace`, `RemovePlace` lazy singletons.

- [ ] **Step 1: Write the failing tests** (Hive in a temp dir as in `test/features/surah/data/repositories/last_read_repository_impl_test.dart`; register `PlaceRecordModelAdapter` in `setUpAll`)

- `place_record_model_test.dart`: `'round-trips a فاصل through the entity'` (slot hifz, name «حفظ رمضان», migrated false → `toEntity()` equals the original `Place`); `'a record with no slot is a saved ayah'`; `'an unknown slot index reads as a saved ayah'` (slot 7 → `slot == null`); `'survives a box close and reopen'` (put, close, reopen, `toEntity()` equal).
- `places_local_data_source_test.dart`: `'starts empty'`; `'save then getAll returns the place'`; `'saving the same id replaces it'` (two saves, one record, the second's ayah); `'remove deletes by id'`; `'remove of an unknown id is a no-op'`.
- `places_repository_impl_test.dart` (data source mocked with mocktail): `'getAll wraps the list in Right'`; `'a CacheException on save becomes CacheFailure'`; `'an unexpected error on remove becomes a Failure, never a throw'`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/data`. Expected: FAIL (`Place` undefined).

- [ ] **Step 3: Implement**

- Entities, repository, use cases and data source as in Interfaces; `PlacesRepositoryImpl({required this.dataSource})`, every method shaped `try { … return Right(…); } on CacheException catch (e) { return Left(CacheFailure(e.message)); } catch (e) { return Left(Failure.fromException(e)); }` (`BookmarkRepositoryImpl` has only the first `on`; the generic `catch` follows `quran_playback_repo_impl.dart:342-343`).
- `dart run build_runner build --delete-conflicting-outputs`. Expected: `place_record_model.g.dart` created and `lib/hive_registrar.g.dart` gains `PlaceRecordModelAdapter` in both extensions; `git status` shows no other `.g.dart` change (if one does, `git checkout --` it).
- `hive_config.dart`: `Hive.registerAdapter(PlaceRecordModelAdapter());` then open `places` and `places_meta` after the bookmark boxes.
- `bookmarks_di.dart`: register the new singletons beside the old ones (Task 8 removes the old).

- [ ] **Step 4: Run** `flutter test test/features/bookmarks`, then `flutter analyze --no-fatal-infos`. Expected: PASS, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/domain/entities/fasil_slot.dart lib/features/bookmarks/domain/entities/place.dart lib/features/bookmarks/domain/repositories/places_repository.dart lib/features/bookmarks/domain/usecases/get_places.dart lib/features/bookmarks/domain/usecases/save_place.dart lib/features/bookmarks/domain/usecases/remove_place.dart lib/features/bookmarks/data/models/place_record_model.dart lib/features/bookmarks/data/models/place_record_model.g.dart lib/features/bookmarks/data/datasources/local/places_local_data_source.dart lib/features/bookmarks/data/repositories/places_repository_impl.dart lib/config/hive_config.dart lib/hive_registrar.g.dart lib/features/bookmarks/bookmarks_di.dart test/features/bookmarks/data/models/place_record_model_test.dart test/features/bookmarks/data/datasources/local/places_local_data_source_test.dart test/features/bookmarks/data/repositories/places_repository_impl_test.dart
git commit -m "feat(bookmarks): typed places store (Place, PlaceRecordModel typeId 6, box places)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: PlaceMigration (idempotent, count-verified, flag in places_meta)

**Files:**
- Create: `lib/features/bookmarks/data/datasources/local/place_migration.dart`
- Create: `lib/features/bookmarks/domain/usecases/migrate_places.dart`
- Modify: `lib/features/bookmarks/domain/repositories/places_repository.dart`, `lib/features/bookmarks/data/repositories/places_repository_impl.dart`, `lib/features/bookmarks/bookmarks_di.dart`, `lib/main.dart`
- Create (test): `test/features/bookmarks/data/datasources/local/place_migration_test.dart`
- Modify (test): `test/features/bookmarks/data/repositories/places_repository_impl_test.dart` (created in Task 1)

**Interfaces:**
- Consumes: `Place`, `PlaceRecordModel`, `FasilSlot` (Task 1); `GetMushafPage` (surah domain); `QuranPageService.getPageForAyah`.
- Produces:
  - `class PlaceMigration { PlaceMigration({required Box<PlaceRecordModel> places, required Box<bool> meta, required Box<List> ayahBookmarks, required Box<List> pageBookmarks, required Future<AyahIdentifier?> Function(int page) firstAyahOfPage, required int Function(AyahIdentifier ayah) pageOf, DateTime Function() now = DateTime.now}); static const flag = 'migratedV1'; static int? parsePage(Object? e); static AyahIdentifier? parseAyahKey(Object? e); static List<Place> plan({required List<Object?> ayahKeys, required List<Object?> pages, required Map<int, AyahIdentifier> firstAyahs, required int Function(AyahIdentifier ayah) pageOf, required DateTime now}); Future<int> run(); }`
  - `PlacesRepository.migrate() → Future<Either<Failure, Unit>>`; `MigratePlaces(repo).call()`.

- [ ] **Step 1: Write the failing tests**

`plan` (pure, `now = DateTime(2026, 11, 21, 9)`, `pageOf: (a) => quran.getPageNumber(a.surah, a.ayah)`):
- `'ayah bookmarks become saved ayat in stored order'`: `ayahKeys ['2:5', '3:8']` → two places, `slot == null`, `migrated == true`, ayahs 2:5 then 3:8, `createdAt` `now` then `now − 1 µs`, `updatedAt == createdAt`, `id == createdAt.microsecondsSinceEpoch.toString()`, `page` 2 and 50 (page 50 holds 3:1–3:9).
- `'banner entries are dropped'`: `['5:0', '1:1']` → only 1:1, at index 0's time.
- `'page bookmarks map to the first ayah on the page'`: `pages [106]`, `firstAyahs {106: 4:176}` → one place at 4:176, `page == 106`.
- `'a page with no resolvable ayah is dropped'`: `pages [106]`, `firstAyahs {}` → empty.
- `'an ayah in both lists is kept once'`: `ayahKeys ['4:176']`, `pages [106]` → one place.
- `'malformed entries are skipped'`: `ayahKeys ['x', 7, '2:', '2:5']`, `pages ['12', 'abc']`, `firstAyahs {12: 2:77}` → 2:5 and 2:77.

`run` (temp-dir Hive; old boxes seeded under key `'all'`, as the old data sources wrote them; `firstAyahOfPage: (p) async => {106: 4:176}[p]`):
- `'run writes the plan, sets the flag and returns the count'`: seed `['2:5']` / `[106]` → returns 2, `places.length == 2`, `meta.get('migratedV1') == true`.
- `'a second run changes nothing'`: two runs → second returns 0, same ids.
- `'a run interrupted before the flag never duplicates'`: run, `meta.delete('migratedV1')`, put one reader record (`migrated: false`) at 3:8, run again → 2 migrated records plus the reader's one.
- `'a reader save made after a failed run is not migrated again'`: run, `meta.delete('migratedV1')`, delete the migrated 2:5 record, put a reader record (`slot: null, migrated: false`) at 2:5, run again → exactly one record at 2:5 (the reader's), plus the migrated 4:176.
- `'parsePage and parseAyahKey'`: `parsePage(12) == 12`, `parsePage('12') == 12`, `parsePage('abc') == null`; `parseAyahKey('2:5') == 2:5`, `parseAyahKey('5:0')`, `parseAyahKey('2:')`, `parseAyahKey(7)` are null.
- `'old boxes are left intact'`: old box contents equal before and after.
- `'nothing to migrate still sets the flag'`: empty old boxes → returns 0, flag true.
- Repository: `'migrate maps a throw from the migration to a Failure'`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/data`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `parseAyahKey`: a `String` `'s:a'` split on `:` into two ints with `a > 0`, else null. `parsePage`: an `int`, or `int.tryParse('$e')`. Both `plan` and `run` use them; nothing else parses old entries.
- `plan`: parse with the two helpers, map pages through `firstAyahs`, dedupe on `AyahIdentifier` keeping the first, then build places with `createdAt = now.subtract(Duration(microseconds: i))`.
- `run`: return 0 when the flag is set; read `ayahBookmarks.get('all') ?? []` and `pageBookmarks.get('all') ?? []`; await `firstAyahOfPage` for each distinct `parsePage` result; `plan`; drop planned places whose ayah already has a record with `slot == null && !migrated` (Deliberate reading 3); `places.deleteAll(` keys of records with `migrated` `)`; `places.putAll({for (p in planned) p.id: PlaceRecordModel.fromEntity(p)})`; verify every planned id is present and the migrated-record count equals `planned.length`, else `throw CacheException('place migration count mismatch')`; then `meta.put(flag, true)`; return `planned.length`.
- `PlacesRepositoryImpl` takes `required PlaceMigration migration`; `migrate()` → `Right(unit)` or a `Failure`.
- DI: `PlaceMigration` lazy singleton with `Hive.box<PlaceRecordModel>('places')`, `Hive.box<bool>('places_meta')`, `Hive.box<List>('ayah_bookmarks')`, `Hive.box<List>('page_bookmarks')`, `firstAyahOfPage: (p) async => (await sl<GetMushafPage>()(p)).fold((_) => null, (e) => e.ayahs.where((b) => b.ayah.ayah > 0).firstOrNull?.ayah)`, `pageOf: (a) => sl<QuranPageService>().getPageForAyah(a.surah, a.ayah)`; `MigratePlaces` lazy singleton.
- `main.dart` `_initAll`: `await sl<MigratePlaces>()();` right after `await initGetIt();` (result ignored, Deliberate reading 4).

- [ ] **Step 4: Run** `flutter test test/features/bookmarks`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/data/datasources/local/place_migration.dart lib/features/bookmarks/domain/usecases/migrate_places.dart lib/features/bookmarks/domain/repositories/places_repository.dart lib/features/bookmarks/data/repositories/places_repository_impl.dart lib/features/bookmarks/bookmarks_di.dart lib/main.dart test/features/bookmarks/data/datasources/local/place_migration_test.dart test/features/bookmarks/data/repositories/places_repository_impl_test.dart
git commit -m "feat(bookmarks): migrate ayah and page bookmarks into places once

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: FasilCubit and SavedAyatCubit (app-wide)

**Files:**
- Create: `lib/features/bookmarks/presentation/cubit/fasil_cubit.dart`, `fasil_state.dart`, `saved_ayat_cubit.dart`, `saved_ayat_state.dart`
- Create: `test/features/bookmarks/place_fakes.dart` (shared fakes, not a test file)
- Modify: `lib/features/bookmarks/bookmarks_di.dart`, `lib/main.dart`, `.claude/rules/architecture.md`
- Create (tests): `test/features/bookmarks/presentation/cubit/fasil_cubit_test.dart`, `test/features/bookmarks/presentation/cubit/saved_ayat_cubit_test.dart`

**Interfaces:**
- Consumes: `GetPlaces`, `SavePlace`, `RemovePlace`, `Place`, `FasilSlot` (Task 1); `QuranPageService`.
- Produces:
  - `class FasilState extends Equatable { const FasilState({this.slots = const {}, this.loaded = false, this.error}); final Map<FasilSlot, Place> slots; final bool loaded; final String? error; List<Place> onPage(int page); FasilState copyWith({Map<FasilSlot, Place>? slots, bool? loaded, String? error, bool clearError = false}); }` (`onPage` in `FasilSlot.values` order; `error` is `failure.message`).
  - `class FasilCubit extends Cubit<FasilState> { FasilCubit({required GetPlaces getPlaces, required SavePlace savePlace, required RemovePlace removePlace, required QuranPageService pageService, DateTime Function() now = DateTime.now}); Future<({Place? previous, Place moved})?> move(FasilSlot slot, AyahIdentifier ayah); Future<void> restore(FasilSlot slot, Place? previous); Future<void> rename(FasilSlot slot, String name); }` (loads in the constructor).
  - `class SavedAyatState extends Equatable { const SavedAyatState({this.items = const [], this.loaded = false, this.error}); final List<Place> items; final bool loaded; final String? error; Place? find(AyahIdentifier ayah); bool contains(AyahIdentifier ayah); SavedAyatState copyWith({List<Place>? items, bool? loaded, String? error, bool clearError = false}); }` (`items` newest `createdAt` first).
  - `class SavedAyatCubit extends Cubit<SavedAyatState> { SavedAyatCubit({required GetPlaces getPlaces, required SavePlace savePlace, required RemovePlace removePlace, required QuranPageService pageService, DateTime Function() now = DateTime.now}); Future<Place?> save(AyahIdentifier ayah); Future<void> remove(Place place); Future<void> restore(Place place); }`
  - `place_fakes.dart`: `class InMemoryPlacesRepository implements PlacesRepository` (a `Map<String, Place>`, optional `failNext`), `class FakeFasilCubit extends Cubit<FasilState> implements FasilCubit` (`FakeFasilCubit([FasilState initial = const FasilState(loaded: true)])`; records `moves` `List<(FasilSlot, AyahIdentifier)>`, `restores` `List<(FasilSlot, Place?)>`, `renames` `List<(FasilSlot, String)>`; `move` returns `(previous: state.slots[slot], moved: <a place at the ayah>)` and emits it) and `class FakeSavedAyatCubit extends Cubit<SavedAyatState> implements SavedAyatCubit` (`FakeSavedAyatCubit([SavedAyatState initial = const SavedAyatState(loaded: true)])`; records `saves` `List<AyahIdentifier>`, `removes` and `restores` `List<Place>`; `save` returns a new place and emits it). Both end with `dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);` like the harness fakes. Builders every later test uses to seed state: `Place fasilPlace(FasilSlot slot, AyahIdentifier ayah, {String? name, DateTime? at})` and `Place savedPlace(AyahIdentifier ayah, {DateTime? at, bool migrated = false})` (`page` from `quran.getPageNumber`, `at` defaults to `DateTime(2026, 11, 14, 8)`, `id` from `at`).

- [ ] **Step 1: Write the failing tests** (`bloc_test`, `InMemoryPlacesRepository`, a fixed clock that advances 1 minute per call, page service stub `getPageForAyah → quran.getPageNumber`)

`fasil_cubit_test.dart`:
- `'loads only placed slots'`: repo holds a hifz فاصل and a saved ayah → `slots == {hifz: …}`, `loaded`.
- `'two records on one slot keep the latest updatedAt'`.
- `'move places an unset slot'`: `move(wird, 2:5)` → `previous == null`, `moved.page == 2`, `createdAt == updatedAt`, `id == createdAt.microsecondsSinceEpoch.toString()`.
- `'move keeps id, createdAt and name, updates ayah, page and updatedAt'`.
- `'move ignores the banner'`: `move(wird, 5:0)` → null, no emit, repo unchanged.
- `'restore with null deletes the slot'`; `'restore brings back the exact previous record even after a rename'`.
- `'rename trims; blank resets to the default name'`: `rename(hifz, '  حفظ رمضان ')` → `name == 'حفظ رمضان'`; `rename(hifz, '   ')` → `name == null`; rename of an unset slot does nothing.
- `'rename keeps updatedAt'` (Deliberate reading 21): the clock advances, `rename(hifz, 'x')` → `updatedAt` unchanged.
- `'a failing save emits the error and keeps the slots'`; `'a success after a failure clears the error'` (`failNext`, `move` → `error != null`; `move` again → `error == null`).

`saved_ayat_cubit_test.dart`:
- `'loads saved ayat newest first, skipping فواصل'`.
- `'save adds a dated, unmigrated place at the top'`.
- `'save of an ayah already saved returns null'`; `'save ignores the banner'`.
- `'remove then restore keeps id and createdAt'`.
- `'contains and find look up by ayah'`.
- `'a success after a failure clears the error'`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/presentation/cubit`. Expected: FAIL.

- [ ] **Step 3: Implement**

- Each mutating method returns early when `!state.loaded`, writes through the use case, then (after `isClosed`) emits `copyWith(slots:/items: <new>, clearError: true)` on success or `copyWith(error: failure.message)` on failure (Deliberate reading 26). `rename` saves `place.copyWith(name: …)` or `copyWith(clearName: true)` and never touches `updatedAt`.
- DI: both as lazy singletons with `pageService: sl<QuranPageService>()`.
- `main.dart`: `BlocProvider(create: (_) => sl<FasilCubit>())` and `BlocProvider(create: (_) => sl<SavedAyatCubit>())` after `PageBookmarkCubit` (the old providers stay until Task 8).
- `architecture.md` app-wide list: add `FasilCubit`, `SavedAyatCubit`.

- [ ] **Step 4: Run** `flutter test test/features/bookmarks`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/presentation/cubit/fasil_cubit.dart lib/features/bookmarks/presentation/cubit/fasil_state.dart lib/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart lib/features/bookmarks/presentation/cubit/saved_ayat_state.dart lib/features/bookmarks/bookmarks_di.dart lib/main.dart .claude/rules/architecture.md test/features/bookmarks/place_fakes.dart test/features/bookmarks/presentation/cubit/fasil_cubit_test.dart test/features/bookmarks/presentation/cubit/saved_ayat_cubit_test.dart
git commit -m "feat(bookmarks): FasilCubit and SavedAyatCubit with undoable writes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Ribbon colours with contrast gates, chooserPreselect, place labels

**Files:**
- Modify: `lib/features/surah/presentation/utils/mushaf_paper_colors.dart`
- Create: `lib/features/bookmarks/presentation/utils/fasil_rules.dart`, `lib/features/bookmarks/presentation/utils/enum_localization.dart`, `lib/features/bookmarks/presentation/utils/place_labels.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`
- Modify (test): `test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart` (exists; its `for (final p in MushafPaper.values)` groups gain the ribbon cases)
- Create (tests): `test/features/bookmarks/presentation/utils/fasil_rules_test.dart`, `test/features/bookmarks/presentation/utils/place_labels_test.dart`

**Interfaces:**
- Consumes: `FasilSlot`, `Place` (Task 1).
- Produces:
  - `Color fasilRibbon(FasilSlot slot, {required bool dark})`: light papers (`dark: false`) wird `#8A2F3B`, hifz `#1F5A8A`, muraja `#835F0F`; dark wird `#E39AA2`, hifz `#8EBBE3`, muraja `#E2B85C`. `extension on MushafPaper`: `Color ribbon(FasilSlot slot) => fasilRibbon(slot, dark: isDark)` (inside `MushafPaperX`).
  - `FasilSlot chooserPreselect({required Map<FasilSlot, Place> slots, required int page, required AyahIdentifier at})` (Deliberate readings 12, 13).
  - In `fasil_rules.dart`: `const fasilClusterHeight = 56.0;`, `const fasilTailHeight = 88.0;`, `double fasilRibbonX(FasilSlot slot) => 4 + 14.0 * slot.index;` and `List<double> layoutTailTops(List<double> wanted, {required double pageHeight})` (Deliberate reading 9: `wanted` already sorted; clamp ≥ `fasilClusterHeight`, stack with gap `fasilTailHeight`, push up from `pageHeight − fasilTailHeight`).
  - `extension FasilSlotLocalization on FasilSlot { String localized(BuildContext context); }` and `String fasilName(BuildContext context, FasilSlot slot, Place? place) => place?.name ?? slot.localized(context)`.
  - `String ayahPlace(BuildContext context, AyahIdentifier ayah)` → «آل عمران ٦» (`surahDisplayName` + space + localized ayah).
  - `String placeWhen(DateTime at, {required DateTime now, required String localeCode, bool use24h = false})` (Deliberate readings 19, 23; time `DateFormat(use24h ? 'H:mm' : 'h:mm a', localeCode)`, date `DateFormat('d MMMM', localeCode)` / `'d MMMM y'`, then `toIndicNumerals(localeCode)`; the «اليوم» / «أمس» wrappers come from `PendingS.forLanguage(localeCode).places_today(time)` / `.places_yesterday(time)`, never `PendingS.current`, which reads the global `Intl` locale).
  - Strings: `fasil_wird` «الورد» / 'Wird'; `fasil_hifz` «الحفظ» / 'Memorisation'; `fasil_muraja` «المراجعة» / 'Review'; `places_position(place, page)` «$place، صفحة $page» / '$place, page $page'; `places_today(time)` «اليوم $time» / 'Today $time'; `places_yesterday(time)` «أمس $time» / 'Yesterday $time'; `fasil_movedAt(when)` «نُقل $when» / 'Moved $when'; `savedAyat_savedAt(when)` «حُفظت $when» / 'Saved $when'.

- [ ] **Step 1: Write the failing tests**

- `mushaf_paper_contrast_test.dart`, inside each paper's group, for every `FasilSlot`: `'ribbon <slot> on background is at least 3'` (`contrast(p.ribbon(s), c.background) >= 3`) and `'tail text on ribbon <slot> is at least 4.5'` (`contrast(c.background, p.ribbon(s)) >= 4.5`). Plus `'ribbons follow the paper darkness'`: `MushafPaper.night.ribbon(FasilSlot.hifz) == fasilRibbon(FasilSlot.hifz, dark: true)`.
- `fasil_rules_test.dart` (places built with `quran.getPageNumber`):
  - `'the slot on this page wins'`: hifz at 3:6 (p.50), wird at 2:5 → `at 3:10, page 50` → hifz.
  - `'two on this page: the last at or before the ayah'`: wird 3:4, hifz 3:6 (both p.50, which holds 3:1–3:9) → at 3:5 → wird; at 3:7 → hifz; at 3:2 (both after) → wird, the first on the page.
  - `'else the nearest preceding'`: wird 2:5 (p.2), hifz 2:102 (p.16), at 3:7 (p.50) → hifz.
  - `'else the last used'`: wird 5:1 (updated day 1), hifz 10:1 (updated day 2), at 2:5 → hifz.
  - `'nothing placed gives الورد'`.
  - `'layoutTailTops'`: `[200]`, height 700 → `[200]`; `[10]` → `[56]` (below the cluster); `[200, 200]` → `[200, 288]` (same line stacks); `[200, 230, 250]` → `[200, 288, 376]`; `[650, 650]` → `[524, 612]` (pushed up from 700 − 88).
  - `'fasilRibbonX'`: wird 4, hifz 18, muraja 32.
- `place_labels_test.dart` (`initializeDateFormatting('ar')` and `'en'` in `setUpAll`; `now = DateTime(2026, 11, 21, 12)`):
  - `'today'`: `placeWhen(DateTime(2026, 11, 21, 6, 10), now: now, localeCode: 'ar') == 'اليوم ٦:١٠ ص'`.
  - `'yesterday by calendar day, even under 24 hours'`: `DateTime(2026, 11, 20, 21, 40)` → `'أمس ٩:٤٠ م'`.
  - `'older this year'`: `DateTime(2026, 11, 14, 8)` → `'١٤ نوفمبر'`; `'another year adds it'`: `DateTime(2025, 11, 14)` → `'١٤ نوفمبر ٢٠٢٥'`.
  - `'english'`: `DateTime(2026, 11, 21, 6, 10)` with `'en'` → `'Today 6:10 AM'` (run with the default `Intl` locale, so a `PendingS.current` mistake shows).
  - `'24-hour clock'`: `DateTime(2026, 11, 20, 21, 40)`, `use24h: true`, `'ar'` → `'أمس ٢١:٤٠'`.
  - Widget test `'ayahPlace and fasilName read the locale'`: Arabic `ayahPlace(context, 3:6) == 'آل عمران ٦'`; `fasilName(context, FasilSlot.hifz, null) == 'الحفظ'`; a place named «حفظ رمضان» returns its name.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart test/features/bookmarks/presentation/utils`. Expected: FAIL.

- [ ] **Step 3: Implement** the Interfaces; strings in both ARBs and `PendingS`. If any gate fails with these values, nudge the failing hex's lightness only and record it in the report. `feature-widgets.md` → Presentation utils: `surah` `mushaf_paper_colors.dart` adds `ribbon` and `fasilRibbon`; `bookmarks` lists `fasil_rules.dart` (`chooserPreselect`, `layoutTailTops`, `fasilRibbonX`), `enum_localization.dart` (`FasilSlot.localized`), `place_labels.dart` (`fasilName`, `ayahPlace`, `placeWhen`).

- [ ] **Step 4: Run** the Step 2 command, `flutter test test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS; 0 errors, 0 warnings, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/utils/mushaf_paper_colors.dart lib/features/bookmarks/presentation/utils/fasil_rules.dart lib/features/bookmarks/presentation/utils/enum_localization.dart lib/features/bookmarks/presentation/utils/place_labels.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart test/features/bookmarks/presentation/utils/fasil_rules_test.dart test/features/bookmarks/presentation/utils/place_labels_test.dart
git commit -m "feat(mushaf): ribbon colours with contrast gates, chooser preselect, place labels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: FasilChooser and FasilRibbonCluster / FasilTailTab widgets

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/fasil_chooser.dart`
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Create (tests): `test/features/surah/presentation/pages/mushaf/widgets/fasil_chooser_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster_test.dart`

**Interfaces:**
- Consumes: `fasilRibbon`, `MushafPaperX.ribbon`, `fasilName`, `ayahPlace`, `fasilRibbonX`, `fasilClusterHeight`, `fasilTailHeight`, `PendingS.places_position` (Task 4); `Place`, `FasilSlot`.
- Produces:
  - `sealed class FasilChoice extends Equatable`; `final class FasilGo extends FasilChoice { const FasilGo(this.place); }`; `final class FasilMoveHere extends FasilChoice { const FasilMoveHere(this.slot); }`.
  - `FasilChooser({required Map<FasilSlot, Place> slots, AyahIdentifier? selected, FasilSlot? preselect})`; `static Future<FasilChoice?> show(BuildContext context, {required Map<FasilSlot, Place> slots, AyahIdentifier? selected, FasilSlot? preselect})` (`showModalBottomSheet`, `showDragHandle`, `isScrollControlled`, `useSafeArea`; app colours).
  - Keys: `fasil-row-<slot.name>`, `fasil-go-<slot.name>`, `fasil-move-<slot.name>`.
  - `FasilRibbonCluster({required Map<FasilSlot, String> placed, required MushafPaper paper, required VoidCallback onTap})` (key `fasil-cluster`; 48×56; draws only `placed` keys, each at `fasilRibbonX(slot)` from its left edge, Deliberate reading 8; `Tooltip` `fasil_title`, `Semantics(button: true, label: fasil_clusterLabel(names joined «، »))`).
  - `FasilTailTab({required FasilSlot slot, required String name, required MushafPaper paper, required VoidCallback onTap})` (key `fasil-tail-<slot.name>`; a 48 × `fasilTailHeight` opaque hit box; the 22 px label at `left: max(0, fasilRibbonX(slot) + 12 − 22)` per Deliberate reading 9; end shapes: wird V notch, hifz V point, muraja square; `Semantics(button: true, label: name)`).
  - `FasilStrip({required FasilSlot slot, required MushafPaper paper})` (key `fasil-strip-<slot.name>`; `IgnorePointer` around a `CustomPaint` that fills its box with `paper.ribbon(slot)` plus the centre stitch, sharing the cluster's painter code).
  - Strings: `fasil_title` «الفواصل» / 'Markers'; `fasil_notPlaced` «غير موضوع» / 'Not placed'; `fasil_moveHere` «نقل إلى هنا» / 'Move here'; `fasil_moveNamedHere(name)` «نقل $name إلى هنا» / 'Move $name here'; `fasil_placeHere` «ضع هنا» / 'Place here'; `fasil_placeNamedHere(name)` «ضع $name هنا» / 'Place $name here'; `fasil_clusterLabel(names)` «الفواصل: $names» / 'Markers: $names'.

- [ ] **Step 1: Write the failing tests** (Arabic locale; hifz placed at 3:6 p.50 unless stated)

`fasil_chooser_test.dart`:
- `'three rows in fixed order'`: the `fasil-row-*` widgets' `dy` increase wird → hifz → muraja; wird and muraja read «غير موضوع», hifz reads «الحفظ» and «آل عمران ٦، صفحة ٥٠».
- `'a placed row goes there'`: tapping `fasil-go-hifz` («انتقال») pops `FasilGo(hifzPlace)`; unset rows have no `fasil-go-*`.
- `'without a selection nothing moves'`: no `fasil-move-*`.
- `'with a selection placed rows move and unset rows place'`: `selected: 2:5` → `fasil-move-hifz` reads «نقل إلى هنا», `fasil-move-wird` reads «ضع هنا»; tapping `fasil-move-wird` pops `FasilMoveHere(FasilSlot.wird)`.
- `'the preselected row names its slot and is the only filled button'`: `preselect: hifz` → «نقل الحفظ إلى هنا» in a `FilledButton`; the other move buttons are `OutlinedButton`s.
- `'a renamed slot shows its name'`: hifz named «حفظ رمضان».
- `'fits at 2x text'`: 360 px wide, `TextScaler.linear(2.0)`, selection + preselect → no exception.

`fasil_ribbon_cluster_test.dart`:
- `'draws nothing when no فاصل is placed'`: `placed: {}` → `SizedBox.shrink`, a tap at its spot does not call `onTap`.
- `'one tap target labelled with the placed names'`: `placed {wird: 'الورد', muraja: 'المراجعة'}` → size 48×56; semantics label «الفواصل: الورد، المراجعة»; tap calls `onTap`.
- `'the tail tab prints its name and is 48 by 88'`: «الحفظ» found, `tester.getSize(find.byKey(fasil-tail-hifz)) == Size(48, 88)`; tap calls `onTap`.
- `'the tail label sits under its ribbon'`: for muraja, the label's left edge is 22 px from the tab's left edge (wird 0, hifz 8), checked in both an RTL and an LTR `Directionality`.
- `'a long name ellipsizes inside the tab'`: name «حفظ سورة البقرة كاملة» → no exception, tab still 48×88.
- `'tail text uses the paper background'`: the `Text` colour equals `MushafPaper.sepia.colors.background`.
- `'the strip ignores taps'`: a `FasilStrip` over a `GestureDetector` → tapping the strip reaches the detector.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/fasil_chooser_test.dart test/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

- Chooser: header `fasil_title` `TS.bold16`; each row a `SurfaceCard`-free `Padding` row ≥ 56 high: a 12×24 rounded swatch `fasilRibbon(slot, dark: scheme.brightness == Brightness.dark)`, a column with `fasilName` (`TS.bold14`) over the position or «غير موضوع» (`TS.medium14`, `onSurfaceVariant`), then «انتقال» `TextButton` (placed only) and, with a selection, the move/place button (`FilledButton` for `preselect`, else `OutlinedButton`, ≥ 48). Buttons `Navigator.pop(context, choice)`.
- Cluster: `CustomPaint` ribbons 12 px wide, 44 px long, 8 px notch, a 1 px centre stitch in `paper.colors.background` at alpha 0.45, the drop shadow of the old `_RibbonPainter`; wrapped in `PrettierTap`-free `GestureDetector(behavior: opaque)`.
- Tail: a `SizedBox(48, fasilTailHeight)` `GestureDetector(behavior: opaque)` holding a `Stack` with the label `Positioned(left: …, top: 0, bottom: 0, width: 22)`: `CustomPaint` for the end shape behind a `RotatedBox` label `TS.bold14` in `paper.colors.background`, `maxLines: 1`, `overflow: TextOverflow.ellipsis`, `softWrap: false`. Physical `left`, never `start` (Deliberate reading 8).
- Strip: the cluster's ribbon painter reused with no notch, filling the given size.

- [ ] **Step 4: Run** the Step 2 command, `flutter test test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS; 0 errors, 0 warnings, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/fasil_chooser.dart lib/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/fasil_chooser_test.dart test/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster_test.dart
git commit -m "feat(mushaf): فاصل chooser, ribbon cluster, strips and tail tabs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Ribbons on the page, the chooser in the reader, MushafPageRibbon deleted

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`, `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart`, `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_follow_test.dart`
- Create (test): `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_places_test.dart`

**Interfaces:**
- Consumes: `FasilCubit` (`state.slots`, `move`, `restore`), `SavedAyatCubit` (`state.items`), `FakeFasilCubit`, `FakeSavedAyatCubit`, `fasilPlace`, `savedPlace` (Task 3); `chooserPreselect`, `fasilName`, `ayahPlace`, `layoutTailTops`, `fasilRibbonX`, `fasilTailHeight` (Task 4); `FasilChooser`, `FasilGo`, `FasilMoveHere`, `FasilRibbonCluster`, `FasilTailTab`, `FasilStrip` (Task 5).
- Produces:
  - `MushafPageView({super.key, required int pageNumber, required void Function(FasilSlot? slot) onOpenFawasil})`.
  - `MushafCubit.jumpTo(int page, {AyahIdentifier? focus})` per Deliberate reading 24: `final f = focus == null || focus.ayah == 0 ? null : focus;` same page and `f != null` → `select(f)`, return; otherwise today's body, then `if (f != null) emit(state.copyWith(selectedAyah: f));`.
  - Harness: `typedef MushafHarness = ({FakePlayback playback, FakeSettings settings, FakeBookmarks bookmarks, FakeDownloads downloads, FakeScreenWake wake, StubLastReadRepo repo, FakeFasilCubit fawasil, FakeSavedAyatCubit saved});` and `pumpMushafPage(WidgetTester tester, MushafArgs args, {required MushafCubit mushaf, FakePlayback? playback, FakeSettings? settings, FakeFasilCubit? fawasil, FakeSavedAyatCubit? saved, LastRead? stored, bool pushed = false, double textScale = 1.0})`, defaulting to `FakeFasilCubit()` / `FakeSavedAyatCubit()`, `addTearDown(close)` for both, both in `providers`. A test seeds state by passing `fawasil: FakeFasilCubit(FasilState(slots: {FasilSlot.hifz: fasilPlace(FasilSlot.hifz, 3:6)}, loaded: true))` or `saved: FakeSavedAyatCubit(SavedAyatState(items: [savedPlace(2:5)], loaded: true))`.
  - `_MushafPageState._openFawasil(FasilSlot? preselect)` and `_jumpInPlace(int page, {AyahIdentifier? focus})` (Task 8 calls both).
  - Strings: `fasil_moved(name, place)` «نُقل فاصل $name إلى $place» / 'Moved the $name marker to $place'; `fasil_placed(name, place)` «وُضع فاصل $name عند $place» / 'Placed the $name marker at $place'.
  - Keys: `saved-dot-<surah>:<ayah>`.

- [ ] **Step 1: Write the failing tests**

- `mushaf_cubit_auto_follow_test.dart`: `'jumpTo with focus selects it on the new page'` (`jumpTo(50, focus: 3:6)` → `currentPage 50`, `selectedAyah 3:6`, `jumpFrom` set); `'jumpTo the current page with focus only selects'` (with `jumpFrom` set beforehand: it is unchanged); `'jumpTo ignores a banner focus'` (another page, focus 5:0 → no selection); `'jumpTo the current page with a banner focus follows today's rule'` (on p.50, no `jumpFrom`, `jumpTo(50, focus: 3:0)` → no emit).
- `mushaf_page_follow_test.dart`: `_RecordingMushaf`'s override becomes `void jumpTo(int page, {AyahIdentifier? focus}) { jumps.add(page); super.jumpTo(page, focus: focus); }`; `expect(mushaf.jumps, [120])` stays.
- `mushaf_page_view_places_test.dart`: built on the `mushaf_page_view_tap_test.dart` scaffolding (same `pumpView` shape, 400×800 view, `Align(topLeft)`), with harness `FakeSettings()`, `FakeMushaf(const MushafState(currentPage: 50))`, `FakePlayback()` imported from `../mushaf_page_harness.dart`, plus `FasilCubit`/`SavedAyatCubit` fakes, and `GetMushafPage(_BoundsRepo())` registered in `setUp` like the tap test. `_BoundsRepo.getPage` returns `MushafPageEntity(pageNumber: 50, ayahs: [AyahBoundEntity(ayah: 3:1, lines: [NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05)]), AyahBoundEntity(ayah: 3:6, lines: [NormalizedRect(x: 0.1, y: 0.50, w: 0.8, h: 0.05), NormalizedRect(x: 0.1, y: 0.55, w: 0.8, h: 0.05)])])`. Default locale `en` (LTR, like the tap test):
  - `'no placed فاصل draws no cluster'`.
  - `'the cluster opens the chooser with no preselect'`: hifz on p.300 → `fasil-cluster` shown on p.50; tap → `onOpenFawasil(null)`.
  - `'the cluster and tails hug the left edge in either direction'`: hifz at 3:6, saved 3:1; under `Locale('en')` and again under `Locale('ar')`, `getTopLeft(fasil-cluster).dx` and `getTopLeft(fasil-tail-hifz).dx` equal `getTopLeft(find.byType(MushafPageView)).dx`, and `getTopRight(saved-dot-3:1).dx` is 6 px inside the page's right edge.
  - `'a فاصل on this page hangs its tail at the ayah line'`: hifz at 3:6 → `fasil-tail-hifz` present; its bottom equals `0.55 × page height` (±1); `fasil-strip-hifz` spans from the page top to the tail top; tapping the tail calls `onOpenFawasil(FasilSlot.hifz)`.
  - `'two فواصل on one ayah stack'`: wird and hifz at 3:6 → the hifz tail's top is the wird tail's top + 88.
  - `'a فاصل on the first line stays below the cluster'`: wird at 3:1 → the tail's top is 56.
  - `'a saved ayah on this page shows the dot'`: saved 3:1 → `saved-dot-3:1` present; a saved ayah on another page draws none.
- `mushaf_page_view_tap_test.dart`, `mushaf_page_view_load_error_test.dart`: replace the `PageBookmarkCubit` provider with `FakeFasilCubit` and `FakeSavedAyatCubit`; pass `onOpenFawasil: (_) {}`. Existing assertions unchanged.
- Harness: the signature in Interfaces; `FakeMushaf.jumpTo(int page, {AyahIdentifier? focus})` records `(page, focus)` in `jumps` (`final jumps = <(int, AyahIdentifier?)>[];`) and keeps today's emit; the shell test's two readers (lines 352 and 475) become `mushaf.jumps.map((j) => j.$1)`.
- `mushaf_page_shell_test.dart`:
  - `'انتقال in the chooser jumps in place with the ayah selected'`: hifz at 3:6 (p.50) on a reader at p.2; tap `fasil-cluster`, tap `fasil-go-hifz` → `mushaf.jumps.last == (50, 3:6)`.
  - `'moving a فاصل confirms and تراجع restores it'`: wird placed at 2:5; select 3:7 by `mushaf.push`; tap the cluster, tap `fasil-move-wird` → `fawasil.moves.last == (wird, 3:7)`, SnackBar «نُقل فاصل الورد إلى آل عمران ٧»; tap «تراجع» → `fawasil.restores.last == (wird, previousPlace)`.
  - `'placing an unset فاصل says وُضع'`: nothing placed except hifz elsewhere; select 2:5, cluster → `fasil-move-wird` → «وُضع فاصل الورد عند البقرة ٥».

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/cubit/mushaf test/features/surah/presentation/pages/mushaf`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `mushaf_page_view.dart`: drop `PageBookmarkCubit`, `S`, `_onRibbonTap` and the ribbon import. Inside the existing `LayoutBuilder` stack, after the tap `GestureDetector`, two selectors, each returning `Positioned.fill(child: Stack(children: …))` with physical positions only (Deliberate reading 8):
  - `BlocSelector<SavedAyatCubit, SavedAyatState, List<Place>>(selector: (s) => s.items, …)`: the list's identity changes only on a write, so pages do not rebuild on other emits. The builder keeps the items with `page == widget.pageNumber` and a bound in `entity.ayahs`, and draws `Positioned(right: 6, top: centre of the first line − 3, width: 6, height: 6)` `IgnorePointer` `colors.accent` dots keyed `saved-dot-<surah>:<ayah>`.
  - `BlocSelector<FasilCubit, FasilState, Map<FasilSlot, Place>>(selector: (s) => s.slots, …)`: the builder takes `slots.values.where((p) => p.page == widget.pageNumber)` with a bound, sorted by wanted top then `slot.index`, runs `layoutTailTops(wanted, pageHeight: constraints.maxHeight)`, and draws in order the `FasilStrip`s (`Positioned(left: fasilRibbonX(slot), top: 0, width: 12, height: t)`), the `FasilTailTab`s (`Positioned(left: 0, top: t, width: 48, height: fasilTailHeight)`, `onTap: () => widget.onOpenFawasil(slot)`), and, when `slots` is not empty, `Positioned(left: 0, top: 0, child: FasilRibbonCluster(placed: {for (final e in slots.entries) e.key: fasilName(context, e.key, e.value)}, paper: settings.mushafPaper, onTap: () => widget.onOpenFawasil(null)))`. Strips and tails need `entity`; the cluster does not.
- `mushaf_page.dart`: pass `onOpenFawasil: _openFawasil` in both `itemBuilder`s.
  - `_openFawasil(preselect)`: `selected` = `state.selectedAyah` when its `ayah > 0`; `pre = preselect ?? (selected == null ? null : chooserPreselect(slots: fawasil.state.slots, page: state.currentPage, at: selected))`; `await FasilChooser.show(…)`; `if (!mounted) return;` `FasilGo(:final place)` → `_jumpInPlace(place.page, focus: place.ayah)`; `FasilMoveHere(:final slot)` → `_moveFasil(slot, selected!)`.
  - `_moveFasil(slot, ayah)`: `final result = await fawasil.move(slot, ayah); if (!mounted || result == null) return;`; SnackBar (hide current first) with `fasil_placed` or `fasil_moved` (name `fasilName(context, slot, result.moved)`, place `ayahPlace`), action `S.undo` → `fawasil.restore(slot, result.previous)`. Strings via `PendingS.current` (callback).
  - `_jumpInPlace(int page, {AyahIdentifier? focus})`: today's body, passing `focus` to `_mushafCubit.jumpTo`; the return-chip call site keeps `_jumpInPlace(page)`.
- `mushaf_cubit.dart`: `jumpTo` per Interfaces.
- `git rm` the ribbon widget and its test.

- [ ] **Step 4: Run** the Step 2 command, `flutter test test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_places_test.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_follow_test.dart
git commit -m "feat(mushaf): فواصل ribbons, tail tabs and saved-ayah dots on the page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7a: PlaceRowMenu, PlacesGroups and PlacesSheet (item 18)

**Files:**
- Create: `lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart`, `places_groups.dart`, `places_sheet.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`, `.claude/rules/icons.md`
- Create (tests): `test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart`, `test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart`

**Interfaces:**
- Consumes: `FasilCubit`, `SavedAyatCubit`, `FakeFasilCubit`, `FakeSavedAyatCubit`, `fasilPlace`, `savedPlace` (Task 3); `fasilRibbon`, `fasilName`, `ayahPlace`, `placeWhen`, `places_position`, `places_today`, `fasil_movedAt`, `savedAyat_savedAt` (Task 4); `LastReadCubit` (`LastRead.page`, `ayah`, `updatedAt`); `SettingsCubit` (`settingsModel.is24HourFormat`).
- Produces:
  - `PlaceRowMenu({super.key, required VoidCallback onRemove})`: a 48×48 `MenuAnchor` button (`HugeIcons.strokeRoundedMoreVertical`, tooltip `places_more`) with one item «إزالة» (key `place-remove`).
  - `PlacesGroups({super.key, required void Function(int page, AyahIdentifier? focus) onOpen, DateTime Function() now = DateTime.now})`: a `Column(spacing: 16)` of (1) the continue card (key `places-continue`), (2) «الفواصل» with three rows (keys `places-fasil-<slot.name>`, actions `places-go-<slot.name>`, `places-rename-<slot.name>`), (3) «الآيات المحفوظة» with a count badge and saved rows (keys `places-saved-<surah>:<ayah>`).
  - `class PlacesOpen extends Equatable { const PlacesOpen({required this.page, this.focus}); }`; `PlacesSheet` with `static Future<PlacesOpen?> show(BuildContext context, {DateTime Function() now = DateTime.now})` (title «أماكني» + «إغلاق», `PlacesGroups(now: now)` in a scrollable body whose `onOpen` pops `PlacesOpen`).
  - `savedAyat_removed(ayah, surah)` «أُزيلت الآية $ayah من $surah» / 'Removed ayah $ayah of $surah' (Task 8 reuses it).
  - Other strings: `places_continue` «متابعة القراءة» / 'Continue reading'; `places_continueCaption` «تُحفظ وحدها حيث تقرأ، ولا تغيّرها الانتقالات» / 'Saved by itself where you read; jumps don\'t change it'; `places_page(page)` «صفحة $page» / 'Page $page'; `places_savedAyat` «الآيات المحفوظة» / 'Saved ayat'; `places_noSavedAyat` «لا توجد آيات محفوظة بعد» / 'No saved ayat yet'; `places_rename` «تسمية» / 'Rename'; `places_renameTitle` «تسمية الفاصل» / 'Rename marker'; `places_cancel` «إلغاء» / 'Cancel'; `places_remove` «إزالة» / 'Remove'; `places_more` «خيارات» / 'Options'.

- [ ] **Step 1: Write the failing tests** (Arabic; a host `Scaffold` whose button calls `PlacesSheet.show(context, now: () => DateTime(2026, 11, 21, 12))`; providers: `FakeFasilCubit` / `FakeSavedAyatCubit` seeded with `fasilPlace` / `savedPlace`, `FakeSettings()` and `LastReadCubit(repository: StubLastReadRepo(stored))`, both imported from `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`)

`place_row_menu_test.dart`: `'opens a menu with إزالة that calls onRemove'`; `'the button is at least 48 by 48'`.

`places_sheet_test.dart`:
- `'continue card names the place and the time'`: last read p.50 at 3:7 updated `DateTime(2026, 11, 21, 6, 10)` → «آل عمران ٧، صفحة ٥٠», «اليوم ٦:١٠ ص», the caption; tapping «متابعة» pops `PlacesOpen(page: 50)` (no focus). Without `updatedAt` the time is absent; with no last read the card is absent.
- `'continue card without an ayah names only the page'` (Deliberate reading 22): `LastRead(page: 50)` → «صفحة ٥٠», and no «آل عمران».
- `'three فاصل rows; placed ones go and rename'`: hifz at 3:6 with `at: DateTime(2026, 11, 20, 21, 40)` → «الحفظ», «آل عمران ٦، صفحة ٥٠», «نُقل أمس ٩:٤٠ م»; `places-go-hifz` pops `PlacesOpen(page: 50, focus: 3:6)`; wird reads «غير موضوع» with no go or rename.
- `'rename writes the trimmed name'`: tap `places-rename-hifz`, type «حفظ رمضان», tap «تم» → `fawasil.renames.last == (hifz, 'حفظ رمضان')`.
- `'saved ayat show the count, the date unless migrated, and open with focus'`: `savedPlace(2:5)` (default `at` Nov 14) and `savedPlace(3:7, migrated: true)` → badge «٢», row titles «البقرة ٥» and «آل عمران ٧», «حُفظت ١٤ نوفمبر» once; tapping a row pops `PlacesOpen(page:, focus:)`.
- `'removing from the row menu offers undo'`: `place-remove` → `saved.removes.last == place`, SnackBar «أُزيلت الآية ٥ من البقرة» shown inside the sheet; tap «تراجع» → `saved.restores.last == place`.
- `'no saved ayat shows the empty line'`.
- `'the row arrow follows the reading direction'`: the saved row's trailing `HugeIcon` uses `forwardArrowIcon(context)`.
- `'fits at 2x text'`: 360 px wide, all groups filled → no exception.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/presentation/pages`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `PlacesGroups`: reads `FasilCubit`, `SavedAyatCubit`, `LastReadCubit` with `BlocSelector`s and `use24h` with `context.select((SettingsCubit c) => c.state.settingsModel.is24HourFormat)`; dates via `placeWhen(at, now: now(), localeCode: context.langCode, use24h: use24h)`. Section headers `AppSectionHeader` (the saved one with `trailing: AppStatusBadge(color: scheme.secondary, label: count.toLocalized(context), showDot: false)`), rows in `SurfaceCard`s ≥ 56 high.
  - Continue card: title `places_position(ayahPlace(context, ayah), page)` or, with no ayah, `places_page(page)` (page via `toLocalized`); time line only when `updatedAt != null`; the caption; «متابعة» → `onOpen(page, null)`.
  - فاصل row: swatch `fasilRibbon(slot, dark: scheme.brightness == Brightness.dark)`, `fasilName` (`TS.bold14`), position or «غير موضوع», `fasil_movedAt(placeWhen(place.updatedAt, …))`, «انتقال» → `onOpen(place.page, place.ayah)`, «تسمية». Rename: `showDialog` with a `TextField` prefilled with `fasilName`, «إلغاء» / «تم»; «تم» calls `fawasil.rename(slot, text)`.
  - Saved row (no leading icon): title `ayahPlace(context, place.ayah)` in `TS.bold14`; subtitle `savedAyat_savedAt(placeWhen(place.createdAt, …))` in `TS.medium14` `onSurfaceVariant`, omitted when `migrated`; trailing `PlaceRowMenu` then `HugeIcon(icon: forwardArrowIcon(context))`; tap → `onOpen(place.page, place.ayah)`. Remove: `saved.remove(place)` then the SnackBar through `ScaffoldMessenger.of(context)` (`PendingS.current`, `S.undo` → `saved.restore(place)`).
- `PlacesSheet.show`: `showModalBottomSheet(isScrollControlled: true, showDragHandle: true, useSafeArea: true)` with a `DraggableScrollableSheet(expand: false, initialChildSize: 0.85)` whose builder returns `ScaffoldMessenger(child: Scaffold(backgroundColor: Colors.transparent, body: ListView(controller: …, padding: 16, children: [header row, PlacesGroups(…)])))` (Deliberate reading 25).
- `feature-widgets.md`: exception line «`bookmarks` exports `PlacesSheet` (used by `surah`)». `icons.md`: HugeIcons list adds the فاصل chooser and the «أماكني» sheet.

- [ ] **Step 4: Run** `flutter test test/features/bookmarks test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS; 0 errors, 0 warnings, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart lib/features/bookmarks/presentation/pages/widgets/places_groups.dart lib/features/bookmarks/presentation/pages/widgets/places_sheet.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md .claude/rules/icons.md test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart
git commit -m "feat(bookmarks): أماكني sheet with row-menu removal and undo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7b: The Bookmarks page shows the same groups (item 19)

**Files:**
- Modify: `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`, `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`, `.claude/rules/feature-widgets.md`, `.claude/rules/icons.md`
- Delete: `lib/features/bookmarks/presentation/utils/page_description.dart`, `test/features/bookmarks/presentation/utils/page_description_test.dart`
- Create (test): `test/features/bookmarks/presentation/pages/bookmarks_page_test.dart`

**Interfaces:**
- Consumes: `PlacesGroups` (Task 7a); `MushafArgs.focus`; `HadithBookmarkCubit` (read from `sl`, unchanged).

- [ ] **Step 1: Write the failing tests** (Arabic; the Task 7a providers; GetIt registers `HadithBookmarkCubit` as `class _FakeHadithBookmarks extends Cubit<HadithBookmarkState> implements HadithBookmarkCubit { _FakeHadithBookmarks(super.initial); @override dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i); }` via `sl.registerSingleton<HadithBookmarkCubit>(…)` in `setUp`, unregistered in `tearDown`; a `GoRouter` with `/` → `BookmarksPage()` and a capturing `AppRouter.mushafPath` route that stores `state.extra`)

`bookmarks_page_test.dart`:
- `'the page is أماكني with the Quran groups and the hadith section'`: title «أماكني»; `places-continue`, `places-fasil-wird`, «الآيات المحفوظة» present; «الأحاديث» shown when the fake holds one `HadithBookmark`; no «الصفحات» section.
- `'a saved ayah opens the reader focused on it'`: tap the row → the captured `extra` is a `MushafArgs` with `focusAyah` 2:5 and `origin: jump`.
- `'continue opens the reader at the page'`: captured `extra == 50`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/presentation/pages/bookmarks_page_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `bookmarks_page.dart`: title `PendingS.of(context).menu_places`; body `ListView` of `PlacesGroups(onOpen: (page, focus) => context.push(AppRouter.mushafPath, extra: focus == null ? page : MushafArgs.focus(focus)))` then, when hadiths exist, the existing hadith section. Remove `_QuranBookmarkTile`, `_PageBookmarkTile`, the `BookmarkCubit`/`PageBookmarkCubit` builders, the empty state and the user doc comment on the class. Hadith tile: `forwardArrowIcon(context)` instead of `strokeRoundedArrowRight01`.
- `quick_access_grid.dart`: label `PendingS.of(context).menu_places`.
- `git rm` `page_description.dart` and its test.
- `feature-widgets.md`: drop `page_description.dart` from the bookmarks utils. `icons.md`: the HugeIcons list adds the Bookmarks page.

- [ ] **Step 4: Run** `flutter test test/features/bookmarks test/features/home test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS; 0 errors, 0 warnings, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git rm lib/features/bookmarks/presentation/utils/page_description.dart test/features/bookmarks/presentation/utils/page_description_test.dart
git add lib/features/bookmarks/presentation/pages/bookmarks_page.dart lib/features/home/presentation/pages/widgets/quick_access_grid.dart .claude/rules/feature-widgets.md .claude/rules/icons.md test/features/bookmarks/presentation/pages/bookmarks_page_test.dart
git commit -m "feat(bookmarks): the Bookmarks page is أماكني with the same groups

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The S4 ayah leaf, «أماكني» in the reader, and the old bookmark stack removed

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart`, `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, `lib/main.dart`, `lib/features/bookmarks/bookmarks_di.dart`
- Delete (lib): `lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart`, `page_bookmark_local_data_source.dart`; `lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart`, `page_bookmark_repository_impl.dart`; `lib/features/bookmarks/domain/repositories/bookmark_repository.dart`, `page_bookmark_repository.dart`; `lib/features/bookmarks/domain/usecases/get_bookmarks.dart`, `get_page_bookmarks.dart`, `toggle_bookmark.dart`, `toggle_page_bookmark.dart`; `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart`, `bookmark_state.dart`, `page_bookmark_cubit.dart`, `page_bookmark_state.dart`
- Delete (test): `test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart`, `test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart`, `test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart`, `page_bookmark_repository_impl_test.dart`, `test/features/bookmarks/domain/usecases/get_bookmarks_test.dart`, `toggle_bookmark_test.dart`, `test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`, `page_bookmark_cubit_test.dart`, `page_bookmark_state_test.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/architecture.md`, `.claude/rules/routing-and-navigation.md`, `.claude/rules/state-management-patterns.md`, `CLAUDE.md`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`

**Interfaces:**
- Consumes: `SavedAyatCubit` (`save`, `remove`, `restore`, `state.contains/find`), `FakeSavedAyatCubit` (Task 3); `_openFawasil`, `_jumpInPlace(page, focus:)` (Task 6); `PlacesSheet.show`, `PlacesOpen`, `savedAyat_removed` (Task 7a).
- Produces:
  - `AyahLeaf({…, required VoidCallback onFasil})` (all S3 params kept); action row «استماع من هنا» · «فاصل» · «حفظ الآية» · «مشاركة», keys `leaf-listen`, `leaf-fasil`, `leaf-save`, `leaf-share`. «فاصل» uses `HugeIcons.strokeRoundedBookmark03`.
  - Strings: `leaf_fasil` «فاصل» / 'Marker'; `savedAyat_saved(ayah, surah)` «حُفظت الآية $ayah من $surah» / 'Saved ayah $ayah of $surah'.

- [ ] **Step 1: Write the failing tests**

- `ayah_leaf_test.dart`, deliberate rewrite (the S3 labels and `BookmarkCubit` pin S3 behaviour): host provides `FakeSavedAyatCubit`; `'ayah leaf labels are distinct'` now expects `['استماع من هنا', 'فاصل', 'حفظ الآية', 'مشاركة']` over keys `leaf-listen`, `leaf-fasil`, `leaf-save`, `leaf-share` (a set of size 4); `'listen from here, close and save reach their handlers'` → `leaf-save` records `saved.saves.last == 3:7`, `leaf-fasil` calls `onFasil`; `'the save action announces whether the ayah is saved'` reads `SavedAyatState(items: [place 3:7])`. New:
  - `'saving confirms and تراجع removes it'`: tap `leaf-save` → SnackBar «حُفظت الآية ٧ من آل عمران»; «تراجع» → `saved.removes.last.ayah == 3:7`.
  - `'a saved ayah is removed with undo'`: state holds 3:7 → tap `leaf-save` → `removes.last`, SnackBar «أُزيلت الآية ٧ من آل عمران»; «تراجع» → `restores.last` is that place.
  - `'the banner variant has no فاصل and no save'` (extend the existing banner test: «فاصل» absent).
  - `'fits at 2x text'` stays, now with four columns.
- Harness: drop `FakeBookmarks` (and the `bookmarks` field of `MushafHarness`), `_StubPageBookmarkRepo`, the `PageBookmarkCubit`/`BookmarkCubit` providers and their imports; the `bookmarksPath` stub route goes too. The places sheet in the shell tests reads the harness's `LastReadCubit` and `FakeSettings`, already provided.
- `mushaf_page_shell_test.dart`:
  - `'menu places opens the sheet and a saved ayah jumps in place'`: saved 2:5; open «القائمة», tap `menu-tile-places`, then `places-saved-2:5` → `mushaf.jumps.last == (2, 2:5)`.
  - `'continue reading in the sheet jumps without a selection'`: stored last read p.50 → `places-continue` «متابعة» → `jumps.last == (50, null)`.
  - `'the leaf فاصل opens the chooser preselecting the slot on this page'`: hifz at 3:6, reader on p.50 with 3:7 selected (`mushaf.push`) → tap `leaf-fasil` → «نقل الحفظ إلى هنا» in a `FilledButton`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `ayah_leaf.dart`: four `Expanded` columns split by the existing `VerticalDivider`s; «حفظ الآية» is a `BlocSelector<SavedAyatCubit, SavedAyatState, bool>`; its tap: when saved, `remove(find(ayah)!)` and the `savedAyat_removed` SnackBar with `S.undo` → `restore(place)`; else `final place = await save(ayah)`, and when non-null the `savedAyat_saved` SnackBar with `S.undo` → `remove(place)`. Capture the messenger and the strings (`PendingS.of(context)` before the await) as `_share` does; surah name via `surahDisplayName`, ayah via `toLocalized`.
- `mushaf_page.dart`: `AyahLeaf` is built in `_LeafSlot` (line 872), not in `_MushafPageState`, so `_LeafSlot` gains `required this.onFasil` (`final VoidCallback onFasil;`), the `_LeafSlot(` call in `build` (line 562) passes `onFasil: () => _openFawasil(null)`, and `_LeafSlot` forwards `onFasil: onFasil` to `AyahLeaf`. `MenuOpenPlaces()` → `final open = await PlacesSheet.show(context); if (!mounted || open == null) return; _jumpInPlace(open.page, focus: open.focus);` (drop the `AppRouter.bookmarksPath` push and the now-unused import if any).
- `main.dart`: remove the `BookmarkCubit` and `PageBookmarkCubit` providers and imports. `bookmarks_di.dart`: remove the old registrations and imports.
- `git rm` every file in the Delete lists. `grep -rn "BookmarkCubit\|PageBookmark\|bookmark_repository\|toggle_bookmark\|get_bookmarks" lib test | grep -v -i 'hadith_\?bookmark'` returns nothing (the `-i` filter also drops the snake_case hadith imports in `ahadith_di.dart`, `hadith_bookmark_repository_impl.dart`, `get_hadith_bookmarks.dart`, `toggle_hadith_bookmark.dart` and `hadith_bookmark_repository_impl_test.dart`, which stay untouched).
- Rules: `architecture.md` app-wide list drops `BookmarkCubit`, `PageBookmarkCubit`; `routing-and-navigation.md` "App-wide cubits" names `FasilCubit`, `SavedAyatCubit` instead of "bookmarks"; `state-management-patterns.md` example list `BookmarkCubit` → `SavedAyatCubit`.
- `CLAUDE.md` line 5-6: «page and ayah bookmarks» → «three named فواصل, saved ayat and the «أماكني» sheet».

- [ ] **Step 4: Run** `flutter test` (whole suite) and `flutter analyze --no-fatal-infos`. Expected: all pass, 1 skipped, count = 1311 + added − deleted; 0 errors, 0 warnings, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git rm lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart lib/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart lib/features/bookmarks/domain/repositories/bookmark_repository.dart lib/features/bookmarks/domain/repositories/page_bookmark_repository.dart lib/features/bookmarks/domain/usecases/get_bookmarks.dart lib/features/bookmarks/domain/usecases/get_page_bookmarks.dart lib/features/bookmarks/domain/usecases/toggle_bookmark.dart lib/features/bookmarks/domain/usecases/toggle_page_bookmark.dart lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart lib/features/bookmarks/presentation/cubit/bookmark_state.dart lib/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart lib/features/bookmarks/presentation/cubit/page_bookmark_state.dart test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart test/features/bookmarks/data/repositories/page_bookmark_repository_impl_test.dart test/features/bookmarks/domain/usecases/get_bookmarks_test.dart test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart test/features/bookmarks/presentation/cubit/page_bookmark_cubit_test.dart test/features/bookmarks/presentation/cubit/page_bookmark_state_test.dart
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/main.dart lib/features/bookmarks/bookmarks_di.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/architecture.md .claude/rules/routing-and-navigation.md .claude/rules/state-management-patterns.md CLAUDE.md test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart
git commit -m "feat(mushaf): S4 ayah leaf, أماكني in the reader; remove the old bookmark stack

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Accepted trade-off (branch confirm, 2026-11-22)

In page mode the page reaches the screen edge, so the ribbon cluster and tail tabs are only as wide as the text margin (about 37 px on a 360 px page) and cannot widen outward. Widening them inward would cover the text and steal ayah taps, so they keep the margin width with a 56 px (cluster) and 88 px (tail tab) height. The same targets stay reachable from «فاصل» in the ayah leaf and from «أماكني», both 48 px.
