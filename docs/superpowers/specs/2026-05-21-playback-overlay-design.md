# Playback Overlay + Continue Reading — Design

**Date:** 2026-05-21
**Branch:** `feature/300-quran-playback`
**Status:** Draft (awaiting user approval)

## 1. Goal

Replace the current `AyahActionBar` with a dedicated **playback overlay** that gives the user transport control (play, pause, restart, skip prev/next, speed, close) over a selected ayah. Move the secondary actions (Tafsir, Translation, Bookmark, Share) plus a new reciter picker into a **modal bottom sheet** triggered by long-pressing an ayah. Wire the existing `LastQuranRead` widget to real persistence so users can resume where they left off, including a paused ayah position. Add a "play surah from start" entry point on the surah list.

## 2. User-facing behavior

### 2.1 Mushaf gestures

| Gesture | Result |
|---|---|
| Tap an ayah | Highlight the ayah; **playback overlay** slides up from the bottom in idle/ready state. **No audio starts.** |
| Tap the same ayah again | Clears the highlight; overlay slides away. Audio (if any) keeps playing. |
| Tap a *different* ayah while audio plays | Overlay re-targets to the newly tapped ayah in idle state. The previous ayah keeps playing in the background. Pressing Play on the overlay switches playback to the newly targeted ayah. |
| Long-press an ayah | Modal **`AyahLongPressSheet`** opens (Tafsir / Translation / Bookmark / Share / Reciter picker). Does not change the highlighted ayah. |
| Swipe between pages | No effect on playback. The existing `auto_swap_helper` keeps following the playing ayah's page in the other direction. |
| Navigate away from Mushaf (back, route change) | Snapshot `(currentPage, highlightedAyah ?? currentAyah)` to `LastReadRepository`, then `PlaybackCubit.stop()`. App-backgrounding does *not* stop audio. |

### 2.2 Playback overlay controls

Layout (replaces the `AyahActionBar` slot in the `Column`, same slide/fade animation envelope):

```
┌──────────────────────────────────────────────────────────────┐
│  ✕    سورة البقرة، الآية ٥                             1.0x ▾│
│                                                              │
│      ⏮       ⟲ (reset)    ▶/⏸ (large)    ⏭                  │
│   prev ayah   restart      play/pause     next ayah          │
└──────────────────────────────────────────────────────────────┘
```

| Control | Action |
|---|---|
| ✕ (close) | `PlaybackCubit.stop()` + `MushafCubit.clearHighlight()` → overlay slides away. |
| Ayah label | Read-only. Renders `سورة {surah}، الآية {ayah}` for the targeted ayah (= `MushafCubit.highlightedAyah`). |
| Speed chip | Tap opens popover with 0.5 / 0.75 / 1 / 1.25 / 1.5 / 2. Selection persists via `SettingsCubit.playbackSpeed`. |
| Skip-previous (⏮) | `PlaybackCubit.skipPrevious()` — **always** starts playing the previous ayah (per user spec). Disabled at (1:1). |
| Restart (⟲) | `PlaybackCubit.restartCurrent()` — `player.seek(0)` + `player.play()`. Disabled if `currentAyah == null` (overlay opened by tap, never played). |
| Play / Pause | Toggle based on `isPlaying`. Calls `PlaybackCubit.playSelected(highlightedAyah)` or `PlaybackCubit.pause()`. When `isLoading`, the icon is replaced by a `CircularProgressIndicator`. |
| Skip-next (⏭) | `PlaybackCubit.skipNext()` — always starts the next ayah. Disabled at (114, last ayah). |

### 2.3 Long-press sheet

```
┌──────────────────────────────────────────────────────────────┐
│                       ──── (drag handle)                     │
│  سورة البقرة، الآية ٥                                        │
│                                                              │
│  📖 التفسير      🌐 الترجمة      🔖 حفظ      ↗ مشاركة      │
│                                                              │
│  ─── القارئ ───                                              │
│  ( الحصري ) ( العفاسي ) ( السديس ) ( المنشاوي ) …          │
└──────────────────────────────────────────────────────────────┘
```

