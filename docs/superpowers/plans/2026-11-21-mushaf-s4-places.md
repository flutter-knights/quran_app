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
- Rule catalogues (`architecture.md`, `feature-widgets.md`, `state-management-patterns.md`, `routing-and-navigation.md`, `icons.md`) change in the task that changes what they describe.

## Deliberate readings (the plan governs here)

1. **Migration order.** The plan walks the ayah list (stored order) then the page list (stored order) as one sequence; item `i` gets `createdAt = now − i µs`. Saved ayat are shown newest first, so the migrated list reads in the old stored order.
2. **One saved ayah per ayah.** An ayah that appears twice (in both lists, or twice in one) is migrated once, at its first position. `SavedAyatCubit.save` of an ayah already saved returns null and changes nothing.
3. **A re-run without the flag replaces its own records.** `PlaceMigration.run` deletes every record with `migrated == true` before writing, so a crash between the writes and the flag can never duplicate. Records the reader created (`migrated == false`) are kept.
4. **The migration runs once per launch until it succeeds**, in `_AppLoaderState._initAll` after `initGetIt()` and before `_ready = true`, so the app-wide cubits load after it. A failure leaves the flag unset; the app still starts.
5. **Old boxes stay open** (`ayah_bookmarks`, `page_bookmarks` in `hive_config.dart`) because the migration reads them; after Task 8 no code writes them.
6. **«تسمية» is offered on placed فواصل only** (the record holds the name). A blank or whitespace name resets to the default name (`name: null`).
7. **The cluster draws nothing when no فاصل is placed** (no empty button). The chooser stays reachable from the leaf's «فاصل».
8. **Ribbon x positions are fixed per slot** (slot index `k` sits `4 + 14·k` px from the cluster's end edge), so an unset slot leaves a gap and each tail tab sits under its own ribbon.
9. **Tail tab geometry** (design `final-reading.html` `.ftail`): a vertical label (`RotatedBox(quarterTurns: 1)`) 22 px wide, ≥ 56 px long, on the ribbon colour, text paper `background`, with a 48 px-wide hit box at the page's end edge whose bottom aligns with the bottom of the فاصل ayah's first line. A thin 12 px ribbon strip runs from the top of the page to the tab. Tapping a tail opens the chooser preselecting that slot. The page view is always RTL, so "end" is the page's left edge.
10. **Ochre is nudged.** On light papers المراجعة is `#835F0F`, not `#8A6410`: sepia background on `#8A6410` is 4.34:1 (< 4.5); `#835F0F` gives 4.70. All other ribbon values are the spec's. Record this in the PR.
11. **App-surface swatches follow the app palette**: `fasilRibbon(slot, dark: context.colorScheme.brightness == Brightness.dark)`, so a chip reads on the sheet, not on the paper.
12. **"Last used" = the placed slot with the greatest `updatedAt`.** With nothing placed `chooserPreselect` returns `FasilSlot.wird`.
13. **On this page with two فواصل**, `chooserPreselect` takes the last one at or before the selected ayah, else the first on the page.
14. **Placing a فاصل keeps the leaf open.** A first placement says «وُضع فاصل الحفظ عند البقرة ٥»; a move says «نُقل فاصل الحفظ إلى البقرة ٥». «تراجع» restores the previous record exactly (same `id`, `createdAt`, `name`), or deletes the record when the slot was unset.
15. **«حفظ الآية» toggles.** On a saved ayah it removes, with «أُزيلت الآية ٥ من البقرة» + «تراجع» (restore keeps `id` and `createdAt`).
16. **Navigation from أماكني.** In the reader every row jumps in place (`MushafCubit.jumpTo(page, focus: …)`, guard re-armed): a فاصل or saved ayah selects its ayah (leaf opens); «متابعة» jumps without a selection. On the Bookmarks page a فاصل or saved ayah pushes `MushafArgs.focus(ayah)`; «متابعة» pushes `extra: page` (normal origin), like the home card.
17. **Hadith rows on the Bookmarks page get only the arrow fix** (`forwardArrowIcon`); no row menu, since hadith bookmarks stay untouched.
18. **Terminology (item 19) changes callers, not ARB values.** The page title and the home quick-access label become `PendingS.menu_places` «أماكني»; new terms are new `PendingS` keys. `S.bookmarks_pages_section`, `S.bookmarks_quran_section`, `S.no_bookmarks_yet`, `S.pageRemovedFromBookmarks` lose their callers; their ARB keys stay. The hadith view's «حفظ» is hadith and stays.
19. **Relative dates** use the local calendar day: same day «اليوم ٦:١٠ ص», previous day «أمس ٩:٤٠ م», older «١٤ نوفمبر», another year «١٤ نوفمبر ٢٠٢٥». A migrated record shows no date.
20. **The places sheet and the Bookmarks page share one widget, `PlacesGroups`.** The continue card hides when there is no last read; the saved group shows «لا توجد آيات محفوظة بعد» when empty; the three فاصل rows always show.

## Review Focus

1. **Old data that is odd.** Non-string ayah entries, `'5:0'`, `'2:'`, page entries stored as strings, a page whose bounds yield no ayah, the same ayah in both lists, and a crash before the flag. Task 2 pins each, plus a twice-run.
2. **The banner (ayah 0) is never a place.** `FasilCubit.move` and `SavedAyatCubit.save` ignore ayah 0; the banner leaf shows neither «فاصل» nor «حفظ الآية». Tasks 3 and 8 pin it.
3. **Undo after more changes.** Undo of a move restores the exact previous record even after a rename; undo of a removal restores `id` and `createdAt`. Task 3 pins both.
4. **No فاصل placed yet.** No cluster is drawn and no tap is swallowed at the corner; chooser rows read «غير موضوع» with no «انتقال». Tasks 5 and 6 pin it.
5. **Large text (2×) in 360 px.** The four-column leaf, the chooser and the places sheet lay out without overflow. Tasks 5, 7 and 8 pump each at `TextScaler.linear(2.0)` and assert no exception.

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
- Test: `test/features/bookmarks/data/models/place_record_model_test.dart`, `test/features/bookmarks/data/datasources/local/places_local_data_source_test.dart`, `test/features/bookmarks/data/repositories/places_repository_impl_test.dart`

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

- Entities, repository, use cases and data source as in Interfaces; `PlacesRepositoryImpl({required this.dataSource})` with the `try / on CacheException / catch (e) → Failure.fromException(e)` shape of `BookmarkRepositoryImpl`.
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
- Test: `test/features/bookmarks/data/datasources/local/place_migration_test.dart`, `test/features/bookmarks/data/repositories/places_repository_impl_test.dart`

**Interfaces:**
- Consumes: `Place`, `PlaceRecordModel`, `FasilSlot` (Task 1); `GetMushafPage` (surah domain); `QuranPageService.getPageForAyah`.
- Produces:
  - `class PlaceMigration { PlaceMigration({required Box<PlaceRecordModel> places, required Box<bool> meta, required Box<List> ayahBookmarks, required Box<List> pageBookmarks, required Future<AyahIdentifier?> Function(int page) firstAyahOfPage, required int Function(AyahIdentifier ayah) pageOf, DateTime Function() now = DateTime.now}); static const flag = 'migratedV1'; static List<Place> plan({required List<Object?> ayahKeys, required List<Object?> pages, required Map<int, AyahIdentifier> firstAyahs, required int Function(AyahIdentifier ayah) pageOf, required DateTime now}); Future<int> run(); }`
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
- `'a run interrupted before the flag never duplicates'`: run, `meta.delete('migratedV1')`, put one reader record (`migrated: false`), run again → 2 migrated records plus the reader's one.
- `'old boxes are left intact'`: old box contents equal before and after.
- `'nothing to migrate still sets the flag'`: empty old boxes → returns 0, flag true.
- Repository: `'migrate maps a throw from the migration to a Failure'`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/data`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `plan`: parse `'s:a'` strings (split on `:`, two ints, `a > 0`) and page entries (`int`, or `int.tryParse('$e')`), map pages through `firstAyahs`, dedupe on `AyahIdentifier` keeping the first, then build places with `createdAt = now.subtract(Duration(microseconds: i))`.
- `run`: return 0 when the flag is set; read `ayahBookmarks.get('all') ?? []` and `pageBookmarks.get('all') ?? []`; await `firstAyahOfPage` for each distinct parsed page; `plan`; `places.deleteAll(` keys of records with `migrated` `)`; `places.putAll({for (p in planned) p.id: PlaceRecordModel.fromEntity(p)})`; verify every planned id is present and the migrated-record count equals `planned.length`, else `throw CacheException('place migration count mismatch')`; then `meta.put(flag, true)`; return `planned.length`.
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
- Test: `test/features/bookmarks/presentation/cubit/fasil_cubit_test.dart`, `test/features/bookmarks/presentation/cubit/saved_ayat_cubit_test.dart`

**Interfaces:**
- Consumes: `GetPlaces`, `SavePlace`, `RemovePlace`, `Place`, `FasilSlot` (Task 1); `QuranPageService`.
- Produces:
  - `class FasilState extends Equatable { const FasilState({this.slots = const {}, this.loaded = false, this.error}); final Map<FasilSlot, Place> slots; List<Place> onPage(int page); FasilState copyWith(…); }` (`onPage` in `FasilSlot.values` order).
  - `class FasilCubit extends Cubit<FasilState> { FasilCubit({required GetPlaces getPlaces, required SavePlace savePlace, required RemovePlace removePlace, required QuranPageService pageService, DateTime Function() now = DateTime.now}); Future<({Place? previous, Place moved})?> move(FasilSlot slot, AyahIdentifier ayah); Future<void> restore(FasilSlot slot, Place? previous); Future<void> rename(FasilSlot slot, String name); }` (loads in the constructor).
  - `class SavedAyatState extends Equatable { const SavedAyatState({this.items = const [], this.loaded = false, this.error}); final List<Place> items; Place? find(AyahIdentifier ayah); bool contains(AyahIdentifier ayah); }` (`items` newest `createdAt` first).
  - `class SavedAyatCubit extends Cubit<SavedAyatState> { SavedAyatCubit({required GetPlaces getPlaces, required SavePlace savePlace, required RemovePlace removePlace, required QuranPageService pageService, DateTime Function() now = DateTime.now}); Future<Place?> save(AyahIdentifier ayah); Future<void> remove(Place place); Future<void> restore(Place place); }`
  - `place_fakes.dart`: `class InMemoryPlacesRepository implements PlacesRepository` (a `Map<String, Place>`, optional `failNext`), `class FakeFasilCubit extends Cubit<FasilState> implements FasilCubit` (`FakeFasilCubit([FasilState initial = const FasilState(loaded: true)])`; records `moves` `List<(FasilSlot, AyahIdentifier)>`, `restores` `List<(FasilSlot, Place?)>`, `renames` `List<(FasilSlot, String)>`; `move` returns `(previous: state.slots[slot], moved: <a place at the ayah>)` and emits it) and `class FakeSavedAyatCubit extends Cubit<SavedAyatState> implements SavedAyatCubit` (records `saves` `List<AyahIdentifier>`, `removes` and `restores` `List<Place>`; `save` returns a new place and emits it). Both end with `dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);` like the harness fakes.

- [ ] **Step 1: Write the failing tests** (`bloc_test`, `InMemoryPlacesRepository`, a fixed clock that advances 1 minute per call, page service stub `getPageForAyah → quran.getPageNumber`)

`fasil_cubit_test.dart`:
- `'loads only placed slots'`: repo holds a hifz فاصل and a saved ayah → `slots == {hifz: …}`, `loaded`.
- `'two records on one slot keep the latest updatedAt'`.
- `'move places an unset slot'`: `move(wird, 2:5)` → `previous == null`, `moved.page == 2`, `createdAt == updatedAt`, `id == createdAt.microsecondsSinceEpoch.toString()`.
- `'move keeps id, createdAt and name, updates ayah, page and updatedAt'`.
- `'move ignores the banner'`: `move(wird, 5:0)` → null, no emit, repo unchanged.
- `'restore with null deletes the slot'`; `'restore brings back the exact previous record even after a rename'`.
- `'rename trims; blank resets to the default name'`: `rename(hifz, '  حفظ رمضان ')` → `name == 'حفظ رمضان'`; `rename(hifz, '   ')` → `name == null`; rename of an unset slot does nothing.
- `'a failing save emits the error and keeps the slots'`.

`saved_ayat_cubit_test.dart`:
- `'loads saved ayat newest first, skipping فواصل'`.
- `'save adds a dated, unmigrated place at the top'`.
- `'save of an ayah already saved returns null'`; `'save ignores the banner'`.
- `'remove then restore keeps id and createdAt'`.
- `'contains and find look up by ayah'`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/presentation/cubit`. Expected: FAIL.

