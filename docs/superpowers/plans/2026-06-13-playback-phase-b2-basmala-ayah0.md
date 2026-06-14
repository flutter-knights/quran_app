# Playback — Phase B2 (Basmala as Ayah 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the basmala a first-class, highlighted **ayah 0** playback step (for surahs other than Al-Fatiha and At-Tawbah) that advances to ayah 1 — replacing the hidden glued-sequence + `isPlayingBasmala` approach.

**Architecture:** Map ayah-0 *audio* to the canonical basmala file `(1,1)` at the repository boundary (one pure helper), so ayah 0 is an ordinary single-file step whose identity stays `(surah, 0)`. The engine already advances 0→1 (`getNextAyah`). This deletes the 2-track `playPreparedAudioSequence` path, the `isPlayingBasmala` flag, and the `CurrentAyahNotifier` basmala translation. The page painter highlights ayah 0 because every relevant page's bounds JSON already has an `ayah:0` region.

**Tech Stack:** Flutter, `flutter_bloc`, `just_audio`, `quran` package, `mocktail`, `bloc_test`, `flutter_test`. FVM-pinned Flutter 3.38.1.

> **Scope / ordering:** Phase B2 of Workstream B. **Run after Phase B1** (B1 is independent) **and after Workstream A Phase 1** — B2 edits the "Play page" entry point that A Phase 1 moved from `mushaf_action_dock.dart` into `mushaf_page.dart` `_onPlayPage`. The program's decided order is C → A → B → D, so A is done first. If A Phase 1 is NOT yet done when B2 runs, apply Task 8's change to `mushaf_action_dock.dart`'s `_onPlay` instead (same logic; noted in that task).
> **Behavior change:** directly selecting ayah 1 of a surah (tapping the verse) now plays **ayah 1 only** — the basmala plays when starting a surah from its top (the ayah-0 header / Play page / play range from the surah start). This is intentional and simpler.
> **Test caveat:** never run the full `fvm flutter test` (asset regeneration); scope to `test/features/...`. Never `git add -A`.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/features/quran_playback/domain/services/basmala_audio.dart` | Pure `audioSourceAyah()` — ayah 0 → (1,1) | Create |
| `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart` | Use `audioSourceAyah` for url + cache; drop `playPreparedAudioSequence` | Modify |
| `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart` | Drop `playPreparedAudioSequence` from interface | Modify |
| `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart` | Remove `isPlayingBasmala` | Modify |
| `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` | Simplify `_playAyah`/`playSelected`/`playRange`/`stop`; no basmala branch | Modify |
| `lib/features/surah/presentation/utils/current_ayah_notifier.dart` | Remove basmala translation (currentAyah is already (surah,0)) | Modify |
| `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart` | Play/seed from ayah 0 (stop normalizing 0→1) | Modify |
| `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` | `_onPlayPage` plays range from ayah 0 | Modify |
| `test/features/quran_playback/playback_cubit_test.dart` | Rewrite basmala cases | Modify |

---

### Task 1: `audioSourceAyah` helper

**Files:**
- Create: `lib/features/quran_playback/domain/services/basmala_audio.dart`
- Test: `test/features/quran_playback/domain/services/basmala_audio_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/basmala_audio.dart';

