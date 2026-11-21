# Mushaf S2 (listening: media notification, audio focus, background audio, surah download) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a recitation outlive the reader with a media notification and lock-screen controls, pause it for calls and the adhan, and let the reader download a whole surah for the current reciter from the surah index, with a one-time hint that says how.

**Architecture:** `audio_service` hosts a `QuranAudioHandler` that mirrors the shared `just_audio` player out to the OS and sends OS commands to the app-wide `PlaybackCubit`; it publishes one `MediaItem` per ayah from the cubit's state. `audio_session` (speech) feeds a `PlaybackAudioFocus` that pauses the cubit on interruptions and on becoming noisy, and never resumes. Surah downloads are a stream on `QuranPlaybackRepo` that runs on the existing 2-slot queue behind playback preloads, driven by an app-wide `SurahDownloadCubit` and drawn by a `SurahDownloadButton` on `SurahListTile`. Today's reader widgets stay; S3 builds the new shell.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), `just_audio` 0.10.6, `audio_service` 0.18.19, `audio_session` 0.2.4, flutter_bloc + bloc_test, mocktail, dartz, equatable, hive_ce, GoRouter 18, the vendored `quran` package.

**Spec:** `docs/superpowers/specs/2026-11-21-mushaf-leaf-ribbon-design.md` (§4 in full, D5, D6, D8, §1A notification row, §7 S2 rows). `docs/superpowers/plans/2026-06-13-playback-phase-b1-media-controls.md` is used for the handler shape only, with the §4 deltas. Where the spec and this plan disagree, the spec wins, except for the **Deliberate readings** below, where the plan governs. Raise any other disagreement in the task report.

## Global Constraints

