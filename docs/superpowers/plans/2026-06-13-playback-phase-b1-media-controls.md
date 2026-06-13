# Playback — Phase B1 (Background Audio + OS Media Controls) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ayah recitation play in the background and be controllable from the lock screen / Control Center / notification (play, pause, seek, next, previous, stop) without changing the custom repeat/range playback engine.

**Architecture:** Add `audio_service`; introduce a `QuranAudioHandler extends BaseAudioHandler` that **bridges** the existing `just_audio` `AudioPlayer` (state → OS) and routes OS commands to the existing `PlaybackCubit` via callbacks set at bind time. The cubit publishes a `MediaItem` (reciter · surah:ayah) on each ayah change. The engine, downloads, and repeat logic are untouched. `just_audio_background` (unused) is removed.

**Tech Stack:** Flutter, `just_audio`, **`audio_service`**, `flutter_bloc`, `get_it`, `quran` package, `flutter_test`. FVM-pinned Flutter 3.38.1.

> **Scope:** Phase B1 of Workstream B. Phase B2 (basmala as ayah 0) is a separate plan and also rewrites the playback tests; do B1 first.
> **Test caveat:** never run the full `fvm flutter test` (asset regeneration); scope to `test/features/...`. Never `git add -A`.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `pubspec.yaml` | `+ audio_service`, `- just_audio_background` | Modify |
| `lib/features/quran_playback/presentation/audio/playback_state_mapper.dart` | Pure map `ProcessingState → AudioProcessingState` | Create |
| `lib/features/quran_playback/presentation/audio/quran_audio_handler.dart` | `BaseAudioHandler` bridge (state out, commands in, metadata) | Create |
| `lib/core/di/dependency_injection.dart` | `AudioService.init(...)`; register handler | Modify |
| `lib/features/quran_playback/playback_di.dart` | Inject handler into `PlaybackCubit` | Modify |
| `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` | Bind handler; push `MediaItem` on ayah change | Modify |
| `android/app/src/main/AndroidManifest.xml` | audio_service `<service>` + `<receiver>` | Modify |
| `ios/Runner/Info.plist` | `UIBackgroundModes: [audio]` | Modify |

---

### Task 1: Add `audio_service`, drop `just_audio_background`

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Edit dependencies**

In `pubspec.yaml`, replace the two audio-background lines (59–60):
```yaml
  just_audio: ^0.10.5
  just_audio_background: ^0.0.1-beta.17
```
with:
```yaml
  just_audio: ^0.10.5
  audio_service: ^0.18.15
```

- [ ] **Step 2: Resolve**

Run: `fvm flutter pub get`
Expected: resolves with `audio_service` added. (If `audio_service ^0.18.15` is incompatible with the pinned SDK, use the latest `0.18.x` that resolves — do not downgrade `just_audio`.)

- [ ] **Step 3: Confirm `just_audio_background` is gone**

Run: `grep -rn "just_audio_background\|JustAudioBackground" lib`
Expected: no matches (it was never used in code).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: swap just_audio_background for audio_service

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Pure processing-state mapper

**Files:**
- Create: `lib/features/quran_playback/presentation/audio/playback_state_mapper.dart`
- Test: `test/features/quran_playback/presentation/audio/playback_state_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/playback_state_mapper.dart';

void main() {
  test('maps just_audio ProcessingState to AudioProcessingState', () {
    expect(mapProcessingState(ProcessingState.idle), AudioProcessingState.idle);
    expect(mapProcessingState(ProcessingState.loading), AudioProcessingState.loading);
    expect(mapProcessingState(ProcessingState.buffering), AudioProcessingState.buffering);
    expect(mapProcessingState(ProcessingState.ready), AudioProcessingState.ready);
    expect(mapProcessingState(ProcessingState.completed), AudioProcessingState.completed);
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/quran_playback/presentation/audio/playback_state_mapper_test.dart`
Expected: FAIL — function missing.

- [ ] **Step 3: Implement**

