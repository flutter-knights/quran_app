# Mushaf Phase 2 — Overlay-Aware Playback — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
>
> **REPO LANDMINE:** `test/tools/generate_mushaf_assets_test.dart` regenerates `assets/mushaf/**` when run. NEVER run the full `fvm flutter test`; run scoped paths only (`fvm flutter test test/features/...`). NEVER `git add -A` — stage explicit paths. After any test run, verify `git status --porcelain | grep assets/mushaf` is empty.

**Goal:** Play a from→to ayah range with per-ayah and per-range repeat counts (plus infinite), via a redesigned mini/expanded player whose numeric fields are type-editable; and keep the active ayah from hiding under the player (page-mode scale-into-safe-area).

**Architecture:** Extend `PlaybackState`/`PlaybackCubit` (reuse the existing `_endSurah`/`_endAyah` + `AyahSequenceService` end-boundary plumbing) with range + repeat counters. Add a pure `PlaybackRangeValidator`. Replace `ayah_playback_overlay.dart` with a two-state player. Add page-scale avoidance in `MushafPage`.

**Tech Stack:** Flutter, flutter_bloc Cubit, get_it, the local `quran` package, flutter_intl.

**Spec:** `docs/superpowers/specs/2026-05-31-mushaf-reading-experience-design.md` (Phase 2). Visual refs: `.superpowers/mockups/05,06,07-*.html`.

**Use `fvm flutter` / `fvm dart` for all commands.**

---

## File structure (Phase 2)

**Create:**
- `lib/features/quran_playback/domain/services/playback_range_validator.dart` — pure validation (8 rules).
- `lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart` — the expanded panel (range steppers + repeat boxes + ∞ + type-edit).
- Tests mirroring each.

**Modify:**
- `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart` — range + repeat fields.
- `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` — `playRange`, repeat sequencing, setters.
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart` — mini-player redesign + expand.
- `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` — page-scale avoidance when player visible.
- `lib/l10n/intl_en.arb`, `intl_ar.arb` — new strings.

---

## Task 1: PlaybackState range + repeat fields

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`
- Test: `test/features/quran_playback/presentation/cubit/playback_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/quran_playback/presentation/cubit/playback_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  group('PlaybackState repeat/range defaults', () {
    test('defaults: no range, repeats = 1, not infinite', () {
      const s = PlaybackState();
      expect(s.rangeStart, isNull);
      expect(s.rangeEnd, isNull);
      expect(s.eachAyahRepeat, 1);
      expect(s.rangeRepeat, 1);
      expect(s.infiniteRepeat, false);
      expect(s.infiniteTarget, RepeatTarget.range);
      expect(s.currentAyahPlayCount, 1);
      expect(s.currentRangePass, 1);
    });

    test('copyWith updates and preserves repeat fields', () {
      const s = PlaybackState();
      final n = s.copyWith(
        rangeStart: const AyahIdentifier(surah: 2, ayah: 5),
        rangeEnd: const AyahIdentifier(surah: 2, ayah: 20),
        eachAyahRepeat: 3,
        rangeRepeat: 2,
        infiniteRepeat: true,
        infiniteTarget: RepeatTarget.eachAyah,
        currentAyahPlayCount: 2,
        currentRangePass: 1,
      );
      expect(n.rangeStart, const AyahIdentifier(surah: 2, ayah: 5));
      expect(n.rangeEnd, const AyahIdentifier(surah: 2, ayah: 20));
      expect(n.eachAyahRepeat, 3);
      expect(n.rangeRepeat, 2);
      expect(n.infiniteRepeat, true);
      expect(n.infiniteTarget, RepeatTarget.eachAyah);
      expect(n.currentAyahPlayCount, 2);
      // unrelated field preserved
      expect(n.speed, s.speed);
    });

    test('clearRange wipes range bounds', () {
      const s = PlaybackState(
        rangeStart: AyahIdentifier(surah: 2, ayah: 5),
        rangeEnd: AyahIdentifier(surah: 2, ayah: 20),
      );
      final n = s.copyWith(clearRange: true);
      expect(n.rangeStart, isNull);
      expect(n.rangeEnd, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/quran_playback/presentation/cubit/playback_state_test.dart`
Expected: FAIL (`RepeatTarget` undefined; fields missing).

- [ ] **Step 3: Add the enum + fields**

