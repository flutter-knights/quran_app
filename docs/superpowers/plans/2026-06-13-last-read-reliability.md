# Last-Read Card Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the "Continue reading" card reflect the user's real last position even after an OS background-kill, never persist an out-of-range page, and never display "ayah 0" for the basmala header.

**Architecture:** Three independent fixes — (1) persist last-read on debounced page-change + on app-background + on dispose (not dispose-only); (2) clamp the page to 1..604 at the repository chokepoint; (3) treat ayah 0 / null as page-based in `computeSurahProgress`.

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `hive`, `quran` package, `flutter_test`. FVM-pinned Flutter 3.38.1.

> **Ordering:** Workstream D. Independent of A/B/C, but Task 3 (mushaf save triggers) edits `mushaf_page.dart`, which Workstream A Phase 1 also edits — if both are in flight, do them in separate sessions/commits to avoid overlap. The fixes themselves don't conflict.
> **Test caveat:** never run the full `fvm flutter test` (asset regeneration); scope to `test/features/...`. Never `git add -A`; this branch may have a parallel session — stage with explicit paths and prefer `git commit -o <paths> -m ...` (commit-only the named paths) so unrelated staged changes are not swept in.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart` | ayah 0/null → page-based progress | Modify |
| `lib/features/surah/data/repositories/last_read_repository_impl.dart` | Clamp page 1..604 on save | Modify |
| `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` | Debounced + lifecycle + dispose saves | Modify |

---

### Task 1: ayah 0 / null → page-based progress

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart`
- Test: `test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart';

void main() {
  test('ayah > 0 is ayah-based', () {
    final p = computeSurahProgress(
      const LastRead(page: 3, ayah: AyahIdentifier(surah: 2, ayah: 5)),
    );
    expect(p.ayahBased, isTrue);
    expect(p.ayahCurrent, 5);
    expect(p.surahNumber, 2);
  });

  test('ayah == 0 (basmala) is page-based, not "ayah 0"', () {
    final p = computeSurahProgress(
      const LastRead(page: 2, ayah: AyahIdentifier(surah: 2, ayah: 0)),
    );
    expect(p.ayahBased, isFalse);
    expect(p.ayahCurrent, isNull);
    expect(p.surahNumber, 2); // resolved from the page
  });

  test('null ayah is page-based', () {
    final p = computeSurahProgress(const LastRead(page: 2));
    expect(p.ayahBased, isFalse);
    expect(p.ayahCurrent, isNull);
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart`
Expected: FAIL — the ayah==0 case currently returns `ayahBased: true`, `ayahCurrent: 1`.

- [ ] **Step 3: Treat zero like null**

In `surah_reading_progress.dart`, change the surah derivation and the guard so a zero ayah behaves like a missing one:

Replace:
```dart
  final surah = last.ayah?.surah ?? _firstSurahOfPage(last.page);
  final total = quran.getVerseCount(surah);

  if (last.ayah != null) {
```
with:
```dart
  final hasAyah = last.ayah != null && last.ayah!.ayah > 0;
  final surah = hasAyah ? last.ayah!.surah : _firstSurahOfPage(last.page);
  final total = quran.getVerseCount(surah);

  if (hasAyah) {
```
(The rest is unchanged — the page-based branch handles ayah 0/null.)

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart
git commit -o lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart -m "fix(last-read): basmala/ayah-0 shows page-based progress

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Clamp page on save

**Files:**
- Modify: `lib/features/surah/data/repositories/last_read_repository_impl.dart`
- Test: `test/features/surah/data/repositories/last_read_repository_impl_test.dart` (extend the existing file)

- [ ] **Step 1: Add failing tests** (append inside the existing `main()`)

```dart
  test('save clamps a too-low page up to 1', () async {
    await repo.save(const LastRead(page: 0));
    final got = await repo.get();
    expect(got!.page, 1);
  });

  test('save clamps a too-high page down to 604', () async {
    await repo.save(const LastRead(page: 700));
    final got = await repo.get();
    expect(got!.page, 604);
  });

  test('save leaves a valid page unchanged', () async {
    await repo.save(const LastRead(page: 300));
    final got = await repo.get();
    expect(got!.page, 300);
  });
```

- [ ] **Step 2: Run, verify the clamp tests fail**

Run: `fvm flutter test test/features/surah/data/repositories/last_read_repository_impl_test.dart`
Expected: the two clamp tests FAIL (page persists as 0 / 700); the existing round-trip tests still pass.

- [ ] **Step 3: Clamp in `_to`**

In `last_read_repository_impl.dart`, change `_to`:
```dart
  LastReadHiveModel _to(LastRead v) => LastReadHiveModel(
        page: v.page.clamp(1, 604),
        surah: v.ayah?.surah,
        ayah: v.ayah?.ayah,
      );
```

- [ ] **Step 4: Run, verify all pass**

Run: `fvm flutter test test/features/surah/data/repositories/last_read_repository_impl_test.dart`
Expected: PASS (clamp + existing round-trip tests).

- [ ] **Step 5: Commit**