- [ ] **Step 3: Implement**

- Each mutating method returns early when `!state.loaded`, writes through the use case, then (after `isClosed`) emits the new map/list or `error: failure.message`.
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
- Test: `test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart`, `test/features/bookmarks/presentation/utils/fasil_rules_test.dart`, `test/features/bookmarks/presentation/utils/place_labels_test.dart`

**Interfaces:**
- Consumes: `FasilSlot`, `Place` (Task 1).
- Produces:
  - `Color fasilRibbon(FasilSlot slot, {required bool dark})`: light papers (`dark: false`) wird `#8A2F3B`, hifz `#1F5A8A`, muraja `#835F0F`; dark wird `#E39AA2`, hifz `#8EBBE3`, muraja `#E2B85C`. `extension on MushafPaper`: `Color ribbon(FasilSlot slot) => fasilRibbon(slot, dark: isDark)` (inside `MushafPaperX`).
  - `FasilSlot chooserPreselect({required Map<FasilSlot, Place> slots, required int page, required AyahIdentifier at})` (Deliberate readings 12, 13).
  - `extension FasilSlotLocalization on FasilSlot { String localized(BuildContext context); }` and `String fasilName(BuildContext context, FasilSlot slot, Place? place) => place?.name ?? slot.localized(context)`.
  - `String ayahPlace(BuildContext context, AyahIdentifier ayah)` → «آل عمران ٦» (`surahDisplayName` + space + localized ayah).
  - `String placeWhen(DateTime at, {required DateTime now, required String localeCode})` (Deliberate reading 19; time `DateFormat('h:mm a', localeCode)`, date `DateFormat('d MMMM', …)` / `'d MMMM y'`, then `toIndicNumerals(localeCode)`).
  - Strings: `fasil_wird` «الورد» / 'Wird'; `fasil_hifz` «الحفظ» / 'Memorisation'; `fasil_muraja` «المراجعة» / 'Review'; `places_position(place, page)` «$place، صفحة $page» / '$place, page $page'; `places_today(time)` «اليوم $time» / 'Today $time'; `places_yesterday(time)` «أمس $time» / 'Yesterday $time'; `fasil_movedAt(when)` «نُقل $when» / 'Moved $when'; `savedAyat_savedAt(when)` «حُفظت $when» / 'Saved $when'.