In `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`, add at the top (after imports):

```dart
/// Which repeat dimension the infinite (∞) toggle applies to.
enum RepeatTarget { eachAyah, range }
```

Add these fields to `PlaybackState` (after `speed`):

```dart
  /// Inclusive playback range. Null start/end = play from currentAyah to the
  /// natural end of the surah (legacy behavior).
  final AyahIdentifier? rangeStart;
  final AyahIdentifier? rangeEnd;

  /// How many times each ayah plays before advancing (1..99).
  final int eachAyahRepeat;

  /// How many times the whole range loops (1..99).
  final int rangeRepeat;

  /// When true, the [infiniteTarget] dimension repeats forever.
  final bool infiniteRepeat;
  final RepeatTarget infiniteTarget;

  /// Runtime counters (1-based): how many times the current ayah has played
  /// in this pass, and which range pass we're on.
  final int currentAyahPlayCount;
  final int currentRangePass;
```

Add to the constructor parameter list (with defaults):

```dart
    this.rangeStart,
    this.rangeEnd,
    this.eachAyahRepeat = 1,
    this.rangeRepeat = 1,
    this.infiniteRepeat = false,
    this.infiniteTarget = RepeatTarget.range,
    this.currentAyahPlayCount = 1,
    this.currentRangePass = 1,
```

In `copyWith`, add params:

```dart
    AyahIdentifier? rangeStart,
    AyahIdentifier? rangeEnd,
    int? eachAyahRepeat,
    int? rangeRepeat,
    bool? infiniteRepeat,
    RepeatTarget? infiniteTarget,
    int? currentAyahPlayCount,
    int? currentRangePass,
    bool clearRange = false,
```

and in the returned `PlaybackState(...)`:

```dart
      rangeStart: clearRange ? null : (rangeStart ?? this.rangeStart),
      rangeEnd: clearRange ? null : (rangeEnd ?? this.rangeEnd),
      eachAyahRepeat: eachAyahRepeat ?? this.eachAyahRepeat,
      rangeRepeat: rangeRepeat ?? this.rangeRepeat,
      infiniteRepeat: infiniteRepeat ?? this.infiniteRepeat,
      infiniteTarget: infiniteTarget ?? this.infiniteTarget,
      currentAyahPlayCount: currentAyahPlayCount ?? this.currentAyahPlayCount,
      currentRangePass: currentRangePass ?? this.currentRangePass,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/quran_playback/presentation/cubit/playback_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_state.dart \
  test/features/quran_playback/presentation/cubit/playback_state_test.dart
git commit -m "feat(playback): add range + repeat fields to PlaybackState"
```

---

## Task 2: PlaybackRangeValidator (8 rules)

Pure, UI-independent validation. Uses `quran.getVerseCount`.

**Files:**
- Create: `lib/features/quran_playback/domain/services/playback_range_validator.dart`
- Test: `test/features/quran_playback/domain/services/playback_range_validator_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/quran_playback/domain/services/playback_range_validator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/services/playback_range_validator.dart';

void main() {
  group('clampFrom (rule 1) — surah 2 has 286 ayahs', () {
    test('0 or below snaps to 1', () {
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: 0), 1);
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: -5), 1);
    });
    test('above verse count clamps to last ayah', () {
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: 999), 286);
    });
    test('in-range passes through', () {
      expect(PlaybackRangeValidator.clampFrom(surah: 2, value: 50), 50);
    });
  });

  group('clampTo (rules 2 & 3)', () {
    test('to below from auto-follows from (to=from)', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 50, value: 10), 50);
    });
    test('to above verse count clamps to last ayah', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 50, value: 999), 286);
    });
    test('valid to passes through', () {
      expect(PlaybackRangeValidator.clampTo(surah: 2, from: 50, value: 100), 100);
    });
  });

  group('clampRepeat (rule 5)', () {
    test('blank/0 -> 1, negative -> 1', () {
      expect(PlaybackRangeValidator.clampRepeat(0), 1);
      expect(PlaybackRangeValidator.clampRepeat(-3), 1);
    });
    test('caps at 99', () {
      expect(PlaybackRangeValidator.clampRepeat(500), 99);
    });
    test('in-range passes through', () {
      expect(PlaybackRangeValidator.clampRepeat(7), 7);
    });
  });

  group('parseCounter (rule 8) — non-numeric/blank handling', () {
    test('non-numeric returns null (caller keeps last valid)', () {
      expect(PlaybackRangeValidator.parseCounter('abc'), isNull);
      expect(PlaybackRangeValidator.parseCounter(''), isNull);
    });
    test('numeric (incl. Arabic-Indic digits) parses', () {
      expect(PlaybackRangeValidator.parseCounter('12'), 12);
      expect(PlaybackRangeValidator.parseCounter('٧'), 7);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/quran_playback/domain/services/playback_range_validator_test.dart`