```bash
git commit -o lib/features/surah/data/repositories/last_read_repository_impl_test.dart lib/features/surah/data/repositories/last_read_repository_impl.dart -m "fix(last-read): clamp persisted page to 1..604

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
(`git add` both paths first if `-o` needs them staged: `git add <both paths>` then the `git commit -o <both paths>`.)

---

### Task 3: Persist on page-change (debounced) + app background + dispose

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
- Test: `test/features/surah/presentation/pages/mushaf/mushaf_last_read_save_test.dart` (create)

- [ ] **Step 1: Refactor saving into one method + add the debounce/lifecycle/flush triggers**

In `mushaf_page.dart`:

1. Add the import + make the state observe lifecycle. Change the class declaration:
```dart
class _MushafPageState extends State<MushafPage> with WidgetsBindingObserver {
```
Add `import 'dart:async';` if not present (for `Timer`).

2. Add fields near the other state fields:
```dart
  Timer? _lastReadDebounce;
  static const _lastReadDebounceDelay = Duration(milliseconds: 800);
```

3. In `initState`, register the observer (after the existing setup):
```dart
    WidgetsBinding.instance.addObserver(this);
```
Also schedule a save when the page settles — add a `MushafCubit` listener. The simplest hook: the existing `_onScroll`/`onPageChanged` both call `_mushafCubit.setPage`. Add a debounced save call inside the page-mode `onPageChanged` and the scroll listener. To keep it in one place, add a listener on the cubit in `initState`:
```dart
    _mushafCubit.stream
        .map((s) => s.currentPage)
        .distinct()
        .listen((_) => _scheduleLastReadSave());
```
Store that subscription in a field `late final StreamSubscription _pageSub;` and cancel it in `dispose`.

4. Add the save helpers:
```dart
  void _scheduleLastReadSave() {
    _lastReadDebounce?.cancel();
    _lastReadDebounce = Timer(_lastReadDebounceDelay, _saveLastRead);
  }

  void _saveLastRead() {
    _lastReadDebounce?.cancel();
    if (isClosedOrUnmounted()) return;
    final mushafState = _mushafCubit.state;
    final ayah =
        mushafState.highlightedAyah ?? _playbackCubit.state.currentAyah;
    _lastReadCubit
        .save(LastRead(page: mushafState.currentPage, ayah: ayah))
        .catchError((_) {});
  }