- Actions row: Tafsir, Translation, Bookmark, Share. Tafsir + Translation show the existing "coming soon" SnackBar.
- Reciter chip list: current reciter highlighted. Tapping a chip pops the sheet and calls `PlaybackCubit.setReciter(newReciter)`. If audio is currently playing or paused for an ayah, that call **restarts the same ayah with the new reciter from the beginning**. If overlay is idle, the reciter is updated for the next play. The chosen reciter persists via `SettingsCubit.defaultReciter`.
- No Play button (per user spec — tap on the ayah is the Play path).

### 2.4 Continue Reading

- The `LastQuranRead` widget (currently hardcoded) becomes data-bound. Two display modes:
  - `{page}` only → `الصفحة {page}`.
  - `{page, ayah}` → `سورة {surah}، الآية {ayah}`.
- Continue button navigates to `/mushaf` with `extra: lastRead.page`.
- On `MushafPage.initState`, if `LastRead.ayah` matches the requested page's range, schedule a post-frame `MushafCubit.toggleHighlight(lastRead.ayah)` → overlay appears in idle state. `PlaybackCubit` starts clean (idle), so Play is the action and Restart is disabled (per the `currentAyah == null` rule).
- **No auto-resume of audio.** Continue puts the user back at the same visual state (page + selected ayah), nothing more.

### 2.5 Play surah from start

- Each tile in `SurahListTile` gets a small play-icon button (trailing, before the existing chevron / number star).
- Tap → routes to `/mushaf` with `extra: firstPageOfSurah`, then on init calls `PlaybackCubit.playFromAyah(AyahIdentifier(surah, 1))`.
- The basmala is included automatically because the everyayah.com mirror embeds it at the start of `{surah}001.mp3` (verified: `002000.mp3` returns 404; `002001.mp3` returns 200 with ~123 KB). See Appendix A.

## 3. Architecture

### 3.1 Cubit ownership

| Concern | Owner | Notes |
|---|---|---|
| Selected ("target") ayah for the overlay | `MushafCubit.highlightedAyah` | Already exists. Set on tap; cleared on close. |
| Currently-playing ayah | `PlaybackCubit.currentAyah` → mirrored to `MushafCubit.playingAyah` via existing `ValueNotifier`. | Already exists. |
| Play / pause / loading / speed / reciter | `PlaybackCubit` | Extend state. |
| Last-read snapshot (page + optional ayah) | New `LastReadCubit` over `LastReadRepository` (Hive) | New box `last_read`. |
| Default reciter, playback speed | `SettingsCubit` | New fields. |

### 3.2 Overlay visibility rule

The overlay is visible iff `MushafCubit.highlightedAyah != null`. It always shows controls for `highlightedAyah` (the "target"). `PlaybackCubit` supplies the play/pause/loading/speed state; whether the controls' state lines up with the target is computed:

- `isTargetPlaying = (PlaybackCubit.state.currentAyah == highlightedAyah) && PlaybackCubit.state.isPlaying`.
- If the target is not the playing ayah, the Play button always shows "▶" (pressing it switches playback to the target).

### 3.3 Auto-follow rule

When `PlaybackCubit` advances to a new ayah (auto-advance at end of audio OR user pressed skip), `MushafCubit._onPlayingAyahChanged` updates `playingAyah` and conditionally updates `highlightedAyah`:

```dart
void _onPlayingAyahChanged() {
  final prevPlaying = state.playingAyah;
  final next = _notifier.value;
  final wasFollowing = state.highlightedAyah == null
      || state.highlightedAyah == prevPlaying;
  if (next == null) {
    emit(state.copyWith(clearPlaying: true));
    // Do NOT clear highlightedAyah here — overlay closes via explicit Close/Reset.
  } else {
    emit(state.copyWith(
      playingAyah: next,
      highlightedAyah: wasFollowing ? next : state.highlightedAyah,
    ));
  }
}
```

This implements: "highlight follows the playing verse unless the user has manually tapped a different verse."

### 3.4 Dispose order

`MushafPage.dispose`:

```dart
final ayah = mushafCubit.state.highlightedAyah
          ?? playbackCubit.state.currentAyah;
await lastReadRepository.save(LastRead(
  page: mushafCubit.state.currentPage,
  ayah: ayah,
));
await playbackCubit.stop();
```

Snapshot **before** stop (because `stop` clears `currentAyah`).

