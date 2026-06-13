# Background Audio + Media Controls + Basmala-as-Ayah-0 — Design

- **Date:** 2026-06-13
- **Branch:** `feature/mushaf-reading-experience`
- **Status:** Approved (brainstorming) — pending spec review → writing-plans
- **Workstream:** B of a 4-part program (A control surface · **B background audio/basmala** · C prayer notifications · D last-read). C and A are specced+planned. Each workstream is its own brainstorm → spec → plan → build cycle.

## Problem statement

1. **Ayah playback dies in the background and has no OS controls.** When the app is backgrounded or the screen locks, recitation stops, and there is nothing on the lock screen / Control Center (iOS) or notification shade (Android) to control it. The user wants it to behave like a music app: keep playing in the background and be controllable (play/pause, **and** next/previous) from the OS.
2. **Basmala is a silent prefix, not a real step.** Starting most surahs glues the basmala onto ayah 1 as a hidden 2-track sequence (`isPlayingBasmala` suppresses the highlight). The user wants the basmala to be a first-class "ayah 0" — highlighted on the basmala header and shown in the player — before ayah 1.

## Root causes (verified in code)

- `just_audio_background: ^0.0.1-beta.17` is in `pubspec.yaml` but **never initialized** — no `JustAudioBackground.init()`, no `MediaItem` tags. The repo plays via `player.setFilePath(path)` (`quran_playback_repo_impl.dart:94`), which carries no metadata, so the OS shows nothing and the iOS audio session/background mode is never declared (`Info.plist` has no `UIBackgroundModes`).
- The playback engine is a **custom per-ayah state machine**: `PlaybackCubit` prepares each ayah (`prepareAyahAudio`), plays a single file, and advances on `onAudioCompleted` via the pure `nextPlaybackStep` (per-ayah repeat, range repeat, infinite — `playback_cubit.dart:27`). `just_audio_background`'s next/prev only operate on a `ConcatenatingAudioSource` playlist via `seekToNext`, which would bypass and desync this engine. → A playlist rewrite is the wrong fit.
- The cubit **already has** `skipNext()`, `skipPrevious()`, `pause()`, `resume()`, `stop()`, `seek` (via repo) — they're just not connected to any OS control surface.
- Basmala: `_playAyah` (`playback_cubit.dart:163–224`) prepares `(1,1)` + the target, plays them as a 2-track `setAudioSources` sequence, sets `isPlayingBasmala`, and drops it on advance to the final track. `(surah,0)` taps are redirected to ayah 1 (`playback_cubit.dart:120`). So the *highlight* never lands on the basmala header.

## Decision: `audio_service`, not `just_audio_background`