  bool isClosedOrUnmounted() => !mounted;
```

5. Add the lifecycle hook:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveLastRead(); // flush before a possible OS kill
    }
  }
```

6. In `dispose`, cancel the timer + subscription + observer, then keep the final save. Replace the current dispose save region with:
```dart
  @override
  void dispose() {
    _pageController.removeListener(_precacheFromPageController);
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    _lastReadDebounce?.cancel();
    _pageSub.cancel();
    WidgetsBinding.instance.removeObserver(this);

    _saveLastRead(); // final flush on clean exit
    _playbackCubit.stop();

    super.dispose();
  }
```
> NOTE: `_saveLastRead` reads `mounted`; in `dispose` `mounted` is already `false`, so guard the dispose flush separately — call the save inline there instead of through the `mounted` guard. Concretely, in `dispose` replace `_saveLastRead();` with the direct save (no `mounted` check, since we are intentionally flushing on teardown):
> ```dart
>     final mushafState = _mushafCubit.state;
>     final ayah =
>         mushafState.highlightedAyah ?? _playbackCubit.state.currentAyah;
>     _lastReadCubit
>         .save(LastRead(page: mushafState.currentPage, ayah: ayah))
>         .catchError((_) {});
> ```
> and keep `_saveLastRead()` (with the `mounted` guard) for the debounce + lifecycle paths only.

7. Remove the now-removed `SystemChrome.setPreferredOrientations([])` line only if Workstream A Phase 1 hasn't already removed it; otherwise leave A's change intact. (D does not depend on it.)

- [ ] **Step 2: Write the save-trigger widget test**

`test/features/surah/presentation/pages/mushaf/mushaf_last_read_save_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
// Import the page + cubits used to host it. If MushafPage requires heavy DI
// (GetMushafPage, etc.), prefer a focused test of the save method by extracting
// _saveLastRead into a testable helper; otherwise host the widget with mocked
// cubits as below.

class _MockLastReadCubit extends Mock {}

void main() {
  setUpAll(() => registerFallbackValue(const LastRead(page: 1)));

  // The save path is: page-change → debounced save; lifecycle paused → save.
  // Because MushafPage wires many cubits, this test verifies the DEBOUNCE +
  // LIFECYCLE contract at the unit level by exercising a small extracted
  // controller. See Step 3.
  test('placeholder — replaced by Step 3 extraction test', () {
    expect(true, isTrue);
  });
}
```
> The mushaf page has heavy DI (image loading, playback, settings). A full `pumpWidget` test is brittle. Instead, extract the save scheduling into a tiny testable unit (Step 3) and test that.

- [ ] **Step 3: Extract a testable `LastReadSaver` and test it**

Create `lib/features/surah/presentation/pages/mushaf/last_read_saver.dart`:
```dart
import 'dart:async';

import '../../../domain/entities/last_read.dart';

/// Debounced + immediate persistence of the reading position. Pure timing
/// logic, decoupled from the widget so it is unit-testable. The page widget
/// owns a [LastReadSaver] and supplies [readCurrent] + [persist].
class LastReadSaver {
  LastReadSaver({
    required this.readCurrent,
    required this.persist,
    this.debounce = const Duration(milliseconds: 800),
  });

  final LastRead Function() readCurrent;
  final Future<void> Function(LastRead) persist;
  final Duration debounce;

  Timer? _timer;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    persist(readCurrent());
  }

  void dispose() => _timer?.cancel();
}
```
Test `test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart`:
```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/last_read_saver.dart';

void main() {
  test('schedule persists once after the debounce window', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      var page = 10;
      final saver = LastReadSaver(
        readCurrent: () => LastRead(page: page),
        persist: (v) async => saved.add(v),
        debounce: const Duration(milliseconds: 800),
      );

      saver.schedule();
      page = 11;
      saver.schedule(); // resets the timer
      async.elapse(const Duration(milliseconds: 700));
      expect(saved, isEmpty); // not yet
      async.elapse(const Duration(milliseconds: 200));
      expect(saved.single.page, 11); // once, with the latest page
    });
  });

  test('flush persists immediately and cancels the pending timer', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final saver = LastReadSaver(
        readCurrent: () => const LastRead(page: 5),
        persist: (v) async => saved.add(v),
      );
      saver.schedule();
      saver.flush(); // immediate
      async.elapse(const Duration(seconds: 2));
      expect(saved.length, 1); // timer did not also fire
      expect(saved.single.page, 5);
    });
  });
}
```
> `fake_async` is already a transitive dev dependency of `flutter_test`; if the import fails, add `fake_async` to `dev_dependencies` via `fvm flutter pub add --dev fake_async`.

Then wire `LastReadSaver` into `mushaf_page.dart`: replace the inline `Timer`/`_scheduleLastReadSave`/`_saveLastRead` from Step 1 with a `late final LastReadSaver _lastReadSaver;` built in `initState`:
```dart
    _lastReadSaver = LastReadSaver(
      readCurrent: () {
        final s = _mushafCubit.state;
        return LastRead(
          page: s.currentPage,
          ayah: s.highlightedAyah ?? _playbackCubit.state.currentAyah,
        );
      },
      persist: (v) => _lastReadCubit.save(v).catchError((_) {}),
    );
```
- page-change listener → `if (mounted) _lastReadSaver.schedule();`
- `didChangeAppLifecycleState(paused/inactive)` → `_lastReadSaver.flush();`
- `dispose` → `_lastReadSaver.flush(); _lastReadSaver.dispose();` (flush before dispose; `readCurrent` reads cubit state which is valid during dispose), then cancel `_pageSub`, remove the observer.

Delete the placeholder test file from Step 2 (`mushaf_last_read_save_test.dart`) — the `LastReadSaver` test replaces it.

- [ ] **Step 4: Run the saver test + analyze**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart`
Expected: PASS.
Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/last_read_saver.dart`
Expected: No issues.

- [ ] **Step 5: Run the broader mushaf suite (regression)**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf`
Expected: PASS (the existing `mushaf_page_dispose_test.dart` still passes — the dispose flush preserves its behavior).

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/last_read_saver.dart test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart
git commit -o lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/last_read_saver.dart test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart -m "fix(last-read): persist on page-change (debounced), background, and dispose

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Verification

- [ ] **Step 1: Scoped tests + analyze**

Run: `fvm flutter test test/features/surah`
Run: `fvm flutter analyze lib/features/surah`
Expected: All PASS / no issues.

- [ ] **Step 2: Manual gate (document in PR)**

1. Read to page N → **background the app** (home button / app switcher) without reopening the reader → fully kill it from the app switcher → cold launch → the card shows **page N**.
2. In scroll mode, fling through many pages and settle on page M → only one save fires (after ~0.8 s) and the card shows page M.
3. Open a surah at its basmala (ayah 0) and leave → the card shows the page/surah, never "ayah 0".
4. Save still occurs on a normal back-navigation (dispose path).

- [ ] **Step 3: Finalize**

Workstream D complete. Use `superpowers:finishing-a-development-branch` to integrate.

---

## Self-review notes (author)

- **Spec coverage:** D1 (debounced + lifecycle + dispose) → Task 3; D2 (clamp 1..604) → Task 2; D3 (ayah 0/null page-based) → Task 1. All covered.
- **Placeholder scan:** the Step-2 placeholder test is explicitly deleted and replaced by the `LastReadSaver` extraction in Step 3 (a real, testable unit) — not a left-in placeholder. The `fake_async`/extraction notes are concrete fallbacks.
- **Type consistency:** `LastReadSaver({readCurrent, persist, debounce})` + `schedule()`/`flush()`/`dispose()` used identically in the widget wiring and the test; `computeSurahProgress` return shape unchanged; `_to` signature unchanged.
- **Parallel-session safety:** every commit uses `git commit -o <paths>` so only the named files are committed (the branch may have a concurrent session staging other files).
- **Test caveat honored:** all runs scoped under `test/features/...`.