Expected: FAIL ("Target of URI doesn't exist").

- [ ] **Step 3: Write the validator**

Create `lib/features/quran_playback/domain/services/playback_range_validator.dart`:

```dart
import 'package:quran/quran.dart' as quran;

/// Pure validation for the from→to playback range and repeat counters.
/// Rules (per the Phase 2 spec):
/// 1. from ∈ [1, verseCount]; 0/blank → 1.
/// 2. to ∈ [from, verseCount]; over last → clamp to last.
/// 3. to < from → to follows from (to = from).
/// 4. single-surah ranges (enforced by callers using one surah's count).
/// 5. repeat ∈ [1, 99]; blank/0 → 1.
/// 8. non-numeric input → null (caller keeps the last valid value).
class PlaybackRangeValidator {
  static const int maxRepeat = 99;

  static int clampFrom({required int surah, required int value}) {
    final last = quran.getVerseCount(surah);
    if (value < 1) return 1;
    if (value > last) return last;
    return value;
  }

  static int clampTo({required int surah, required int from, required int value}) {
    final last = quran.getVerseCount(surah);
    final lo = from < 1 ? 1 : from;
    if (value < lo) return lo;
    if (value > last) return last;
    return value;
  }

  static int clampRepeat(int value) {
    if (value < 1) return 1;
    if (value > maxRepeat) return maxRepeat;
    return value;
  }

  /// Parses user text (Western or Arabic-Indic digits). Returns null for
  /// blank/non-numeric so the caller can revert to the last valid value.
  static int? parseCounter(String raw) {
    final normalized = raw.split('').map((ch) {
      final code = ch.codeUnitAt(0);
      // Arabic-Indic ٠..٩ = U+0660..U+0669 → ASCII 0..9
      if (code >= 0x0660 && code <= 0x0669) {
        return String.fromCharCode(code - 0x0660 + 0x30);
      }
      return ch;
    }).join();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/quran_playback/domain/services/playback_range_validator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/domain/services/playback_range_validator.dart \
  test/features/quran_playback/domain/services/playback_range_validator_test.dart
git commit -m "feat(playback): pure range/repeat validator (8 rules)"
```

---

## Task 3: PlaybackCubit range + repeat sequencing

Wire range + repeat into the cubit. Reuse `_endSurah`/`_endAyah` for the range end.

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Test: `test/features/quran_playback/presentation/cubit/playback_repeat_logic_test.dart`

- [ ] **Step 1: Read the cubit to confirm structure**