- [ ] **Step 1: Write the failing tests**

- `mushaf_paper_contrast_test.dart`, inside each paper's group, for every `FasilSlot`: `'ribbon <slot> on background is at least 3'` (`contrast(p.ribbon(s), c.background) >= 3`) and `'tail text on ribbon <slot> is at least 4.5'` (`contrast(c.background, p.ribbon(s)) >= 4.5`). Plus `'ribbons follow the paper darkness'`: `MushafPaper.night.ribbon(FasilSlot.hifz) == fasilRibbon(FasilSlot.hifz, dark: true)`.
- `fasil_rules_test.dart` (places built with `quran.getPageNumber`):
  - `'the slot on this page wins'`: hifz at 3:6 (p.50), wird at 2:5 → `at 3:10, page 50` → hifz.
  - `'two on this page: the last at or before the ayah'`: wird 3:4, hifz 3:6 (both p.50, which holds 3:1–3:9) → at 3:5 → wird; at 3:7 → hifz; at 3:2 (both after) → wird, the first on the page.
  - `'else the nearest preceding'`: wird 2:5 (p.2), hifz 2:102 (p.16), at 3:7 (p.50) → hifz.
  - `'else the last used'`: wird 5:1 (updated day 1), hifz 10:1 (updated day 2), at 2:5 → hifz.
  - `'nothing placed gives الورد'`.
