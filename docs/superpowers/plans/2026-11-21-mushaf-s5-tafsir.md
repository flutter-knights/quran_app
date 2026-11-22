# Mushaf S5 (Tafsir al-Muyassar, ayah strip, full detent) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the meaning of an ayah in the leaf: one line of التفسير الميسر in the compact leaf, a full-height study detent with an ayah strip cropped from the page, static section chips, the book and source rows, and previous/next ayah, all fed by an online-with-cache tafsir store that never dead-ends offline.

**Architecture:** A new `features/tafsir/` holds the entity `Tafsir`, `TafsirRepository` (`Either<Failure, _>`), `GetAyahTafsir`, a Dio remote data source (one page call fills the cache, a per-ayah fallback, one `CancelToken` per page owned by the repository, per-request timeouts), a `Box<String>('tafsirCache')` local data source, the route-scoped `TafsirCubit` and the exported `TafsirSection` (compact `lead` mode and full mode). The reader (`surah`) gets the S5 action row and lead line in `AyahLeaf`, a new `AyahStrip` (`drawImageRect` over the ayah's line rects) and a new full-detent widget `AyahStudyLeaf`, drawn as a layer over the reading area while the compact leaf stays mounted underneath. `MushafCubit.stepTo` moves the selection for «الآية السابقة» / «الآية التالية», turning the page behind when needed. «العرض» gains the «عند الضغط على الآية» selector that S3 deferred.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), flutter_bloc + bloc_test, mocktail, equatable, dartz, dio 5.9.2 (`CancelToken`, per-request `Options` timeouts), hive_ce, skeletonizer 3, hugeicons, share_plus, the vendored `quran` package.

**Spec:** `docs/superpowers/specs/2026-11-21-mushaf-leaf-ribbon-design.md`: §6 in full, D1, D3, D4, the S5 row of the §3.3 action table and its lead-line bullet, the «عند الضغط على الآية» line of §3.6, the `TafsirCubit`, `TafsirSection` and `AyahStrip` items of §7, and the §8 rows on alquran.cloud, the Muyassar licence and strip memory. Where the spec and this plan disagree the spec wins, except for the **Deliberate readings** below, where the plan governs. Raise any other disagreement in the task report.

## Global Constraints

- Work on `feature/mushaf-s5-tafsir`. Never switch branches, never touch `main`, never push, never rebase, never amend.
- Commits: stage explicit paths only (never `git add -A` / `git add .`). Never stage `quran-1.4.1/**`, `lib/generated/**`, `ios/Podfile.lock`, `.claude/agents/` or `.claude/skills/impeccable/`. Conventional message (`feat|fix|refactor|test(scope): …`) ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No comments and no doc comments in new or changed code. No redundant type annotations. Lean code. A user comment inside lines a task replaces goes with them; other existing comments stay.
- New strings: add each to both `lib/l10n/intl_ar.arb` and `lib/l10n/intl_en.arb` and mirror it in `lib/core/localization/pending_s.dart` as `String get key => _ar ? '…' : '…';` (single quotes, `\'` for an apostrophe). Read with `PendingS.of(context)` in `build`, `PendingS.current` in callbacks. `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`; never run `intl_utils:generate`. Reuse, do not duplicate: `S.share` «مشاركة», `S.share_failed`, `S.playback_previous` «الآية السابقة», `S.playback_next` «الآية التالية», `PendingS.mushaf_retry` «إعادة المحاولة», `PendingS.onb_later` «لاحقًا».
- Arabic numbers use Arabic-Indic digits via `toLocalized(context)` / `toIndicNumerals(localeCode)`.
- Colours: everything drawn on the reading paper (compact leaf, full detent, strip, chips, `TafsirSection` on the leaf) reads `MushafPaperX` / `MushafPaperColors`; every Text/Outlined button on the paper uses `colors.paperButton()` (`outlined: true` for outlined). The filled «استماع من هنا» keeps `colorScheme.primary`. The «العرض» sheet reads `context.colorScheme`. Hex literals only where `theming.md` allows. Text styles only `TS.*`; `test/config/theme/typography_ratchet_test.dart` must not rise. Leaf and full-detent text is `TS.*14` or larger, except `AppStatusBadge` labels (`TS.bold12`, owned by the core widget).
- Icons: HugeIcons in the leaf and the full detent; arrows only via `backArrowIcon(context)` / `forwardArrowIcon(context)`.
- Layers: `features/tafsir/domain/` imports no `package:flutter`, `package:dio` or `generated/` directly; `core/errors/failure.dart` is allowed (every existing domain imports it). Presentation never imports `data/`. The repository catches every exception (`CacheException` → `CacheFailure`, anything else → `Failure.fromException(e)`).
- Cubits: `if (isClosed) return;` before every emit after an `await`; sealed states, `Equatable`, every field in `props`.
- SnackBars raised by the full detent go through `showPlaceNotice` (`bookmarks/presentation/utils/place_notices.dart`), except the share fallback which keeps today's `SnackBar(content: Text(S.share_failed, style: TS.regular14))`.
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`; never modify `assets/mushaf/**`.
- Every task has a format step before its commit: `dart format` followed by exactly the `.dart` paths in that task's `git add` line (never a directory, `.`, `lib`, `test` or `lib/generated/**`).
- Every task's Step 4 ends with a full `flutter test` and `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings, ≤ 69 infos; all tests pass, 1 skipped, at the cumulative total the step names. The totals assume 1523 at the start of Task 1; if the starting count differs, keep the same per-task deltas. Running totals: Task 1 → 1545, 2 → 1555, 3 → 1564, 4 → 1576, 5a → 1585, 5b → 1596, 6a → 1597, 6b → 1609, 7 → 1611.
- Rule catalogues (`feature-widgets.md`, `core-utilities.md`, `routing-and-navigation.md`, `icons.md`) and `CLAUDE.md`'s feature summary change in the task that changes what they describe.
- The PR (opened later by the workflow, not by a task) lists the Muyassar licence as open for the owner (§8).

## Deliberate readings (the plan governs here)

1. **Cancellation lives in data and is never an error.** The repository owns the `CancelToken`; the domain sees only `TafsirRepository.cancelPending()` (exposed as `GetAyahTafsir.cancel()`). `TafsirCubit.cancel()` cancels and bumps a private request counter, and emits `TafsirIdle` only from `TafsirLoading` (a loaded or failed state stays, so a closing leaf never flashes a skeleton during its fade and reselecting a loaded ayah needs no refetch); every `load` result checks the counter, so a cancelled (or superseded) request never emits, and «تعذّر تحميل التفسير» appears only for a real failure.
2. **When a request is cancelled ("on page change").** The reader calls `TafsirCubit.cancel()` when the selection clears; a manual page swipe clears the selection, so a swipe cancels. A new selection on another page makes the repository cancel the old page's token before starting the new page. A page change that keeps the selection (playback turning the page while another ayah stays selected) does not cancel, since the open leaf still needs that tafsir. Closing the cubit (leaving the reader) cancels.
3. **The fetched page is the ayah's own page**, from `QuranPageService.getPageForAyah(surah, ayah)`, never `currentPage`. This holds in the cubit (the page to fetch) and in the reader (the strip's page and lines, reading 11), because the two differ in scroll mode (an ayah on a neighbouring page item) and in page mode (`setPage(byUser: false)` keeps the selection while playback turns the page).
4. **Cache first, one call per page, one token per page.** A cached ayah returns before any token logic, so it never cancels a page in flight. A miss joins the page request: if `_page != page`, the repository cancels `_token`, sets `_page = page`, `_token = CancelToken()` and `_inFlight = null`. Concurrent misses on the same page share `_inFlight`, which reads the page and writes every ayah of it with **one** `putAll` inside the shared future, before it completes. Each caller holds the future it awaited and, in a `finally`, clears `_inFlight` only `if (identical(_inFlight, future))`, so a stale or cancelled page never clears a newer request, and a failed page is asked again on the next request. `_page` and `_token` are not cleared when the page future settles: they stay until the next page replaces them or `cancelPending()` cancels the token and clears all three. Only an ayah absent from the page response falls back to `/v1/ayah/{s}:{a}/ar.muyassar`, on the token the caller joined with (so `cancelPending()` and a later page cancel it too), then caches it with `putAll([t])`. A failed cache write still returns the fetched text.
5. **A body is valid only when `code == 200` and `data` is a `Map`** (for a page, `data['ayahs']` a `List` of maps with `surah.number`, `numberInSurah` and a `String` `text`); anything else throws `FormatException` in the data source, which the repository turns into a `Left`. Every request passes `Options(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15))` (the shared `Dio` has none), so a hung connection ends as `TimeoutFailure` and reaches the retry row.
6. **The tafsir loads when the leaf opens, whatever `tapAction` is.** `options` hides only the compact lead line; «تفسير الآية» still finds the text ready. Ayah 0 (banner) never loads; the banner leaf has no tafsir line, no «تفسير الآية», and a drag up on it does nothing.
7. **Detent state is local UI state above the leaf.** `AyahLeaf` is keyed by `ValueKey(selected)`, so `_MushafPageState` holds `final _studying = ValueNotifier(false)`; it survives previous/next and resets to `false` whenever the selection clears.
8. **The full detent is a layer, not a taller leaf.** `AyahStudyLeaf` is drawn by `_StudyLayer` as the last child of the reading-area `Stack` (`Positioned.fill`, opaque, absorbs taps), between the running head and the foot band, which both stay visible; in scroll mode the `_NoticeSlot` between the reading area and the foot band hides while studying. The compact leaf stays mounted underneath (wrapped in `ExcludeSemantics(excluding: studying)`), so `_overlayHeight`, `_PageSlide`, the scroll padding and `_slideScrollTo` never see the full height, and collapsing returns to exactly the page position the compact leaf had.
9. **Open, collapse, close.** Open: «تفسير الآية», a tap on the lead line, or a drag up on the compact (non-banner) leaf (`primaryVelocity < -300`). Collapse to the compact leaf (selection kept): «العودة إلى المصحف», a drag down on the full detent's header (`> 300`), or system Back. System Back at the compact leaf closes it, as today.
10. **Previous / next use `MushafCubit.stepTo`, not `jumpTo`; the page behind follows (spec §6).** `adjacentAyah` crosses surahs and treats a banner as ayah 1; it returns null before 1:1 and after 114:6, which disables the button. The target page is `getPageForAyah(target)`; "same page" means `page == state.currentPage`, in both `_stepAyah` and `stepTo`. Same page → selection moves. Another page → the page turns to the target and the ayah is selected, with no return chip (studying forward is reading, not a jump) and `_lastReadSaver.onManualTurn()`, because the reader moved on deliberately. So a selection kept on page 51 while page 50 shows turns the page to 51 on the next step, and «المصحف خلفك على هذه الآية» stays true.
11. **AyahStrip draws the ink layer only** (the ayah-number rosette lives on the accent layer and is not drawn), from the bounds of the ayah's own page only (an ayah running onto the next page shows its first part), at most 3 line rects, stacked top to bottom with one common scale set by the widest rect and each rect aligned to the right edge (RTL). The image is injectable (`imageFor`) so tests never decode a real page; the default decodes `AssetsDir.mushafPage(page)` at `min(1536, ceil(width × dpr))` px wide. The previous decode is disposed whenever it is replaced (§8 memory).
12. **`TafsirSection` takes its colours by constructor** (`ink`, `mutedInk`, `buttonStyle`), so `tafsir` imports nothing from `surah`'s paper colours. It is the one export, with a `lead` mode for the compact line.
13. **States for another ayah, and `TafsirIdle`, render as loading.** Only `TafsirLoaded` / `TafsirFailed` for the section's own ayah render text or the retry row. The test fake loads synchronously, so `pumpAndSettle` never waits on the skeleton shimmer.
14. **The section chips are static.** «التفسير» is announced selected; «الترجمة», «معاني الكلمات», «ملاحظتي» are announced disabled and carry a quiet `AppStatusBadge(color: colors.ink2, label: PendingS.of(context).onb_later, showDot: false)`. No chip reacts to a tap.
15. **The «عند الضغط على الآية» selector is drawn in S5** (S3 stored `tapAction` and deferred the control to this slice).

## Review Focus

1. **Offline and uncached, then back online.** The full detent shows «تعذّر تحميل التفسير» + «إعادة المحاولة», and the retry succeeds once the network returns; the compact line shows the same message in one line. A hung connection times out into the same row. Tasks 1 and 2 pin the `NetworkFailure`, the `TimeoutFailure` and the retry; Task 3 pins both renderings.
2. **Fast taps and swipes while a page request is in flight.** The newest selection wins, and a cancellation never paints the error. Task 1 pins token cancellation, the shared in-flight call, the identity guard (a settled cancelled page never clears the newer request) and a cancelled fallback; Task 2 pins A→B and cancel-while-loading; Task 6b pins that clearing the selection cancels.
3. **Boundaries.** «الآية السابقة» is disabled on 1:1 and «الآية التالية» on 114:6; 1:7 → 2:1 crosses surah and page; the banner never loads and never opens the full detent. Tasks 5a, 5b, 6a and 6b pin each.
4. **Large text (2×) at 360 px.** The four-column compact leaf with its lead line and the full detent lay out without overflow (the full detent scrolls). Tasks 3, 5b, 6a and 6b pump each at `TextScaler.linear(2.0)` and 360 px.
5. **English UI.** The Muyassar body stays right-to-left and the previous/next arrows point the right way. Tasks 3 and 5b pin it under `Locale('en')`.

## Out of slice

- Design-only details the spec does not adopt: the page thumbnail beside the strip, the book picker menu («السعدي», «ابن كثير», «الطبري»), the design caption «مختصر، محفوظ على الجهاز» (the spec's «يُحمَّل من الإنترنت ثم يُحفظ على الجهاز» wins), «نقل فاصل إلى بداية السورة».
- Translation, word meanings, notes, other tafsir books, bundling Muyassar (D1, D4).
- The §9 emulator QA pass and the PR, which the workflow runs after this plan's tasks.

---

### Task 1: Tafsir domain, data sources, repository, cache box and DI

**Files:**
- Create: `lib/features/tafsir/domain/entities/tafsir.dart`, `lib/features/tafsir/domain/repositories/tafsir_repository.dart`, `lib/features/tafsir/domain/usecases/get_ayah_tafsir.dart`
- Create: `lib/features/tafsir/data/datasources/remote/tafsir_remote_data_source.dart`, `lib/features/tafsir/data/datasources/local/tafsir_local_data_source.dart`, `lib/features/tafsir/data/repositories/tafsir_repository_impl.dart`
- Create: `lib/features/tafsir/tafsir_di.dart`
- Modify: `lib/config/hive_config.dart`, `lib/core/di/dependency_injection.dart`
- Create (tests): `test/features/tafsir/data/datasources/tafsir_remote_data_source_test.dart`, `test/features/tafsir/data/datasources/tafsir_local_data_source_test.dart`, `test/features/tafsir/data/repositories/tafsir_repository_impl_test.dart`

**Interfaces:**
- Produces:
  - `class Tafsir extends Equatable { const Tafsir({required int surah, required int ayah, required String text, String book = 'muyassar'}); }` with every field in `props`.
  - `abstract class TafsirRepository { Future<Either<Failure, Tafsir>> getAyahTafsir({required int surah, required int ayah, required int page}); void cancelPending(); }`
  - `class GetAyahTafsir { GetAyahTafsir(this._repository); Future<Either<Failure, Tafsir>> call({required int surah, required int ayah, required int page}); void cancel(); }`
  - `abstract class TafsirRemoteDataSource { Future<List<Tafsir>> getPage(int page, {CancelToken? cancelToken}); Future<Tafsir> getAyah(int surah, int ayah, {CancelToken? cancelToken}); }` and `class TafsirRemoteDataSourceImpl implements TafsirRemoteDataSource { TafsirRemoteDataSourceImpl({required this.dio}); final Dio dio; }`. URLs: `https://api.alquran.cloud/v1/page/$page/ar.muyassar`, `https://api.alquran.cloud/v1/ayah/$surah:$ayah/ar.muyassar`. Each `dio.get(url, cancelToken: cancelToken, options: Options(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15)))` (reading 5). Parse in a private function (no `*_model.dart` file: `build.yaml` runs the Hive generator on that pattern).
  - `class TafsirLocalDataSource { TafsirLocalDataSource({required this.box}); final Box<String> box; static String keyOf(int surah, int ayah) => 'muyassar:$surah:$ayah'; String? get(int surah, int ayah); Future<void> putAll(Iterable<Tafsir> items); }`; a failed read or write throws `CacheException` (a failed read reaches the caller as `Left(CacheFailure)`, the only source of the repository's `on CacheException` arm; a failed write is swallowed by `_store`).
  - `class TafsirRepositoryImpl implements TafsirRepository { TafsirRepositoryImpl({required this.remote, required this.local}); }` per readings 1, 4 and 5: private `CancelToken? _token`, `int? _page`, `Future<List<Tafsir>>? _inFlight`. Shape of `getAyahTafsir`:
    ```dart
    Future<List<Tafsir>>? future;
    try {
      final cached = local.get(surah, ayah);
      if (cached != null) return Right(Tafsir(surah: surah, ayah: ayah, text: cached));
      if (_page != page) {
        _token?.cancel();
        _page = page;
        _token = CancelToken();
        _inFlight = null;
      }
      final token = _token!;
      future = _inFlight ??= _fetchPage(page, token);
      final items = await future;
      final hit = items.where((t) => t.surah == surah && t.ayah == ayah).firstOrNull;
      return Right(hit ?? await _fetchAyah(surah, ayah, token));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(Failure.fromException(e));
    } finally {
      if (future != null && identical(_inFlight, future)) _inFlight = null;
    }
    ```
    `_fetchPage` reads the page with `token`, then `_store(items)` once, then returns the items; `_fetchAyah` reads one ayah with `token`, then `_store([t])`. `_store` swallows a `CacheException` (a failed write still returns the text). `cancelPending()`: `_token?.cancel(); _token = null; _page = null; _inFlight = null;`.
  - Box: `await _openCacheBox<String>('tafsirCache');` in `initHive()` (re-fetchable cache, so `_openCacheBox`).
  - DI `void initTafsir()`: `TafsirRemoteDataSource`, `TafsirLocalDataSource(box: Hive.box<String>('tafsirCache'))`, `TafsirRepository`, `GetAyahTafsir` as lazy singletons; called from `initGetIt()` after `initMushaf()`.

- [ ] **Step 1: Write the failing tests**

Remote (mocktail `_MockDio`, `registerFallbackValue(CancelToken())`, `registerFallbackValue(Options())`, `dio.get` stubbed with `cancelToken: any(named: 'cancelToken'), options: any(named: 'options')`; fixtures shaped like the live API: `{'code': 200, 'status': 'OK', 'data': {'number': 2, 'ayahs': [{'number': 8, 'text': 'هذه الحروف…', 'surah': {'number': 2}, 'numberInSurah': 1}, …]}}`):
- `'getPage reads every ayah of the page'`: `dio.get('https://api.alquran.cloud/v1/page/2/ar.muyassar', cancelToken: token, options: captureAny(named: 'options'))` is called with the token passed in, and the captured `Options` has `receiveTimeout == const Duration(seconds: 15)` and `connectTimeout == const Duration(seconds: 10)`; result `[Tafsir(surah: 2, ayah: 1, text: 'هذه الحروف…'), Tafsir(surah: 2, ayah: 2, …)]`.
- `'getAyah reads one ayah'`: URL `…/v1/ayah/2:255/ar.muyassar`, `data` a map with `surah.number` 2, `numberInSurah` 255 → `Tafsir(surah: 2, ayah: 255, …)`.
- `'a code other than 200 throws FormatException'` (`{'code': 404, 'status': 'NOT FOUND', 'data': 'Not found'}`).
- `'a string body throws FormatException'` (`data: '<html>'`).

Local (Hive in a temp dir as in `test/features/surah/data/repositories/last_read_repository_impl_test.dart`, `Box<String>`):
- `'a missing ayah reads null'`; `'putAll stores each ayah under muyassar:s:a'` (`box.get('muyassar:2:255')` is the text); `'get returns the stored text'`; `'a failed write throws CacheException'` (close the box, `putAll` → `throwsA(isA<CacheException>())`).

Repository (`_MockRemote`, `_MockLocal`; pending requests driven by `Completer`s; the token a call used is captured with `captureAny(named: 'cancelToken')`):
- `'a cached ayah never touches the network'` → `Right(Tafsir(…))`, `verifyNever(remote.getPage…)`.
- `'a miss fetches the page once and caches all of it'`: page 1 returns 1:1–1:7; `getAyahTafsir(surah: 1, ayah: 3, page: 1)` → text of 1:3; `local.putAll` called once, captured with 7 items.
- `'two ayat of one page share one request'`: two calls before the first completes → `remote.getPage(1, …)` called once, both `Right`, `local.putAll` called once.
- `'an ayah missing from the page falls back to the ayah endpoint'`: page 50 lacks 3:9 → `remote.getAyah(3, 9, …)` called with the page's token, its result cached and returned.
- `'a request for another page cancels the previous one'`: capture the first token (page 1, pending), call page 2 → first token `isCancelled`.
- `'a cancelled earlier page never clears the newer request'`: page 1 pending, page 2 pending, complete page 1 with `DioException(type: DioExceptionType.cancel, requestOptions: RequestOptions())`, then request another page-2 ayah → `remote.getPage(2, …)` called once; then `cancelPending()` → the page-2 token `isCancelled`.
- `'a cached ayah on another page leaves the in-flight page running'`: page 1 pending, then a cached ayah of page 2 → `Right`, page 1's token `isCancelled == false`.
- `'cancelPending cancels the request in flight'`.
- `'cancelPending reaches a running fallback'`: page 50 returns without 3:9, `getAyah(3, 9, …)` pending; `cancelPending()` → the token passed to `getAyah` `isCancelled`.
- `'offline becomes a NetworkFailure, never a throw'`: `getPage` throws `DioException(type: DioExceptionType.connectionError, requestOptions: RequestOptions())` → `Left(isA<NetworkFailure>())`.
- `'a timeout becomes a TimeoutFailure'`: `getPage` throws `DioException(type: DioExceptionType.receiveTimeout, requestOptions: RequestOptions())` → `Left(isA<TimeoutFailure>())`.
- `'a page that failed is asked again on the next request'`: first `getPage(1, …)` throws the connection error, the second returns 1:1–1:7 → second result `Right`, `remote.getPage(1, …)` called twice.
- `'a malformed body becomes a Failure'`: `getPage` throws `FormatException()` → `Left`.
- `'a failed cache write still returns the text'`: `putAll` throws `CacheException('x')` → `Right`.

- [ ] **Step 2: Run** `flutter test test/features/tafsir`. Expected: FAIL (`Tafsir` undefined).

- [ ] **Step 3: Implement** the files in Interfaces; `hive_config.dart` opens `tafsirCache` after `places_meta`; `dependency_injection.dart` imports and calls `initTafsir()`.

- [ ] **Step 4: Run** `flutter test test/features/tafsir`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +22 tests (remote 4, local 4, repository 14) → 1545 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tafsir/domain/entities/tafsir.dart lib/features/tafsir/domain/repositories/tafsir_repository.dart lib/features/tafsir/domain/usecases/get_ayah_tafsir.dart lib/features/tafsir/data/datasources/remote/tafsir_remote_data_source.dart lib/features/tafsir/data/datasources/local/tafsir_local_data_source.dart lib/features/tafsir/data/repositories/tafsir_repository_impl.dart lib/features/tafsir/tafsir_di.dart lib/config/hive_config.dart lib/core/di/dependency_injection.dart test/features/tafsir/data/datasources/tafsir_remote_data_source_test.dart test/features/tafsir/data/datasources/tafsir_local_data_source_test.dart test/features/tafsir/data/repositories/tafsir_repository_impl_test.dart
git commit -m "feat(tafsir): Muyassar store, one alquran.cloud call per page cached in tafsirCache

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: TafsirCubit, route provider and test fake

**Files:**
- Create: `lib/features/tafsir/presentation/cubit/tafsir_cubit.dart`, `lib/features/tafsir/presentation/cubit/tafsir_state.dart`
- Modify: `lib/features/tafsir/tafsir_di.dart`, `lib/config/router/app_router.dart` (both `mushafPath` and `mushafImagePath` builders), `.claude/rules/routing-and-navigation.md` (route-scoped line)
- Create (tests): `test/features/tafsir/presentation/cubit/tafsir_cubit_test.dart`, `test/features/tafsir/tafsir_fakes.dart`

**Interfaces:**
- Consumes: `GetAyahTafsir`, `Tafsir` (Task 1); `QuranPageService`; `AyahIdentifier`.
- Produces:
  - `sealed class TafsirState extends Equatable`; `final class TafsirIdle`; `final class TafsirLoading { const TafsirLoading(this.ayah); final AyahIdentifier ayah; }`; `final class TafsirLoaded { const TafsirLoaded(this.ayah, this.tafsir); final AyahIdentifier ayah; final Tafsir tafsir; }`; `final class TafsirFailed { const TafsirFailed(this.ayah); final AyahIdentifier ayah; }`.
  - `class TafsirCubit extends Cubit<TafsirState> { TafsirCubit({required GetAyahTafsir getAyahTafsir, required QuranPageService pageService}); Future<void> load(AyahIdentifier ayah); Future<void> retry(); void cancel(); }` starting at `TafsirIdle`. `load`: ayah 0 → `cancel()` and return; already `TafsirLoaded` for that ayah → return; otherwise bump the counter, emit `TafsirLoading(ayah)`, call with `page: pageService.getPageForAyah(ayah.surah, ayah.ayah)`, and after the await return unless `!isClosed` and the counter is unchanged. `retry` reloads the ayah of a `TafsirFailed`. `close()` calls `cancel` on the use case.
  - DI: `sl.registerFactory(() => TafsirCubit(getAyahTafsir: sl(), pageService: sl()))`.
  - Route: each mushaf builder returns `MultiBlocProvider(providers: [BlocProvider(create: (_) => sl<MushafCubit>(param1: args)), BlocProvider(create: (_) => sl<TafsirCubit>())], child: MushafPage(args: args))`.
  - Test fake: `class FakeTafsirCubit extends Cubit<TafsirState> implements TafsirCubit { FakeTafsirCubit([super.initial = const TafsirIdle()]); void push(TafsirState s) => emit(s); }` (as `FakeMushaf.push` in `mushaf_page_harness.dart`) with `loads`, `retries`, `cancels` records and `bool failNext`; `load` emits synchronously `TafsirLoaded(ayah, Tafsir(surah: ayah.surah, ayah: ayah.ayah, text: tafsirText))` (`const tafsirText = 'هذا نص تفسير تجريبي طويل يكفي لأن يملأ أكثر من سطر واحد في الورقة'`), or `TafsirFailed(ayah)` when `failNext`; ayah 0 emits `TafsirIdle`; `cancel` records and emits `TafsirIdle` only from `TafsirLoading`. Tests seed states with the constructor (`FakeTafsirCubit(TafsirLoading(…))`) or `push`.

- [ ] **Step 1: Write the failing tests** (`bloc_test`, a hand-written `_FakeRepo implements TafsirRepository` driven by `Completer`s and recording `pages` and `cancelled`, a page service stub mapping 2:255 → 42 and anything else → 1)

- `'load emits loading then the tafsir'`.
- `"asks for the ayah's own page"`: `load(2:255)` → repo saw page 42.
- `'a failure emits failed for that ayah'`.
- `'ayah 0 loads nothing'`: no repo call, state `TafsirIdle`.
- `'an ayah already loaded is not fetched again'`.
- `'a slow first ayah never overwrites a newer one'`: load A (pending), load B (completes), then complete A → states end `[…, TafsirLoaded(B, …)]`, no `TafsirLoaded(A, …)` after it.
- `'retry reloads the failed ayah'`: fail, then succeed → `TafsirLoaded`.
- `'cancel drops the pending result and never emits failed'`: load (pending), `cancel()` → `TafsirIdle`, repo `cancelled`, completing the request with `Left` emits nothing.
- `'cancel after a load keeps the tafsir'`: loaded A, `cancel()` → no emit, state still `TafsirLoaded(A, …)`.
- `'close cancels the request in flight'`.

- [ ] **Step 2: Run** `flutter test test/features/tafsir/presentation`. Expected: FAIL.

- [ ] **Step 3: Implement** the cubit, state, DI factory and both route builders. `routing-and-navigation.md` route-scoped line: add `TafsirCubit` (the mushaf routes provide `MushafCubit` and `TafsirCubit` in one `MultiBlocProvider`).

- [ ] **Step 4: Run** `flutter test test/features/tafsir test/config/router`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +10 → 1555 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tafsir/presentation/cubit/tafsir_cubit.dart lib/features/tafsir/presentation/cubit/tafsir_state.dart lib/features/tafsir/tafsir_di.dart lib/config/router/app_router.dart .claude/rules/routing-and-navigation.md test/features/tafsir/presentation/cubit/tafsir_cubit_test.dart test/features/tafsir/tafsir_fakes.dart
git commit -m "feat(tafsir): TafsirCubit, stale results dropped, cancel never an error

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: TafsirSection (lead and full modes)

**Files:**
- Create: `lib/features/tafsir/presentation/widgets/tafsir_section.dart`
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`
- Create (test): `test/features/tafsir/presentation/widgets/tafsir_section_test.dart`

**Interfaces:**
- Consumes: `TafsirCubit`, `TafsirState` (Task 2); `FakeTafsirCubit` (`test/features/tafsir/tafsir_fakes.dart`).
- Produces: `class TafsirSection extends StatelessWidget { const TafsirSection({super.key, required AyahIdentifier ayah, required Color ink, required Color mutedInk, required ButtonStyle buttonStyle, bool lead = false, VoidCallback? onTap}); }` reading `TafsirCubit` through `BlocSelector<TafsirCubit, TafsirState, TafsirState>` with `selector: (s) => switch (s) { TafsirLoaded(ayah: final a) || TafsirFailed(ayah: final a) when a == ayah => s, _ => TafsirLoading(ayah) }` (reading 13), so another ayah's state never rebuilds it.
  - Placeholder text for the skeleton: `'هذا نص تفسير مؤقت يملأ السطر'`, four copies in full mode, one in lead mode, each a `Text` in the loaded style, inside one `Skeletonizer`.
  - Full mode, a `Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8)`, top to bottom: book row `PendingS.tafsir_muyassar` (`TS.bold16`, `ink`) over `PendingS.tafsir_bookCaption` (`TS.regular14`, `mutedInk`); body: loaded → `Text(text, textDirection: TextDirection.rtl, style: TS.regular16.copyWith(height: 1.95, color: ink))` (key `tafsir-body`); loading → the skeleton; failed → `Semantics(liveRegion: true)` `PendingS.tafsir_loadFailed` (`TS.medium14`, `ink`) + `TextButton(key: ValueKey('tafsir-retry'), style: buttonStyle, onPressed: retry)` labelled `PendingS.mushaf_retry`; then the source line `PendingS.tafsir_source` (`TS.regular14`, `mutedInk`).
  - Lead mode (`key` given by the caller): `InkWell(onTap: onTap, child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Align(alignment: AlignmentDirectional.centerStart, child: …)))`. Loaded → one `Text` of the body, `maxLines: 1`, `overflow: TextOverflow.ellipsis`, `TS.regular14` in `mutedInk`, RTL; loading → the one-line skeleton; failed → `Row(children: [Expanded(child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.medium14 in ink)), the same retry button])`. No book row, no source.
- Strings (ar / en): `tafsir_muyassar` «التفسير الميسر» / 'Al-Tafsir al-Muyassar'; `tafsir_bookCaption` «يُحمَّل من الإنترنت ثم يُحفظ على الجهاز» / 'Loaded from the internet, then saved on the device'; `tafsir_source` «المصدر: التفسير الميسر، مجمع الملك فهد، عبر alquran.cloud» / 'Source: Al-Tafsir al-Muyassar, King Fahd Complex, via alquran.cloud'; `tafsir_loadFailed` «تعذّر تحميل التفسير» / 'Couldn\'t load the tafsir'.

- [ ] **Step 1: Write the failing tests** (host: `MaterialApp` with `S.delegate`, `Locale('ar')`, `BlocProvider<TafsirCubit>.value(FakeTafsirCubit(…))`, width 360, `ink`/`mutedInk` from `MushafPaper.cream.colors`, `buttonStyle: MushafPaper.cream.colors.paperButton()`, a `Material` ancestor for the `InkWell`; `pump()` only while a skeleton shows)

- `'loading shows a skeletonized paragraph and no retry'` (`FakeTafsirCubit(TafsirLoading(3:7))` → `find.byType(Skeletonizer)` one, `tafsir-retry` none).
- `'a state for another ayah reads as loading'` (`FakeTafsirCubit(TafsirLoaded(3:8, …))` for a section on 3:7 → skeleton, no 3:8 text).
- `'loaded shows the text at regular16 with line height 1.95'` (style `fontSize == TS.regular16.fontSize`, `height == 1.95`, colour `ink`).
- `'failed offers إعادة المحاولة that retries'` (tap → `fake.retries == 1`; message «تعذّر تحميل التفسير» shown; the button's `style` is the one passed in).
- `'full mode names the book, the caption and the source'`.
- `'lead mode shows one line with an ellipsis and opens on tap'` (`maxLines == 1`, `overflow == TextOverflow.ellipsis`; tap → `onTap` called; book row and source absent).
- `'lead mode failure keeps the retry in one row'`.
- `'lead failure fits at 2x text in 360 px'` (`TextScaler.linear(2.0)`, `TafsirFailed(3:7)`, lead mode: no exception, `tafsir-retry` shown).
- `'the body stays right-to-left in English'` (`Locale('en')`, `textDirection == TextDirection.rtl`).

- [ ] **Step 2: Run** `flutter test test/features/tafsir/presentation/widgets`. Expected: FAIL.

- [ ] **Step 3: Implement** the widget and the four strings. `feature-widgets.md`: the placement bullet becomes «`quran_playback` and `tafsir` have no pages, so their widgets sit in `presentation/widgets/`.»; in the exception bullet add «`tafsir` exports `TafsirSection` (used by `surah`); it takes its ink colours and button style by constructor, so `tafsir` reads nothing from `surah`'s paper colours».

- [ ] **Step 4: Run** `flutter test test/features/tafsir test/core/localization`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +9 → 1564 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tafsir/presentation/widgets/tafsir_section.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/tafsir/presentation/widgets/tafsir_section_test.dart
git commit -m "feat(tafsir): TafsirSection with a one-line lead, skeleton loading and inline retry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: AyahStrip and its layout

**Files:**
- Create: `lib/features/surah/presentation/utils/ayah_strip_layout.dart`, `lib/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart`
- Modify: `lib/core/constants/assets_dir.dart` (add `mushafPage`), `.claude/rules/core-utilities.md` (the `AssetsDir` line), `.claude/rules/feature-widgets.md` (surah utils list)
- Create (tests): `test/features/surah/presentation/utils/ayah_strip_layout_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart`, `test/core/constants/assets_dir_test.dart`

**Interfaces:**
- Consumes: `NormalizedRect`, `MushafPaperColors`, `mushafPageAspect`.
- Produces:
  - `static String mushafPage(int page) => 'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png';` on `AssetsDir` (the existing hardcoded copies in `mushaf_page.dart` and `mushaf_page_view.dart` stay; no sweep).
  - `const ayahStripMaxLines = 3;` `({List<({Rect src, Rect dst})> slices, double height}) ayahStripLayout({required List<NormalizedRect> lines, required Size image, required double width})` per reading 11: `lines.take(3)`, `scale = width / (maxW × image.width)`, slice `i`: `src = Rect.fromLTWH(x·W, y·H, w·W, h·H)`, `dst = Rect.fromLTWH(width − w·W·scale, top_i, w·W·scale, h·H·scale)`, `top_i` = sum of the previous heights; empty lines → no slices, height 0.
  - `int ayahStripCacheWidth(double width, double devicePixelRatio)` → `min(1536, (width × dpr).ceil())`.
  - `class AyahStrip extends StatefulWidget { const AyahStrip({super.key, required int page, required List<NormalizedRect> lines, required MushafPaperColors colors, ImageProvider Function(int cacheWidth)? imageFor}); }` default `imageFor: (w) => ResizeImage(AssetImage(AssetsDir.mushafPage(page)), width: w)`. A `LayoutBuilder` sizes it to `width × ayahStripLayout(…, image: const Size(1536, 2795)).height` before decode. The state resolves the provider through an `ImageStream` and keeps `ImageInfo? _info`: on each new `ImageInfo` it calls `_info?.dispose()` and then keeps the new one (`setState`); when `page` or the width changes it removes the listener, disposes `_info`, sets it to null and resolves again; `dispose()` removes the listener and calls `_info?.dispose()`. It paints with `CustomPaint(key: ValueKey('ayah-strip-paint'), painter: AyahStripPainter(image: _info?.image, slices: …, colors: colors))`.
  - `@visibleForTesting class AyahStripPainter extends CustomPainter { AyahStripPainter({required this.image, required this.slices, required this.colors}); final ui.Image? image; final List<({Rect src, Rect dst})> slices; final MushafPaperColors colors; }`: paper `background` fill, then, when `image` is non-null, `drawImageRect(image, src, dst, Paint()..colorFilter = ColorFilter.mode(colors.ink, BlendMode.srcIn)..filterQuality = FilterQuality.medium)` with the layout recomputed from the decoded size; `shouldRepaint` compares the three fields. The strip is `Semantics(image: true, excludeSemantics: true)`. Empty lines → `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing tests**

AssetsDir: `'mushafPage pads the page number to three digits'` (`AssetsDir.mushafPage(7) == 'assets/mushaf/pages/page_007.png'`).

Layout (image `Size(1536, 2795)`, width 320; line A `x .1, y .2, w .8, h .05`, line B `x .5, y .25, w .4, h .05`):
- `'a full line spans the strip width'` (`dst == Rect.fromLTWH(0, 0, 320, .05·2795·320/(.8·1536))`, `src == Rect.fromLTWH(.1·1536, .2·2795, .8·1536, .05·2795)`).
- `'a shorter line keeps the common scale and sits at the right edge'` (B after A: `dst.left == 160`, `dst.width == 160`).
- `'lines stack top to bottom'` (B's `dst.top` == A's `dst.bottom`; `height` == sum).
- `'at most three lines are drawn'` (five lines → three slices).
- `'no lines is an empty strip'` (height 0).
- `'the strip height depends only on the page aspect'` (image `Size(768, 1397.5)` gives the same `dst` rects and height).
- `'the cache width follows the strip width and never passes the page width'` (`ayahStripCacheWidth(320, 3) == 960`, `(600, 3) == 1536`).

Widget (`tester.view.devicePixelRatio = 3`; `imageFor` records the requested width and returns a `MemoryImage` of a small valid PNG built by a top-level helper called at the start of each `testWidgets`, since `setUpAll` has no `WidgetTester`):

```dart
Future<Uint8List> _png(WidgetTester t) async => (await t.runAsync(() async {
      final img = await createTestImage(width: 64, height: 116);
      return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    }))!;
```

- `'sizes itself from the line rects before the image decodes'` (two lines at width 320 → `tester.getSize(find.byType(AyahStrip)).height` equals the layout height).
- `'asks for the page decoded at strip width'` (requested width 960).
- `'an ayah with no lines draws nothing'` (height 0, no `ayah-strip-paint`).
- `'paints once the image decodes'` (after `tester.runAsync` lets it decode and a `pump`, `(tester.widget<CustomPaint>(find.byKey(const ValueKey('ayah-strip-paint'))).painter! as AyahStripPainter).image` is non-null).

- [ ] **Step 2: Run** `flutter test test/core/constants/assets_dir_test.dart test/features/surah/presentation/utils/ayah_strip_layout_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** as in Interfaces. `core-utilities.md`: the `AssetsDir` line lists `mushafPage(page)`. `feature-widgets.md` surah utils: a new entry `ayah_strip_layout.dart` (`ayahStripLayout`, `ayahStripCacheWidth`: the ayah strip's slices and decode width).

- [ ] **Step 4: Run** the same three files, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +12 (assets 1, layout 7, widget 4) → 1576 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/assets_dir.dart lib/features/surah/presentation/utils/ayah_strip_layout.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart .claude/rules/core-utilities.md .claude/rules/feature-widgets.md test/core/constants/assets_dir_test.dart test/features/surah/presentation/utils/ayah_strip_layout_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart
git commit -m "feat(mushaf): AyahStrip, the ayah's lines cropped from the page in paper ink

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5a: adjacentAyah and MushafCubit.stepTo

**Files:**
- Modify: `lib/features/surah/presentation/utils/reader_rules.dart`, `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`, `.claude/rules/feature-widgets.md`
- Modify (test): `test/features/surah/presentation/utils/reader_rules_test.dart`
- Create (test): `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_step_test.dart`

**Interfaces:**
- Produces:
  - `AyahIdentifier? adjacentAyah(AyahIdentifier ayah, int delta)` in `reader_rules.dart` (`delta` ±1; uses `quran.getVerseCount`; ayah 0 counts as ayah 1).
  - `MushafCubit.stepTo(AyahIdentifier ayah, {required int page})`: `page == state.currentPage` → `select(ayah)`; otherwise ONE emit `state.copyWith(currentPage: page, pageAyahs: const [], selectedAyah: ayah, clearJumpFrom: true, followPlayback: followAfterManualTurn(followPlayback: state.followPlayback, newPage: page, playingPage: playingPage))`, then `_loadPageAyahs(page)`. Never through `_turnByUser`: its `clearSelected` emit would reach the reader's selection listener as a cleared selection and collapse the full detent (reading 7).

- [ ] **Step 1: Write the failing tests**

`reader_rules_test.dart` group `adjacentAyah`: `'next stays in the surah'` (3:7 → 3:8); `'next crosses into the next surah'` (1:7 → 2:1); `'previous crosses back'` (2:1 → 1:7); `'nothing before 1:1 or after 114:6'`; `'a banner steps as ayah 1'` (`adjacentAyah(2:0, 1) == 2:2`, `adjacentAyah(2:0, -1) == 1:7`).

`mushaf_cubit_step_test.dart` (stubs as in `mushaf_cubit_clear_highlight_test.dart`, args page 50): `'stepTo on this page only moves the selection'` (state: page 50, `selectedAyah` 3:8, `jumpFrom` null); `'stepTo onto another page turns it and selects the ayah, with no return chip'` (`stepTo(3:10, page: 51)` → page 51, `selectedAyah` 3:10, `jumpFrom` null); `'stepTo clears a pending return chip'` (after `jumpTo(60)`, `stepTo(…, page: 61)` → `jumpFrom` null); `'a cross-page step never passes through an empty selection'` (record every emitted state of `stepTo(3:10, page: 51)` from a 3:9 selection: exactly one emit, none with `selectedAyah == null`).

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/cubit/mushaf`. Expected: FAIL.

- [ ] **Step 3: Implement** as in Interfaces. `feature-widgets.md`: add `adjacentAyah` to the `reader_rules.dart` list.

- [ ] **Step 4: Run** `flutter test test/features/surah`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +9 (adjacentAyah 5, stepTo 4) → 1585 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/utils/reader_rules.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart .claude/rules/feature-widgets.md test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_step_test.dart
git commit -m "feat(mushaf): adjacentAyah and stepTo, the selection steps and the page behind follows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5b: Full detent widget (AyahStudyLeaf)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart` (move `ayahShareText` out; import it from `ayah_study_leaf.dart` until Task 6a drops share from the leaf), `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/icons.md`
- Create (test): `test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart`
- Modify (test): `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart` (move `'share text quotes the ayah and names it'` out; it now lives in the study leaf test)

**Interfaces:**
- Consumes: `AyahStrip` (Task 4), `TafsirSection` (Task 3), `FakeTafsirCubit` (Task 2).
- Produces:
  - `String ayahShareText(BuildContext context, AyahIdentifier ayah)` moved unchanged into `ayah_study_leaf.dart`.
  - `class AyahStudyLeaf extends StatelessWidget { const AyahStudyLeaf({super.key, required AyahIdentifier ayah, required int page, required List<NormalizedRect> lines, required MushafPaperColors colors, required VoidCallback onBack, VoidCallback? onPrevious, VoidCallback? onNext}); }`: `Material(color: colors.leaf, shape: Border(top: BorderSide(color: colors.accent)))` filling its constraints, holding a `Column`:
    - Header (`GestureDetector`, drag down `> 300` → `onBack`), `Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8))` around a `Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4)`: the title «آل عمران، الآية ٧» on its own line (`Text`, `TS.bold16`, ink, `maxLines: 2`, `overflow: TextOverflow.ellipsis`), then `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: back), Flexible(child: share)])`. Back is `TextButton.icon(key: ValueKey('study-back'), style: colors.paperButton(), icon: HugeIcons.strokeRoundedArrowDown01, label: Text(PendingS.tafsir_backToMushaf, maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.semi14))`; share is `TextButton.icon(key: ValueKey('study-share'))` with `S.share` and `HugeIcons.strokeRoundedShare08`, same label rules (today's `_share` body, moved).
    - Then `Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: […])))` with: `AyahStrip(page, lines, colors)`; `PendingS.tafsir_behind` (`TS.medium14`, `ink2`); the chip row; `TafsirSection(ayah: ayah, ink: colors.ink, mutedInk: colors.ink2, buttonStyle: colors.paperButton())`; the previous/next row.
    - Chip row (reading 14): `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(spacing: 8, children: [four chips]))`, keys `study-chip-tafsir`, `study-chip-translation`, `study-chip-words`, `study-chip-note`. Each chip: `Semantics(key: …, container: true, button: true, selected: isTafsir, enabled: isTafsir, child: Container(constraints: const BoxConstraints(minHeight: 48), padding: const EdgeInsetsDirectional.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: colors.accent), borderRadius: BorderRadius.circular(24), color: isTafsir ? colors.accent.withValues(alpha: 0.16) : null), child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [Text(label, style: TS.semi14.copyWith(color: isTafsir ? colors.ink : colors.ink2)), if (!isTafsir) AppStatusBadge(color: colors.ink2, label: PendingS.of(context).onb_later, showDot: false)])))`. No tap handler.
    - Previous/next: `Row(spacing: 8, children: [Expanded(previous), Expanded(next)])`, each an `OutlinedButton.icon` with `style: colors.paperButton(outlined: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48)))` and a label `Text(…, textAlign: TextAlign.center, style: TS.semi14)` that wraps: `study-previous` `S.playback_previous` with `backArrowIcon(context)`, `study-next` `S.playback_next` with `forwardArrowIcon(context)`; a null handler disables its button. All buttons use `paperButton()`.
- Strings (ar / en): `tafsir_backToMushaf` «العودة إلى المصحف» / 'Back to the mushaf'; `tafsir_behind` «المصحف خلفك على هذه الآية» / 'The mushaf behind you is on this ayah'; `tafsir_sectionTafsir` «التفسير» / 'Tafsir'; `tafsir_sectionTranslation` «الترجمة» / 'Translation'; `tafsir_sectionWords` «معاني الكلمات» / 'Word meanings'; `tafsir_sectionNote` «ملاحظتي» / 'My note'.

- [ ] **Step 1: Write the failing tests**

`ayah_study_leaf_test.dart` (host: `Locale('ar')`, `BlocProvider<TafsirCubit>.value(FakeTafsirCubit()..load(ayah))`, `SizedBox(width: 360, height: 640)`, ayah 3:7, page 50, `lines: const []`; the strip's painting is Task 4's to test):
- `'the header carries العودة إلى المصحف, the title and مشاركة'`.
- `'shows the strip and المصحف خلفك على هذه الآية'` (`find.byType(AyahStrip)` one).
- `'التفسير is selected and the other three are disabled with لاحقًا'` (semantics: `study-chip-tafsir` selected; the other three `isEnabled == false`; `find.text('لاحقًا')` three).
- `'the book row, caption, body and source show'`.
- `'previous and next reach their handlers; a null one is disabled'`.
- `'العودة إلى المصحف and a drag down on the header call onBack'`.
- `'the buttons take the paper ink on night paper'` (`MushafPaper.night.colors`: the foreground of `study-back`, `study-share`, `study-next` resolves to `colors.ink`).
- `'the arrows follow the reading direction in English'` (`Locale('en')`: `study-next` holds `forwardArrowIcon(context)`).
- `'fits at 2x text in 360 px'` (`TextScaler.linear(2.0)`, no exception).
- moved from `ayah_leaf_test.dart`: `'share text quotes the ayah and names it'`; copied (the compact leaf keeps sharing until Task 6a deletes its copy): group `share` with `'hands the quoted ayah to the share sheet'` and `'a failing share sheet shows the fallback message'`, tapping `study-share`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** as in Interfaces. `icons.md`: add «the tafsir full detent» to the HugeIcons mushaf list.

- [ ] **Step 4: Run** `flutter test test/features/surah test/core/localization`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +11 (9 new, 2 copied share tests; the moved test is net 0) → 1596 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/icons.md test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart
git commit -m "feat(mushaf): the tafsir full detent with strip, section chips and ayah stepping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6a: S5 compact leaf (action row, lead line, drag up)

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart`, `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify (test): `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`

**Interfaces:**
- Consumes: `TafsirCubit` (Task 2), `TafsirSection` (Task 3), `FakeTafsirCubit`.
- Produces:
  - `AyahLeaf` gains `this.onExpand = _noop` (`void _noop() {}` top-level) and `this.tafsirLead = false`, so `mushaf_page.dart` compiles unchanged and its leaf shows no lead line (and needs no `TafsirCubit` provider) until Task 6b makes both `required`. It loses share (`_share`, `leaf-share`, the `share_plus` import). Action row: `leaf-listen` «استماع من هنا» (filled), `leaf-tafsir` `PendingS.leaf_tafsir` with `HugeIcons.strokeRoundedBookOpen01` → `onExpand`, `leaf-fasil`, `leaf-save`. Under the row, when `tafsirLead` and not the banner: `TafsirSection(key: ValueKey('tafsir-lead'), ayah: ayah, ink: colors.ink, mutedInk: colors.ink2, buttonStyle: colors.paperButton(), lead: true, onTap: onExpand)`. Vertical drag: `if (!_isBanner && velocity < -300) onExpand()`, `velocity > 300` → `onClose`. The banner variant is otherwise unchanged.
- String (ar / en): `leaf_tafsir` «تفسير الآية» / 'Ayah tafsir'.

- [ ] **Step 1: Write the failing tests**

`ayah_leaf_test.dart`, deliberate rewrites (they pin the S4 row): `_host` provides `BlocProvider<TafsirCubit>.value(tafsir)` (a `FakeTafsirCubit` loaded with the ayah in `setUp`) and always passes `onExpand: calls.tap('expand')` and `tafsirLead` explicitly (default argument of `_host` true), so Task 6b needs no change here.
- `'ayah leaf labels are distinct'` → keys `leaf-listen`, `leaf-tafsir`, `leaf-fasil`, `leaf-save`, labels `['استماع من هنا', 'تفسير الآية', 'فاصل', 'حفظ الآية']`, four distinct, and `find.byKey(ValueKey('leaf-share'))` finds nothing.
- `'listen from here, close, فاصل and save reach their handlers'` → also taps `leaf-tafsir`; `calls.taps == ['here', 'close', 'expand', 'fasil']`.
- `'fits at 2x text'` keeps its name and now pumps with the lead line showing.
- Edit `'the banner variant offers the surah actions only'` (no new test): `leaf-tafsir` and `tafsir-lead` find nothing, and `tester.fling(find.byType(AyahLeaf), const Offset(0, -300), 1000)` records no `'expand'`.
- Delete the `share` group (its two tests now live in `ayah_study_leaf_test.dart`).
- New: `'the tafsir line shows one line and opens the full detent'` (`tafsir-lead` contains `tafsirText`; tapping it → `'expand'`); `'tafsirLead false hides the line'`; `'dragging up opens the full detent'` (`tester.fling(find.byType(AyahLeaf), const Offset(0, -300), 1000)` → `'expand'`).

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`. Expected: FAIL (`onExpand` undefined).

- [ ] **Step 3: Implement** as in Interfaces; add `leaf_tafsir`.

- [ ] **Step 4: Run** `flutter test test/features/surah test/core/localization`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +1 (3 new, share group −2) → 1597 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart
git commit -m "feat(mushaf): S5 ayah leaf with تفسير الآية and the tafsir line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6b: Reader wiring for the tafsir and the full detent

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart` (`onExpand`, `tafsirLead` become `required`; `_noop` goes), `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, `CLAUDE.md`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`

**Interfaces:**
- Consumes: `TafsirCubit` (Task 2), `AyahStudyLeaf` (Task 5b), `adjacentAyah`, `MushafCubit.stepTo` (Task 5a), `AyahLeaf` (Task 6a), `FakeTafsirCubit`.
- Produces:
  - `_MushafPageState`: `late final TafsirCubit _tafsirCubit` (read in `initState`, which then calls `load` when `_mushafCubit.state.selectedAyah` is non-null, so a seeded or arrival selection never sits at `TafsirIdle`); `final _studying = ValueNotifier(false)` (disposed); `void _closeLeaf()` (studying → `_studying.value = false`, else `clearSelection()`) passed to `_LeafPopScope`; a `BlocListener` with `listenWhen: (a, b) => a.selectedAyah != b.selectedAyah` → null: `_studying.value = false; _tafsirCubit.cancel()`, else `_tafsirCubit.load(b.selectedAyah!)`; `void _moveViewTo(int page)` (the controller move from `_jumpInPlace`, now shared); `void _stepAyah(int delta)` per reading 10: `final target = adjacentAyah(selected, delta)`; return when null; `final page = sl<QuranPageService>().getPageForAyah(target.surah, target.ayah)`; `page == _mushafCubit.state.currentPage` → `stepTo(target, page: page)` only; otherwise `_lastReadSaver.onManualTurn()`, `_turns.begin(page)`, `stepTo(target, page: page)`, `_moveViewTo(page)`, post-frame `_turns.end`.
  - `_LeafSlot` gains `required ValueListenable<bool> studying` and `required VoidCallback onExpand` (the call site passes `studying: _studying, onExpand: () => _studying.value = true`); it passes `onExpand` and `tafsirLead: tapAction == LeafTapAction.meaning` (`context.select` on `SettingsCubit`) to `AyahLeaf`, and wraps the ayah leaf in `ValueListenableBuilder<bool>(valueListenable: studying, …)` → `ExcludeSemantics(excluding: studying, …)`, keeping `ValueKey(selected)` on the outer widget.
  - `class _StudyLayer extends StatefulWidget { const _StudyLayer({required ValueListenable<bool> studying, required MushafPaperColors colors, required VoidCallback onBack, required void Function(int delta) onStep}); }`, the last child of the reading-area `Stack`, inside `Positioned.fill`; the call site passes `studying: _studying, onBack: () => _studying.value = false, onStep: _stepAyah`. Its state holds `int? _boundsPage` and `Future<List<AyahBoundEntity>>? _bounds`. `build`: `ValueListenableBuilder<bool>(valueListenable: widget.studying, …)` around `BlocBuilder<MushafCubit, MushafState>` (`buildWhen` on `selectedAyah`, `currentPage`, `pageAyahs`) around an `AnimatedSwitcher` (200 ms). When studying and the selection is a non-banner ayah: `final page = sl<QuranPageService>().getPageForAyah(selected.surah, selected.ayah)` (reading 3); if `page != _boundsPage`, set `_boundsPage = page` and `_bounds = context.read<MushafCubit>().boundsFor(page)` (the future lives in the state, never rebuilt per frame); then `FutureBuilder(key: ValueKey(page), future: _bounds, initialData: page == state.currentPage && state.pageAyahs.isNotEmpty ? state.pageAyahs : null, builder: …)` → `AyahStudyLeaf(key: ValueKey('study-leaf'), ayah: selected, page: page, lines: <the bound whose ayah == selected>?.lines ?? const [], colors, onBack, onPrevious: adjacentAyah(selected, -1) == null ? null : () => onStep(-1), onNext: … +1)`. Otherwise `SizedBox.shrink()`. (After a cross-page step `pageAyahs` is empty until loaded, so the strip reads `boundsFor(page)`, a bundled-asset read; it may show at height 0 for that read.)
  - The scroll-mode `_NoticeSlot` (between the reading area and `ReaderFoot`) is wrapped in `ValueListenableBuilder<bool>(valueListenable: _studying, …)` and returns `const SizedBox.shrink()` while studying (reading 8).
  - Harness: `pumpMushafPage` gains `FakeTafsirCubit? tafsir`, provides it, returns it in `MushafHarness` (`tafsir`), and closes it; `FakeSettings` gains `LeafTapAction tapAction = LeafTapAction.meaning`; `FakeMushaf` gains `final steps = <(AyahIdentifier, int)>[]` and `stepTo` (records, then same page → select, else `copyWith(currentPage: page, selectedAyah: ayah, clearJumpFrom: true)`).
  - `CLAUDE.md` first paragraph: the mushaf summary becomes «the mushaf (page and scroll reading, reading papers, three named فواصل, saved ayat, the «أماكني» sheet and Tafsir al-Muyassar)».

- [ ] **Step 1: Write the failing tests**

`mushaf_page_shell_test.dart`, new group `tafsir` (selection pushed through `FakeMushaf.push` as the existing tests do; the harness's default `_StubPageService` maps every ayah to page 1, so the group calls `setUpMushafHarness(pageService: _PageMap(…))`, a local stub that maps listed ayat to given pages and every other ayah to the pushed `currentPage`):
- `'selecting an ayah loads its tafsir'` (`h.tafsir.loads == [3:7]`).
- `'a jump arrival with focusAyah loads its tafsir'`.
- `'clearing the selection cancels the tafsir request'` (`h.tafsir.cancels == 1`).
- `'تفسير الآية opens the full detent and العودة إلى المصحف returns with the ayah still selected'` (`study-leaf` shown; after `study-back`, `study-leaf` gone, `leaf-tafsir` visible, `selectedAyah` unchanged).
- `'returning from the full detent leaves the page where it was'` (an ayah under the leaf: the `page-slide` `Transform` offset before opening equals the offset after `study-back` and `pumpAndSettle`).
- `'system back at the full detent collapses first, then closes'`.
- `'الآية التالية keeps the full detent open and moves the selection'` (`steps == [(3:8, page)]`, `study-leaf` still shown).
- `'الآية التالية on the last ayah of a page turns the page behind'` (`_PageMap` maps the next ayah to the next page: `steps.last.$2 == current + 1`, `currentPage` follows, no «العودة إلى صفحة» chip).
- `'the strip shows the ayah's own page, not the current page'` (`_PageMap` maps 3:9 to 51; push `currentPage: 50` with `selectedAyah` 3:9; open the detent → `tester.widget<AyahStrip>(find.byType(AyahStrip)).page == 51`).
- `'with الخيارات the compact leaf has no tafsir line'` (`FakeSettings(tapAction: LeafTapAction.options)` → `tafsir-lead` none, `leaf-tafsir` present).
- `'the full detent fits at 2x text'` (`textScale: 2`; after `pumpMushafPage` set `tester.view.physicalSize = const Size(360, 800)` and `pumpAndSettle`; open it, no exception).
- In the scroll-mode group: `'the notice chips hide behind the full detent'` (`FakeSettings(mode: MushafReadingMode.scroll, hintSeen: false)`, select an ayah, open the detent → `notice-chip` finds nothing).
- `mushaf_page_dispose_test.dart` and `mushaf_page_follow_test.dart` pump through `pumpMushafPage`, so the harness change covers them. The slide tests (`mushaf_page_shell_test.dart` from `'an ayah under the leaf slides the page up…'` to the scroll-mode return-chip test) measure the leaf rather than hard-coding its height; the taller leaf with its lead line should keep them green. If one fails, move its fixture ayah, never loosen the assertion, and name it in the task report.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf`. Expected: FAIL (`stepTo` and `tafsir` missing from the harness, no `study-leaf`).

- [ ] **Step 3: Implement** as in Interfaces.

- [ ] **Step 4: Run** `flutter test test/features/surah test/features/tafsir test/core/localization`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS; +12 → 1609 pass, 1 skipped; ≤ 69 infos.

- [ ] **Step 5: Format** the `.dart` paths of Step 6.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart CLAUDE.md test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart
git commit -m "feat(mushaf): tafsir loads with the selection, full detent in the reader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: «عند الضغط على الآية» in العرض and slice verification

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart`, `lib/features/surah/presentation/utils/enum_localization.dart`, `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`
- Modify (test): `test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart`

**Interfaces:**
- Consumes: `LeafTapAction`, `SettingsCubit.updateTapAction` (S3).
- Produces:
  - `extension LeafTapActionLocalization on LeafTapAction { String localized(BuildContext context); }` → `display_tapMeaning` / `display_tapOptions`.
  - `DisplaySheet`: after the «طريقة القراءة» selector, `Text(pending.display_tapAction, style: TS.medium12)` and `AppSegmentedSelector<LeafTapAction>(key: ValueKey('tap-action-toggle'), selected: model.tapAction, expand: true, onChanged: cubit.updateTapAction, options: [for (final a in LeafTapAction.values) SegmentOption(value: a, label: a.localized(context))])`, spaced like the reading-mode block.
- Strings (ar / en): `display_tapAction` «عند الضغط على الآية» / 'When you tap an ayah'; `display_tapMeaning` «المعنى» / 'Meaning'; `display_tapOptions` «الخيارات» / 'Options'.

- [ ] **Step 1: Write the failing tests** in `display_sheet_test.dart`

- `'the tap-action selector stores الخيارات'` (tap «الخيارات» → `cubit.state.settingsModel.tapAction == LeafTapAction.options`).
- `'the tap-action selector starts on المعنى'` (selected value `meaning`).
- Deliberate edit: `'the title reads العرض and the sections are named'` adds `'عند الضغط على الآية'` to its label list.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** the extension, the selector and the strings. `feature-widgets.md` surah utils: `enum_localization.dart` (`MushafPaper.localized`, `LeafTapAction.localized`).

- [ ] **Step 4: Verify the slice**

Run, in order:
1. `dart format lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart lib/features/surah/presentation/utils/enum_localization.dart lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart` (the `.dart` paths of Step 5).
2. Check only, no rewrite: `dart format --output=none --set-exit-if-changed` on every `.dart` path this plan changed: `lib/features/tafsir/domain/entities/tafsir.dart lib/features/tafsir/domain/repositories/tafsir_repository.dart lib/features/tafsir/domain/usecases/get_ayah_tafsir.dart lib/features/tafsir/data/datasources/remote/tafsir_remote_data_source.dart lib/features/tafsir/data/datasources/local/tafsir_local_data_source.dart lib/features/tafsir/data/repositories/tafsir_repository_impl.dart lib/features/tafsir/tafsir_di.dart lib/config/hive_config.dart lib/core/di/dependency_injection.dart lib/features/tafsir/presentation/cubit/tafsir_cubit.dart lib/features/tafsir/presentation/cubit/tafsir_state.dart lib/config/router/app_router.dart lib/features/tafsir/presentation/widgets/tafsir_section.dart lib/core/localization/pending_s.dart lib/core/constants/assets_dir.dart lib/features/surah/presentation/utils/ayah_strip_layout.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart lib/features/surah/presentation/utils/reader_rules.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart lib/features/surah/presentation/utils/enum_localization.dart` and every test path: `test/features/tafsir/data/datasources/tafsir_remote_data_source_test.dart test/features/tafsir/data/datasources/tafsir_local_data_source_test.dart test/features/tafsir/data/repositories/tafsir_repository_impl_test.dart test/features/tafsir/presentation/cubit/tafsir_cubit_test.dart test/features/tafsir/tafsir_fakes.dart test/features/tafsir/presentation/widgets/tafsir_section_test.dart test/core/constants/assets_dir_test.dart test/features/surah/presentation/utils/ayah_strip_layout_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_step_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart`. Expected: exit 0, no file changed.
3. `flutter analyze --no-fatal-infos` (0 errors, 0 warnings, ≤ 69 infos).
4. `flutter test`: +2 → 1611 pass, 1 skipped.
5. `git status --short`: before Step 5 only this task's paths are modified; `.claude/agents/`, `.claude/skills/impeccable/` stay untracked and `lib/generated/**` untouched.
6. Comment and style check on the slice's added lines: `git diff origin/main...HEAD -U0 -- lib test` plus `git diff -U0 -- lib test`, keep lines starting with `+`, then grep each of `-E '^\+\s*//|\s//(\s|$)'`, `Color(0x`, `TextStyle(` and `Theme.of(context).colorScheme`. Expected: no match (the alquran.cloud URLs contain `//` with no space before it, so the comment pattern skips them).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart lib/features/surah/presentation/utils/enum_localization.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart
git commit -m "feat(mushaf): عند الضغط على الآية in العرض

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