- Work on `feature/mushaf-s2-audio`. Never switch branches, never touch `main`, never push, never rebase, never amend.
- Never stage, edit or revert `test/core/arabic_normalizer_test.dart`, `test/core/utils/calculation_method_for_country_test.dart` or `test/core/widgets/last_quran_read_test.dart` (stray format changes that are not this slice's).
- Commits: stage explicit paths only (never `git add -A` or `git add .`). Conventional message (`feat|fix|refactor|test|build(scope): …`) ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No comments and no doc comments in new or changed code (Dart, Kotlin, XML). No redundant type annotations. Lean code. Comments the user wrote stay unless they sit inside lines a task replaces.
- New strings: add each to both `lib/l10n/intl_ar.arb` and `lib/l10n/intl_en.arb` (with a `"@key": {"placeholders": {…: {"type": "String"}}}` block per placeholder) and mirror it in `lib/core/localization/pending_s.dart` as `String get key => _ar ? '…' : '…';` or `String key(String a) => _ar ? '… $a' : '… $a';` (single quotes, `String` parameters only, signature on one line after `dart format`, numbers preformatted). Read with `PendingS.of(context)` in `build`, `PendingS.current` in callbacks, `PendingS.forLanguage(code)` where there is no context. `test/core/localization/pending_s_test.dart` stays green. Never edit `lib/generated/`; never run `intl_utils:generate`.
- Arabic numbers use Arabic-Indic digits via `toLocalized(context)` / `toIndicNumerals(localeCode)`.
- Colours only from `context.colorScheme`; text styles only `TS.*`; `test/config/theme/typography_ratchet_test.dart` must not rise. Playback and surah-list widgets keep Material `Icons.*` (`icons.md`: match the surrounding set).
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`; never modify `assets/mushaf/**`.
- Every task ends at baseline or better: `flutter analyze --no-fatal-infos` = 0 errors, 0 warnings, ≤ 69 infos; `flutter test` = 1063 + the tests this plan adds pass, 1 skipped. `dart format` touched Dart files.
- Rule catalogues (`architecture.md`, `feature-widgets.md`) change in the task that changes what they describe.

## Deliberate readings (the plan governs here)

1. **just_audio's own interruption handling is switched off.** `AudioPlayer(handleInterruptions: false)` in `core/di/dependency_injection.dart`: left on, just_audio pauses the player behind `PlaybackCubit`'s back and auto-resumes after a transient interruption, which §4 forbids. `PlaybackAudioFocus` takes over, and every interruption *begin* (pause, duck, unknown) pauses: speech is not ducked.
2. **The adhan asks for transient audio focus.** `AdhanPlaybackService` plays through a bare `MediaPlayer` without focus today, so `audio_session` would never see it. Task 1 adds an `AUDIOFOCUS_GAIN_TRANSIENT` request before `start()` and abandons it when the clip ends or stops.
3. **Cancel is cancelling the subscription.** `downloadSurah` returns a stream whose `onCancel` drops that batch's queued ayat; there is no separate repository cancel method.
4. **`SurahDownloadCubit` calls the repository directly**, as `PlaybackCubit` does in the same feature; no use cases are added.
5. **The notification tap does nothing while a reader is already on top** (`mushafPath` or `mushafImagePath`): that reader already follows playback, and pushing a second reader would stack two.
6. **`initPlayback` becomes `Future<void>` and is awaited** in `initGetIt`. Today it is `void … async`, so its registrations land after `initGetIt` returns; the handler and audio session need it awaited.
7. **The download hint SnackBar carries an action «تنزيل السورة»** that downloads the playing surah. §4 gives only the text; the owner asked that users know *how* to download.
8. **Deleting a surah keeps 1:1** unless the surah is 1: the basmala file is shared by every surah's download.
9. **`SurahDownloadButton` lives in `quran_playback/presentation/widgets/`** (it reads `SurahDownloadCubit` and `PlaybackCubit`) and is listed in `feature-widgets.md` as the export `quran_playback` makes to `surah`.
10. **`AudioService.init` failure does not block start-up.** It is caught and logged; playback then works without a notification.

## Review Focus

1. **Start-up when the media service cannot start** (an OEM that refuses the foreground service, an old activity): the app must still reach home and play in-app. Task 4 tests `connectMediaSession` with an `init` that throws.
2. **Tapping the notification while the reader is already open** must not stack a second reader; tapping it from home must open the playing page with the player, not an ayah leaf, and without overwriting last read. Task 4 tests both routes and `MushafState.initial(MushafArgs.nowPlaying(…))`.
3. **Starting a recitation while a surah download runs**: the next ayah's preload must not wait behind 280 queued download ayat. Task 5 tests that a preload jumps the queued batch.
4. **Changing reciter during a download**: the running download stays tied to the reciter it started with, and the button for the new reciter shows that reciter's own status. Task 6 tests status isolation by `Reciter.downloadKey`.
5. **Retry after a partial failure or a cancel** must download only the missing ayat and keep finished files. Task 5 tests cancel-then-resume and a failure with kept files.

## Out of slice

- S3: the player leaf download chip, the «القائمة» surah row button, the download hint as a notice chip, `hintSeen`, the listening-away state, and the inline audio error. S5: `tapAction`. S3: `keepScreenOn`.
- `just_audio_background` is not in `pubspec.yaml`; nothing is removed.
- The audio cache stays in the documents directory (§8).

---

### Task 1: Packages and platform configuration

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock` (via `flutter pub add`)
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/MainActivity.kt`
- Modify: `android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt`
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Produces: `audio_service` and `audio_session` importable by later tasks; `MainActivity` is an `AudioServiceActivity`.

- [ ] **Step 1: Add the packages**

Run: `flutter pub add audio_service audio_session`
Expected: `audio_service: ^0.18.19` and `audio_session: ^0.2.4` (promoted from transitive) in `pubspec.yaml`; resolves with no downgrade of `just_audio`.

- [ ] **Step 2: Android manifest**

Permissions block (top of the manifest): `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` are already there (checked). `WAKE_LOCK` is **missing**: add `<uses-permission android:name="android.permission.WAKE_LOCK" />`.

Inside `<application>`, after the `.AdhanPlaybackService` service, add the `com.ryanheise.audioservice.AudioService` service (`android:foregroundServiceType="mediaPlayback"`, `android:exported="true"`, intent-filter action `android.media.browse.MediaBrowserService`) and the `com.ryanheise.audioservice.MediaButtonReceiver` receiver (`android:exported="true"`, intent-filter action `android.intent.action.MEDIA_BUTTON`), as in B1 Task 6 Step 1. The activity keeps `launchMode="singleTop"`.

- [ ] **Step 3: MainActivity**

`class MainActivity : AudioServiceActivity()` (import `com.ryanheise.audioservice.AudioServiceActivity`, drop the `FlutterActivity` import). Keep `configureFlutterEngine` exactly as it is: `super.configureFlutterEngine(flutterEngine)` then `flutterEngine.plugins.add(PrayerStripPlugin())`.

- [ ] **Step 4: Adhan transient focus (Deliberate reading 2)**

In `AdhanPlaybackService`: a `private var focusRequest: AudioFocusRequest? = null`; `private fun requestFocus(attrs: AudioAttributes)` that on API ≥ 26 builds `AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).setAudioAttributes(attrs).build()`, stores it and calls `requestAudioFocus(it)`, and below 26 calls the deprecated `requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)`; `private fun abandonFocus()` that mirrors it (`abandonAudioFocusRequest` / `abandonAudioFocus(null)`) and nulls the field. Call `requestFocus(attrs)` in `startMediaPlayer` right before `start()`; call `abandonFocus()` in the completion listener, in `handleStop`, and in `onDestroy`. Playback still starts if the request is refused.

- [ ] **Step 5: iOS background mode**

In `ios/Runner/Info.plist`, top-level `<dict>`: `<key>UIBackgroundModes</key><array><string>audio</string></array>` (the key does not exist today).

- [ ] **Step 6: Build and baseline**

Run: `flutter build apk --debug`
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.
Run (when Xcode is present): `flutter build ios --debug --no-codesign`
Expected: build succeeds.
Run: `flutter analyze --no-fatal-infos` and `flutter test`
Expected: baseline (0/0/69; 1063 pass, 1 skipped).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/example/quran_app/MainActivity.kt android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt ios/Runner/Info.plist
git commit -m "build(playback): audio_service + audio_session platform setup

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: QuranAudioHandler (state out, commands in, now-playing item)

**Files:**
- Create: `lib/features/quran_playback/presentation/audio/playback_state_mapper.dart`
- Create: `lib/features/quran_playback/presentation/audio/now_playing_item.dart`
- Create: `lib/features/quran_playback/presentation/audio/quran_audio_handler.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` (add `seek`)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/features/quran_playback/presentation/audio/playback_state_mapper_test.dart`, `test/features/quran_playback/presentation/audio/now_playing_item_test.dart`, `test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart`, `test/features/quran_playback/playback_cubit_test.dart`

**Interfaces:**
- Produces:
  - `AudioProcessingState mapProcessingState(ProcessingState state)`
  - `MediaItem? nowPlayingItem(PlaybackState state, {required String langCode, Uri? artUri})`: `null` when `state.skipOrigin` is null; else `id: '${reciter.name}:${surah}:${ayah}'`, `title: PendingS.forLanguage(langCode).playback_mediaTitle(surahName, ayahDigits)` (surah name `quran.getSurahNameArabic` for `ar`, `quran.getSurahName` otherwise; ayah via `toIndicNumerals(langCode)`), `artist: reciter.arabicName`, `album: playback_mediaAlbum`, `artUri`.
  - `class QuranAudioHandler extends BaseAudioHandler` with `QuranAudioHandler({required AudioPlayer player, required String Function() langCode, Uri? artUri})` and `void attach(PlaybackCubit cubit)`.
  - `Future<void> PlaybackCubit.seek(Duration position)` → `repository.seek(position)`.
  - Strings: `playback_mediaTitle(String surah, String ayah)` ar `'$surah، الآية $ayah'` / en `'$surah, ayah $ayah'`; `playback_mediaAlbum` ar `'القرآن الكريم'` / en `'The Holy Quran'`.

Handler behaviour (B1 Task 3 shape, with these deltas): the constructor listens to `player.playbackEventStream` and broadcasts `playbackState` with controls `[skipToPrevious, playing ? pause : play, skipToNext, stop]`, `systemActions: {MediaAction.seek}`, `androidCompactActionIndices: [0, 1, 2]`, `processingState: mapProcessingState(player.processingState)`, `playing`, `updatePosition`, `bufferedPosition`, `speed`, `queueIndex`. It also listens to `player.durationStream` and re-adds `mediaItem.value?.copyWith(duration: d)`. `attach(cubit)` replaces any earlier subscription, listens to `cubit.stream` (and handles `cubit.state` once) and adds `nowPlayingItem(state, langCode: langCode(), artUri: artUri)` when its `id` differs from the current item's. Commands go to the attached cubit: `play` → `resume`, `pause` → `pause`, `stop` → `stop`, `skipToNext` → `skipNext`, `skipToPrevious` → `skipPrevious`, `seek` → `seek`; before `attach` they do nothing.

- [ ] **Step 1: Write the failing tests**

`playback_state_mapper_test.dart`: B1 Task 2's test (five `ProcessingState` → `AudioProcessingState` expectations).

`now_playing_item_test.dart`:
```dart
test('Arabic item names the surah, ayah, reciter and album', () {
  final art = Uri.parse('android.resource://com.example.quran_app/mipmap/ic_launcher');
  final item = nowPlayingItem(
    const PlaybackState(requestedAyah: AyahIdentifier(surah: 3, ayah: 4), reciter: Reciter.husary),
    langCode: 'ar',
    artUri: art,
  )!;
  expect(item.id, 'husary:3:4');
  expect(item.title, 'آل عمران، الآية ٤');
  expect(item.artist, 'محمود خليل الحصري');
  expect(item.album, 'القرآن الكريم');
  expect(item.artUri, art);
});

test('English item uses the English surah name and Latin digits', () {
  final item = nowPlayingItem(
    const PlaybackState(currentAyah: AyahIdentifier(surah: 3, ayah: 4)),
    langCode: 'en',
  )!;
  expect(item.title, '${quran.getSurahName(3)}, ayah 4');
  expect(item.album, 'The Holy Quran');
  expect(item.artUri, isNull);
});

test('requestedAyah wins over currentAyah; idle gives null', () {
  expect(
    nowPlayingItem(
      const PlaybackState(currentAyah: AyahIdentifier(surah: 3, ayah: 4), requestedAyah: AyahIdentifier(surah: 3, ayah: 5)),
      langCode: 'ar',
    )!.id,
    'alafasy:3:5',
  );
  expect(nowPlayingItem(const PlaybackState(), langCode: 'ar'), isNull);
});
```

`quran_audio_handler_test.dart`: a mocktail `_MockPlayer implements AudioPlayer` with `playbackEventStream` / `durationStream` from `StreamController`s and `playing` true, `processingState` ready, `position` / `bufferedPosition` zero, `speed` 1.0; a `_FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit` that records `resume`, `pause`, `stop`, `skipNext`, `skipPrevious`, `seek:<seconds>` and exposes `push(PlaybackState)`. Tests:
- `OS commands route to the attached cubit`: `play, pause, skipToNext, skipToPrevious, seek(3 s), stop` → `['resume', 'pause', 'next', 'prev', 'seek:3', 'stop']`.
- `commands before attach do nothing`: `play()` and `skipToNext()` complete without throwing.
- `a new ayah publishes its MediaItem`: `attach`, `push(PlaybackState(requestedAyah: 2:5, reciter: husary))`, `await pumpEventQueue()` → `handler.mediaItem.value!.id == 'husary:2:5'`; pushing the same ayah with `isPlaying` changed adds no new item (count `mediaItem` events).
- `a player event broadcasts the four controls`: add `PlaybackEvent()` → `playbackState.value.controls == [MediaControl.skipToPrevious, MediaControl.pause, MediaControl.skipToNext, MediaControl.stop]`, `playing` true, `processingState == AudioProcessingState.ready`, `androidCompactActionIndices == [0, 1, 2]`.
- `duration reaches the current MediaItem`: after an item is published, `durations.add(Duration(seconds: 9))` → `mediaItem.value!.duration == Duration(seconds: 9)`.

`playback_cubit_test.dart`: `seek forwards to the repository` → `verify(() => repo.seek(const Duration(seconds: 4))).called(1)` after `stub repo.seek`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/quran_playback/presentation/audio test/features/quran_playback/playback_cubit_test.dart`
Expected: FAIL (files and `seek` missing).

- [ ] **Step 3: Implement** the three files, `PlaybackCubit.seek`, and the two strings in both ARBs and `PendingS`.

- [ ] **Step 4: Run them to see them pass**

Run: `flutter test test/features/quran_playback test/core/localization/pending_s_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/audio/playback_state_mapper.dart lib/features/quran_playback/presentation/audio/now_playing_item.dart lib/features/quran_playback/presentation/audio/quran_audio_handler.dart lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/quran_playback/presentation/audio test/features/quran_playback/playback_cubit_test.dart
git commit -m "feat(playback): QuranAudioHandler bridges the player and PlaybackCubit to the OS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Audio session and focus rules

**Files:**
- Create: `lib/features/quran_playback/presentation/audio/playback_audio_focus.dart`
- Modify: `lib/core/di/dependency_injection.dart` (`AudioPlayer(handleInterruptions: false)`, `await initPlayback()`)
- Modify: `lib/features/quran_playback/playback_di.dart` (`Future<void> initPlayback() async`, session wiring at the end)
- Test: `test/features/quran_playback/presentation/audio/playback_audio_focus_test.dart`

**Interfaces:**
- Produces: `class PlaybackAudioFocus { PlaybackAudioFocus({required Stream<AudioInterruptionEvent> interruptions, required Stream<void> becomingNoisy, required PlaybackCubit cubit}); Future<void> dispose(); }`. Rule: an interruption with `begin: true` of any type, or a becoming-noisy event, calls `cubit.pause()` when `cubit.state.isPlaying`; an interruption with `begin: false` does nothing.
- Produces: `Future<void> initPlayback()` (awaited by `initGetIt`; Deliberate reading 6).

- [ ] **Step 1: Write the failing tests** (fake `PlaybackCubit` as in Task 2 that counts `pause` and `resume`; `StreamController<AudioInterruptionEvent>` and `StreamController<void>`; `await pumpEventQueue()` after each add)

```dart
test('a call (pause interruption) pauses a playing recitation', …pause == 1);
test('a duck interruption pauses too: speech is not ducked', …AudioInterruptionType.duck → pause == 1);
test('an unknown interruption pauses', …AudioInterruptionType.unknown → pause == 1);
test('the interruption ending never resumes', …begin pause then AudioInterruptionEvent(false, AudioInterruptionType.pause) → pause == 1, resume == 0);
test('unplugging headphones pauses', …noisy.add(null) → pause == 1);
test('nothing happens while already paused', …state isPlaying false, begin + noisy → pause == 0);
test('dispose stops listening', …dispose then begin → pause == 0);
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/quran_playback/presentation/audio/playback_audio_focus_test.dart`
Expected: FAIL (class missing).

- [ ] **Step 3: Implement**

`PlaybackAudioFocus` per the interface. In `dependency_injection.dart`, `sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer(handleInterruptions: false))` and `await initPlayback();` (Deliberate reading 1, 6). At the end of `initPlayback`: `final session = await AudioSession.instance; await session.configure(const AudioSessionConfiguration.speech());` then `sl.registerSingleton(PlaybackAudioFocus(interruptions: session.interruptionEventStream, becomingNoisy: session.becomingNoisyEventStream, cubit: sl<PlaybackCubit>()))`.

- [ ] **Step 4: Run to see it pass, then the feature and DI tests**

Run: `flutter test test/features/quran_playback test/features/qibla/qibla_di_test.dart test/features/notifications/notifications_di_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/audio/playback_audio_focus.dart lib/core/di/dependency_injection.dart lib/features/quran_playback/playback_di.dart test/features/quran_playback/presentation/audio/playback_audio_focus_test.dart
git commit -m "feat(playback): pause recitation on interruptions and becoming noisy, never auto-resume

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Media service start-up, notification tap, audio outlives the reader

**Files:**
- Modify: `lib/features/quran_playback/presentation/audio/quran_audio_handler.dart` (add `connectMediaSession`)
- Modify: `lib/features/quran_playback/playback_di.dart` (call it)
- Modify: `lib/features/surah/presentation/utils/mushaf_args.dart` (add `MushafArgs.nowPlaying`)
- Create: `lib/config/router/now_playing_route.dart`
- Modify: `lib/main.dart` (`_QuranAppState` listens to `AudioService.notificationClicked`)
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart:165` (delete `_playbackCubit.stop();`)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart`, `test/features/surah/presentation/utils/mushaf_args_test.dart`, `test/config/router/now_playing_route_test.dart` (Create), `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`

**Interfaces:**
- Consumes: `QuranAudioHandler`, `attach` (Task 2).
- Produces:
  - `Future<QuranAudioHandler?> connectMediaSession({required Future<QuranAudioHandler> Function() init, required PlaybackCubit cubit})`: awaits `init()`, calls `attach(cubit)`, returns the handler; on any throw, `debugPrint`s and returns `null` (Deliberate reading 10).
  - `factory MushafArgs.nowPlaying(AyahIdentifier ayah)`: `page: quran.getPageNumber(ayah.surah, ayah.realAyah)`, `openedSurah: ayah.surah`, `origin: MushafOrigin.jump`, no `focusAyah`.
  - `void openNowPlaying(GoRouter router, AyahIdentifier? playing)`: returns when `playing` is null or `router.state.matchedLocation` is `AppRouter.mushafPath` or `AppRouter.mushafImagePath`; else `router.push(AppRouter.mushafPath, extra: MushafArgs.nowPlaying(playing))`.
  - String `playback_channelName` ar `'تلاوة القرآن'` / en `'Quran recitation'`.

- [ ] **Step 1: Write the failing tests**

`quran_audio_handler_test.dart`:
```dart
test('connectMediaSession attaches the cubit to the started handler', …returns the handler; a pushed ayah reaches handler.mediaItem);
test('connectMediaSession survives a service that will not start', () async {
  final handler = await connectMediaSession(init: () async => throw Exception('no service'), cubit: _FakePlayback());
  expect(handler, isNull);
});
```

`mushaf_args_test.dart`:
```dart
test('nowPlaying on 3:4 opens page 50 as a jump with the player, not a leaf', () {
  final args = MushafArgs.nowPlaying(const AyahIdentifier(surah: 3, ayah: 4));
  expect(args.page, 50);
  expect(args.openedSurah, 3);
  expect(args.origin, MushafOrigin.jump);
  expect(args.focusAyah, isNull);
  final initial = MushafState.initial(args);
  expect(initial.selectedAyah, isNull);
  expect(initial.followPlayback, isTrue);
});
```

`now_playing_route_test.dart` (a `GoRouter` with `GoRoute(path: '/')` and `GoRoute(path: AppRouter.mushafPath)` whose builder records `state.extra` and counts builds, pumped in `MaterialApp.router`):
- `from home it opens the playing page`: `openNowPlaying(router, 3:4)`, `pumpAndSettle` → extra is `MushafArgs` with page 50, origin jump, `focusAyah` null.
- `on the reader it does not stack a second one`: push mushaf first, then `openNowPlaying` → `router.routerDelegate.currentConfiguration.matches.length` unchanged.
- `with nothing playing it stays put`: `openNowPlaying(router, null)` → `router.state.matchedLocation == '/'`.

`mushaf_page_dispose_test.dart` (deliberate rewrite of tests that pin the old stop-on-leave):
- Rename `'on dispose: saves (page, selected) then stops playback'` to `'on dispose: saves (page, selected) and the recitation keeps playing'`; pass `playbackState: const PlaybackState(currentAyah: AyahIdentifier(surah: 2, ayah: 5), isPlaying: true)`; replace `expect(playback.stopCalls, 1)` with `expect(playback.stopCalls, 0)` and `expect(playback.state.currentAyah, const AyahIdentifier(surah: 2, ayah: 5))`.
- In `'jump arrival: dispose does not overwrite last read'`, `expect(playback.stopCalls, 0)`.

- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart test/features/surah/presentation/utils/mushaf_args_test.dart test/config/router/now_playing_route_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`
Expected: FAIL (missing symbols; dispose tests see one stop call).

- [ ] **Step 3: Implement**

- `connectMediaSession`, `MushafArgs.nowPlaying`, `openNowPlaying`, the channel string.
- `initPlayback`, after the `PlaybackAudioFocus` registration: `await connectMediaSession(init: () => AudioService.init(builder: () => QuranAudioHandler(player: sl<AudioPlayer>(), langCode: () => sl<SettingsCubit>().state.settingsModel.isArabic ? 'ar' : 'en', artUri: Platform.isAndroid ? Uri.parse('android.resource://com.example.quran_app/mipmap/ic_launcher') : null), config: AudioServiceConfig(androidNotificationChannelId: 'com.example.quran_app.playback', androidNotificationChannelName: PendingS.forLanguage(sl<SettingsCubit>().state.settingsModel.isArabic ? 'ar' : 'en').playback_channelName, androidNotificationOngoing: true, androidStopForegroundOnPause: true)), cubit: sl<PlaybackCubit>());`
- `main.dart` `_QuranAppState`: a `StreamSubscription<bool>?` set in `initState` to `AudioService.notificationClicked.where((c) => c).listen((_) => openNowPlaying(_router, sl<PlaybackCubit>().state.skipOrigin))`, cancelled in a new `dispose`.
- `mushaf_page.dart`: delete `_playbackCubit.stop();` from `dispose` (D5). The field stays (used by `readCurrent` and `_onPlayPage`).

- [ ] **Step 4: Run to see them pass, then the router suite**

Run: `flutter test test/features/quran_playback test/features/surah test/config test/core/localization/pending_s_test.dart`
Expected: PASS (`app_router_test` unchanged: no new `GoRoute`).

- [ ] **Step 5: Device check (emulator-5554)**

`flutter run -d emulator-5554`; play a surah from the index, press Home: audio continues; the notification shows «البقرة، الآية …», the reciter and ⏮ ⏯ ⏭ ⏹; each works; tapping the notification opens the reader on the playing page with the player; ⏹ removes the notification. `adb -s emulator-5554 shell dumpsys media_session` lists the app's session. Note results in the task report.

- [ ] **Step 6: Commit**

```bash
git add lib/features/quran_playback/presentation/audio/quran_audio_handler.dart lib/features/quran_playback/playback_di.dart lib/features/surah/presentation/utils/mushaf_args.dart lib/config/router/now_playing_route.dart lib/main.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/quran_playback/presentation/audio/quran_audio_handler_test.dart test/features/surah/presentation/utils/mushaf_args_test.dart test/config/router/now_playing_route_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
git commit -m "feat(playback): media notification opens the playing page; audio outlives the reader

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Repository: surah download on the shared queue

**Files:**
- Modify: `lib/features/quran_playback/domain/entities/reciter.dart` (add `downloadKey`)
- Modify: `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart`
- Modify: `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`
- Modify: `lib/features/quran_playback/data/datasources/local/quran_playback_local_data_source.dart`
- Modify: `lib/features/quran_playback/playback_di.dart` (pass `downloadsBox: Hive.box<bool>('surahDownloads')`)
- Modify: `lib/config/hive_config.dart` (`await Hive.openBox<bool>('surahDownloads');` with `Hive.openBox`, next to `ayahAudioCache`)
- Test: `test/features/quran_playback/data/repositories/quran_playback_repo_impl_test.dart`

**Interfaces:**
- Produces (domain):
  - `String Reciter.downloadKey(int surah)` → `'$name:$surah'` (e.g. `'alafasy:112'`).
  - `Stream<Either<Failure, double>> downloadSurah({required int surah, required Reciter reciter})`
  - `bool isSurahDownloaded({required int surah, required Reciter reciter})`
  - `Future<Either<Failure, void>> deleteSurahDownload({required int surah, required Reciter reciter})`
  - `bool isAyahCached({required AyahIdentifier ayah, required Reciter reciter})`: cached path present and the file exists.
- Produces (data): `QuranPlaybackLocalDataSource({required Box<String> audioBox, required Box<bool> downloadsBox})` with `Future<void> removeCachedPath(String url)`, `bool isSurahDownloaded(String key)`, `Future<void> markSurahDownloaded(String key)`, `Future<void> clearSurahDownloaded(String key)`.

Behaviour:
- The ayat of a download are `1..quran.getVerseCount(surah)`, plus `1:1` first when `surah ∉ {1, 9}`. `total` is their count; cached ayat count as done.
- On listen: if nothing is missing, `markSurahDownloaded`, emit `Right(1.0)`, close. Else enqueue one task per missing ayah, tagged with `reciter.downloadKey(surah)`, that runs `prepareAyahAudio`. After each success emit `Right(done / total)`; mark the record before the success that reaches `total`. When every task has settled with at least one failure, emit `Left(firstFailure)` and close, with no record; finished files stay.
- `onCancel` removes that batch's queued tasks; in-flight ones finish and keep their files.
- The queue becomes two: preload tasks (from `preloadAyahs`) and batch tasks (`({String batch, Future<void> Function() run})`). `_runNextDownload` takes a preload task first, keeping the 2-slot limit. Direct `prepareAyahAudio` calls from playback stay outside the queue, as today.
- `deleteSurahDownload` deletes each ayah's file (the download's ayat minus `1:1` when `surah != 1`; Deliberate reading 8), calls `removeCachedPath(url)` for each, then `clearSurahDownloaded(key)`; exceptions map to `Failure` per `architecture.md`.

- [ ] **Step 1: Write the failing tests** (extend the existing file: stub `local.markSurahDownloaded`, `removeCachedPath`, `clearSurahDownloaded` to `async {}` and `local.isSurahDownloaded` to `false` in `setUp`; `remote.downloadAudio` answers with its `savePath` argument unless a test says otherwise)

```dart
test('downloadSurah 112 fetches the basmala and four ayat, then marks it', …
  emissions all Right, last == 1.0, monotonic; remote called 5 times incl. Reciter.alafasy.getAyahUrl(1, 1);
  verify(() => local.markSurahDownloaded('alafasy:112')).called(1));
test('surahs 1 and 9 fetch no extra basmala', …surah 9: verifyNever downloadAudio(getAyahUrl(1, 1), any()); surah 1: 7 calls);
test('cached ayat are skipped and count as done', …112:1 and 1:1 cached with files on disk → 3 remote calls, last Right(1.0));
test('everything cached marks at once', …emits [Right(1.0)] and marks);
test('a failed ayah ends with Left, no record, finished files kept', …112:3 throws DioException → last event isLeft; verifyNever markSurahDownloaded; 112:1 file exists);
test('cancel drops queued ayat and keeps finished files; a new download resumes', …
  remote answers from per-url completers; listen, complete 1:1, cancel subscription, complete the in-flight one →
  exactly 3 downloadAudio calls; then downloadSurah again downloads only the 2 still missing);
test('a preload goes ahead of a queued surah download', …
  both slots blocked by batch completers; preloadAyahs([2:255]); complete one slot →
  the next downloadAudio url is getAyahUrl(2, 255));
test('deleteSurahDownload removes files, cache entries and the record but keeps 1:1', …
  Right; 112:1..4 files gone, 1:1 file still there; removeCachedPath ×4; clearSurahDownloaded('alafasy:112'));
test('isSurahDownloaded reads the record', …local.isSurahDownloaded('husary:2') true → repo true for (2, husary));
test('isAyahCached needs both the cache entry and the file', …entry without file → false; with file → true);
```
Also `test/features/quran_playback/domain/entities/` gains no file: `downloadKey` is pinned by the first test's `'alafasy:112'`.

- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/quran_playback/data/repositories/quran_playback_repo_impl_test.dart`
Expected: FAIL (methods missing).

- [ ] **Step 3: Implement** per Behaviour. The existing two tests (failed download not reused, shared in-flight download) must still pass unchanged.

- [ ] **Step 4: Run to see them pass**

Run: `flutter test test/features/quran_playback`
Expected: PASS. (`_MockRepo` in `playback_cubit_test.dart` needs no change: unstubbed new methods are not called.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/domain/entities/reciter.dart lib/features/quran_playback/domain/repositories/quran_playback_repo.dart lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart lib/features/quran_playback/data/datasources/local/quran_playback_local_data_source.dart lib/features/quran_playback/playback_di.dart lib/config/hive_config.dart test/features/quran_playback/data/repositories/quran_playback_repo_impl_test.dart
git commit -m "feat(playback): download a whole surah on the shared queue behind preloads

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: SurahDownloadCubit (app-wide)

**Files:**
- Create: `lib/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart`
- Create: `lib/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart`
- Modify: `lib/features/quran_playback/playback_di.dart` (`sl.registerLazySingleton(() => SurahDownloadCubit(repository: sl()))`)
- Modify: `lib/main.dart` (`BlocProvider(create: (_) => sl<SurahDownloadCubit>())` in the `MultiBlocProvider`)
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` (delete `preloadFullSurah` and its now-unused `SurahEntity` import; `Reciter` stays, `setReciter` uses it)
- Modify: `.claude/rules/architecture.md` (app-wide cubit list gains `SurahDownloadCubit`)
- Test: `test/features/quran_playback/presentation/cubit/surah_download_cubit_test.dart`

**Interfaces:**
- Consumes: Task 5 repository methods and `Reciter.downloadKey`.
- Produces:
  - `sealed class SurahDownloadStatus extends Equatable` with `final class SurahNotDownloaded`, `SurahDownloading(double progress)`, `SurahDownloaded`, `SurahDownloadFailed`, all `const`.
  - `class SurahDownloadState extends Equatable { const SurahDownloadState({this.statuses = const {}}); final Map<String, SurahDownloadStatus> statuses; }`
  - `SurahDownloadCubit({required QuranPlaybackRepo repository})` with `SurahDownloadStatus statusOf(Reciter reciter, int surah)` (map entry, else `SurahDownloaded` when `repository.isSurahDownloaded`, else `SurahNotDownloaded`), `void download(Reciter reciter, int surah)` (no-op while that key is downloading; emits `SurahDownloading(0)`, then one `SurahDownloading(p)` per `Right(p)`, `SurahDownloadFailed` on `Left`, `SurahDownloaded` on done without a failure), `Future<void> cancel(Reciter reciter, int surah)` (cancels that key's subscription, emits `SurahNotDownloaded`), `Future<void> delete(Reciter reciter, int surah)` (`Right` → `SurahNotDownloaded`; `Left` leaves the status). Subscriptions live in a `Map<String, StreamSubscription>`, all cancelled in `close()`. `isClosed` checks before emits inside listeners.

- [ ] **Step 1: Write the failing tests** (`_MockRepo implements QuranPlaybackRepo`; `downloadSurah` answers from a `StreamController` per test)

```dart
blocTest('download walks downloading → downloaded', …stream Right(.5), Right(1.0), close →
  statuses['husary:2'] goes SurahDownloading(0), SurahDownloading(.5), SurahDownloading(1.0), SurahDownloaded());
blocTest('a Left ends in failed', …Right(.2), Left(UnknownFailure('x')), close → …, SurahDownloadFailed());
test('download while downloading does not start a second stream', …verify downloadSurah called once);
test('cancel stops listening and returns to not downloaded', …controller.hasListener false; statusOf == SurahNotDownloaded());
test('statusOf falls back to the stored record', …repo.isSurahDownloaded(surah: 2, reciter: husary) true → SurahDownloaded(); no map entry);
test('statuses are per reciter', …download(husary, 2) → statusOf(alafasy, 2) == SurahNotDownloaded());
blocTest('delete returns to not downloaded', …Right(null) → SurahNotDownloaded(); verify deleteSurahDownload(surah: 2, reciter: husary));
test('close cancels live downloads', …close → controller.hasListener false);
test('retry after failure downloads again', …failed then download → downloadSurah called twice);
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/features/quran_playback/presentation/cubit/surah_download_cubit_test.dart`
Expected: FAIL (cubit missing).

- [ ] **Step 3: Implement** the state, the cubit, the DI and `main.dart` registration, delete `preloadFullSurah`, and update `architecture.md`'s app-wide list.

- [ ] **Step 4: Run to see it pass**

Run: `flutter test test/features/quran_playback`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/surah_download lib/features/quran_playback/playback_di.dart lib/main.dart lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart .claude/rules/architecture.md test/features/quran_playback/presentation/cubit/surah_download_cubit_test.dart
git commit -m "feat(playback): app-wide SurahDownloadCubit per reciter and surah

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: SurahDownloadButton on the surah index tile

**Files:**
- Create: `lib/features/quran_playback/presentation/widgets/surah_download_button.dart`
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart` (button before the number disc, `Row` gap as the other children)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Modify: `.claude/rules/feature-widgets.md` (exception line: «`quran_playback` exports `SurahDownloadButton` (used by `surah`)»)
- Test: `test/features/quran_playback/presentation/widgets/surah_download_button_test.dart` (Create), `test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart`

**Interfaces:**
- Consumes: `SurahDownloadCubit.statusOf/download/cancel/delete`, `SurahDownloadStatus` (Task 6); `PlaybackState.reciter`.
- Produces: `class SurahDownloadButton extends StatelessWidget { const SurahDownloadButton({super.key, required this.surah}); final int surah; }` (S3 reuses it in «القائمة»).
- Strings: `surahDownload_download` «تنزيل السورة» / 'Download surah'; `surahDownload_cancel` «إلغاء التنزيل» / 'Cancel download'; `surahDownload_saved` «محفوظة للاستماع دون إنترنت» / 'Saved for offline listening'; `surahDownload_delete` «حذف التنزيل» / 'Delete download'; `surahDownload_failed` «تعذّر التنزيل، أعِد المحاولة» / 'Download failed, try again'; `surahDownload_progress(String percent)` `'جارٍ التنزيل $percent٪'` / `'Downloading $percent%'`.

UI: `BlocSelector<PlaybackCubit, PlaybackState, Reciter>` for the reciter, then `BlocBuilder<SurahDownloadCubit, SurahDownloadState>` with `buildWhen` on `statuses[reciter.downloadKey(surah)]`, drawing from `cubit.statusOf(reciter, surah)`; a sibling `BlocListener` with the same key shows a SnackBar (`surahDownload_failed`, `TS.regular14`) when the status becomes `SurahDownloadFailed`. One `IconButton` (≥ 48 × 48, `tooltip`), Material icons, colours from `context.colorScheme`:

| Status | Child | Tooltip | Tap |
|---|---|---|---|
| not downloaded | `Icons.download_for_offline_outlined`, `secondary` | `surahDownload_download` | `download` |
| downloading(p) | 22 px `CircularProgressIndicator(value: p, strokeWidth: 2.5)` in `Semantics(label: surahDownload_progress(round(p·100).toLocalized))` | `surahDownload_cancel` | `cancel` |
| downloaded | `Icons.offline_pin`, `primary` | `surahDownload_saved` | `showDialog` `AlertDialog`: content `surahDownload_saved`, actions `MaterialLocalizations.cancelButtonLabel` and `surahDownload_delete` → `delete` |
| failed | `Icons.error_outline`, `error` | `surahDownload_failed` | `download` |

The determinate ring is download progress, not a content-loading state, so `loading-states.md` does not apply.

- [ ] **Step 1: Write the failing tests** (`MaterialApp(locale: Locale('ar'), …S + Global delegates)`; `_FakeDownloads extends Cubit<SurahDownloadState> implements SurahDownloadCubit` whose `statusOf` reads `state.statuses` else `SurahNotDownloaded()` and records `download/cancel/delete` calls with `(reciter, surah)`; `_FakePlayback` with `PlaybackState(reciter: Reciter.husary)`)

```dart
testWidgets('not downloaded: «تنزيل السورة» starts the download for the current reciter', …
  find.byTooltip('تنزيل السورة'); tap → downloads == [(husary, 2)]);
testWidgets('downloading: a 40% ring that cancels on tap', …
  statuses {'husary:2': SurahDownloading(.4)} → CircularProgressIndicator.value == .4;
  find.bySemanticsLabel('جارٍ التنزيل ٤٠٪'); tap tooltip 'إلغاء التنزيل' → cancels == [(husary, 2)]);
testWidgets('downloaded: «محفوظة» offers «حذف التنزيل»', …
  tap tooltip 'محفوظة للاستماع دون إنترنت' → dialog; tap 'حذف التنزيل' → deletes == [(husary, 2)]);
testWidgets('failed: retry on tap, and the failure shows a SnackBar once', …
  push failed → find.text('تعذّر التنزيل، أعِد المحاولة') in a SnackBar; tap → downloads == [(husary, 2)]);
testWidgets('another reciter\'s download does not show on this button', …
  statuses {'alafasy:2': SurahDownloaded()} → tooltip 'تنزيل السورة');
```

`surah_list_tile_test.dart`: provide `_FakeDownloads` in `_tap`'s tree (`MultiBlocProvider`), keep the two tests, and add `'the tile carries the download button for its surah'` → `tester.widget<SurahDownloadButton>(find.byType(SurahDownloadButton)).surah == 2`.

- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/quran_playback/presentation/widgets/surah_download_button_test.dart test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart`
Expected: FAIL (widget missing).

- [ ] **Step 3: Implement** the button, the strings, the tile change and the `feature-widgets.md` line.

- [ ] **Step 4: Run to see them pass**

Run: `flutter test test/features/quran_playback test/features/surah/presentation/pages/surah_list test/core/localization/pending_s_test.dart test/config/theme/typography_ratchet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/widgets/surah_download_button.dart lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/quran_playback/presentation/widgets/surah_download_button_test.dart test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart
git commit -m "feat(playback): surah download button on the surah index

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: One-time download hint (SettingsCubit downloadHintSeen)

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart` (`final bool downloadHintSeen;` default `false`, `copyWith`, `props`)
- Modify: `lib/features/settings/data/models/settings_model.dart` (constructor, `copyWith`, `fromMap` `map['downloadHintSeen'] ?? false`, `toMap`)
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart` (`void markDownloadHintSeen()`, no-op when already set, like `dismissNotificationHint`)
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart` (`final bool playedFromNetwork;` default `false`, `props`, `copyWith`)
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` (`_playAyah`)
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` (`MultiBlocListener`)
- Modify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/features/settings/data/models/settings_model_test.dart`, `test/features/settings/presentation/cubit/settings_cubit_test.dart`, `test/features/quran_playback/presentation/cubit/playback_state_test.dart`, `test/features/quran_playback/playback_cubit_test.dart`, `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`

**Interfaces:**
- Consumes: `QuranPlaybackRepo.isAyahCached` (Task 5), `SurahDownloadCubit.download` (Task 6), `surahDownload_download` (Task 7).
- Produces: `Settings.downloadHintSeen`, `SettingsCubit.markDownloadHintSeen()`, `PlaybackState.playedFromNetwork`; string `surahDownload_hint` «يمكنك تنزيل السورة لتستمع دون إنترنت» / 'You can download the surah to listen offline'.

Behaviour: `_playAyah` reads `repository.isAyahCached(ayah: ayah, reciter: state.reciter)` before `prepareAyahAudio(ayah)`, and on a successful prepare (after the stale check) emits `playedFromNetwork: !cached`. `MushafPage` adds a `BlocListener<PlaybackCubit, PlaybackState>` (`listenWhen: (a, b) => !a.playedFromNetwork && b.playedFromNetwork`) beside the existing `MushafCubit` listener; when `SettingsCubit`'s `downloadHintSeen` is false it calls `markDownloadHintSeen()` and shows a SnackBar `surahDownload_hint` (`TS.regular14`) with a `SnackBarAction(label: surahDownload_download)` that calls `context.read<SurahDownloadCubit>().download(playback.reciter, playback.skipOrigin!.surah)` (Deliberate reading 7). Strings via `PendingS.current` (listener).

- [ ] **Step 1: Write the failing tests**

- `settings_model_test.dart`: `'downloadHintSeen: defaults false and round-trips via map'` (shape of the `notificationHintDismissed` test), plus `SettingsModel.fromMap({})` → `downloadHintSeen` false.
- `settings_cubit_test.dart`: `'markDownloadHintSeen sets the flag once'` → true after the call; a second call emits nothing (`expectLater(c.stream, emitsDone)` after `close`, or count emissions).
- `playback_state_test.dart`: `PlaybackState(playedFromNetwork: true) != PlaybackState()` and `copyWith(playedFromNetwork: true).playedFromNetwork`.
- `playback_cubit_test.dart`: add `when(() => repo.isAyahCached(ayah: any(named: 'ayah'), reciter: any(named: 'reciter'))).thenReturn(true)` to `setUp` (existing tests otherwise get `null` for a `bool`); new tests `'an ayah fetched from the network marks playedFromNetwork'` (stub false for 2:5, `playSelected(2:5)` with prepare `Right` and play `Right` → `state.playedFromNetwork` true) and `'a cached ayah does not'` (→ false).
- `mushaf_page_dispose_test.dart`: `_FakeSettings` takes `downloadHintSeen` and records `markDownloadHintSeen`; `_FakePlayback` gains `push(PlaybackState)`; the harness provides a `_FakeDownloads` `SurahDownloadCubit` that records `download`. Group `'download hint'`:
  - `'the first network ayah shows the hint once and marks it seen'`: push `PlaybackState(currentAyah: 2:5, reciter: husary, playedFromNetwork: true)` → `find.text('يمكنك تنزيل السورة لتستمع دون إنترنت')` and `markCalls == 1`.
  - `'its action downloads the playing surah'`: tap `'تنزيل السورة'` in the SnackBar → downloads == [(husary, 2)].
  - `'a seen hint never shows again'`: `downloadHintSeen: true` → no SnackBar text.

- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/settings test/features/quran_playback test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart`
Expected: FAIL (fields and listener missing).

- [ ] **Step 3: Implement** per Behaviour, and the string in both ARBs and `PendingS`.

- [ ] **Step 4: Run to see them pass, then the full gate**

Run: `flutter test test/features/settings test/features/quran_playback test/features/surah test/core/localization/pending_s_test.dart`
Expected: PASS.
Run: `flutter analyze --no-fatal-infos` and `flutter test`
Expected: 0 errors, 0 warnings, ≤ 69 infos; all pass, 1 skipped.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/domain/entities/settings.dart lib/features/settings/data/models/settings_model.dart lib/features/settings/presentation/cubit/settings_cubit.dart lib/features/quran_playback/presentation/cubit/playback/playback_state.dart lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/features/settings/data/models/settings_model_test.dart test/features/settings/presentation/cubit/settings_cubit_test.dart test/features/quran_playback/presentation/cubit/playback_state_test.dart test/features/quran_playback/playback_cubit_test.dart test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
git commit -m "feat(mushaf): one-time hint that a surah can be downloaded for offline listening

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Slice verification

- `dart format` on every touched Dart file; `flutter analyze --no-fatal-infos` (≤ 69 infos, 0 warnings, 0 errors); `flutter test` (all pass, 1 skipped).
- Emulator-5554: Task 4 Step 5 again, plus: download البقرة from the index (ring, cancel, resume, «محفوظة», delete); with the network off, a downloaded surah plays; an incoming call (`adb emu gsm call 123`) pauses recitation and it stays paused after `adb emu gsm cancel 123`; unplug-headset is covered by the unit test; a test adhan from the alerts screen pauses recitation. Record `adb shell dumpsys media_session` in the PR.
- The slice PR (`gh pr create --base main`) follows the branch review (D2); the owner merges.