- `place_labels_test.dart` (`initializeDateFormatting('ar')` and `'en'` in `setUpAll`; `now = DateTime(2026, 11, 21, 12)`):
  - `'today'`: `placeWhen(DateTime(2026, 11, 21, 6, 10), now: now, localeCode: 'ar') == 'اليوم ٦:١٠ ص'`.
  - `'yesterday by calendar day, even under 24 hours'`: `DateTime(2026, 11, 20, 21, 40)` → `'أمس ٩:٤٠ م'`.
  - `'older this year'`: `DateTime(2026, 11, 14, 8)` → `'١٤ نوفمبر'`; `'another year adds it'`: `DateTime(2025, 11, 14)` → `'١٤ نوفمبر ٢٠٢٥'`.
  - `'english'`: `DateTime(2026, 11, 21, 6, 10)` with `'en'` → `'Today 6:10 AM'`.
  - Widget test `'ayahPlace and fasilName read the locale'`: Arabic `ayahPlace(context, 3:6) == 'آل عمران ٦'`; `fasilName(context, FasilSlot.hifz, null) == 'الحفظ'`; a place named «حفظ رمضان» returns its name.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/mushaf_paper_contrast_test.dart test/features/bookmarks/presentation/utils`. Expected: FAIL.

- [ ] **Step 3: Implement** the Interfaces; strings in both ARBs and `PendingS`. If any gate fails with these values, nudge the failing hex's lightness only and record it in the report. `feature-widgets.md` → Presentation utils: `surah` `mushaf_paper_colors.dart` adds `ribbon` and `fasilRibbon`; `bookmarks` lists `fasil_rules.dart` (`chooserPreselect`), `enum_localization.dart` (`FasilSlot.localized`), `place_labels.dart` (`fasilName`, `ayahPlace`, `placeWhen`).

- [ ] **Step 4: Run** the Step 2 command and `flutter test test/core/localization`. Expected: PASS.

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
- Test: `test/features/surah/presentation/pages/mushaf/widgets/fasil_chooser_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster_test.dart`

**Interfaces:**
- Consumes: `fasilRibbon`, `MushafPaperX.ribbon`, `fasilName`, `ayahPlace`, `PendingS.places_position` (Task 4); `Place`, `FasilSlot`.
- Produces:
  - `sealed class FasilChoice extends Equatable`; `final class FasilGo extends FasilChoice { const FasilGo(this.place); }`; `final class FasilMoveHere extends FasilChoice { const FasilMoveHere(this.slot); }`.
  - `FasilChooser({required Map<FasilSlot, Place> slots, AyahIdentifier? selected, FasilSlot? preselect})`; `static Future<FasilChoice?> show(BuildContext context, {required Map<FasilSlot, Place> slots, AyahIdentifier? selected, FasilSlot? preselect})` (`showModalBottomSheet`, `showDragHandle`, `isScrollControlled`, `useSafeArea`; app colours).
  - Keys: `fasil-row-<slot.name>`, `fasil-go-<slot.name>`, `fasil-move-<slot.name>`.
  - `FasilRibbonCluster({required Map<FasilSlot, String> placed, required MushafPaper paper, required VoidCallback onTap})` (key `fasil-cluster`; 48×56; draws only `placed` keys, at fixed slot x, Deliberate reading 8; `Tooltip` `fasil_title`, `Semantics(button: true, label: fasil_clusterLabel(names joined «، »))`).
  - `FasilTailTab({required FasilSlot slot, required String name, required MushafPaper paper, required VoidCallback onTap})` (key `fasil-tail-<slot.name>`; geometry per Deliberate reading 9; end shapes: wird V notch, hifz V point, muraja square; `Semantics(button: true, label: name)`).
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
- `'the tail tab prints its name and is at least 48 wide'`: «الحفظ» found, `tester.getSize(find.byKey(fasil-tail-hifz)).width >= 48`, height ≥ 56; tap calls `onTap`.
- `'tail text uses the paper background'`: the `Text` colour equals `MushafPaper.sepia.colors.background`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/fasil_chooser_test.dart test/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**

- Chooser: header `fasil_title` `TS.bold16`; each row a `SurfaceCard`-free `Padding` row ≥ 56 high: a 12×24 rounded swatch `fasilRibbon(slot, dark: scheme.brightness == Brightness.dark)`, a column with `fasilName` (`TS.bold14`) over the position or «غير موضوع» (`TS.medium14`, `onSurfaceVariant`), then «انتقال» `TextButton` (placed only) and, with a selection, the move/place button (`FilledButton` for `preselect`, else `OutlinedButton`, ≥ 48). Buttons `Navigator.pop(context, choice)`.
- Cluster: `CustomPaint` ribbons 12 px wide, 44 px long, 8 px notch, a 1 px centre stitch in `paper.colors.background` at alpha 0.45, the drop shadow of the old `_RibbonPainter`; wrapped in `PrettierTap`-free `GestureDetector(behavior: opaque)`.
- Tail: `CustomPaint` for the end shape behind a `RotatedBox` label `TS.bold14` in `paper.colors.background`.

- [ ] **Step 4: Run** the Step 2 command and `flutter test test/core/localization`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/fasil_chooser.dart lib/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/fasil_chooser_test.dart test/features/surah/presentation/pages/mushaf/widgets/fasil_ribbon_cluster_test.dart
git commit -m "feat(mushaf): فاصل chooser, ribbon cluster and tail tabs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Ribbons on the page, the chooser in the reader, MushafPageRibbon deleted

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`, `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart`, `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`
- Create (test): `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_places_test.dart`