## 4. State + API extensions

### 4.1 `PlaybackState`

```dart
class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final bool isPaused;           // NEW
  final bool isAutoPlaying;
  final bool isLoading;
  final String? error;
  final Reciter reciter;         // NEW (default = SettingsCubit.defaultReciter or Reciter.alafasy)
  final double speed;            // NEW (default = SettingsCubit.playbackSpeed or 1.0)
}
```

Pairs of (isPlaying, isPaused):
- `(false, false)` → idle (no audio bound; Restart disabled).
- `(true, false)` → playing.
- `(false, true)` → paused at `currentAyah` (Restart and Play available).

### 4.2 `PlaybackCubit` new methods

- `Future<void> playSelected(AyahIdentifier ayah)` — wraps `playFromAyah(ayah)`; applies `state.speed` to `player.setSpeed` right after `setFilePath` in `playPreparedAudio` (small repo change).
- `Future<void> skipNext()` / `Future<void> skipPrevious()` — uses `AyahSequenceService.getNextAyah` and a new `getPreviousAyah` (3.5 lines, mirror of next). Always starts playback. No-op past boundaries.
- `Future<void> restartCurrent()` — if `state.currentAyah == null`, no-op. Otherwise `await repository.player.seek(Duration.zero); await repository.player.play();` — expose a `seek(Duration)` method on the repo.
- `void setSpeed(double v)` — emits new state, calls `repository.setSpeed(v)`, calls `SettingsCubit.updatePlaybackSpeed(v)`.
- `Future<void> setReciter(Reciter r)` — emits new state with reciter, calls `SettingsCubit.updateDefaultReciter(r)`. If `currentAyah != null && (isPlaying || isPaused)`: `await stop(); await playFromAyah(currentAyah)` (restart with new reciter).
- `pause()` (existing) — also sets `isPaused = true`.
- `stop()` (existing) — resets `currentAyah`, `isPlaying`, `isPaused`, `isAutoPlaying`. Leaves `speed` and `reciter` alone (user prefs).

**Race guard:** `playSelected(A)` then `playSelected(B)` before A's download resolves should result in only B's `notifyAyahChanged` firing. Add `AyahIdentifier? _inFlightAyah` on the cubit; check before calling `notifyAyahChanged` in `_playAyah`'s fold.

### 4.3 `AyahSequenceService` addition

```dart
AyahIdentifier? getPreviousAyah({required AyahIdentifier current}) {
  if (current.ayah > 1) {
    return AyahIdentifier(surah: current.surah, ayah: current.ayah - 1);
  }
  if (current.surah > 1) {
    final prevSurah = current.surah - 1;
    return AyahIdentifier(surah: prevSurah, ayah: getVerseCount(prevSurah));
  }
  return null;
}
```

### 4.4 `MushafCubit`

Update `_onPlayingAyahChanged()` per §3.3. No new public methods needed.

### 4.5 `SettingsCubit`

Add two fields persisted via the existing settings mechanism:
- `playbackSpeed: double` (default `1.0`).
- `defaultReciter: Reciter` (default `Reciter.alafasy`).

Both are read by `PlaybackCubit` on construction (via `sl<SettingsCubit>().state`) to seed `PlaybackState`.

### 4.6 `QuranPlaybackRepo` additions

```dart
Future<void> seek(Duration position);
Future<void> setSpeed(double speed);
```

Both forward to `just_audio`'s `AudioPlayer`.

### 4.7 `LastReadRepository` (NEW)

**Domain:** `features/surah/domain/`

```dart
class LastRead {
  final int page;
  final AyahIdentifier? ayah; // null = page-only
  const LastRead({required this.page, this.ayah});
}

abstract class LastReadRepository {
  Future<void> save(LastRead value);
  Future<LastRead?> get();
  Stream<LastRead?> watch();
}
```

**Data:** Hive box `last_read`, single key `'current'`.

```dart
@HiveType(typeId: 5)
class LastReadHiveModel {
  @HiveField(0) int page;
  @HiveField(1) int? surah;
  @HiveField(2) int? ayah;
}
```

Implementation streams via `box.watch(key: 'current').map(...)`.

### 4.8 `LastReadCubit` (NEW)