void main() {
  test('ayah 0 maps to the canonical basmala file (1,1)', () {
    expect(
      audioSourceAyah(const AyahIdentifier(surah: 2, ayah: 0)),
      const AyahIdentifier(surah: 1, ayah: 1),
    );
    expect(
      audioSourceAyah(const AyahIdentifier(surah: 114, ayah: 0)),
      const AyahIdentifier(surah: 1, ayah: 1),
    );
  });

  test('non-zero ayahs are unchanged', () {
    const a = AyahIdentifier(surah: 2, ayah: 5);
    expect(audioSourceAyah(a), a);
    const b = AyahIdentifier(surah: 1, ayah: 1);
    expect(audioSourceAyah(b), b);
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/quran_playback/domain/services/basmala_audio_test.dart`
Expected: FAIL — function missing.

- [ ] **Step 3: Implement**

`lib/features/quran_playback/domain/services/basmala_audio.dart`:
```dart
import '../entities/ayah_identifier.dart';

/// The basmala header is modelled as "ayah 0" of a surah (other than Al-Fatiha
/// and At-Tawbah). It has no per-ayah audio file; its recitation is the
/// canonical opening verse `(1,1)`. This maps a playback ayah to the ayah whose
/// audio file should actually be fetched — identity/highlight stays `(surah,0)`.
AyahIdentifier audioSourceAyah(AyahIdentifier ayah) {
  if (ayah.ayah == 0) return const AyahIdentifier(surah: 1, ayah: 1);
  return ayah;
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/quran_playback/domain/services/basmala_audio_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/domain/services/basmala_audio.dart test/features/quran_playback/domain/services/basmala_audio_test.dart
git commit -m "feat(playback): audioSourceAyah maps ayah 0 to the basmala file

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Repo maps ayah-0 audio to the basmala file

**Files:**
- Modify: `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`
- Test: `test/features/quran_playback/data/repositories/quran_playback_repo_basmala_test.dart`

- [ ] **Step 1: Write the failing test** (the URL used for ayah 0 is the (1,1) basmala URL)

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/data/datasources/local/quran_playback_local_data_source.dart';
import 'package:quran_app/features/quran_playback/data/datasources/remote/quran_playback_remote_data_source.dart';
import 'package:quran_app/features/quran_playback/data/repositories/quran_playback_repo_impl.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';

class _MockRemote extends Mock implements QuranPlaybackRemoteDataSource {}
class _MockLocal extends Mock implements QuranPlaybackLocalDataSource {}

void main() {
  late _MockRemote remote;
  late _MockLocal local;
  late QuranPlaybackRepoImpl repo;

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    repo = QuranPlaybackRepoImpl(
      player: AudioPlayer(),
      remote: remote,
      local: local,
      dir: Directory.systemTemp,
    );
  });

  test('ayah 0 resolves to the cached basmala (1,1) path', () async {
    final basmalaUrl = Reciter.alafasy.getAyahUrl(1, 1);
    // Simulate the (1,1) file already cached so no download happens.
    final tmp = File('${Directory.systemTemp.path}/basmala_test.mp3')
      ..writeAsStringSync('x');
    when(() => local.getCachedLocalPath(basmalaUrl)).thenReturn(tmp.path);

    final result = await repo.prepareAyahAudio(
      ayah: const AyahIdentifier(surah: 2, ayah: 0),
      reciter: Reciter.alafasy,
    );

    expect(result.isRight(), true);
    result.fold((_) {}, (p) => expect(p, tmp.path));
    // It must look up the basmala URL, never a (2,0) URL.
    verify(() => local.getCachedLocalPath(basmalaUrl)).called(1);
    tmp.deleteSync();
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/quran_playback/data/repositories/quran_playback_repo_basmala_test.dart`
Expected: FAIL — repo still builds the URL from the raw `(2,0)`.

- [ ] **Step 3: Map ayah 0 in `prepareAyahAudio` and `preloadAyahs`**

In `quran_playback_repo_impl.dart`:
1. Add the import:
```dart
import '../../domain/services/basmala_audio.dart';
```
2. In `prepareAyahAudio`, change the first two lines of the method body so the URL + file path use the mapped audio ayah:
```dart
  Future<Either<Failure, String>> prepareAyahAudio({
    required AyahIdentifier ayah,
    required Reciter reciter,
  }) async {
    final audioAyah = audioSourceAyah(ayah);
    final url = reciter.getAyahUrl(audioAyah.surah, audioAyah.ayah);

    try {
      // 1️⃣ Already cached
      final cachedPath = local.getCachedLocalPath(url);
      if (cachedPath != null && File(cachedPath).existsSync()) {
        return Right(cachedPath);
      }

      // 2️⃣ Download already running
      if (_inFlightDownloads.containsKey(url)) {
        final path = await _inFlightDownloads[url]!;
        return Right(path);
      }

      final filePath =
          '${dir.path}/${reciter.folderName}/${audioAyah.surah}/${audioAyah.ayah}.mp3';
```
(Leave the rest of the method unchanged — `file`, download, cache, return.)
3. In `preloadAyahs`, map each ayah before building the URL:
```dart
    for (final ayah in ayahs) {
      final audioAyah = audioSourceAyah(ayah);
      final url = reciter.getAyahUrl(audioAyah.surah, audioAyah.ayah);
```
(The rest of the loop — the cached/in-flight skip and the `prepareAyahAudio(ayah: ayah, ...)` enqueue — stays; `prepareAyahAudio` maps again internally, which is idempotent.)

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/quran_playback/data/repositories/quran_playback_repo_basmala_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart test/features/quran_playback/data/repositories/quran_playback_repo_basmala_test.dart
git commit -m "feat(playback): repo fetches the basmala file for ayah 0

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Remove `isPlayingBasmala` from `PlaybackState`

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`

- [ ] **Step 1: Delete the field, its constructor default, and the copyWith plumbing**

In `playback_state.dart`:
- Remove the doc comment + field (lines 14–18): `final bool isPlayingBasmala;`
- Remove `this.isPlayingBasmala = false,` from the constructor.
- Remove `bool? isPlayingBasmala,` from `copyWith`'s parameters.
- Remove `isPlayingBasmala: isPlayingBasmala ?? this.isPlayingBasmala,` from the returned `PlaybackState`.

- [ ] **Step 2: Expect compile errors in the cubit (next task fixes them)**

Run: `fvm flutter analyze lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`
Expected: clean for the state file itself. (The cubit still references the field — fixed in Task 4. Do not run the cubit analyze yet.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_state.dart
git commit -m "refactor(playback): drop isPlayingBasmala from PlaybackState

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Simplify the cubit + rewrite basmala tests

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Modify: `test/features/quran_playback/playback_cubit_test.dart`

- [ ] **Step 1: Replace `playSelected`, `playRange`, `_playAyah`, and `stop`'s basmala bits**

In `playback_cubit.dart`:

`playSelected` — remove the ayah-0 redirect:
```dart
  Future<void> playSelected(AyahIdentifier ayah) async {
    _endSurah = null;
    _endAyah = null;
    emit(state.copyWith(
      clearRange: true,
      currentAyahPlayCount: 1,
      currentRangePass: 1,
      isAutoPlaying: true,
      isLoading: true,
    ));
    await _playAyah(ayah);
  }
```

`playRange` — keep the start as-is (ayah 0 allowed):
```dart
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async {
    _endSurah = end.surah;
    _endAyah = end.ayah;
    emit(state.copyWith(
      rangeStart: start,
      rangeEnd: end,
      isAutoPlaying: true,
      isLoading: true,
      currentAyahPlayCount: 1,
      currentRangePass: 1,
    ));
    await _playAyah(start);
  }
```

`_playAyah` — single-file only; no basmala branch:
```dart
  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (isClosed) return;
    _inFlightAyah = ayah;

    // Ayah 0 (the basmala header) is an ordinary step — the repository maps its
    // audio to the canonical (1,1) file. No special sequencing here.
    final result = await repository.prepareAyahAudio(
      ayah: ayah,
      reciter: state.reciter,
    );

    if (isClosed) return;
    if (_inFlightAyah != ayah) return; // race guard

    await result.fold(
      (failure) async {
        emit(state.copyWith(
          isPlaying: false,
          isLoading: false,
          error: failure.message,
        ));
      },
      (path) async {
        await repository.setSpeed(state.speed);
        repository.notifyAyahChanged(ayah);
        await repository.playPreparedAudio(path);
      },
    );
  }
```

`stop` — drop the `isPlayingBasmala: false,` line from the `emit(state.copyWith(...))`.

- [ ] **Step 2: Replace the basmala test region**

In `test/features/quran_playback/playback_cubit_test.dart`, delete the five blocTests under the `// ── basmala prefix …` comment (the `isPlayingBasmala` test, the "prepares basmala then ayah sequence" test, the `(1,1)` test, the `(9,1)` test, the `(2,0)` redirect test, and the "basmala prepare fails fallback" test that follows) and replace that whole region with:

```dart
  // ── basmala is ayah 0 (single-file step mapped to (1,1) by the repo) ─────

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,1)) plays ayah 1 directly — no basmala prepended',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 1)),
    verify: (_) {
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 2, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
      verifyNever(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 1, ayah: 1),
            reciter: any(named: 'reciter'),
          ));
      verify(() => repo.playPreparedAudio('/p.mp3')).called(1);
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((2,0)) plays the basmala header as a real ayah-0 step',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/basmala.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 2, ayah: 0)),
    verify: (c) {
      // The cubit asks for (2,0); the repo (real impl) maps it to (1,1).
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 2, ayah: 0),
            reciter: any(named: 'reciter'),
          )).called(1);
      verify(() => repo.notifyAyahChanged(
            const AyahIdentifier(surah: 2, ayah: 0))).called(1);
      verify(() => repo.playPreparedAudio('/basmala.mp3')).called(1);
      expect(c.state.currentAyah, const AyahIdentifier(surah: 2, ayah: 0));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'completing ayah 0 advances to ayah 1',
    build: () {
      when(() => seq.getNextAyah(
            current: const AyahIdentifier(surah: 2, ayah: 0),
            endSurah: any(named: 'endSurah'),
            endAyah: any(named: 'endAyah'),
          )).thenReturn(const AyahIdentifier(surah: 2, ayah: 1));
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    seed: () => const PlaybackState(
      currentAyah: AyahIdentifier(surah: 2, ayah: 0),
      isAutoPlaying: true,
      rangeEnd: AyahIdentifier(surah: 2, ayah: 286),
    ),
    act: (c) => c.debugHandleNextForTest(),
    verify: (_) {
      verify(() => repo.prepareAyahAudio(
            ayah: const AyahIdentifier(surah: 2, ayah: 1),
            reciter: any(named: 'reciter'),
          )).called(1);
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected((9,1)) plays ayah 1 (At-Tawbah has no basmala)',
    build: () {
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) async => const Right('/p.mp3'));
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) => c.playSelected(const AyahIdentifier(surah: 9, ayah: 1)),
    verify: (_) {
      verify(() => repo.playPreparedAudio('/p.mp3')).called(1);
    },
  );
```

> The "advances to ayah 1" test calls a tiny test seam. Add it to the cubit (it just exposes the existing private `_handleNextAyah`): in `playback_cubit.dart`, add
> ```dart
>   @visibleForTesting
>   void debugHandleNextForTest() => _handleNextAyah();
> ```
> and import `package:flutter/foundation.dart` is already present (the cubit uses `ValueNotifier`). If `seed:` isn't supported by the installed `bloc_test`, replace that one test with a plain `test(...)` that constructs the cubit, uses `emit` via a public setter, or drop it (the advance is already covered by `aya_sequence_service` tests) — keep the other three.

- [ ] **Step 3: Run the playback tests**

Run: `fvm flutter test test/features/quran_playback`
Expected: PASS. Fix any remaining references to `isPlayingBasmala` the analyzer/tests surface.

- [ ] **Step 4: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart test/features/quran_playback/playback_cubit_test.dart
git commit -m "refactor(playback): ayah 0 is an ordinary step; drop glued basmala

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Remove the now-unused `playPreparedAudioSequence`

**Files:**
- Modify: `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart`
- Modify: `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`

- [ ] **Step 1: Confirm there are no callers left**

Run: `grep -rn "playPreparedAudioSequence" lib`
Expected: only the interface (`quran_playback_repo.dart`) and impl (`quran_playback_repo_impl.dart`) — no cubit caller (Task 4 removed it).

- [ ] **Step 2: Delete the method from the interface**

In `quran_playback_repo.dart`, remove the doc comment + the `playPreparedAudioSequence(...)` declaration (the block at lines ~20–28).

- [ ] **Step 3: Delete the method + its subscription field from the impl**

In `quran_playback_repo_impl.dart`:
- Remove the entire `playPreparedAudioSequence(...)` method.
- Remove the `StreamSubscription<int?>? _sequenceIndexSub;` field.
- In `stop()`, remove the two `_sequenceIndexSub` lines (the `await _sequenceIndexSub?.cancel(); _sequenceIndexSub = null;`) so it is just `await player.stop();`.

- [ ] **Step 4: Analyze**

Run: `fvm flutter analyze lib/features/quran_playback`
Expected: No issues (no dangling references; `dart:async` import may now be unused — remove if flagged).

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/domain/repositories/quran_playback_repo.dart lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart
git commit -m "refactor(playback): remove unused playPreparedAudioSequence

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Simplify `CurrentAyahNotifier`

**Files:**
- Modify: `lib/features/surah/presentation/utils/current_ayah_notifier.dart`

- [ ] **Step 1: Remove the basmala translation**

`currentAyah` is already `(surah, 0)` during the basmala, so the translation is dead. Replace the file body with:
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';

/// Mirrors the playback cubit's `currentAyah` (including the basmala header,
/// modelled as `(surah, 0)`) into a [ValueNotifier] consumed by `MushafCubit`
/// so the page painter highlights the active line.
class CurrentAyahNotifier extends ValueNotifier<AyahIdentifier?> {
  CurrentAyahNotifier({required PlaybackCubit playbackCubit}) : super(null) {
    _sub = playbackCubit.stream
        .map((s) => s.currentAyah)
        .distinct((a, b) => a?.surah == b?.surah && a?.ayah == b?.ayah)
        .listen((ayah) => value = ayah);
  }

  late final StreamSubscription<AyahIdentifier?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Run any notifier tests + analyze**

Run: `grep -rln "CurrentAyahNotifier" test` — if a test exists, run it:
Run: `fvm flutter test test/features/surah` (scoped)
Run: `fvm flutter analyze lib/features/surah/presentation/utils/current_ayah_notifier.dart`
Expected: PASS / no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/utils/current_ayah_notifier.dart
git commit -m "refactor(mushaf): CurrentAyahNotifier mirrors ayah 0 directly

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Overlay plays/seeds from ayah 0

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`

- [ ] **Step 1: Play button — start at ayah 0**

In `ayah_playback_overlay.dart`, in the play `GestureDetector.onTap` (the `else` branch ~lines 526–534), replace the normalize-to-1 with the target as-is:
```dart
              } else {
                final t = target!;
                cubit.playRange(
                  start: t,
                  end: AyahIdentifier(
                      surah: t.surah, ayah: q.getVerseCount(t.surah)),
                );
              }
```

- [ ] **Step 2: Options-sheet seed — start at ayah 0**

In `_openOptionsSheet` (~line 49), replace:
```dart
        final startAyah = highlighted.ayah == 0 ? 1 : highlighted.ayah;
```
with:
```dart
        final startAyah = highlighted.ayah;
```
(the surrounding `setRange(start: AyahIdentifier(surah: surah, ayah: startAyah), …)` is unchanged and now seeds ayah 0 when the basmala header is selected.)

- [ ] **Step 3: Analyze + run**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`
Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart`
Expected: No issues / PASS. (If the overlay test asserts the old 0→1 normalization, update that expectation to start at ayah 0.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart
git commit -m "feat(mushaf): playback overlay plays the basmala header from ayah 0

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: "Play page" starts at ayah 0

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` (post-Workstream-A Phase 1)

- [ ] **Step 1: `_onPlayPage` plays the range from ayah 0**

In `mushaf_page.dart`, in `_onPlayPage` (added by Workstream A Phase 1), the code converts the page's first ayah to `(surah, 0)` then plays the range from ayah 1. Change it to play the range from the ayah-0 start. Replace the range-start computation:
```dart
    _mushafCubit.toggleHighlight(firstAyah);
    final surah = firstAyah.surah;
    _playbackCubit.playRange(
      start: firstAyah,
      end: AyahIdentifier(surah: surah, ayah: quran.getVerseCount(surah)),
    );
```
(`firstAyah` is `(surah, 0)` for surahs ≠1,≠9, else the real first ayah — so basmala plays first when present, and Al-Fatiha/At-Tawbah start at their real ayah 1.)

> **If Workstream A Phase 1 is NOT yet applied** (the `mushaf_action_dock.dart` still exists), make the identical change in `mushaf_action_dock.dart`'s `_onPlay`: pass `start: firstAyah` to `playRange` instead of normalizing `firstAyah.ayah == 0` to ayah 1.

- [ ] **Step 2: Analyze + run**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
Run: `fvm flutter test test/features/surah/presentation`
Expected: No issues / PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart
git commit -m "feat(mushaf): Play page begins at the basmala (ayah 0)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Phase B2 verification

- [ ] **Step 1: Scoped test sweep + analyze**

Run: `fvm flutter test test/features/quran_playback test/features/surah/presentation`
Run: `fvm flutter analyze lib/features/quran_playback lib/features/surah`
Expected: All PASS / no issues. Confirm no remaining `isPlayingBasmala` / `playPreparedAudioSequence`:
Run: `grep -rn "isPlayingBasmala\|playPreparedAudioSequence" lib test`
Expected: no matches.

- [ ] **Step 2: Manual gate (document in PR)**

1. Play a surah (≠ Al-Fatiha, ≠ At-Tawbah) from its top / "Play page": the **basmala line highlights first** (ayah 0), then advances to ayah 1.
2. The player + OS notification (from B1) show "Basmala" / بسم الله الرحمن الرحيم during ayah 0, then surah:ayah.
3. Tapping the basmala header plays from the basmala; tapping ayah 1 directly plays ayah 1 only.
4. Al-Fatiha plays from its ayah 1 (basmala IS ayah 1); At-Tawbah starts at ayah 1 with no basmala.
5. Range repeat that includes the surah start replays the basmala each pass.

- [ ] **Step 3: Finalize**

Workstream B complete (B1 + B2). Use `superpowers:finishing-a-development-branch` to integrate, or continue to Workstream D.

---

## Self-review notes (author)

- **Spec coverage (B2):** ayah-0 audio → (1,1) → Tasks 1,2; first-class highlighted step (no `isPlayingBasmala`, no glued sequence) → Tasks 3,4,5,6; entry points play from ayah 0 → Tasks 7,8; Al-Fatiha/At-Tawbah special cases → covered (ayah 0 only exists for other surahs; `_onPlayPage`/`audioSourceAyah` leave (1,x)/(9,1) untouched).
- **Placeholder scan:** none. The two conditional notes (Task 4 `seed:`/`bloc_test` capability; Task 8 pre-/post-A location) are real environment branches with exact fallbacks.
- **Type consistency:** `audioSourceAyah(AyahIdentifier) → AyahIdentifier` used identically in helper, repo, and tests; `isPlayingBasmala` fully removed (Task 3) and all readers updated (Tasks 4,6 — matches the grep of readers: state, cubit, current_ayah_notifier); `playPreparedAudioSequence` removed from interface+impl after its only caller (cubit) is gone.
- **Cross-workstream dep:** Task 8 targets the entry point Workstream A Phase 1 relocated; both locations specified. Program order is C→A→B, so the `mushaf_page.dart` path applies.
- **Test caveat honored:** all runs scoped under `test/features/...`.
