# Mushaf S5 (Tafsir al-Muyassar, ayah strip, full detent) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the meaning of an ayah in the leaf: one line of التفسير الميسر in the compact leaf, a full-height study detent with an ayah strip cropped from the page, static section chips, the book and source rows, and previous/next ayah, all fed by an online-with-cache tafsir store that never dead-ends offline.

**Architecture:** A new `features/tafsir/` holds the entity `Tafsir`, `TafsirRepository` (`Either<Failure, _>`), `GetAyahTafsir`, a Dio remote data source (one page call fills the cache, a per-ayah fallback, one `CancelToken` per page owned by the repository), a `Box<String>('tafsirCache')` local data source, the route-scoped `TafsirCubit` and the exported `TafsirSection` (compact `lead` mode and full mode). The reader (`surah`) gets the S5 action row and lead line in `AyahLeaf`, a new `AyahStrip` (`drawImageRect` over the ayah's line rects) and a new full-detent widget `AyahStudyLeaf`, drawn as a layer over the reading area while the compact leaf stays mounted underneath. `MushafCubit.stepTo` moves the selection for «الآية السابقة» / «الآية التالية», turning the page behind when needed. «العرض» gains the «عند الضغط على الآية» selector that S3 deferred.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), flutter_bloc + bloc_test, mocktail, equatable, dartz, dio 5 (`CancelToken`), hive_ce, skeletonizer 3, hugeicons, share_plus, the vendored `quran` package.

**Spec:** `docs/superpowers/specs/2026-11-21-mushaf-leaf-ribbon-design.md`: §6 in full, D1, D3, D4, the S5 row of the §3.3 action table and its lead-line bullet, the «عند الضغط على الآية» line of §3.6, the `TafsirCubit`, `TafsirSection` and `AyahStrip` items of §7, and the §8 rows on alquran.cloud, the Muyassar licence and strip memory. Where the spec and this plan disagree the spec wins, except for the **Deliberate readings** below, where the plan governs. Raise any other disagreement in the task report.

## Global Constraints

- Work on `feature/mushaf-s5-tafsir`. Never switch branches, never touch `main`, never push, never rebase, never amend.
- Commits: stage explicit paths only (never `git add -A` / `git add .`). Never stage `quran-1.4.1/**`, `lib/generated/**`, `ios/Podfile.lock`, `.claude/agents/` or `.claude/skills/impeccable/`. Conventional message (`feat|fix|refactor|test(scope): …`) ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No comments and no doc comments in new or changed code. No redundant type annotations. Lean code. A user comment inside lines a task replaces goes with them; other existing comments stay.
- New strings: add each to both `lib/l10n/intl_ar.arb` and `lib/l10n/intl_en.arb` and mirror it in `lib/core/localization/pending_s.dart` as `String get key => _ar ? '…' : '…';` (single quotes, `\'` for an apostrophe). Read with `PendingS.of(context)` in `build`, `PendingS.current` in callbacks. `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`; never run `intl_utils:generate`. Reuse, do not duplicate: `S.share` «مشاركة», `S.share_failed`, `S.playback_previous` «الآية السابقة», `S.playback_next` «الآية التالية», `PendingS.mushaf_retry` «إعادة المحاولة», `PendingS.onb_later` «لاحقًا».
- Arabic numbers use Arabic-Indic digits via `toLocalized(context)` / `toIndicNumerals(localeCode)`.
- Colours: everything drawn on the reading paper (compact leaf, full detent, strip, chips, `TafsirSection` on the leaf) reads `MushafPaperX` / `MushafPaperColors`; every Text/Outlined button on the paper uses `colors.paperButton()` (`outlined: true` for outlined). The filled «استماع من هنا» keeps `colorScheme.primary`. The «العرض» sheet reads `context.colorScheme`. Hex literals only where `theming.md` allows. Text styles only `TS.*`; `test/config/theme/typography_ratchet_test.dart` must not rise. Leaf and full-detent text is `TS.*14` or larger.
- Icons: HugeIcons in the leaf and the full detent; arrows only via `backArrowIcon(context)` / `forwardArrowIcon(context)`.
- Layers: `features/tafsir/domain/` is pure Dart (no Flutter, no Dio, no `S`); presentation never imports `data/`. The repository catches every exception (`CacheException` → `CacheFailure`, anything else → `Failure.fromException(e)`).
- Cubits: `if (isClosed) return;` before every emit after an `await`; sealed states, `Equatable`, every field in `props`.
- SnackBars raised by the full detent go through `showPlaceNotice` (`bookmarks/presentation/utils/place_notices.dart`), except the share fallback which keeps today's `SnackBar(content: Text(S.share_failed, style: TS.regular14))`.
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`; never modify `assets/mushaf/**`.
- `dart format` only the explicit `.dart` paths a task changed (never a directory, `.`, `lib`, `test` or `lib/generated/**`).
- Every task ends at baseline or better: `flutter analyze --no-fatal-infos` = 0 errors, 0 warnings, ≤ 69 infos; `flutter test` = 1523 at start plus the tests this plan adds minus the tests it moves out, all pass, 1 skipped.
- Rule catalogues (`feature-widgets.md`, `routing-and-navigation.md`, `icons.md`) and `CLAUDE.md`'s feature summary change in the task that changes what they describe.
- The PR (opened later by the workflow, not by a task) lists the Muyassar licence as open for the owner (§8).

## Deliberate readings (the plan governs here)

1. **Cancellation lives in data and is never an error.** The repository owns the `CancelToken`; the domain sees only `TafsirRepository.cancelPending()` (exposed as `GetAyahTafsir.cancel()`). `TafsirCubit.cancel()` cancels, bumps a private request counter and emits `TafsirIdle`; every `load` result checks the counter, so a cancelled (or superseded) request never emits, and «تعذّر تحميل التفسير» appears only for a real failure.
2. **When a request is cancelled ("on page change").** The reader calls `TafsirCubit.cancel()` when the selection clears; a manual page swipe clears the selection, so a swipe cancels. A new selection on another page makes the repository cancel the old page's token before starting the new page. A page change that keeps the selection (playback turning the page while another ayah stays selected) does not cancel, since the open leaf still needs that tafsir. Closing the cubit (leaving the reader) cancels.
3. **The fetched page is the ayah's own page**, from `QuranPageService.getPageForAyah(surah, ayah)` inside the cubit, never `currentPage` (scroll mode can select an ayah on a neighbouring page item).
4. **Cache first, one call per page.** A cached ayah returns without network. A miss fetches the whole page once (concurrent misses on the same page share the in-flight future) and writes every ayah of it. Only an ayah absent from the page response falls back to `/v1/ayah/{s}:{a}/ar.muyassar`. A failed cache write still returns the fetched text.
5. **A body is valid only when `code == 200` and `data` is a `Map`** (for a page, `data['ayahs']` a `List` of maps with `surah.number`, `numberInSurah` and a `String` `text`); anything else throws `FormatException` in the data source, which the repository turns into a `Left`.
6. **The tafsir loads when the leaf opens, whatever `tapAction` is.** `options` hides only the compact lead line; «تفسير الآية» still finds the text ready. Ayah 0 (banner) never loads; the banner leaf has no tafsir line and no «تفسير الآية».
7. **Detent state is local UI state above the leaf.** `AyahLeaf` is keyed by `ValueKey(selected)`, so `_MushafPageState` holds `final _studying = ValueNotifier(false)`; it survives previous/next and resets to `false` whenever the selection clears.
8. **The full detent is a layer, not a taller leaf.** `AyahStudyLeaf` is drawn by `_StudyLayer` as the last child of the reading-area `Stack` (`Positioned.fill`, opaque, absorbs taps), between the running head and the foot band, which both stay visible. The compact leaf stays mounted underneath (wrapped in `ExcludeSemantics(excluding: studying)`), so `_overlayHeight`, `_PageSlide`, the scroll padding and `_slideScrollTo` never see the full height, and collapsing returns to exactly the page position the compact leaf had.
9. **Open, collapse, close.** Open: «تفسير الآية», a tap on the lead line, or a drag up on the compact leaf (`primaryVelocity < -300`). Collapse to the compact leaf (selection kept): «العودة إلى المصحف», a drag down on the full detent's header (`> 300`), or system Back. System Back at the compact leaf closes it, as today.
10. **Previous / next use `MushafCubit.stepTo`, not `jumpTo`.** `adjacentAyah` crosses surahs and skips banners; it returns null before 1:1 and after 114:6, which disables the button. Same page → selection moves. Another page → the page turns and the ayah is selected, with no return chip (studying forward is reading, not a jump) and `_lastReadSaver.onManualTurn()`, because the reader moved on deliberately.
11. **AyahStrip draws the ink layer only** (the ayah-number rosette lives on the accent layer and is not drawn), from the current page's bounds only (an ayah running onto the next page shows its first part), at most 3 line rects, stacked top to bottom with one common scale set by the widest rect and each rect aligned to the right edge (RTL). The image is injectable (`imageFor`) so tests never decode a real page; the default decodes the page asset at `min(1536, ceil(width × dpr))` px wide.
12. **`TafsirSection` takes its colours by constructor** (`ink`, `mutedInk`, `buttonStyle`), so `tafsir` imports nothing from `surah`'s paper colours. It is the one export, with a `lead` mode for the compact line.
13. **States for another ayah, and `TafsirIdle`, render as loading.** Only `TafsirLoaded` / `TafsirFailed` for the section's own ayah render text or the retry row. The test fake loads synchronously, so `pumpAndSettle` never waits on the skeleton shimmer.
14. **The section chips are static.** «التفسير» is announced selected; «الترجمة», «معاني الكلمات», «ملاحظتي» are announced disabled and carry a quiet `AppStatusBadge(label: PendingS.onb_later, showDot: false)`. No chip reacts to a tap.
15. **The «عند الضغط على الآية» selector is drawn in S5** (S3 stored `tapAction` and deferred the control to this slice).

## Review Focus

1. **Offline and uncached, then back online.** The full detent shows «تعذّر تحميل التفسير» + «إعادة المحاولة», and the retry succeeds once the network returns; the compact line shows the same message in one line. Tasks 1 and 2 pin the `NetworkFailure` and the retry; Task 3 pins both renderings.
2. **Fast taps and swipes while a page request is in flight.** The newest selection wins, and a cancellation never paints the error. Task 1 pins token cancellation and the shared in-flight call; Task 2 pins A→B and cancel-while-loading; Task 6 pins that clearing the selection cancels.
3. **Boundaries.** «الآية السابقة» is disabled on 1:1 and «الآية التالية» on 114:6; 1:7 → 2:1 crosses surah and page; the banner never loads. Tasks 5 and 6 pin each.
4. **Large text (2×) at 360 px.** The four-column compact leaf with its lead line and the full detent lay out without overflow (the full detent scrolls). Tasks 5 and 6 pump each at `TextScaler.linear(2.0)`.
5. **English UI.** The Muyassar body stays right-to-left and the previous/next arrows point the right way. Tasks 3 and 5 pin it under `Locale('en')`.

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
  - `abstract class TafsirRemoteDataSource { Future<List<Tafsir>> getPage(int page, {CancelToken? cancelToken}); Future<Tafsir> getAyah(int surah, int ayah, {CancelToken? cancelToken}); }` and `class TafsirRemoteDataSourceImpl implements TafsirRemoteDataSource { TafsirRemoteDataSourceImpl({required this.dio}); final Dio dio; }`. URLs: `https://api.alquran.cloud/v1/page/$page/ar.muyassar`, `https://api.alquran.cloud/v1/ayah/$surah:$ayah/ar.muyassar`. Parse in a private function (no `*_model.dart` file: `build.yaml` runs the Hive generator on that pattern).
  - `class TafsirLocalDataSource { TafsirLocalDataSource({required this.box}); final Box<String> box; static String keyOf(int surah, int ayah) => 'muyassar:$surah:$ayah'; String? get(int surah, int ayah); Future<void> putAll(Iterable<Tafsir> items); }`; a failed write throws `CacheException`.
  - `class TafsirRepositoryImpl implements TafsirRepository { TafsirRepositoryImpl({required this.remote, required this.local}); }` per readings 1, 4 and 5: private `CancelToken? _token`, `int? _page`, `Future<List<Tafsir>>? _inFlight`; a request for another page cancels `_token` first; `cancelPending()` cancels and clears all three.
  - Box: `await _openCacheBox<String>('tafsirCache');` in `initHive()` (re-fetchable cache, so `_openCacheBox`).
  - DI `void initTafsir()`: `TafsirRemoteDataSource`, `TafsirLocalDataSource(box: Hive.box<String>('tafsirCache'))`, `TafsirRepository`, `GetAyahTafsir` as lazy singletons; called from `initGetIt()` after `initMushaf()`.

- [ ] **Step 1: Write the failing tests**

Remote (mocktail `_MockDio`, `registerFallbackValue(CancelToken())`, fixtures shaped like the live API: `{'code': 200, 'status': 'OK', 'data': {'number': 2, 'ayahs': [{'number': 8, 'text': 'هذه الحروف…', 'surah': {'number': 2}, 'numberInSurah': 1}, …]}}`):
- `'getPage reads every ayah of the page'`: `dio.get('https://api.alquran.cloud/v1/page/2/ar.muyassar', cancelToken: token)` is called with the token passed in; result `[Tafsir(surah: 2, ayah: 1, text: 'هذه الحروف…'), Tafsir(surah: 2, ayah: 2, …)]`.
- `'getAyah reads one ayah'`: URL `…/v1/ayah/2:255/ar.muyassar`, `data` a map with `surah.number` 2, `numberInSurah` 255 → `Tafsir(surah: 2, ayah: 255, …)`.
- `'a code other than 200 throws FormatException'` (`{'code': 404, 'status': 'NOT FOUND', 'data': 'Not found'}`).
- `'a string body throws FormatException'` (`data: '<html>'`).

Local (Hive in a temp dir as in `test/features/surah/data/repositories/last_read_repository_impl_test.dart`, `Box<String>`):
- `'a missing ayah reads null'`; `'putAll stores each ayah under muyassar:s:a'` (`box.get('muyassar:2:255')` is the text); `'get returns the stored text'`.

Repository (`_MockRemote`, `_MockLocal`):
- `'a cached ayah never touches the network'` → `Right(Tafsir(…))`, `verifyNever(remote.getPage…)`.
- `'a miss fetches the page once and caches all of it'`: page 1 returns 1:1–1:7; `getAyahTafsir(surah: 1, ayah: 3, page: 1)` → text of 1:3; `local.putAll` captured with 7 items.
- `'two ayat of one page share one request'`: two calls before the first completes (a `Completer`) → `remote.getPage(1, …)` called once, both `Right`.
- `'an ayah missing from the page falls back to the ayah endpoint'`: page 50 lacks 3:9 → `remote.getAyah(3, 9, …)` called, its result cached and returned.
- `'a request for another page cancels the previous one'`: capture the first token (page 1, pending), call page 2 → first token `isCancelled`.
- `'cancelPending cancels the request in flight'`.
- `'offline becomes a NetworkFailure, never a throw'`: `getPage` throws `DioException(type: DioExceptionType.connectionError, requestOptions: RequestOptions())` → `Left(isA<NetworkFailure>())`.
- `'a malformed body becomes a Failure'`: `getPage` throws `FormatException()` → `Left`.
- `'a failed cache write still returns the text'`: `putAll` throws `CacheException('x')` → `Right`.

- [ ] **Step 2: Run** `flutter test test/features/tafsir`. Expected: FAIL (`Tafsir` undefined).

- [ ] **Step 3: Implement** the files in Interfaces; `hive_config.dart` opens `tafsirCache` after `places_meta`; `dependency_injection.dart` imports and calls `initTafsir()`.

- [ ] **Step 4: Run** `flutter test test/features/tafsir`, then `flutter analyze --no-fatal-infos`. Expected: PASS, ≤ 69 infos.

- [ ] **Step 5: Commit**

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
  - Test fake: `class FakeTafsirCubit extends Cubit<TafsirState> implements TafsirCubit` with `loads`, `retries`, `cancels` records and `bool failNext`; `load` emits synchronously `TafsirLoaded(ayah, Tafsir(surah: ayah.surah, ayah: ayah.ayah, text: tafsirText))` (`const tafsirText = 'هذا نص تفسير تجريبي طويل يكفي لأن يملأ أكثر من سطر واحد في الورقة'`), or `TafsirFailed(ayah)` when `failNext`; ayah 0 emits `TafsirIdle`; `cancel` emits `TafsirIdle`.

- [ ] **Step 1: Write the failing tests** (`bloc_test`, a hand-written `_FakeRepo implements TafsirRepository` driven by `Completer`s and recording `pages` and `cancelled`, a page service stub mapping 2:255 → 42 and anything else → 1)

- `'load emits loading then the tafsir'`.
- `"asks for the ayah's own page"`: `load(2:255)` → repo saw page 42.
- `'a failure emits failed for that ayah'`.
- `'ayah 0 loads nothing'`: no repo call, state `TafsirIdle`.
- `'an ayah already loaded is not fetched again'`.
- `'a slow first ayah never overwrites a newer one'`: load A (pending), load B (completes), then complete A → states end `[…, TafsirLoaded(B, …)]`, no `TafsirLoaded(A, …)` after it.
- `'retry reloads the failed ayah'`: fail, then succeed → `TafsirLoaded`.
- `'cancel drops the pending result and never emits failed'`: load (pending), `cancel()` → `TafsirIdle`, repo `cancelled`, completing the request with `Left` emits nothing.
- `'close cancels the request in flight'`.

- [ ] **Step 2: Run** `flutter test test/features/tafsir/presentation`. Expected: FAIL.

- [ ] **Step 3: Implement** the cubit, state, DI factory and both route builders. `routing-and-navigation.md` route-scoped line: add `TafsirCubit` (the mushaf routes provide `MushafCubit` and `TafsirCubit` in one `MultiBlocProvider`).

- [ ] **Step 4: Run** `flutter test test/features/tafsir test/config/router`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

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
- Produces: `class TafsirSection extends StatelessWidget { const TafsirSection({super.key, required AyahIdentifier ayah, required Color ink, required Color mutedInk, required ButtonStyle buttonStyle, bool lead = false, VoidCallback? onTap}); }` reading `TafsirCubit` through `BlocSelector<TafsirCubit, TafsirState, TafsirState>` scoped to its ayah (reading 13).
  - Full mode, top to bottom: book row `PendingS.tafsir_muyassar` (`TS.bold16`, `ink`) over `PendingS.tafsir_bookCaption` (`TS.regular14`, `mutedInk`); body: loaded → `Text(text, textDirection: TextDirection.rtl, style: TS.regular16.copyWith(height: 1.95, color: ink))` (key `tafsir-body`); loading → `Skeletonizer` over four placeholder `Text` lines in the body style; failed → `Semantics(liveRegion: true)` `PendingS.tafsir_loadFailed` (`TS.medium14`, `ink`) + `TextButton(key: ValueKey('tafsir-retry'), style: buttonStyle, onPressed: retry)` labelled `PendingS.mushaf_retry`; then the source line `PendingS.tafsir_source` (`TS.regular14`, `mutedInk`).
  - Lead mode (`key` given by the caller): one `Text` of the body, `maxLines: 1`, `overflow: TextOverflow.ellipsis`, `TS.regular14` in `mutedInk`, RTL, wrapped in a 48 px-high tap target calling `onTap`; loading → a skeletonized single line; failed → one row: message + the same retry button. No book row, no source.
- Strings (ar / en): `tafsir_muyassar` «التفسير الميسر» / 'Al-Tafsir al-Muyassar'; `tafsir_bookCaption` «يُحمَّل من الإنترنت ثم يُحفظ على الجهاز» / 'Loaded from the internet, then saved on the device'; `tafsir_source` «المصدر: التفسير الميسر، مجمع الملك فهد، عبر alquran.cloud» / 'Source: Al-Tafsir al-Muyassar, King Fahd Complex, via alquran.cloud'; `tafsir_loadFailed` «تعذّر تحميل التفسير» / 'Couldn\'t load the tafsir'.

- [ ] **Step 1: Write the failing tests** (host: `MaterialApp` with `S.delegate`, `Locale('ar')`, `BlocProvider<TafsirCubit>.value(FakeTafsirCubit(…))`, width 360, `ink`/`mutedInk` from `MushafPaper.cream.colors`, `buttonStyle: MushafPaper.cream.colors.paperButton()`; `pump()` only while a skeleton shows)

- `'loading shows a skeletonized paragraph and no retry'` (`TafsirLoading(3:7)` → `find.byType(Skeletonizer)` one, `tafsir-retry` none).
- `'a state for another ayah reads as loading'` (`TafsirLoaded(3:8, …)` for a section on 3:7 → skeleton, no 3:8 text).
- `'loaded shows the text at regular16 with line height 1.95'` (style `fontSize == TS.regular16.fontSize`, `height == 1.95`, colour `ink`).
- `'failed offers إعادة المحاولة that retries'` (tap → `fake.retries == 1`; message «تعذّر تحميل التفسير» shown; the button's `style` is the one passed in).
- `'full mode names the book, the caption and the source'`.
- `'lead mode shows one line with an ellipsis and opens on tap'` (`maxLines == 1`, `overflow == TextOverflow.ellipsis`; tap → `onTap` called; book row and source absent).
- `'lead mode failure keeps the retry in one row'`.
- `'the body stays right-to-left in English'` (`Locale('en')`, `textDirection == TextDirection.rtl`).

- [ ] **Step 2: Run** `flutter test test/features/tafsir/presentation/widgets`. Expected: FAIL.

- [ ] **Step 3: Implement** the widget and the four strings. `feature-widgets.md`: in the exception bullet add «`tafsir` exports `TafsirSection` (used by `surah`); it takes its ink colours and button style by constructor, so `tafsir` reads nothing from `surah`'s paper colours».

- [ ] **Step 4: Run** `flutter test test/features/tafsir test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tafsir/presentation/widgets/tafsir_section.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/tafsir/presentation/widgets/tafsir_section_test.dart
git commit -m "feat(tafsir): TafsirSection with a one-line lead, skeleton loading and inline retry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: AyahStrip and its layout

**Files:**
- Create: `lib/features/surah/presentation/utils/ayah_strip_layout.dart`, `lib/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart`
- Modify: `lib/features/surah/presentation/utils/reader_rules.dart` (add `mushafPageAsset`), `.claude/rules/feature-widgets.md` (surah utils list)
- Create (tests): `test/features/surah/presentation/utils/ayah_strip_layout_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart`

**Interfaces:**
- Consumes: `NormalizedRect`, `MushafPaperColors`, `mushafPageAspect`.
- Produces:
  - `String mushafPageAsset(int page)` → `'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png'` in `reader_rules.dart` (existing private copies stay; no sweep).
  - `const ayahStripMaxLines = 3;` `({List<({Rect src, Rect dst})> slices, double height}) ayahStripLayout({required List<NormalizedRect> lines, required Size image, required double width})` per reading 11: `lines.take(3)`, `scale = width / (maxW × image.width)`, slice `i`: `src = Rect.fromLTWH(x·W, y·H, w·W, h·H)`, `dst = Rect.fromLTWH(width − w·W·scale, top_i, w·W·scale, h·H·scale)`, `top_i` = sum of the previous heights; empty lines → no slices, height 0.
  - `int ayahStripCacheWidth(double width, double devicePixelRatio)` → `min(1536, (width × dpr).ceil())`.
  - `class AyahStrip extends StatefulWidget { const AyahStrip({super.key, required int page, required List<NormalizedRect> lines, required MushafPaperColors colors, ImageProvider Function(int cacheWidth)? imageFor}); }` default `imageFor: (w) => ResizeImage(AssetImage(mushafPageAsset(page)), width: w)`. A `LayoutBuilder` sizes it to `width × ayahStripLayout(…, image: const Size(1536, 2795)).height` before decode; it resolves the provider into a `ui.Image` (listener removed in `dispose` and when `page` or the width changes) and paints with a `CustomPaint(key: ValueKey('ayah-strip-paint'))`: paper `background` fill, then `drawImageRect(image, src, dst, Paint()..colorFilter = ColorFilter.mode(colors.ink, BlendMode.srcIn)..filterQuality = FilterQuality.medium)` with the layout recomputed from the decoded size. `Semantics(image: true, excludeSemantics: true)`. Empty lines → `SizedBox.shrink()`.

- [ ] **Step 1: Write the failing tests**

Layout (image `Size(1536, 2795)`, width 320; line A `x .1, y .2, w .8, h .05`, line B `x .5, y .25, w .4, h .05`):
- `'a full line spans the strip width'` (`dst == Rect.fromLTWH(0, 0, 320, .05·2795·320/(.8·1536))`, `src == Rect.fromLTWH(.1·1536, .2·2795, .8·1536, .05·2795)`).
- `'a shorter line keeps the common scale and sits at the right edge'` (B after A: `dst.left == 160`, `dst.width == 160`).
- `'lines stack top to bottom'` (B's `dst.top` == A's `dst.bottom`; `height` == sum).
- `'at most three lines are drawn'` (five lines → three slices).
- `'no lines is an empty strip'` (height 0).
- `'the strip height depends only on the page aspect'` (image `Size(768, 1397.5)` gives the same `dst` rects and height).
- `'the cache width follows the strip width and never passes the page width'` (`ayahStripCacheWidth(320, 3) == 960`, `(600, 3) == 1536`).

Widget (`imageFor` records the requested width and returns a `MemoryImage` of a small valid PNG created in `setUpAll` with `createTestImage` → `toByteData(format: ImageByteFormat.png)` under `tester.runAsync`; `tester.view.devicePixelRatio = 3`):
- `'sizes itself from the line rects before the image decodes'` (two lines at width 320 → `tester.getSize(find.byType(AyahStrip)).height` equals the layout height).
- `'asks for the page decoded at strip width'` (requested width 960).
- `'an ayah with no lines draws nothing'` (height 0, no `ayah-strip-paint`).
- `'paints once the image decodes'` (after `tester.runAsync` lets it decode and a `pump`, the painter of `ayah-strip-paint` holds a non-null image).

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/ayah_strip_layout_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** as in Interfaces. `feature-widgets.md` surah utils: add `mushafPageAsset` to the `reader_rules.dart` list and a new entry `ayah_strip_layout.dart` (`ayahStripLayout`, `ayahStripCacheWidth`: the ayah strip's slices and decode width).

- [ ] **Step 4: Run** the same two files, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/utils/ayah_strip_layout.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart lib/features/surah/presentation/utils/reader_rules.dart .claude/rules/feature-widgets.md test/features/surah/presentation/utils/ayah_strip_layout_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_strip_test.dart
git commit -m "feat(mushaf): AyahStrip, the ayah's lines cropped from the page in paper ink

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Full detent widget, adjacentAyah and MushafCubit.stepTo

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart` (move `ayahShareText` out; import it from `ayah_study_leaf.dart` until Task 6 drops share from the leaf), `lib/features/surah/presentation/utils/reader_rules.dart`, `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`, `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`, `.claude/rules/icons.md`
- Create (tests): `test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart`, `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_step_test.dart`
- Modify (tests): `test/features/surah/presentation/utils/reader_rules_test.dart`, `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart` (move `'share text quotes the ayah and names it'` out; it now lives in the study leaf test)

**Interfaces:**
- Consumes: `AyahStrip` (Task 4), `TafsirSection` (Task 3), `FakeTafsirCubit` (Task 2).
- Produces:
  - `AyahIdentifier? adjacentAyah(AyahIdentifier ayah, int delta)` in `reader_rules.dart` (`delta` ±1; uses `quran.getVerseCount`; ayah 0 counts as ayah 1).
  - `MushafCubit.stepTo(AyahIdentifier ayah, {required int page})`: same page → `select(ayah)`; another page → `_turnByUser(page)` then `emit(state.copyWith(selectedAyah: ayah))` (no `jumpFrom`, reading 10).
  - `String ayahShareText(BuildContext context, AyahIdentifier ayah)` moved unchanged into `ayah_study_leaf.dart`.
  - `class AyahStudyLeaf extends StatelessWidget { const AyahStudyLeaf({super.key, required AyahIdentifier ayah, required int page, required List<NormalizedRect> lines, required MushafPaperColors colors, required VoidCallback onBack, VoidCallback? onPrevious, VoidCallback? onNext}); }`: `Material(color: colors.leaf, shape: Border(top: BorderSide(color: colors.accent)))` filling its constraints; header row (drag down → `onBack`): `TextButton.icon(key: ValueKey('study-back'))` «العودة إلى المصحف» with `HugeIcons.strokeRoundedArrowDown01`, the title «آل عمران، الآية ٧» (`TS.bold16`, ink, `Expanded`, ellipsis), `TextButton.icon(key: ValueKey('study-share'))` `S.share` with `HugeIcons.strokeRoundedShare08` (today's `_share` body, moved); then an `Expanded` `SingleChildScrollView` with: `AyahStrip(page, lines, colors)`, `PendingS.tafsir_behind` (`TS.medium14`, `ink2`), a horizontally scrolling chip row (reading 14; keys `study-chip-tafsir`, `study-chip-translation`, `study-chip-words`, `study-chip-note`; each chip ≥ 48 px high, accent border, selected fill `colors.accent.withValues(alpha: 0.16)`, disabled labels in `ink2`), `TafsirSection(ayah: ayah, ink: colors.ink, mutedInk: colors.ink2, buttonStyle: colors.paperButton())`, and a row of two `OutlinedButton.icon`s (`style: colors.paperButton(outlined: true)` plus `minimumSize: Size(0, 48)`): `study-previous` `S.playback_previous` with `backArrowIcon(context)`, `study-next` `S.playback_next` with `forwardArrowIcon(context)`; a null handler disables its button. All buttons use `paperButton()`.
- Strings (ar / en): `tafsir_backToMushaf` «العودة إلى المصحف» / 'Back to the mushaf'; `tafsir_behind` «المصحف خلفك على هذه الآية» / 'The mushaf behind you is on this ayah'; `tafsir_sectionTafsir` «التفسير» / 'Tafsir'; `tafsir_sectionTranslation` «الترجمة» / 'Translation'; `tafsir_sectionWords` «معاني الكلمات» / 'Word meanings'; `tafsir_sectionNote` «ملاحظتي» / 'My note'.

- [ ] **Step 1: Write the failing tests**

`reader_rules_test.dart` group `adjacentAyah`: `'next stays in the surah'` (3:7 → 3:8); `'next crosses into the next surah'` (1:7 → 2:1); `'previous crosses back'` (2:1 → 1:7); `'nothing before 1:1 or after 114:6'`.

`mushaf_cubit_step_test.dart` (stubs as in `mushaf_cubit_clear_highlight_test.dart`, args page 50): `'stepTo on this page only moves the selection'` (state: page 50, `selectedAyah` 3:8, `jumpFrom` null); `'stepTo onto another page turns it and selects the ayah, with no return chip'` (`stepTo(3:10, page: 51)` → page 51, `selectedAyah` 3:10, `jumpFrom` null); `'stepTo clears a pending return chip'` (after `jumpTo(60)`, `stepTo(…, page: 61)` → `jumpFrom` null).

`ayah_study_leaf_test.dart` (host: `Locale('ar')`, `BlocProvider<TafsirCubit>.value(FakeTafsirCubit()..load(ayah))`, `SizedBox(width: 360, height: 640)`, ayah 3:7, page 50, `lines: const []`; the strip's painting is Task 4's to test):
- `'the header carries العودة إلى المصحف, the title and مشاركة'`.
- `'shows the strip and المصحف خلفك على هذه الآية'` (`find.byType(AyahStrip)` one).
- `'التفسير is selected and the other three are disabled with لاحقًا'` (semantics: `study-chip-tafsir` selected; the other three `isEnabled == false`; `find.text('لاحقًا')` three).
- `'the book row, caption, body and source show'`.
- `'previous and next reach their handlers; a null one is disabled'`.
- `'العودة إلى المصحف and a drag down on the header call onBack'`.
- `'the buttons take the paper ink on night paper'` (`MushafPaper.night.colors`: the foreground of `study-back`, `study-share`, `study-next` resolves to `colors.ink`).
- `'the arrows follow the reading direction in English'` (`Locale('en')`: `study-next` holds `forwardArrowIcon(context)`).
- `'fits at 2x text in 360 px'` (no exception).
- moved from `ayah_leaf_test.dart`: `'share text quotes the ayah and names it'`; copied (the compact leaf keeps sharing until Task 6 deletes its copy): group `share` with `'hands the quoted ayah to the share sheet'` and `'a failing share sheet shows the fallback message'`, tapping `study-share`.

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/cubit/mushaf test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** as in Interfaces. `feature-widgets.md`: add `adjacentAyah` to the `reader_rules.dart` list. `icons.md`: add «the tafsir full detent» to the HugeIcons mushaf list.

- [ ] **Step 4: Run** `flutter test test/features/surah test/core/localization`, then `flutter analyze --no-fatal-infos`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf.dart lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/features/surah/presentation/utils/reader_rules.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md .claude/rules/icons.md test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_step_test.dart test/features/surah/presentation/utils/reader_rules_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart
git commit -m "feat(mushaf): the tafsir full detent with strip, section chips and ayah stepping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: S5 compact leaf and reader wiring

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart`, `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify (tests): `test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart`

**Interfaces:**
- Consumes: `TafsirCubit` (Task 2), `TafsirSection` (Task 3), `AyahStudyLeaf`, `adjacentAyah`, `MushafCubit.stepTo` (Task 5), `FakeTafsirCubit`.
- Produces:
  - `AyahLeaf` gains `required VoidCallback onExpand` and `bool tafsirLead = true`; loses share (`_share`, `leaf-share`, the `share_plus` import). Action row: `leaf-listen` «استماع من هنا» (filled), `leaf-tafsir` `PendingS.leaf_tafsir` with `HugeIcons.strokeRoundedBookOpen01` → `onExpand`, `leaf-fasil`, `leaf-save`. Under the row, when `tafsirLead` and not the banner: `TafsirSection(key: ValueKey('tafsir-lead'), ayah: ayah, ink: colors.ink, mutedInk: colors.ink2, buttonStyle: colors.paperButton(), lead: true, onTap: onExpand)`. Vertical drag: `< -300` → `onExpand`, `> 300` → `onClose`. The banner variant is unchanged.
  - `_MushafPageState`: `late final TafsirCubit _tafsirCubit` (read in `initState`; loads the arrival selection when `args` selected one); `final _studying = ValueNotifier(false)` (disposed); `void _closeLeaf()` (studying → `_studying.value = false`, else `clearSelection()`) passed to `_LeafPopScope`; a `BlocListener` with `listenWhen: (a, b) => a.selectedAyah != b.selectedAyah` → null: `_studying.value = false; _tafsirCubit.cancel()`, else `_tafsirCubit.load(b.selectedAyah!)`; `void _moveViewTo(int page)` (the controller move from `_jumpInPlace`, now shared); `void _stepAyah(int delta)` per reading 10 (another page: `_lastReadSaver.onManualTurn()`, `_turns.begin(page)`, `stepTo`, `_moveViewTo`, post-frame `_turns.end`; same page: `stepTo` only).
  - `_LeafSlot` passes `onExpand: () => _studying.value = true` and `tafsirLead: tapAction == LeafTapAction.meaning` (`context.select` on `SettingsCubit`), and wraps the ayah leaf in `ValueListenableBuilder(_studying)` → `ExcludeSemantics(excluding: studying, …)` keeping `ValueKey(selected)` on the outer widget.
  - `_StudyLayer` (private, last child of the reading-area `Stack`, `Positioned.fill`): when `_studying` and the selection is a non-banner ayah, `AyahStudyLeaf(key: ValueKey('study-leaf'), ayah: selected, page: state.currentPage, lines: <that ayah's lines in state.pageAyahs, else const []>, colors, onBack: () => _studying.value = false, onPrevious: adjacentAyah(selected, -1) == null ? null : () => _stepAyah(-1), onNext: … +1)`; otherwise `SizedBox.shrink()`; `BlocBuilder` with `buildWhen` on `selectedAyah`, `currentPage`, `pageAyahs`; an `AnimatedSwitcher` (200 ms) between the two.
  - Harness: `pumpMushafPage` gains `FakeTafsirCubit? tafsir`, provides it, returns it in `MushafHarness` (`tafsir`), and closes it; `FakeSettings` gains `LeafTapAction tapAction = LeafTapAction.meaning`; `FakeMushaf` gains `final steps = <(AyahIdentifier, int)>[]` and `stepTo` (records, then same page → select, else `copyWith(currentPage: page, selectedAyah: ayah, clearJumpFrom: true)`).
- String (ar / en): `leaf_tafsir` «تفسير الآية» / 'Ayah tafsir'.

- [ ] **Step 1: Write the failing tests**

`ayah_leaf_test.dart`, deliberate rewrites (they pin the S4 row): `_host` provides `BlocProvider<TafsirCubit>.value(tafsir)` (a `FakeTafsirCubit` loaded with the ayah in `setUp`) and passes `onExpand: calls.tap('expand')` and a `tafsirLead` argument (default true).
- `'ayah leaf labels are distinct'` → keys `leaf-listen`, `leaf-tafsir`, `leaf-fasil`, `leaf-save`, labels `['استماع من هنا', 'تفسير الآية', 'فاصل', 'حفظ الآية']`, four distinct, and `find.byKey(ValueKey('leaf-share'))` finds nothing.
- `'listen from here, close, فاصل and save reach their handlers'` → also taps `leaf-tafsir`; `calls.taps == ['here', 'close', 'expand', 'fasil']`.
- `'fits at 2x text'` keeps its name and now pumps with the lead line showing.
- the share group and `'share text quotes the ayah and names it'` are gone from this file (Task 5 moved the latter; delete the group here, its two tests now live in `ayah_study_leaf_test.dart`).
- New: `'the tafsir line shows one line and opens the full detent'` (`tafsir-lead` contains `tafsirText`; tapping it → `'expand'`); `'tafsirLead false hides the line'`; `'dragging up opens the full detent'` (`tester.fling(find.byType(AyahLeaf), const Offset(0, -300), 1000)` → `'expand'`); `'the banner has no tafsir line or button'` (extend `'the banner variant offers the surah actions only'` with `leaf-tafsir` and `tafsir-lead` finding nothing).

`mushaf_page_shell_test.dart`, new group `tafsir` (selection pushed through `FakeMushaf.push` as the existing tests do):
- `'selecting an ayah loads its tafsir'` (`h.tafsir.loads == [3:7]`).
- `'a jump arrival with focusAyah loads its tafsir'`.
- `'clearing the selection cancels the tafsir request'` (`h.tafsir.cancels == 1`).
- `'تفسير الآية opens the full detent and العودة إلى المصحف returns with the ayah still selected'` (`study-leaf` shown; after `study-back`, `study-leaf` gone, `leaf-tafsir` visible, `selectedAyah` unchanged).
- `'returning from the full detent leaves the page where it was'` (an ayah under the leaf: the `page-slide` `Transform` offset before opening equals the offset after `study-back` and `pumpAndSettle`).
- `'system back at the full detent collapses first, then closes'`.
- `'الآية التالية keeps the full detent open and moves the selection'` (`steps == [(3:8, page)]`, `study-leaf` still shown).
- `'الآية التالية on the last ayah of a page turns the page behind'` (stub page service maps the next ayah to the next page: `steps.last.$2 == current + 1`, `currentPage` follows, no «العودة إلى صفحة» chip).
- `'with الخيارات the compact leaf has no tafsir line'` (`FakeSettings(tapAction: LeafTapAction.options)` → `tafsir-lead` none, `leaf-tafsir` present).
- `'the full detent fits at 2x text'` (`textScale: 2`, open it, no exception).

- [ ] **Step 2: Run** `flutter test test/features/surah/presentation/pages/mushaf`. Expected: FAIL (`onExpand` undefined, no `TafsirCubit` provider).

- [ ] **Step 3: Implement** as in Interfaces; add `leaf_tafsir`.

- [ ] **Step 4: Run** `flutter test test/features/surah test/features/tafsir test/core/localization`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, baseline counts plus the new tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_leaf_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_harness.dart test/features/surah/presentation/pages/mushaf/mushaf_page_shell_test.dart
git commit -m "feat(mushaf): S5 ayah leaf with تفسير الآية and the tafsir line, full detent in the reader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: «عند الضغط على الآية» in العرض, docs and slice verification

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart`, `lib/features/surah/presentation/utils/enum_localization.dart`, `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`, `CLAUDE.md`
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

- [ ] **Step 3: Implement** the extension, the selector and the strings. `feature-widgets.md` surah utils: `enum_localization.dart` (`MushafPaper.localized`, `LeafTapAction.localized`). `CLAUDE.md` first paragraph: the mushaf summary becomes «the mushaf (page and scroll reading, reading papers, فواصل and saved ayat, Tafsir al-Muyassar)».

- [ ] **Step 4: Verify the slice**

Run, in order: `dart format` on every `.dart` path this plan changed (explicit paths), `flutter analyze --no-fatal-infos` (0 errors, 0 warnings, ≤ 69 infos), `flutter test` (1523 + this plan's added tests − none deleted, all pass, 1 skipped), `git status --short` (only this task's paths staged; `.claude/agents/`, `.claude/skills/impeccable/`, `lib/generated/**` untouched). Grep the new and changed files for `//`, `Color(0x`, `TextStyle(` and `Theme.of(context).colorScheme`; each must be absent from new lines.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/display_sheet.dart lib/features/surah/presentation/utils/enum_localization.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md CLAUDE.md test/features/surah/presentation/pages/mushaf/widgets/display_sheet_test.dart
git commit -m "feat(mushaf): عند الضغط على الآية in العرض, docs for the tafsir slice

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