`Cubit<LastRead?>`. Subscribes to `repository.watch()` on construction; cancels subscription on close. Registered as **lazy singleton** in DI because it represents app-global state (the homepage and surah list both read it).

## 5. Components (file map)

| File | Status | Purpose |
|---|---|---|
| `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart` | NEW | Replaces `ayah_action_bar.dart` at the same slot. Implements §2.2. |
| `lib/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart` | NEW | Modal sheet. Implements §2.3. |
| `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart` | DELETE | Replaced by overlay. |
| `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` | EDIT | Add `onLongPress` to ayah hit-region. |
| `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` | EDIT | Swap `AyahActionBar` for `AyahPlaybackOverlay`; add dispose snapshot + stop; on init restore highlight from `LastRead`. |
| `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart` | EDIT | Auto-follow rule (§3.3). |
| `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart` | EDIT | Add `isPaused`, `reciter`, `speed`. |
| `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` | EDIT | Add `playSelected` / `skipNext` / `skipPrevious` / `restartCurrent` / `setSpeed` / `setReciter`; race guard. |
| `lib/features/quran_playback/domain/services/aya_sequence_service.dart` | EDIT | Add `getPreviousAyah`. |
| `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart` | EDIT | Add `seek` + `setSpeed`. |
| `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart` | EDIT | Implement `seek` + `setSpeed`. |
| `lib/features/settings/domain/entities/settings.dart` | EDIT | Add `playbackSpeed`, `defaultReciter`. |
| `lib/features/settings/data/models/settings_model.dart` | EDIT | Serialize new fields. |
| `lib/features/settings/presentation/cubit/settings_cubit.dart` | EDIT | Add `updatePlaybackSpeed`, `updateDefaultReciter`. |
| `lib/features/surah/domain/entities/last_read.dart` | NEW | `LastRead` entity. |
| `lib/features/surah/domain/repositories/last_read_repository.dart` | NEW | Repo contract. |
| `lib/features/surah/data/models/last_read_hive_model.dart` (+ `.g.dart`) | NEW | Hive model + adapter. |
| `lib/features/surah/data/datasources/last_read_local_data_source.dart` | NEW | Wraps the Hive box. |
| `lib/features/surah/data/repositories/last_read_repository_impl.dart` | NEW | Domain ↔ data mapping. |
| `lib/features/surah/presentation/cubit/last_read/last_read_cubit.dart` (+ `_state.dart`) | NEW | App-global cubit. |
| `lib/features/surah/surah_di.dart` | EDIT | Register data source + repository + cubit (lazy singleton for cubit). |
| `lib/config/hive_config.dart` | EDIT | Register `LastReadHiveModelAdapter`; open `last_read` box. |
| `lib/core/widgets/last_quran_read.dart` | EDIT | `BlocBuilder<LastReadCubit, ...>`; real labels; real navigation; localize "متابعة التلاوة". |
| `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart` | EDIT | Add trailing play-icon button → routes to mushaf + `playFromAyah(surah, 1)`. |
| `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb` | EDIT | New keys (see §6). |
| `test/features/quran_playback/playback_cubit_test.dart` | NEW | See §8.1. |
| `test/features/surah/mushaf_cubit_auto_follow_test.dart` | NEW | See §8.2. |
| `test/features/surah/last_read_repository_test.dart` | NEW | See §8.3. |
| `test/features/surah/widgets/ayah_playback_overlay_test.dart` | NEW | See §8.4. |
| `test/features/surah/widgets/ayah_long_press_sheet_test.dart` | NEW | See §8.5. |
| `test/features/surah/mushaf_page_dispose_test.dart` | NEW | See §8.6. |
| `test/core/widgets/last_quran_read_test.dart` | NEW | See §8.7. |

## 6. Localization

New keys in `lib/l10n/intl_en.arb` and `intl_ar.arb`:

| Key | English | Arabic |
|---|---|---|
| `playback_pause` | Pause | إيقاف مؤقت |
| `playback_next` | Next ayah | الآية التالية |
| `playback_previous` | Previous ayah | الآية السابقة |
| `playback_restart` | Restart | إعادة |
| `playback_close` | Close | إغلاق |
| `playback_speed` | Speed | السرعة |
| `reciter_label` | Reciter | القارئ |
| `continue_reading` | Continue reading | متابعة التلاوة |
| `ayah_label` | Surah {surah}, Ayah {ayah} | سورة {surah}، الآية {ayah} |
| `page_label` | Page {page} | الصفحة {page} |
| `play_surah` | Play surah | تشغيل السورة |