**Interfaces:**
- Consumes: `FasilCubit` (`state.slots`, `state.onPage`, `move`, `restore`), `SavedAyatCubit` (`state.items`), `FakeFasilCubit`, `FakeSavedAyatCubit` (Task 3); `chooserPreselect`, `fasilName`, `ayahPlace` (Task 4); `FasilChooser`, `FasilGo`, `FasilMoveHere`, `FasilRibbonCluster`, `FasilTailTab` (Task 5).
- Produces:
  - `MushafPageView({super.key, required int pageNumber, required void Function(FasilSlot? slot) onOpenFawasil})`.
  - `MushafCubit.jumpTo(int page, {AyahIdentifier? focus})`: same page → `select(focus)` when given, else today's rule; another page → today's jump, then `selectedAyah: focus` when `focus != null && focus.ayah > 0`.
  - `_MushafPageState._openFawasil(FasilSlot? preselect)` and `_jumpInPlace(int page, {AyahIdentifier? focus})` (Task 8 calls both).
  - Strings: `fasil_moved(name, place)` «نُقل فاصل $name إلى $place» / 'Moved the $name marker to $place'; `fasil_placed(name, place)` «وُضع فاصل $name عند $place» / 'Placed the $name marker at $place'.
  - Keys: `saved-dot-<surah>:<ayah>`.

- [ ] **Step 1: Write the failing tests**

- `mushaf_cubit_auto_follow_test.dart`: `'jumpTo with focus selects it on the new page'` (`jumpTo(50, focus: 3:6)` → `currentPage 50`, `selectedAyah 3:6`, `jumpFrom` set); `'jumpTo the current page with focus only selects'`; `'jumpTo ignores a banner focus'` (focus 5:0 → no selection).
- `mushaf_page_view_places_test.dart` (page 50 with stub bounds containing 3:1 and 3:6 lines; fakes provided):
  - `'no placed فاصل draws no cluster'`.
  - `'the cluster opens the chooser with no preselect'`: hifz on p.300 → `fasil-cluster` shown on p.50; tap → `onOpenFawasil(null)`.
  - `'a فاصل on this page hangs its tail at the ayah line'`: hifz at 3:6 → `fasil-tail-hifz` present; its bottom equals the bottom of 3:6's first line rect × page height (±1); tapping it calls `onOpenFawasil(FasilSlot.hifz)`.
  - `'a saved ayah on this page shows the dot'`: saved 3:1 → `saved-dot-3:1` present; a saved ayah on another page draws none.