Run: `sed -n '56,150p' lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
Expected: shows `playSelected`, `_playAyah`, `_handleNextAyah` (uses `_endSurah`/`_endAyah`).

- [ ] **Step 2: Write the failing test (repeat decision logic)**

The audio pipeline is async/stream-driven, so we test the **pure decision helper** `nextPlaybackStep`, which Step 4 extracts. Create `test/features/quran_playback/presentation/cubit/playback_repeat_logic_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  final seq = AyahSequenceService();

  PlaybackState base({
    required AyahIdentifier current,
    int eachAyahRepeat = 1,
    int rangeRepeat = 1,
    bool infinite = false,
    RepeatTarget target = RepeatTarget.range,
    int playCount = 1,
    int pass = 1,
    AyahIdentifier? start,
    AyahIdentifier? end,
  }) =>
      PlaybackState(
        currentAyah: current,
        rangeStart: start ?? const AyahIdentifier(surah: 2, ayah: 5),
        rangeEnd: end ?? const AyahIdentifier(surah: 2, ayah: 7),
        eachAyahRepeat: eachAyahRepeat,
        rangeRepeat: rangeRepeat,
        infiniteRepeat: infinite,
        infiniteTarget: target,
        currentAyahPlayCount: playCount,
        currentRangePass: pass,
      );

  group('nextPlaybackStep', () {
    test('repeats the same ayah until eachAyahRepeat reached', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 5),
        eachAyahRepeat: 3,
        playCount: 1,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.repeatAyah);
      expect(step.ayah, const AyahIdentifier(surah: 2, ayah: 5));
      expect(step.nextPlayCount, 2);
    });

    test('advances to next ayah after repeats exhausted', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 5),
        eachAyahRepeat: 2,
        playCount: 2,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.advance);
      expect(step.ayah, const AyahIdentifier(surah: 2, ayah: 6));
      expect(step.nextPlayCount, 1);
    });

    test('at range end with rangeRepeat left, restarts at rangeStart', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 7),
        rangeRepeat: 2,
        pass: 1,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.restartRange);
      expect(step.ayah, const AyahIdentifier(surah: 2, ayah: 5));
      expect(step.nextPass, 2);
    });

    test('at range end with no repeats left, stops', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 7),
        rangeRepeat: 1,
        pass: 1,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.stop);
    });

    test('infinite range never stops at range end', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 7),
        rangeRepeat: 1,
        pass: 9,
        infinite: true,
        target: RepeatTarget.range,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.restartRange);
    });

    test('infinite each-ayah repeats the ayah forever', () {
      final s = base(
        current: const AyahIdentifier(surah: 2, ayah: 5),
        eachAyahRepeat: 1,
        playCount: 9,
        infinite: true,
        target: RepeatTarget.eachAyah,
      );
      final step = nextPlaybackStep(s, seq);
      expect(step.kind, PlaybackStepKind.repeatAyah);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `fvm flutter test test/features/quran_playback/presentation/cubit/playback_repeat_logic_test.dart`
Expected: FAIL (`nextPlaybackStep`, `PlaybackStep`, `PlaybackStepKind` undefined).

- [ ] **Step 4: Add the pure step function + wire it into the cubit**

In `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`, add at top-level (above the class):

```dart
enum PlaybackStepKind { repeatAyah, advance, restartRange, stop }

class PlaybackStep {
  const PlaybackStep(this.kind, {this.ayah, this.nextPlayCount = 1, this.nextPass = 1});
  final PlaybackStepKind kind;
  final AyahIdentifier? ayah;
  final int nextPlayCount;
  final int nextPass;
}

/// Pure decision: given the current state, what plays next when the current
/// ayah's audio completes? No side effects — the cubit applies the result.
PlaybackStep nextPlaybackStep(PlaybackState s, AyahSequenceService seq) {
  final current = s.currentAyah;
  if (current == null) return const PlaybackStep(PlaybackStepKind.stop);

  // 1) Repeat the same ayah if more plays remain (or each-ayah is infinite).
  final eachInfinite =
      s.infiniteRepeat && s.infiniteTarget == RepeatTarget.eachAyah;
  if (eachInfinite || s.currentAyahPlayCount < s.eachAyahRepeat) {
    return PlaybackStep(
      PlaybackStepKind.repeatAyah,
      ayah: current,
      nextPlayCount: s.currentAyahPlayCount + 1,
      nextPass: s.currentRangePass,
    );
  }

  // 2) Try to advance within the range.
  final next = seq.getNextAyah(
    current: current,
    endSurah: s.rangeEnd?.surah,
    endAyah: s.rangeEnd?.ayah,
  );
  if (next != null) {
    return PlaybackStep(
      PlaybackStepKind.advance,
      ayah: next,
      nextPlayCount: 1,
      nextPass: s.currentRangePass,
    );
  }

  // 3) Hit the range end. Loop the range if repeats remain (or infinite range).
  final rangeInfinite =
      s.infiniteRepeat && s.infiniteTarget == RepeatTarget.range;
  if (rangeInfinite || s.currentRangePass < s.rangeRepeat) {
    final start = s.rangeStart ?? current;
    return PlaybackStep(
      PlaybackStepKind.restartRange,
      ayah: start,
      nextPlayCount: 1,
      nextPass: s.currentRangePass + 1,
    );
  }

  return const PlaybackStep(PlaybackStepKind.stop);
}
```

Add a `playRange` method (after `playSelected`):

```dart
  /// Plays [start]..[end] (single surah) with the current repeat settings.
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
    await _playAyah(start.ayah == 0
        ? AyahIdentifier(surah: start.surah, ayah: 1)
        : start);
  }
```

Replace the body of `_handleNextAyah()` with the step-driven version:

```dart
  void _handleNextAyah() {
    if (!state.isAutoPlaying || state.currentAyah == null) return;
    final step = nextPlaybackStep(state, ayahSequenceService);
    switch (step.kind) {
      case PlaybackStepKind.stop:
        stop();
        return;
      case PlaybackStepKind.repeatAyah:
        emit(state.copyWith(currentAyahPlayCount: step.nextPlayCount));
        _playAyah(step.ayah!);
        return;
      case PlaybackStepKind.advance:
        emit(state.copyWith(
          currentAyahPlayCount: step.nextPlayCount,
          currentRangePass: step.nextPass,
        ));
        _playAyah(step.ayah!);
        return;
      case PlaybackStepKind.restartRange:
        emit(state.copyWith(
          currentAyahPlayCount: step.nextPlayCount,
          currentRangePass: step.nextPass,
        ));
        _playAyah(step.ayah!);
        return;
    }
  }
```

Add repeat-setting mutators (after `setSpeed`):

```dart
  void setEachAyahRepeat(int value) =>
      emit(state.copyWith(eachAyahRepeat: value));

  void setRangeRepeat(int value) =>
      emit(state.copyWith(rangeRepeat: value));

  void setInfiniteRepeat(bool value, RepeatTarget target) =>
      emit(state.copyWith(infiniteRepeat: value, infiniteTarget: target));

  /// Updates the active range end live (used by the expanded panel).
  void setRangeEnd(AyahIdentifier end) {
    _endSurah = end.surah;
    _endAyah = end.ayah;
    emit(state.copyWith(rangeEnd: end));
  }
```

In `playSelected`, after `_endSurah = null; _endAyah = null;`, also reset the range + counters so a plain tap-to-play behaves as before:

```dart
    emit(state.copyWith(
      clearRange: true,
      currentAyahPlayCount: 1,
      currentRangePass: 1,
      isAutoPlaying: true,
      isLoading: true,
    ));
```
(Replace the existing single `emit(state.copyWith(isAutoPlaying: true, isLoading: true));` line in `playSelected` with the above.)

- [ ] **Step 5: Run test to verify it passes**

Run: `fvm flutter test test/features/quran_playback/presentation/cubit/playback_repeat_logic_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the playback test dir to confirm no regression**

Run: `fvm flutter test test/features/quran_playback/`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart \
  test/features/quran_playback/presentation/cubit/playback_repeat_logic_test.dart
git commit -m "feat(playback): range + repeat sequencing (each-ayah, range, infinite)"
```

---

## Task 4: l10n strings for the player

**Files:**
- Modify: `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`
- Then regenerate.

- [ ] **Step 1: Add strings**

In `intl_en.arb`:
```json
  "repeat": "Repeat",
  "range": "Range",
  "fromAyah": "From",
  "toAyah": "To",
  "eachAyah": "Each ayah",
  "wholeRange": "Range",
  "infinite": "∞",
  "playbackOptions": "Playback options",
```
In `intl_ar.arb`:
```json
  "repeat": "التكرار",
  "range": "النطاق",
  "fromAyah": "من آية",
  "toAyah": "إلى آية",
  "eachAyah": "كل آية",
  "wholeRange": "النطاق",
  "infinite": "∞",
  "playbackOptions": "خيارات التشغيل",
```
Watch JSON commas; ensure keys are unique.

- [ ] **Step 2: Regenerate + analyze**

Run: `fvm dart run intl_utils:generate && fvm flutter analyze`
Expected: l10n.dart gains the getters; analyze 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/l10n.dart lib/generated/intl/messages_en.dart lib/generated/intl/messages_ar.dart
git commit -m "feat(playback): l10n strings for range + repeat panel"
```

---

## Task 5: Expanded repeat/range panel (type-editable counters)

A panel with: From/To steppers, each-ayah & range repeat boxes, ∞ toggle. Each numeric value is tappable to type (via a small dialog) and has +/− steppers. Uses `PlaybackRangeValidator`.

**Files:**
- Create: `lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart`
- Test: `test/features/quran_playback/presentation/widgets/playback_repeat_options_test.dart`

- [ ] **Step 1: Write the widget**

Create `lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/playback_range_validator.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/generated/l10n.dart';

/// Expanded playback panel: from→to range + per-ayah / per-range repeat counts
/// + an infinite toggle. Every counter is +/- steppable and tap-to-type.
class PlaybackRepeatOptions extends StatelessWidget {
  const PlaybackRepeatOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) =>
          a.rangeStart != b.rangeStart ||
          a.rangeEnd != b.rangeEnd ||
          a.eachAyahRepeat != b.eachAyahRepeat ||
          a.rangeRepeat != b.rangeRepeat ||
          a.infiniteRepeat != b.infiniteRepeat ||
          a.infiniteTarget != b.infiniteTarget,
      builder: (context, st) {
        final cubit = context.read<PlaybackCubit>();
        final surah = st.rangeStart?.surah ?? st.currentAyah?.surah ?? 1;
        final from = st.rangeStart?.ayah ?? st.currentAyah?.ayah ?? 1;
        final to = st.rangeEnd?.ayah ?? quran.getVerseCount(surah);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.range, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Counter(
                    keyValue: 'range-from',
                    label: s.fromAyah,
                    value: from,
                    onChanged: (v) {
                      final nf = PlaybackRangeValidator.clampFrom(
                          surah: surah, value: v);
                      final nt = PlaybackRangeValidator.clampTo(
                          surah: surah, from: nf, value: to);
                      cubit.playRange(
                        start: AyahIdentifier(surah: surah, ayah: nf),
                        end: AyahIdentifier(surah: surah, ayah: nt),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Counter(
                    keyValue: 'range-to',
                    label: s.toAyah,
                    value: to,
                    onChanged: (v) {
                      final nt = PlaybackRangeValidator.clampTo(
                          surah: surah, from: from, value: v);
                      cubit.setRangeEnd(
                          AyahIdentifier(surah: surah, ayah: nt));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(s.repeat, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Counter(
                    keyValue: 'repeat-each',
                    label: s.eachAyah,
                    value: st.eachAyahRepeat,
                    onChanged: (v) =>
                        cubit.setEachAyahRepeat(
                            PlaybackRangeValidator.clampRepeat(v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Counter(
                    keyValue: 'repeat-range',
                    label: s.wholeRange,
                    value: st.rangeRepeat,
                    onChanged: (v) =>
                        cubit.setRangeRepeat(
                            PlaybackRangeValidator.clampRepeat(v)),
                  ),
                ),
                const SizedBox(width: 10),
                _InfiniteToggle(
                  on: st.infiniteRepeat,
                  onTap: () => cubit.setInfiniteRepeat(
                      !st.infiniteRepeat, RepeatTarget.range),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.keyValue,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String keyValue;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  Future<void> _typeValue(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          key: const ValueKey('counter-text-field'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () {
              final parsed =
                  PlaybackRangeValidator.parseCounter(controller.text);
              Navigator.pop(ctx, parsed); // null reverts to last valid
            },
            child: Text(S.of(context).save),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(keyValue),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => onChanged(value - 1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _typeValue(context),
              child: Column(
                children: [
                  Text('$value',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(label,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _InfiniteToggle extends StatelessWidget {
  const _InfiniteToggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const ValueKey('repeat-infinite'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: on ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('∞',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: on ? scheme.onPrimary : scheme.onSurface,
            )),
      ),
    );
  }
}
```

- [ ] **Step 2: Write the widget test**

Create `test/features/quran_playback/presentation/widgets/playback_repeat_options_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/playback_repeat_options.dart';
import 'package:quran_app/generated/l10n.dart';

class _MockPlaybackCubit extends MockCubit<PlaybackState>
    implements PlaybackCubit {}

void main() {
  late _MockPlaybackCubit cubit;

  setUp(() {
    cubit = _MockPlaybackCubit();
    when(() => cubit.state).thenReturn(
      const PlaybackState(eachAyahRepeat: 3, rangeRepeat: 1),
    );
  });

  Widget host() => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PlaybackCubit>.value(
            value: cubit,
            child: const PlaybackRepeatOptions(),
          ),
        ),
      );

  testWidgets('renders the four counters and the infinite toggle',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('range-from')), findsOneWidget);
    expect(find.byKey(const ValueKey('range-to')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-each')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-range')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-infinite')), findsOneWidget);
  });

  testWidgets('plus on each-ayah repeat calls setEachAyahRepeat(clamped)',
      (tester) async {
    when(() => cubit.setEachAyahRepeat(any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final plus = find.descendant(
      of: find.byKey(const ValueKey('repeat-each')),
      matching: find.byIcon(Icons.add),
    );
    await tester.tap(plus);
    await tester.pump();
    verify(() => cubit.setEachAyahRepeat(4)).called(1); // 3 + 1
  });
}
```

> NOTE: this test uses `mocktail` + `bloc_test`'s `MockCubit`. Confirm both are dev_dependencies (they are used elsewhere in the repo); if `MockCubit` import differs, match the repo's existing cubit-mock pattern (grep `MockCubit` in test/).

- [ ] **Step 3: Run test**

Run: `fvm flutter test test/features/quran_playback/presentation/widgets/playback_repeat_options_test.dart`
Expected: PASS. (If `MockCubit`/registerFallbackValue is needed for `AyahIdentifier`, add `setUpAll(() => registerFallbackValue(const AyahIdentifier(surah: 1, ayah: 1)));`.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart \
  test/features/quran_playback/presentation/widgets/playback_repeat_options_test.dart
git commit -m "feat(playback): expanded range + repeat panel with type-editable counters"
```

---

## Task 6: Mini-player redesign + expand-to-panel + range entry points

Augment `ayah_playback_overlay.dart`: add a live repeat-status subtitle and an expand button that opens `PlaybackRepeatOptions` in a bottom sheet. Make the dock/tap "play" set a range (tapped ayah → end of surah) via `playRange`.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` (tap-to-play uses range)

- [ ] **Step 1: Add an expand button + repeat-status subtitle to the overlay**

In `ayah_playback_overlay.dart`'s `_Body`, in the header `Row` (after the close `IconButton`, before the `Expanded` label), add an expand button:

```dart
                IconButton(
                  key: const ValueKey('playback-expand'),
                  icon: const Icon(Icons.tune),
                  tooltip: S.of(context).playbackOptions,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(
                      value: context.read<PlaybackCubit>(),
                      child: const SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: PlaybackRepeatOptions(),
                        ),
                      ),
                    ),
                  ),
                ),
```
Add the import:
```dart
import '../../../../../quran_playback/presentation/widgets/playback_repeat_options.dart';
```
Under the `ayah_label` Text in the `Expanded`, show a live repeat-status line when a finite repeat is active:
```dart
                      BlocBuilder<PlaybackCubit, PlaybackState>(
                        buildWhen: (a, b) =>
                            a.currentAyahPlayCount != b.currentAyahPlayCount ||
                            a.eachAyahRepeat != b.eachAyahRepeat ||
                            a.infiniteRepeat != b.infiniteRepeat,
                        builder: (context, p) {
                          if (p.eachAyahRepeat <= 1 && !p.infiniteRepeat) {
                            return const SizedBox.shrink();
                          }
                          final txt = p.infiniteRepeat
                              ? '∞'
                              : '${p.currentAyahPlayCount}/${p.eachAyahRepeat}';
                          return Text('↻ $txt',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall);
                        },
                      ),
```
(Wrap the existing label `Text` + this new builder in a `Column(mainAxisSize: min)` inside the `Expanded`.)

- [ ] **Step 2: Dock play sets a range (tapped page first ayah → end of surah)**

In `mushaf_action_dock.dart`'s `_onPlay`, after computing `firstAyah` (non-null branch), replace `context.read<PlaybackCubit>().playSelected(firstAyah)` with a range play to the end of that surah:

```dart
      mushafCubit.toggleHighlight(firstAyah);
      final surah = firstAyah.surah;
      final start = firstAyah.ayah == 0
          ? AyahIdentifier(surah: surah, ayah: 1)
          : firstAyah;
      context.read<PlaybackCubit>().playRange(
            start: start,
            end: AyahIdentifier(surah: surah, ayah: quran.getVerseCount(surah)),
          );
```
Add `import 'package:quran/quran.dart' as quran;` to the dock file.

- [ ] **Step 3: Tap-to-play a verse sets range tapped→end of surah**

In `mushaf_page_view.dart`'s `_handleTap`, the verse-hit branch currently does `cubit.toggleHighlight(hit)` (which opens the overlay; play is started elsewhere). Leave highlight behavior, but ensure the overlay's play uses range. The overlay's `_PlayPauseButton` calls `cubit.playSelected(target!)` — change that call to `playRange(start: target!, end: lastAyahOfSurah)`:

In `ayah_playback_overlay.dart` `_PlayPauseButton.onPressed` else-branch, replace `cubit.playSelected(target!)` with:
```dart
                final t = target!;
                final start = t.ayah == 0
                    ? AyahIdentifier(surah: t.surah, ayah: 1)
                    : t;
                cubit.playRange(
                  start: start,
                  end: AyahIdentifier(
                      surah: t.surah, ayah: q.getVerseCount(t.surah)),
                );
```
(`q` is the existing `quran` alias imported in that file.)

- [ ] **Step 4: Analyze + scoped tests**

Run: `fvm flutter analyze && fvm flutter test test/features/surah/ test/features/quran_playback/`
Expected: 0 errors; all pass. Confirm `git status --porcelain | grep assets/mushaf` is empty.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart \
  lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart \
  lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart
git commit -m "feat(playback): range-based play + expandable repeat panel in overlay"
```

---

## Task 7: Overlay-aware page positioning (page mode)

When the player is visible, scale the page into the area above it so the active ayah is never hidden.

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`

- [ ] **Step 1: Reserve bottom space for the player when visible**

In `mushaf_page.dart`, the `PageView.builder` is inside `Positioned.fill`. Wrap it so that when the playback overlay is visible (driven by `MushafCubit` highlighted/pinned OR `PlaybackCubit` currentAyah), the PageView gets bottom padding equal to a fixed player height (e.g. 132) and the page scales to fit. Use an `AnimatedPadding`:

```dart
              // PAGE — scales into the safe area above the player when active.
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.highlightedAyah != b.highlightedAyah ||
                    a.isOverlayPinned != b.isOverlayPinned,
                builder: (context, state) {
                  final playerVisible =
                      state.highlightedAyah != null || state.isOverlayPinned;
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: playerVisible ? 132 : 0),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: 604,
                        onPageChanged: (i) =>
                            _mushafCubit.setPage(_pageNumberFor(i)),
                        itemBuilder: (_, i) =>
                            MushafPageView(pageNumber: _pageNumberFor(i)),
                      ),
                    ),
                  );
                },
              ),
```
(Replace the existing `Positioned.fill(child: Directionality(... PageView ...))` block with the above wrapped in `Positioned.fill`.)

- [ ] **Step 2: Analyze + scoped tests + manual note**

Run: `fvm flutter analyze && fvm flutter test test/features/surah/`
Expected: 0 errors; pass. Manual: on device, selecting a verse near the bottom shows the page shrink so the verse stays visible above the player (smooth 0.4s). Confirm `git status` shows no asset changes.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart
git commit -m "feat(mushaf): scale page into safe area when player is visible"
```

---

## Self-review notes (author)

- **Spec coverage:** range play → Tasks 1,3,5,6; repeat each-ayah + range + infinite → Tasks 1,3,5; type-editable counters → Task 5; 8 validation rules → Task 2 (rule 4 single-surah is enforced by callers passing one surah's count + rule 6 infinite-override handled in UI by the ∞ toggle disabling numeric meaning; rule 7 live-edit → `setRangeEnd`/`playRange` restart); redesigned mini/expanded player → Tasks 5,6; overlay-aware page-mode positioning → Task 7. Scroll-mode auto-scroll is deferred to Phase 3 (depends on the scroll view) — NOT in this plan.
- **Reused infra:** `_endSurah`/`_endAyah` + `AyahSequenceService` end-boundary already existed; Task 3 layers repeat logic on top via the pure `nextPlaybackStep`.
- **Type consistency:** `RepeatTarget{eachAyah,range}`, `PlaybackStep`/`PlaybackStepKind`, `nextPlaybackStep`, `playRange`, `setEachAyahRepeat/setRangeRepeat/setInfiniteRepeat/setRangeEnd`, `PlaybackRangeValidator.{clampFrom,clampTo,clampRepeat,parseCounter,maxRepeat}` — used consistently across tasks.
- **Landmine:** never run full `fvm flutter test`; scope to `test/features/...`; never `git add -A`.
- **Deferred:** rule-6 "infinite disables the count field visually" is a minor UI affordance; the ∞ toggle currently targets `RepeatTarget.range` — a follow-up can let the user choose the target. Flagged, not built.