The existing `play` key is reused. `tafsir`, `translation`, `bookmark`, `share`, `share_failed`, `coming_soon`, `bookmark_save_failed`, `bookmark_added`, `bookmark_removed` carry over from the current action bar.

Per the project's localization rules (`.claude/rules/localization.md`): all strings via `S.of(context).key`. The hardcoded `"سُورَةُ الْأَنْعَام، الآية 12"` and `"مُتَابَعَةُ التِّلَاوَةِ"` in `last_quran_read.dart` MUST be removed in favor of the localized keys.

## 7. Errors & edge cases

| Case | Behavior |
|---|---|
| `prepareAyahAudio` returns `Left(Failure)` | Existing path sets `state.error`. Overlay shows a SnackBar via a `BlocListener` on `error` transitions, then immediately emits `state.copyWith(error: null)` to avoid repeat snacks. |
| Skip past boundaries (1:1 prev, 114:last next) | Buttons disabled in UI; cubit also no-ops if service returns `null`. |
| Reciter swap mid-download | Old URL's in-flight download finishes harmlessly (cached). New reciter triggers fresh `prepareAyahAudio`. `_inFlightDownloads` keyed by URL already handles this. |
| Speed change while paused | `setSpeed` calls `player.setSpeed(v)` regardless; effect takes hold on resume. |
| `LastReadRepository.save` failure on dispose | Caught + logged. Does not block navigation. |
| Continue when target page out of range | Clamped to [1, 604] inside `LastReadCubit` before emission. |
| Tap-then-tap-different before first audio loads | Race guard via `_inFlightAyah` ensures only the latest target's `notifyAyahChanged` fires. |
| App killed mid-pause | We accept losing the very last position update. We do NOT write on every state change — only on dispose. |
| Coming from Continue with `PlaybackCubit` singleton still holding stale state from a prior visit | `MushafPage.initState` calls `playbackCubit.stop()` once before applying the saved highlight. |
| Long-press while overlay already shows for a different verse | Sheet opens for the long-pressed verse; overlay stays put. Reciter change in sheet applies to the playing/last-played verse (per cubit state), not the long-pressed verse. |
| PageView swipe during playback | No effect. Existing `auto_swap_helper` continues to follow the playing ayah's page. |
| User taps "Play surah" on surah list while another surah is playing | New `playFromAyah` stops the old audio (existing behavior of `startAutoPlay`). |

## 8. Testing strategy

### 8.1 `PlaybackCubit` unit tests

Mocktail the repo + sequence + page services + fake `SettingsCubit`.

- `playSelected` happy path: emits `isLoading=true` → state with `currentAyah` set, `isPlaying=true`.
- `pause()` → `isPaused=true`, `isPlaying=false`; `resume()` flips back.
- `skipNext()` from mid-surah plays next ayah; from (114, last) no-op.
- `skipPrevious()` from (1,1) no-op; otherwise plays previous.
- `restartCurrent()` calls `repo.seek(0)` + `player.play()` when `currentAyah != null`; no-op otherwise.
- `setSpeed(1.5)` → `repo.setSpeed(1.5)`, state has `speed=1.5`, `SettingsCubit.updatePlaybackSpeed` called.
- `setReciter` while idle: state updated, no stop/replay.
- `setReciter` while playing: stop + replay current ayah with new reciter.
- Race guard: `playSelected(A)` then `playSelected(B)` before A resolves → only B's `notifyAyahChanged` fires.

### 8.2 `MushafCubit` auto-follow tests (extend existing test file)