- `mushaf_page_view_tap_test.dart`, `mushaf_page_view_load_error_test.dart`: replace the `PageBookmarkCubit` provider with `FakeFasilCubit` and `FakeSavedAyatCubit`; pass `onOpenFawasil: (_) {}`. Existing assertions unchanged.
- Harness: `FakeFasilCubit` and `FakeSavedAyatCubit` in `MushafHarness` (`fawasil`, `saved`) and in `providers`; `FakeMushaf.jumpTo(int page, {AyahIdentifier? focus})` records `(page, focus)` in `jumps` (update `jumps` readers in the shell test to compare `.$1`).
- `mushaf_page_shell_test.dart`:
  - `'انتقال in the chooser jumps in place with the ayah selected'`: hifz at 3:6 (p.50) on a reader at p.2; tap `fasil-cluster`, tap `fasil-go-hifz` → `mushaf.jumps.last == (50, 3:6)`.
  - `'moving a فاصل confirms and تراجع restores it'`: wird placed at 2:5; select 3:7 by `mushaf.push`; tap the cluster, tap `fasil-move-wird` → `fawasil.moves.last == (wird, 3:7)`, SnackBar «نُقل فاصل الورد إلى آل عمران ٧»; tap «تراجع» → `fawasil.restores.last == (wird, previousPlace)`.
  - `'placing an unset فاصل says وُضع'`: nothing placed except hifz elsewhere; select 2:5, cluster → `fasil-move-wird` → «وُضع فاصل الورد عند البقرة ٥».

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/cubit/mushaf test/features/surah/presentation/pages/mushaf`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `mushaf_page_view.dart`: drop `PageBookmarkCubit`, `S`, `_onRibbonTap` and the ribbon import. Inside the existing `LayoutBuilder` stack, after the tap `GestureDetector`: a `BlocSelector<SavedAyatCubit, SavedAyatState, List<AyahIdentifier>>` (this page's saved ayahs) drawing `IgnorePointer` 6 px `colors.accent` dots at `PositionedDirectional(start: 6, top: centre of the ayah's first line − 3)`; a `BlocSelector<FasilCubit, FasilState, Map<FasilSlot, Place>>` drawing, for `onPage(pageNumber)` with a bound in `entity.ayahs`, `FasilTailTab`s (`onTap: () => widget.onOpenFawasil(slot)`) and, when `slots` is not empty, `PositionedDirectional(top: 0, end: 8, child: FasilRibbonCluster(placed: {for (e in slots) e.key: fasilName(context, e.key, e.value)}, paper: settings.mushafPaper, onTap: () => widget.onOpenFawasil(null)))`. Tails and dots need `entity`; the cluster does not.
- `mushaf_page.dart`: pass `onOpenFawasil: _openFawasil` in both `itemBuilder`s.
  - `_openFawasil(preselect)`: `selected` = `state.selectedAyah` when its `ayah > 0`; `pre = preselect ?? (selected == null ? null : chooserPreselect(slots: fawasil.state.slots, page: state.currentPage, at: selected))`; `await FasilChooser.show(…)`; `if (!mounted) return;` `FasilGo(:final place)` → `_jumpInPlace(place.page, focus: place.ayah)`; `FasilMoveHere(:final slot)` → `_moveFasil(slot, selected!)`.
  - `_moveFasil(slot, ayah)`: `final result = await fawasil.move(slot, ayah)`; null → return; SnackBar (hide current first) with `fasil_placed` or `fasil_moved` (name `fasilName(context, slot, result.moved)`, place `ayahPlace`), action `S.undo` → `fawasil.restore(slot, result.previous)`. Strings via `PendingS.current` (callback).
  - `_jumpInPlace(int page, {AyahIdentifier? focus})`: today's body, passing `focus` to `_mushafCubit.jumpTo`; the return-chip call site keeps `_jumpInPlace(page)`.
- `mushaf_cubit.dart`: `jumpTo` per Interfaces.
- `git rm` the ribbon widget and its test.

- [ ] **Step 4: Run** the Step 2 command, `flutter test test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_tap_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_load_error_test.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_places_test.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart
git commit -m "feat(mushaf): فواصل ribbons, tail tabs and saved-ayah dots on the page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: PlacesSheet, PlacesGroups, the row menu (item 18) and the Bookmarks page (item 19)

**Files:**
- Create: `lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart`, `places_groups.dart`, `places_sheet.dart`
- Modify: `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`, `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`
- Delete: `lib/features/bookmarks/presentation/utils/page_description.dart`, `test/features/bookmarks/presentation/utils/page_description_test.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`, `.claude/rules/icons.md`
- Test: `test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart`, `test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart`, `test/features/bookmarks/presentation/pages/bookmarks_page_test.dart`

**Interfaces:**
- Consumes: `FasilCubit`, `SavedAyatCubit`, fakes (Task 3); `fasilRibbon`, `fasilName`, `ayahPlace`, `placeWhen`, `places_position`, `fasil_movedAt`, `savedAyat_savedAt` (Task 4); `LastReadCubit` (`LastRead.page`, `ayah`, `updatedAt`).
- Produces:
  - `PlaceRowMenu({super.key, required VoidCallback onRemove})`: a 48×48 `MenuAnchor` button (`HugeIcons.strokeRoundedMoreVertical`, tooltip `places_more`) with one item «إزالة» (key `place-remove`).
  - `PlacesGroups({super.key, required void Function(int page, AyahIdentifier? focus) onOpen})`: a `Column(spacing: 16)` of (1) the continue card (key `places-continue`), (2) «الفواصل» with three rows (keys `places-fasil-<slot.name>`, actions `places-go-<slot.name>`, `places-rename-<slot.name>`), (3) «الآيات المحفوظة» with a count badge and saved rows (keys `places-saved-<surah>:<ayah>`).
  - `class PlacesOpen extends Equatable { const PlacesOpen({required this.page, this.focus}); }`; `PlacesSheet` with `static Future<PlacesOpen?> show(BuildContext context)` (title «أماكني» + «إغلاق», `PlacesGroups` in a scrollable body whose `onOpen` pops `PlacesOpen`).
  - `savedAyat_removed(ayah, surah)` «أُزيلت الآية $ayah من $surah» / 'Removed ayah $ayah of $surah' (Task 8 reuses it).
  - Other strings: `places_continue` «متابعة القراءة» / 'Continue reading'; `places_continueCaption` «تُحفظ وحدها حيث تقرأ، ولا تغيّرها الانتقالات» / 'Saved by itself where you read; jumps don\'t change it'; `places_savedAyat` «الآيات المحفوظة» / 'Saved ayat'; `places_noSavedAyat` «لا توجد آيات محفوظة بعد» / 'No saved ayat yet'; `places_rename` «تسمية» / 'Rename'; `places_renameTitle` «تسمية الفاصل» / 'Rename marker'; `places_cancel` «إلغاء» / 'Cancel'; `places_remove` «إزالة» / 'Remove'; `places_more` «خيارات» / 'Options'.

- [ ] **Step 1: Write the failing tests** (Arabic; fakes + a `LastReadCubit` over a stub repo; `HadithBookmarkCubit` fake registered in GetIt for the page test)

`place_row_menu_test.dart`: `'opens a menu with إزالة that calls onRemove'`; `'the button is at least 48 by 48'`.

`places_sheet_test.dart`:
- `'continue card names the place and the time'`: last read p.50 at 3:7 updated today 6:10 → «آل عمران ٧، صفحة ٥٠», «اليوم ٦:١٠ ص», the caption; tapping «متابعة» pops `PlacesOpen(page: 50)` (no focus). Without `updatedAt` the time is absent; with no last read the card is absent.
- `'three فاصل rows; placed ones go and rename'`: hifz at 3:6 moved yesterday 21:40 → «الحفظ», «آل عمران ٦، صفحة ٥٠», «نُقل أمس ٩:٤٠ م»; `places-go-hifz` pops `PlacesOpen(page: 50, focus: 3:6)`; wird reads «غير موضوع» with no go or rename.
- `'rename writes the trimmed name'`: tap `places-rename-hifz`, type «حفظ رمضان», tap «تم» → `fawasil.renames.last == (hifz, 'حفظ رمضان')`.
- `'saved ayat show the count, the date unless migrated, and open with focus'`: two saved (one migrated) → badge «٢», «حُفظت ١٤ نوفمبر» once; tapping a row pops `PlacesOpen(page:, focus:)`.
- `'removing from the row menu offers undo'`: `place-remove` → `saved.removes.last == place`, SnackBar «أُزيلت الآية ٥ من البقرة»; «تراجع» → `saved.restores.last == place`.
- `'no saved ayat shows the empty line'`.
- `'the row arrow follows the reading direction'`: the saved row's trailing `HugeIcon` uses `forwardArrowIcon(context)`.
- `'fits at 2x text'`: 360 px wide, all groups filled → no exception.

`bookmarks_page_test.dart`:
- `'the page is أماكني with the Quran groups and the hadith section'`: title «أماكني»; `places-continue`, `places-fasil-wird`, «الآيات المحفوظة» present; «الأحاديث» shown when a hadith is bookmarked; no «الصفحات» section.
- `'a saved ayah opens the reader focused on it'`: tap the row → the pushed `extra` is a `MushafArgs` with `focusAyah` 2:5 and `origin: jump` (router with a capturing `mushafPath` route).
- `'continue opens the reader at the page'`: pushed `extra == 50`.

- [ ] **Step 2: Run** `flutter test test/features/bookmarks/presentation/pages`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `PlacesGroups`: section headers `AppSectionHeader` (the saved one with `trailing: AppStatusBadge(color: scheme.secondary, label: count.toLocalized(context), showDot: false)`), rows in `SurfaceCard`s ≥ 56 high, swatch `fasilRibbon(slot, dark: scheme.brightness == Brightness.dark)`, dates via `placeWhen(at, now: DateTime.now(), localeCode: context.langCode)`. Rename: `showDialog` with a `TextField` prefilled with `fasilName`, «إلغاء» / «تم»; «تم» calls `fawasil.rename(slot, text)`. Remove: `saved.remove(place)` then the SnackBar (`PendingS.current`, `S.undo` → `saved.restore(place)`).
- `PlacesSheet.show`: `showModalBottomSheet(isScrollControlled: true, showDragHandle: true, useSafeArea: true)` with a `DraggableScrollableSheet(expand: false, initialChildSize: 0.85)` holding a `ListView` (padding 16) with the header row and `PlacesGroups`.
- `bookmarks_page.dart`: title `PendingS.of(context).menu_places`; body `ListView` of `PlacesGroups(onOpen: (page, focus) => context.push(AppRouter.mushafPath, extra: focus == null ? page : MushafArgs.focus(focus)))` then, when hadiths exist, the existing hadith section. Remove `_QuranBookmarkTile`, `_PageBookmarkTile`, the `BookmarkCubit`/`PageBookmarkCubit` builders, the empty state and the user doc comment on the class. Hadith tile: `forwardArrowIcon(context)` instead of `strokeRoundedArrowRight01`.
- `quick_access_grid.dart`: label `PendingS.of(context).menu_places`.
- `git rm` `page_description.dart` and its test.
- `feature-widgets.md`: exception line «`bookmarks` exports `PlacesSheet` (used by `surah`)»; drop `page_description.dart` from the bookmarks utils. `icons.md`: HugeIcons list adds the فاصل chooser, the «أماكني» sheet and the Bookmarks page.

- [ ] **Step 4: Run** `flutter test test/features/bookmarks test/features/home test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git rm lib/features/bookmarks/presentation/utils/page_description.dart test/features/bookmarks/presentation/utils/page_description_test.dart
git add lib/features/bookmarks/presentation/pages/widgets/place_row_menu.dart lib/features/bookmarks/presentation/pages/widgets/places_groups.dart lib/features/bookmarks/presentation/pages/widgets/places_sheet.dart lib/features/bookmarks/presentation/pages/bookmarks_page.dart lib/features/home/presentation/pages/widgets/quick_access_grid.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md .claude/rules/icons.md test/features/bookmarks/presentation/pages/widgets/place_row_menu_test.dart test/features/bookmarks/presentation/pages/widgets/places_sheet_test.dart test/features/bookmarks/presentation/pages/bookmarks_page_test.dart
git commit -m "feat(bookmarks): أماكني sheet and page with row-menu removal and undo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The S4 ayah leaf, «أماكني» in the reader, and the old bookmark stack removed

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart`, `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, `lib/main.dart`, `lib/features/bookmarks/bookmarks_di.dart`
- Delete (lib): `lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart`, `page_bookmark_local_data_source.dart`; `lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart`, `page_bookmark_repository_impl.dart`; `lib/features/bookmarks/domain/repositories/bookmark_repository.dart`, `page_bookmark_repository.dart`; `lib/features/bookmarks/domain/usecases/get_bookmarks.dart`, `get_page_bookmarks.dart`, `toggle_bookmark.dart`, `toggle_page_bookmark.dart`; `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart`, `bookmark_state.dart`, `page_bookmark_cubit.dart`, `page_bookmark_state.dart`
- Delete (test): `test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart`, `test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart`, `test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart`, `page_bookmark_repository_impl_test.dart`, `test/features/bookmarks/domain/usecases/get_bookmarks_test.dart`, `toggle_bookmark_test.dart`, `test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`, `page_bookmark_cubit_test.dart`, `page_bookmark_state_test.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/architecture.md`, `.claude/rules/routing-and-navigation.md`, `.claude/rules/state-management-patterns.md`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`

**Interfaces:**
- Consumes: `SavedAyatCubit` (`save`, `remove`, `restore`, `state.contains/find`), `FakeSavedAyatCubit` (Task 3); `_openFawasil`, `_jumpInPlace(page, focus:)` (Task 6); `PlacesSheet.show`, `PlacesOpen`, `savedAyat_removed` (Task 7).
- Produces:
  - `AyahLeaf({…, required VoidCallback onFasil})` (all S3 params kept); action row «استماع من هنا» · «فاصل» · «حفظ الآية» · «مشاركة», keys `leaf-listen`, `leaf-fasil`, `leaf-save`, `leaf-share`. «فاصل» uses `HugeIcons.strokeRoundedBookmark03`.
  - Strings: `leaf_fasil` «فاصل» / 'Marker'; `savedAyat_saved(ayah, surah)` «حُفظت الآية $ayah من $surah» / 'Saved ayah $ayah of $surah'.

- [ ] **Step 1: Write the failing tests**

- `ayah_leaf_test.dart`, deliberate rewrite (the S3 labels and `BookmarkCubit` pin S3 behaviour): host provides `FakeSavedAyatCubit`; `'ayah leaf labels are distinct'` now expects `['استماع من هنا', 'فاصل', 'حفظ الآية', 'مشاركة']` over keys `leaf-listen`, `leaf-fasil`, `leaf-save`, `leaf-share` (a set of size 4); `'listen from here, close and save reach their handlers'` → `leaf-save` records `saved.saves.last == 3:7`, `leaf-fasil` calls `onFasil`; `'the save action announces whether the ayah is saved'` reads `SavedAyatState(items: [place 3:7])`. New:
  - `'saving confirms and تراجع removes it'`: tap `leaf-save` → SnackBar «حُفظت الآية ٧ من آل عمران»; «تراجع» → `saved.removes.last.ayah == 3:7`.
  - `'a saved ayah is removed with undo'`: state holds 3:7 → tap `leaf-save` → `removes.last`, SnackBar «أُزيلت الآية ٧ من آل عمران»; «تراجع» → `restores.last` is that place.
  - `'the banner variant has no فاصل and no save'` (extend the existing banner test: «فاصل» absent).
  - `'fits at 2x text'` stays, now with four columns.
- Harness: drop `FakeBookmarks`, `_StubPageBookmarkRepo`, the `PageBookmarkCubit`/`BookmarkCubit` providers and their imports; the `bookmarksPath` stub route goes too.
- `mushaf_page_shell_test.dart`:
  - `'menu places opens the sheet and a saved ayah jumps in place'`: saved 2:5; open «القائمة», tap `menu-tile-places`, then `places-saved-2:5` → `mushaf.jumps.last == (2, 2:5)`.
  - `'continue reading in the sheet jumps without a selection'`: stored last read p.50 → `places-continue` «متابعة» → `jumps.last == (50, null)`.
  - `'the leaf فاصل opens the chooser preselecting the slot on this page'`: hifz at 3:6, reader on p.50 with 3:7 selected (`mushaf.push`) → tap `leaf-fasil` → «نقل الحفظ إلى هنا» in a `FilledButton`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf`. Expected: FAIL.

- [ ] **Step 3: Implement**

- `ayah_leaf.dart`: four `Expanded` columns split by the existing `VerticalDivider`s; «حفظ الآية» is a `BlocSelector<SavedAyatCubit, SavedAyatState, bool>`; its tap: when saved, `remove(find(ayah)!)` and the `savedAyat_removed` SnackBar with `S.undo` → `restore(place)`; else `final place = await save(ayah)`, and when non-null the `savedAyat_saved` SnackBar with `S.undo` → `remove(place)`. Capture the messenger and the strings (`PendingS.of(context)` before the await) as `_share` does; surah name via `surahDisplayName`, ayah via `toLocalized`.
- `mushaf_page.dart`: `AyahLeaf(onFasil: () => _openFawasil(null), …)`; `MenuOpenPlaces()` → `final open = await PlacesSheet.show(context); if (!mounted || open == null) return; _jumpInPlace(open.page, focus: open.focus);` (drop the `AppRouter.bookmarksPath` push and the now-unused import if any).
- `main.dart`: remove the `BookmarkCubit` and `PageBookmarkCubit` providers and imports. `bookmarks_di.dart`: remove the old registrations and imports.
- `git rm` every file in the Delete lists. `grep -rn "BookmarkCubit\|PageBookmark\|bookmark_repository\|toggle_bookmark\|get_bookmarks" lib test | grep -v HadithBookmark` returns nothing.
- Rules: `architecture.md` app-wide list drops `BookmarkCubit`, `PageBookmarkCubit`; `routing-and-navigation.md` "App-wide cubits" names `FasilCubit`, `SavedAyatCubit` instead of "bookmarks"; `state-management-patterns.md` example list `BookmarkCubit` → `SavedAyatCubit`.

- [ ] **Step 4: Run** `flutter test` (whole suite) and `flutter analyze --no-fatal-infos`. Expected: all pass, 1 skipped, count = 1311 + added − deleted; 0 errors, 0 warnings, ≤ 69 infos.

- [ ] **Step 5: Commit**

```bash
git rm lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart lib/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart lib/features/bookmarks/domain/repositories/bookmark_repository.dart lib/features/bookmarks/domain/repositories/page_bookmark_repository.dart lib/features/bookmarks/domain/usecases/get_bookmarks.dart lib/features/bookmarks/domain/usecases/get_page_bookmarks.dart lib/features/bookmarks/domain/usecases/toggle_bookmark.dart lib/features/bookmarks/domain/usecases/toggle_page_bookmark.dart lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart lib/features/bookmarks/presentation/cubit/bookmark_state.dart lib/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart lib/features/bookmarks/presentation/cubit/page_bookmark_state.dart test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart test/features/bookmarks/data/repositories/page_bookmark_repository_impl_test.dart test/features/bookmarks/domain/usecases/get_bookmarks_test.dart test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart test/features/bookmarks/presentation/cubit/page_bookmark_cubit_test.dart test/features/bookmarks/presentation/cubit/page_bookmark_state_test.dart
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/main.dart lib/features/bookmarks/bookmarks_di.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/architecture.md .claude/rules/routing-and-navigation.md .claude/rules/state-management-patterns.md test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart
git commit -m "feat(mushaf): S4 ayah leaf, أماكني in the reader; remove the old bookmark stack

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