`lib/features/quran_playback/presentation/audio/playback_state_mapper.dart`:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Pure mapping from just_audio's [ProcessingState] to audio_service's
/// [AudioProcessingState] for the OS playback state.
AudioProcessingState mapProcessingState(ProcessingState state) {
  switch (state) {
    case ProcessingState.idle:
      return AudioProcessingState.idle;
    case ProcessingState.loading:
      return AudioProcessingState.loading;
    case ProcessingState.buffering:
      return AudioProcessingState.buffering;
    case ProcessingState.ready:
      return AudioProcessingState.ready;
    case ProcessingState.completed:
      return AudioProcessingState.completed;
  }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/quran_playback/presentation/audio/playback_state_mapper_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/audio/playback_state_mapper.dart test/features/quran_playback/presentation/audio/playback_state_mapper_test.dart
git commit -m "feat(playback): pure processing-state mapper for audio_service

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `QuranAudioHandler` (bridge)

**Files:**
- Create: `lib/features/quran_playback/presentation/audio/quran_audio_handler.dart`
- Test: `test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart`

- [ ] **Step 1: Write the failing test** (command callbacks fire; nowPlaying publishes a MediaItem)

```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/quran_audio_handler.dart';

void main() {
  late AudioPlayer player;
  late QuranAudioHandler handler;

  setUp(() {
    player = AudioPlayer();
    handler = QuranAudioHandler(player: player);
  });

  tearDown(() async => player.dispose());

  test('OS commands route to bound callbacks', () async {
    final calls = <String>[];
    handler.bind(
      onPlay: () async => calls.add('play'),
      onPause: () async => calls.add('pause'),
      onStop: () async => calls.add('stop'),
      onSkipNext: () async => calls.add('next'),
      onSkipPrevious: () async => calls.add('prev'),
      onSeek: (d) async => calls.add('seek:${d.inSeconds}'),
    );
    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();
    await handler.seek(const Duration(seconds: 3));
    await handler.stop();
    expect(calls, ['play', 'pause', 'next', 'prev', 'seek:3', 'stop']);
  });

  test('setNowPlaying publishes a MediaItem', () async {
    handler.setNowPlaying(const MediaItem(
      id: '2:5',
      title: 'Ayah 5',
      album: 'Al-Baqarah',
      artist: 'Al-Husary',
    ));
    expect(handler.mediaItem.value?.id, '2:5');
    expect(handler.mediaItem.value?.album, 'Al-Baqarah');
  });

  test('commands are safe before bind (no throw)', () async {
    await handler.play();
    await handler.skipToNext();
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement the handler**

`lib/features/quran_playback/presentation/audio/quran_audio_handler.dart`:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'playback_state_mapper.dart';

/// Bridges the app's shared just_audio [AudioPlayer] and the [PlaybackCubit]
/// (via callbacks) to the OS media session. It does NOT own the playback
/// engine: state flows out from the player; OS commands route to the bound
/// callbacks (which the cubit supplies). Metadata is pushed via [setNowPlaying].
class QuranAudioHandler extends BaseAudioHandler {
  QuranAudioHandler({required AudioPlayer player}) : _player = player {
    _player.playbackEventStream.listen(_broadcast);
  }

  final AudioPlayer _player;

  Future<void> Function()? _onPlay;
  Future<void> Function()? _onPause;
  Future<void> Function()? _onStop;
  Future<void> Function()? _onSkipNext;
  Future<void> Function()? _onSkipPrevious;
  Future<void> Function(Duration)? _onSeek;

  /// Wires OS controls to the cubit. Safe to call again on cubit recreation.
  void bind({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onStop,
    required Future<void> Function() onSkipNext,
    required Future<void> Function() onSkipPrevious,
    required Future<void> Function(Duration) onSeek,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onStop = onStop;
    _onSkipNext = onSkipNext;
    _onSkipPrevious = onSkipPrevious;
    _onSeek = onSeek;
  }

  void setNowPlaying(MediaItem item) => mediaItem.add(item);

  void _broadcast(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  @override
  Future<void> play() async => _onPlay?.call();

  @override
  Future<void> pause() async => _onPause?.call();

  @override
  Future<void> stop() async => _onStop?.call();

  @override
  Future<void> skipToNext() async => _onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => _onSkipPrevious?.call();

  @override
  Future<void> seek(Duration position) async => _onSeek?.call(position);
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart`
Expected: PASS. (If constructing `AudioPlayer()` in a unit test fails for lack of platform, wrap the two `AudioPlayer`-dependent tests with `TestWidgetsFlutterBinding.ensureInitialized();` at the top of `main()`; the callback-routing test doesn't exercise the player.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/audio/quran_audio_handler.dart test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart
git commit -m "feat(playback): QuranAudioHandler bridges player + cubit to the OS

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Initialize audio_service + register the handler

**Files:**
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Init in `initGetIt` after the player is registered**

In `dependency_injection.dart`, add imports:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/quran_audio_handler.dart';
```
In `initGetIt`, right after `sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());` and before the feature inits, add:
```dart
  final audioHandler = await AudioService.init(
    builder: () => QuranAudioHandler(player: sl<AudioPlayer>()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.quran_app.playback',
      androidNotificationChannelName: 'Quran playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  sl.registerSingleton<QuranAudioHandler>(audioHandler);
```
> `initGetIt` is already `async` and awaited in `main`'s `_initAll`, so the `await` is fine. `AudioService.init` must be called exactly once — `initGetIt` runs once.

- [ ] **Step 2: Analyze**

Run: `fvm flutter analyze lib/core/di/dependency_injection.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/di/dependency_injection.dart
git commit -m "feat(playback): initialize audio_service + register handler

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Bind the handler in `PlaybackCubit` + publish metadata

**Files:**
- Modify: `lib/features/quran_playback/playback_di.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`

- [ ] **Step 1: Inject the handler into the cubit (DI)**

In `playback_di.dart`, add the import:
```dart
import 'presentation/audio/quran_audio_handler.dart';
```
and pass it into the cubit registration:
```dart
  sl.registerLazySingleton<PlaybackCubit>(
    () => PlaybackCubit(
      ayahSequenceService: sl<AyahSequenceService>(),
      repository: sl<QuranPlaybackRepo>(),
      pageService: sl<QuranPageService>(),
      settingsCubit: sl<SettingsCubit>(),
      audioHandler: sl<QuranAudioHandler>(),
    ),
  );
```

- [ ] **Step 2: Wire the cubit to the handler**

In `playback_cubit.dart`:

1. Add imports:
```dart
import 'package:audio_service/audio_service.dart';
import 'package:quran/quran.dart' as quran;
import '../../audio/quran_audio_handler.dart';
```

2. Add the field + constructor param:
```dart
  final QuranAudioHandler audioHandler;
```
Add `required this.audioHandler,` to the constructor parameter list.

3. At the end of the constructor body (after the two stream subscriptions), bind the OS commands:
```dart
    audioHandler.bind(
      onPlay: resume,
      onPause: pause,
      onStop: stop,
      onSkipNext: skipNext,
      onSkipPrevious: skipPrevious,
      onSeek: (d) => repository.seek(d),
    );
```

4. Publish a `MediaItem` whenever the current ayah changes. In the `_ayahSub` listener (the `repository.currentAyahStream.listen` block), after the `emit(...)`, add:
```dart
      _publishNowPlaying(ayah);
```
and add the helper method to the class:
```dart
  void _publishNowPlaying(AyahIdentifier ayah) {
    final surahName = quran.getSurahNameArabic(ayah.surah);
    final title = ayah.ayah == 0
        ? 'بسم الله الرحمن الرحيم'
        : '$surahName • ${ayah.ayah}';
    audioHandler.setNowPlaying(MediaItem(
      id: '${ayah.surah}:${ayah.ayah}',
      title: title,
      album: surahName,
      artist: state.reciter.arabicName,
    ));
  }
```

- [ ] **Step 3: Update the cubit test constructors**

In `test/features/quran_playback/playback_cubit_test.dart` (and any other test that constructs `PlaybackCubit`), the constructor now requires `audioHandler`. Add a mock:
```dart
import 'package:quran_app/features/quran_playback/presentation/audio/quran_audio_handler.dart';
// ...
class _MockAudioHandler extends Mock implements QuranAudioHandler {}
```
In `setUp`, create `final audioHandler = _MockAudioHandler();` and pass `audioHandler: audioHandler` to every `PlaybackCubit(...)`. Stub the void methods used in the constructor/listeners:
```dart
    when(() => audioHandler.bind(
          onPlay: any(named: 'onPlay'),
          onPause: any(named: 'onPause'),
          onStop: any(named: 'onStop'),
          onSkipNext: any(named: 'onSkipNext'),
          onSkipPrevious: any(named: 'onSkipPrevious'),
          onSeek: any(named: 'onSeek'),
        )).thenReturn(null);
    when(() => audioHandler.setNowPlaying(any())).thenReturn(null);
```
Add `registerFallbackValue(const MediaItem(id: 'x', title: 'x'));` in `setUpAll` (import `package:audio_service/audio_service.dart`).

- [ ] **Step 4: Run the playback cubit tests**

Run: `fvm flutter test test/features/quran_playback`
Expected: PASS (existing behavior unchanged; the handler is mocked).

- [ ] **Step 5: Analyze + commit**

Run: `fvm flutter analyze lib/features/quran_playback`
Expected: No issues.

```bash
git add lib/features/quran_playback/playback_di.dart lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart test/features/quran_playback/playback_cubit_test.dart
git commit -m "feat(playback): cubit binds OS controls + publishes now-playing metadata

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Platform config (Android service/receiver + iOS background mode)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Android — add the audio_service service + media-button receiver**

In `AndroidManifest.xml`, inside `<application>` (next to the existing services), add:
```xml
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
```
The `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions are already declared (shared with the adhan service) — no permission change.

- [ ] **Step 2: iOS — declare the audio background mode**

In `ios/Runner/Info.plist`, add inside the top-level `<dict>` (e.g. after the `NSLocation…` keys):
```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>audio</string>
	</array>
```

- [ ] **Step 3: Build both platforms**

Run: `fvm flutter build apk --debug`
Expected: BUILD SUCCESSFUL.
Run (if on macOS with iOS toolchain): `fvm flutter build ios --debug --no-codesign`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(playback): platform config for background audio + media session

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Phase B1 verification

- [ ] **Step 1: Scoped tests + analyze**

Run: `fvm flutter test test/features/quran_playback`
Run: `fvm flutter analyze lib/features/quran_playback lib/core/di/dependency_injection.dart`
Expected: PASS / no issues.

- [ ] **Step 2: Manual gate (document in PR)**

On a real device (both platforms if possible):
1. Start playing a surah → **lock the screen** → audio keeps playing.
2. Lock screen / Control Center (iOS) and notification (Android) show **reciter + surah:ayah** and update as ayahs advance.
3. **Play/pause**, **seek**, **next**, **previous**, **stop** on the OS controls all work and stay in sync with the in-app mini-player.
4. Stop clears the notification; backgrounding mid-playback doesn't kill audio.

- [ ] **Step 3: Finalize**

Proceed to Phase B2 (basmala as ayah 0), or `superpowers:finishing-a-development-branch` if stopping.

---

## Self-review notes (author)

- **Spec coverage (B1 slice):** background playback + OS controls (play/pause/seek/next/prev/stop) → Tasks 3,5,6; metadata → Task 5; `audio_service` over `just_audio_background` → Task 1; init wiring → Task 4. (Basmala/ayah-0 metadata title is pre-wired in `_publishNowPlaying` but the ayah-0 *step* is Phase B2.)
- **Placeholder scan:** none. The "if `AudioPlayer()` needs bindings" (Task 3 Step 4) and "if `^0.18.15` doesn't resolve" (Task 1 Step 2) notes are real environment fallbacks with exact instructions.
- **Type consistency:** `QuranAudioHandler.bind({onPlay,onPause,onStop,onSkipNext,onSkipPrevious,onSeek})` and `setNowPlaying(MediaItem)` are identical across the handler, the cubit (Task 5), and the tests (Tasks 3,5). `mapProcessingState` signature consistent.
- **Engine untouched:** OS commands delegate to existing `resume`/`pause`/`stop`/`skipNext`/`skipPrevious`/`repository.seek`; `nextPlaybackStep` and downloads unchanged.
- **Test caveat honored:** scoped to `test/features/quran_playback`.