- `highlightedAyah == playingAyah` (both A); notifier emits B → both become B.
- `highlightedAyah = C` (user tapped), `playingAyah = A`; notifier emits B → `highlightedAyah` stays C, `playingAyah = B`.
- `highlightedAyah = null`, notifier emits A → `highlightedAyah` stays null (auto-follow doesn't summon the overlay).

### 8.3 `LastReadRepositoryImpl` tests

- `save` then `get` round-trips (with and without ayah).
- `watch()` emits on save.
- Save with page out of [1, 604] is clamped on emission (or rejected — pick one and document; recommend clamp in cubit, not repo).

### 8.4 `AyahPlaybackOverlay` widget tests

- Hidden when `highlightedAyah == null`.
- Renders `سورة 2، الآية 5` for highlighted (2,5).
- Play tap → `PlaybackCubit.playSelected` called with target.
- `isLoading` → play icon replaced by `CircularProgressIndicator`.
- `isPlaying && currentAyah == highlightedAyah` → pause icon shown; tap → `pause` called.
- Skip-prev disabled at (1,1); skip-next disabled at (114, last).
- Close → `stop` + `clearHighlight`.
- Speed chip → opens popover with six speeds; selecting → `setSpeed`.

### 8.5 `AyahLongPressSheet` widget tests

- Renders 4 actions + reciter chips with current reciter highlighted.
- Reciter chip tap → `PlaybackCubit.setReciter` + sheet pops.
- Tafsir / Translation tap → "coming soon" SnackBar.

### 8.6 `MushafPage` dispose / restore tests

- Pump with `highlightedAyah=(2,5)`, `playingAyah=(2,5)`; dispose → `LastReadRepository.save({page=p, ayah=(2,5)})` then `PlaybackCubit.stop` (asserted order).
- Pump with `highlightedAyah=null`, `currentAyah=null`; dispose → save called with `ayah=null`.
- Init with a `LastRead` whose ayah is on the requested page → after first frame, `MushafCubit.highlightedAyah == lastRead.ayah` (overlay visible).
- Init with stale `PlaybackCubit` state → `stop` is called once before restore.

### 8.7 `LastQuranRead` widget tests

- Given `LastRead(page=42, ayah=(2,5))` → renders `سورة 2، الآية 5` (Arabic locale).
- Given `LastRead(page=42)` → renders `الصفحة 42`.
- Continue tap → `context.go('/mushaf', extra: 42)`.

### 8.8 Golden / lock test (carry forward)

Existing `merged_shape_highlight` golden (§3.4 of `2026-05-15-verse-tap-action-bar-design.md`) MUST keep passing — the auto-follow change must not alter the merged-shape highlight rule for the playing ayah.

## 9. Out of scope (defer)

- Per-surah auto-advance modes ("don't autoplay" / "stop at end of current surah"). User noted these as future additions. The state space is already prepped (`isAutoPlaying` exists) — add a `RepeatMode`/`AutoAdvanceMode` toggle to overlay later.
- App-backgrounding behavior (continuing or pausing audio when the OS backgrounds the app). Default: keep playing.
- Tafsir / Translation content (still SnackBar stubs).
- Reciter download size info in the sheet.
- Standalone basmala recitation (not supported by the API — see Appendix A).
- A persistent app-level mini-player on other screens.

## Appendix A — Basmala on the everyayah.com mirror

Empirically verified on 2026-05-21 against `https://mirrors.quranicaudio.com/everyayah/`:

| URL | Status | Note |
|---|---|---|
| `Alafasy_128kbps/002001.mp3` | 200 OK, ~123 KB | First ayah of Al-Baqarah; audio begins with basmala then recites ayah 1. |
| `Alafasy_128kbps/002000.mp3` | 404 Not Found | No standalone basmala file. |
| `Husary_64kbps/002000.mp3` | 404 Not Found | Confirms the pattern is not reciter-specific. |

**Implication:** the basmala is *implicitly* played whenever the user starts a surah from ayah 1 (auto-advance across surahs, "Play surah" from the surah list, or tapping ayah 1 and pressing play). No code changes are required to "make basmala work" — the current `getAyahUrl(surah, 1)` already serves the file that contains the basmala recitation. The basmala is NOT played when the user starts mid-surah (e.g., tapping ayah 50 and pressing play) — this is the intended behavior.

For Surah 1 (Al-Fatihah), the basmala IS counted as ayah 1 (`001001.mp3`), so it plays normally.

For Surah 9 (At-Tawbah), there is traditionally no basmala — `009001.mp3` starts directly with ayah 1.