To get **full** OS controls (play/pause/seek **and** next/prev) on top of a **custom** playback engine, use the lower-level `audio_service` package with a custom `BaseAudioHandler`. Its `skipToNext`/`skipToPrevious`/`play`/`pause`/`stop`/`seek` are overridable and will **delegate to the existing `PlaybackCubit` methods**, so the repeat/range engine stays the source of truth and the OS buttons simply call into it. `just_audio_background` (which can't do custom skip) is removed.

## Goals

- Recitation continues when the app is backgrounded / screen locked (iOS + Android).
- Lock screen / Control Center / notification shows **reciter + surah : ayah** (and "Basmala" for ayah 0), with working **play/pause, seek, next, previous, stop**.
- OS controls and in-app controls stay in sync (one engine).
- Basmala plays as a highlighted **ayah 0** step (surahs 2–8, 10–114), then advances to ayah 1.

## Non-goals

- Rewriting the repeat/range engine or moving to a `ConcatenatingAudioSource` playlist.
- Downloading/caching changes (the existing prepare/preload pipeline is reused as-is).
- Adhan playback (separate `AdhanPlaybackService`, untouched).
- Carplay/Android Auto.

---

## Design

### B1 — Media layer via `audio_service` (`QuranAudioHandler`)

Add `audio_service`; remove `just_audio_background`. Introduce a `QuranAudioHandler extends BaseAudioHandler` that **bridges the existing `AudioPlayer` and `PlaybackCubit` to the OS** — it does not own the playback engine.

**Responsibilities**
- **Broadcast state to the OS:** subscribe to the shared `AudioPlayer`'s `playbackEventStream`/`positionStream` and publish `playbackState` (processingState, `playing`, position/buffered/duration) plus the active `MediaControl` set `[skipToPrevious, play/pause, skipToNext, stop]`. (Standard just_audio↔audio_service bridge.)
- **Publish metadata:** expose a `setNowPlaying(MediaItem)` the cubit calls on each ayah change with `id` = `surah:ayah`, `title` = ayah label (or "Basmala / ﷽" for ayah 0), `artist` = reciter name, `album` = surah name, optional `artUri` (bundled Quran art / app icon).
- **Route OS commands to the engine:** override `play`→`cubit.resume()`, `pause`→`cubit.pause()`, `stop`→`cubit.stop()`, `seek`→`repo.seek()`, `skipToNext`→`cubit.skipNext()`, `skipToPrevious`→`cubit.skipPrevious()`.

**Wiring**
- `AudioService.init(builder: () => QuranAudioHandler(player: sl<AudioPlayer>()), config: AudioServiceConfig(androidNotificationChannelId, channelName, androidNotificationOngoing: true, ...))` is called once during `_initAll` in `main.dart` **before `initGetIt()` creates dependents**, and the handler is registered in GetIt.
- `PlaybackCubit` gets the handler injected; on construction it binds itself (`handler.bind(this)` stores the command target), and on each `currentAyah`/playing/paused change it pushes `mediaItem` + lets the handler reflect state. The handler holds a weak command interface (not a hard cubit dependency in the domain sense — the binding is presentation-layer).
- The handler wraps the **same** `AudioPlayer` singleton the repo already plays through, so audio output and OS state come from one source.

**Platform config**
- iOS `Info.plist`: `UIBackgroundModes` → `[audio]`.
- Android `AndroidManifest.xml`: add `com.ryanheise.audioservice.AudioService` (`foregroundServiceType="mediaPlayback"`, exported false) and `com.ryanheise.audioservice.MediaButtonReceiver`; permissions `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` already present (shared with adhan). The launcher activity stays `MainActivity` (audio_service uses the existing activity).

### B2 — Basmala as ayah 0

Replace the glued 2-track basmala with a real, highlighted **ayah 0** step. Ayah 0 exists only for surahs other than 1 (Al-Fatiha — basmala *is* ayah 1) and 9 (At-Tawbah — none).

- **Audio mapping:** ayah 0 of any surah plays the canonical basmala file `(1,1)` (`001001.mp3`). A small resolver maps a playback `AyahIdentifier(surah, 0)` → prepare URL for `(1,1)` while keeping the *identity/highlight* as `(surah, 0)`.
- **Selection / play entry points:**
  - Tapping the basmala header (`(surah,0)`) **plays from ayah 0** (no longer redirected to ayah 1).
  - "Play page" / `playRange` starting at the top of a surah (≠1, ≠9) begins at ayah 0.
- **Sequencing:** `AyaSequenceService` treats ayah 0 → ayah 1 as the first advance; `nextPlaybackStep` needs no special basmala branch. Repeats: ayah 0 participates like any ayah (each-ayah repeat would repeat the basmala — acceptable and consistent; range repeat restarts at ayah 0).
- **Highlight:** the page painter highlights the basmala header when `currentAyah.ayah == 0`. The `isPlayingBasmala` flag and the `playPreparedAudioSequence` glued path are **removed** (the repo keeps single-file playback only; `playPreparedAudioSequence` may be deleted if no longer used).
- **Preload:** `_preloadNextAyahs` skips/maps ayah 0 (its file is the shared basmala, effectively always cached after first play).
- **MediaItem:** ayah 0 shows title "Basmala" / "بسم الله الرحمن الرحيم".

---

## Architecture / component map

| Unit | Responsibility | Action |
|---|---|---|
| `QuranAudioHandler` (new, presentation/playback) | Bridge `AudioPlayer` + `PlaybackCubit` ↔ OS (state out, commands in, metadata) | Create |
| `AudioMetadata` (new, domain value object) OR build `MediaItem` in the handler | Carry id/title/artist/album/art from cubit to handler without leaking the package into domain | Create |
| `main.dart` | `AudioService.init(...)` before `initGetIt`; register handler | Modify |
| `dependency_injection.dart` / `playback_di.dart` | Register handler; inject into `PlaybackCubit` | Modify |
| `PlaybackCubit` | Bind handler; push `MediaItem` on ayah change; (skip/pause/etc. unchanged, now also reachable from OS) | Modify |
| `QuranPlaybackRepoImpl` | Remove `just_audio_background` assumptions; expose position/duration if needed; drop glued sequence | Modify |
| `AyaSequenceService` | ayah 0 → 1 sequencing; ayah-0 audio maps to basmala file | Modify |
| `playback_state.dart` | Remove `isPlayingBasmala` | Modify |
| `mushaf` page painter / tap | Highlight ayah 0; play basmala header from 0 (stop redirecting to 1) | Modify |
| `AndroidManifest.xml`, `ios/Runner/Info.plist` | audio_service service/receiver + iOS background mode | Modify |
| `pubspec.yaml` | `+ audio_service`, `- just_audio_background` | Modify |

## Testing

- **Cubit unit tests** (scoped — never the full suite, per the asset-regeneration caveat):
  - ayah 0 is a real step: `playSelected((2,0))` reports `currentAyah == (2,0)`, prepares the basmala `(1,1)` file, then advances to `(2,1)` on completion. `playSelected((1,1))` and `(9,1)` have no ayah 0. Repeat/range behavior with ayah 0 in the sequence.
  - the handler receives a `MediaItem` (surah/ayah/reciter) on each ayah change; OS `skipToNext`→`cubit.skipNext` etc. (verify with a fake/mocked handler binding).
  - `isPlayingBasmala` removal doesn't break existing pause/resume/stop tests (update the ~120 playback tests that reference it).
- **Handler unit test:** maps player processing states → `AudioProcessingState`; exposes the right `MediaControl` set.
- **Manual gate (document in PR):** play a surah → lock the phone → audio continues; lock screen/Control Center shows reciter + surah:ayah, basmala shows for ayah 0; play/pause, seek, next, previous, stop all work and stay in sync with the in-app player; Android notification persists during playback and clears on stop; iOS Control Center reflects state.

## Risks / caveats

- **audio_service is an architectural addition.** Mitigated by the *bridge/adapter* design: the handler delegates to the untouched engine rather than owning playback, so the repeat/range logic and download pipeline are unchanged.
- **Handler ↔ cubit lifecycle:** the handler is a process-lifetime singleton; the cubit may be recreated. The binding must tolerate rebind and avoid leaks (rebind on cubit construction; null command target when unbound).
- **iOS background reliability** depends on the audio session staying active; audio_service manages the category — verify no other code resets the session.
- **120 existing playback tests** reference `isPlayingBasmala`/glued sequence; B2 will touch many — budget for it.
- **`just_audio_background` removal** must not leave dangling imports/config.
