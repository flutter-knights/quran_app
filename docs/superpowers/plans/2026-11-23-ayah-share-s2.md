# Ayah share S2 (recitation reel: image + audio MP4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share one or more consecutive ayat as a 1080×1920 MP4: each ayah's share card is shown while the reader's reciter recites it, with the basmala before ayah 1 and a footer that credits the reciter. The reel is made from the S1 share sheet, which gains an «صورة / مقطع بالتلاوة» selector, an ayah-count stepper, a first-frame preview, encode progress, cancel and share.

**Architecture:** `pro_video_editor` 2.54.0 sits behind a domain `ReelRepository`. Its data implementation writes the frames, runs two passes (a silent stop-motion video, then the audio tracks) and maps a `ReelRequest` to plugin render data through one pure, tested function. The reel frame painter reuses S1's crops and the paint steps extracted from `ShareCardRenderer` on a 1920-high canvas with a footer. `PrepareAyahAudio` downloads or reuses each ayah's MP3 through `QuranPlaybackRepo.prepareAyahAudio` (basmala first) and measures it. `AyahShareCubit` gains the reel format, segments, the 10-ayah and 60 s caps, encode and cancel. The sheet adds the controls.

**Tech Stack:** Flutter 3.47.8 (global, no FVM), `pro_video_editor` 2.54.0 (Media3 on Android, AVFoundation on iOS), `path_provider` (`getApplicationSupportDirectory`), `dart:ui`, flutter_bloc, equatable, dartz, dio `CancelToken`, share_plus 13 (`XFile(path, mimeType: 'video/mp4')`), `wakelock_plus` through `ScreenWake`, hugeicons 4, CocoaPods 1.16.2, the `xcodeproj` gem that ships with CocoaPods.

**Spec:** `docs/superpowers/specs/2026-11-23-ayah-share-design.md`: D4, D5, D9, D11, §3.2 (transforms), §3.4 (`maxHeight`), §3.6 (S2 fields), §4 in full, §5 seams 7–9, §6 (S2 QA), §7 risks 3/5/6, Appendix B. Where the spec and this plan disagree, the spec wins, except for the **Deliberate readings** below.

**Evidence:** the spike in the session scratchpad (`recon/video/main_spike.dart`, `pubspec.diff`, `Podfile.lock.diff`, `ios_log2.txt`, `out/*.mp4`) proved the call shapes in Appendix B. `recon/card_proto.py` has no reel, footer or video rules (no `1920`, `footer` or `reel` in it), so nothing new is ported from it. S1 already ported every card rule. The reel reuses `shareCardLayout` and the crops unchanged.

## Global Constraints

- Checkout `/Users/sameh/Documents/flutter_projects/quran_app`, branch `feature/ayah-share-reel` (already checked out). Never switch branches. Never check out or touch `main` or `feature/ayah-share`. Never push, rebase or amend. Every command runs from the repo root.
- Commits: stage explicit paths only (never `git add -A` / `git add .`), and only files the task changed. The message is `feat|fix|refactor|test|docs(ayah-share): …` and ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage unrelated drift in `.metadata`, `pubspec.lock` (outside Task 1) or `quran-1.4.1/*`.
- No comments and no doc comments in new or changed code. No redundant type annotations. Keep the code lean, and leave existing comments in place.
- Strings: each new key goes in `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb` and as a `PendingS` getter `String get key => _ar ? '…' : '…';` or a method `String key(String a) => _ar ? '…$a…' : '…$a…';` (a single `_ar ? : ;` expression with `String` parameters, so the `pending_s_test.dart` regexes match). ARB placeholders are `{a}` with an `@key` block of type `String`. Read them with `PendingS.of(context)` in `build` and `PendingS.current` / `S.current` in callbacks. Never edit `lib/generated/`, never run `intl_utils:generate`. Reuse `S.share`, `S.share_failed`, `S.ayah_label`, `PendingS.places_cancel` «إلغاء» and `PendingS.mushaf_retry`.
- Text drawn on frames is always Arabic (`PendingS.forLanguage('ar')`, `Reciter.arabicName`, `quran.getSurahNameArabic`, `'…'.toIndicNumerals('ar')`). The share text follows the app locale (D9).
- Colours: frames use `MushafPaperX.colors`, the sheet uses `context.colorScheme`, and no hex appears anywhere. Text uses only `TS.*` with `.copyWith(height:, color:)`, never `TextStyle(`, `fontSize:`, `fontWeight:` or `fontFamily:`, so `test/config/theme/typography_ratchet_test.dart` must not rise. Frame text is laid out at logical size inside `canvas.scale(3)`. Icons come from HugeIcons.
- Layers: `ayah_share/domain/` is pure Dart. It may import `dart:typed_data`, the `surah` / `quran_playback` domain and `core/errors/failure.dart`. Presentation never imports `data/`. The data layer owns all plugin and file I/O. Use cases, the repository and the painter are lazy singletons. The cubit factory stays `registerFactoryParam<AyahShareCubit, AyahIdentifier, MushafPaper>`.
- Cubit: `if (isClosed) return;` before every emit that follows an `await`. Every state field except `cardBytes` goes in `props`. No `BuildContext` in the cubit. The OS share and the SnackBars run in the sheet's `BlocListener`.
- Loading: a slim `LinearProgressIndicator` only over a visible preview. Tests `pump()` rather than `pumpAndSettle()` while a skeleton or progress bar shows.
- Never run `test/tools/generate_mushaf_assets_test.dart` with `GENERATE_MUSHAF_ASSETS=true`, and never modify `assets/mushaf/**`.
- Disk is tight (8.9 GB free at planning time, `build/` holds 5.2 GB). Only Task 1 (one Android debug build) and Task 2 (one iOS simulator build, plus one rebuild only if the WAV probe needs the MP3 fallback) build. Run `flutter clean` before the iOS build. After every build, run `df -h .`, and run `flutter clean` again if less than 5 GB is free.
- Every task formats exactly the `.dart` paths in its `git add` line with `dart format <paths>`. Never format a directory, `.`, `lib`, `test` or `lib/generated/**`.
- Every task's verify step ends with `flutter test` and `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings, ≤ 69 infos, all tests passing and 1 skipped. Running totals from 1771: Task 1 → 1774, 2 → 1789, 3 → 1799, 4 → 1819, 5 → 1830, 6 → 1842. If the start differs, keep the deltas.
- Test fixtures read real bounds from disk through `test/features/ayah_share/share_card_fixture.dart` (`layoutFor`, `contentFor`). Expected surah names and verses come from the `quran` package, never typed literals. No golden tests.

## Deliberate readings (the plan governs here)

1. **`progress` stays the slim-bar getter.** `AyahShareState.progress` is already the `bool` read by the sheet and `ShareCardPreview`. The spec's 0–1 encode value is a new field `encodeProgress` (`double`, default 0).
2. **`reelCount` is derived:** `reelSegments.length`. There is no separate field.
3. **`cardBytes` holds the bytes of the current format.** In reel mode it is the first frame's PNG, so the preview still shows exactly what is shared (§3.5, §4.4). Switching format recomposes from the crops already held.
4. **The 60 s cap on «+».** The next ayah's duration is only known after it is prepared. A tap prepares it. If the measured total would pass 60 s, the segment is dropped (its crops disposed), `reelCapped` turns true and «+» stays disabled until «−». A start ayah longer than 60 s alone disables «+» without preparing anything (D4).
5. **Per-ayah tafsir loads at encode time, not per segment.** The first frame's preview uses the S1 tafsir (`state.tafsir`). When the switch is on, `requestShare` in reel mode fetches the tafsir of every other segment with its own `CancelToken`. A failure draws that frame without tafsir (§4.2). `ReelSegment` therefore carries content and audio, not tafsir. The reel follows the preview: `requestShare` captures `withTafsir = includeTafsir && tafsirStatus == ready` once at its start. A share tapped while the start ayah's tafsir is still loading encodes every frame without tafsir, as S1's image share does in that window (§3.5), so «مشاركة» never waits on the tafsir.
6. **No reel cache.** Every reel share encodes again. A cancelled OS share followed by another tap re-encodes, which is rare and keeps the state small.
7. **The reciter is read when the reel segment is chosen** (`context.read<PlaybackCubit>().state.reciter` in the selector's `onChanged`), never in `AyahShareSheet.show`, so the study leaf, «أماكني» and the S1 tests keep opening the sheet with only `SettingsCubit`. A different reciter on a later reel selection drops the old segments.
8. **The reel block is `layout.textBottom + shareCardMargin`.** That is the card content plus a 72 px bottom edge, centred in `available = 1920 − footerHeight`, with `footerHeight = 3 · footer.height + 2 · 24`. With Cairo at `TS.regular10` (≈ 18.7 logical px per line) the footer is ≈ 104 card px, so `available` ≈ 1816. That keeps 10-row ayat (≈ 1791 px) unscaled, and only 2:282 and 4:12 (11 lines) scale down, as §4.1 states. Task 3's corpus test pins this. If it fails, set `reelFooterPad = 20` and rerun it, then `16`, and keep the first value that passes (`deviceFooter` reads `reelFooterPad`, so the test follows). Record the value in the Task 3 commit body. If `16` still fails, stop and report the extra scaled ayat. Never change the spec rule or the corpus expectation.
9. **Tafsir cut fallback.** §4.1 cuts at the last full sentence that fits. If no full sentence fits but three or more lines do, the cut falls back to the last whole word that fits, followed by « …».
10. **Audio and content failures on «+»** both raise `ReelIssue.audioFailed` (the «تعذّر تحميل التلاوة» SnackBar). The bundled bounds never fail in practice.
11. **iOS step.** The spike already shows fractional per-sample durations on iOS: `ios_t6_fps5_silent.mp4` is 45.508 s = 6.031 + 39.478, with the card switch between 5.9 s and 6.1 s, and `t7_repeat` is 39 × 1 s + 0.478 s. What remains unverified is a sub-second remainder followed by another card. Task 2 keeps the spec's simulator check for exactly that case, with `reelIosStep = 1 / 30` and the tested `1.0` fallback.
12. **Reel work blocks every toggle, a recompose does not.** A new state getter `reelWorking` (`export == preparing || export == encoding`) guards `setPaper`, `setIncludeTafsir` and `selectImage`, and the sheet disables the swatches and switch on it. They are not guarded on `busy`: `busy` includes `rendering`, which every recompose emits, and S1's «a stale compose never replaces a newer one» (`ayah_share_cubit_test.dart:159`) pins two paper taps in a row. The new selector and stepper use `busy`, through `canAddAyah` / `canRemoveAyah` and `enabled: ready && !busy`. A recompose that starts on its own while reel work runs is **deferred**: `_compose()` sets `_composeDeferred` and returns when `state.reelWorking`, as it already does while `sharing`. The S1 tafsir landing mid-prepare or mid-encode (`_loadTafsir` → `_compose`) therefore never replaces `preparing` / `encoding` with `rendering` → `idle`. Every exit from `preparing` or `encoding` goes through one private `_settle(AyahShareState next)`: it emits `next`, then, if `_composeDeferred`, clears it and calls `_compose()`. A path that composes right after (`selectReel`'s and `addAyah`'s success) clears `_composeDeferred` and emits directly instead. `shareFinished` keeps its existing deferred run.
13. **Tests that pin S1 shapes are rewritten on purpose:**
    - `registerFakeAyahShare` and the cubit construction in `ayah_share_fakes.dart`, which the study-leaf and places tests use;
    - `ayah_share_di_test.dart`, which must register a `QuranPlaybackRepo` stub;
    - the cubit test's `setUp`;
    - the sheet test's `open()`, which must provide a `FakePlayback`;
    - `expectDisabled`, which also covers the selector.

    The study-leaf share rewrite from spec §5 already landed in S1 (`ayah_study_leaf_test.dart:288`, «the share button opens the share sheet»), so it is not planned again.

## Review Focus

1. **Offline with an uncached reciter.** Choosing «مقطع بالتلاوة» must show «تعذّر تحميل التلاوة» and fall back to the image, which stays shareable. Task 4 pins the cubit side and Task 6 the SnackBar.
2. **Closing the sheet mid-encode.** The render is cancelled, its files are deleted and the screen wake is released. Task 5 pins cancel and wake. Task 2 pins file cleanup on cancel, a cancel between the two passes (pass 2 never starts) and a cancel while idle (no throw).
3. **A toggle during an encode** (paper swatch, tafsir switch, format) must not replace the encoding state or the preview mid-render, and neither may the S1 tafsir landing mid-prepare or mid-encode. Task 5 pins the toggles and the mid-encode tafsir. Task 4 pins the mid-prepare tafsir.
4. **English UI.** The share text is the English range label, while the frame footer stays Arabic. Task 6 pins the share text and Task 3 the footer.
5. **Double tap on «+».** It must prepare only one more ayah, and a tafsir landing mid-prepare must not reopen «+». Task 4 pins both.

---

### Task 1: Package and platform (seam 7, part 1)

**Files:**
- Modify: `pubspec.yaml` (`pro_video_editor: 2.54.0` after `path_provider` in `dependencies`), `pubspec.lock` (`pro_video_editor` and, if pub moves them, its own dependencies), `ios/Podfile.lock`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`
- Create: `ios/Runner/ar.lproj/InfoPlist.strings`
- Modify only if Step 5 finds a plugin-added media permission: `android/app/src/main/AndroidManifest.xml`
- Create (test): `test/features/ayah_share/reel_platform_test.dart`

**Interfaces:**
- Produces: the `pro_video_editor` package for Task 2. No Dart API.

- [ ] **Step 1: Write the failing tests** (`reel_platform_test.dart`, plain `test`, reading files from disk)
  - `'pro_video_editor is pinned exactly'`: `pubspec.yaml` contains the line `  pro_video_editor: 2.54.0` (no caret).
  - `'Info.plist explains the photo library use'`: `ios/Runner/Info.plist` contains `<key>NSPhotoLibraryUsageDescription</key>` followed by `<string>Used only if you choose to save a shared ayah video.</string>`, and S1's `NSPhotoLibraryAddUsageDescription` followed by `<string>Used only to save a shared ayah image or video to your photos.</string>` (the OS share sheet's "Save Video" for a reel raises this Add-only prompt too).
  - `'the Arabic InfoPlist.strings is bundled'`: `ios/Runner/ar.lproj/InfoPlist.strings` contains both `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddUsageDescription`. `project.pbxproj` contains `ar.lproj/InfoPlist.strings`, and its `knownRegions` list contains `ar`.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/reel_platform_test.dart`. Expected: FAIL (3).

- [ ] **Step 3: Pin the package.** Add `  pro_video_editor: 2.54.0` to `pubspec.yaml`, run `flutter pub get`, then `git diff pubspec.lock`. Expected: a `pro_video_editor` block, plus at most new or bumped entries for its own dependencies (`http`, `mime`, `web`, `plugin_platform_interface`, `path_provider`). Revert any other hunk and do not stage it.

- [ ] **Step 4: iOS config**
  - `Info.plist`: change the `NSPhotoLibraryAddUsageDescription` string to "Used only to save a shared ayah image or video to your photos.", and add `NSPhotoLibraryUsageDescription` with "Used only if you choose to save a shared ayah video." right after that pair.
  - `ar.lproj/InfoPlist.strings` (UTF-8):
    ```
    "NSPhotoLibraryUsageDescription" = "يُستخدم فقط إذا اخترت حفظ مقطع آية شاركته.";
    "NSPhotoLibraryAddUsageDescription" = "يُستخدم فقط لحفظ صورة آية أو مقطعها الذي شاركته في صورك.";
    ```
  - Register it with the CocoaPods `xcodeproj` gem, run from the repo root:
    ```bash
    ruby -e 'require "xcodeproj"; p = Xcodeproj::Project.open("ios/Runner.xcodeproj"); t = p.targets.find { |x| x.name == "Runner" }; v = p.main_group["Runner"].new_variant_group("InfoPlist.strings"); r = v.new_reference("ar.lproj/InfoPlist.strings"); r.name = "ar"; r.last_known_file_type = "text.plist.strings"; t.resources_build_phase.add_file_reference(v); p.root_object.known_regions = (p.root_object.known_regions + ["ar"]).uniq; p.save'
    ```
    Check: `plutil -lint ios/Runner/Info.plist ios/Runner/ar.lproj/InfoPlist.strings` prints `OK` twice. `git diff --stat ios/Runner.xcodeproj/project.pbxproj` stays under ~20 lines, made of one `PBXBuildFile`, one `PBXFileReference` (`name = ar; path = ar.lproj/InfoPlist.strings; lastKnownFileType = text.plist.strings`), one `PBXVariantGroup` `InfoPlist.strings`, the Runner group child, the Resources phase entry and `ar` in `knownRegions`. If the gem rewrites the whole file, `git checkout ios/Runner.xcodeproj/project.pbxproj` and add those six entries by hand with fresh 24-hex IDs.
  - `cd ios && pod install && cd ..`. Then compare `git diff ios/Podfile.lock` with the spike's `recon/video/Podfile.lock.diff`. Expected: the `pro_video_editor (0.0.1)` pod, the DEPENDENCIES and EXTERNAL SOURCES entries, and checksum `7c3b388ec795a713306ab11891b7c98222ea4cd9`. Stage nothing else that `pod install` touches.

- [ ] **Step 5: Android merged manifest.** Run `flutter build apk --debug`, then:
  - `grep -o 'android.permission[.A-Z_]*' $(find build/app/intermediates/merged_manifest -name AndroidManifest.xml | head -1) | sort -u`
  - `grep -n 'uses-permission' -A2 build/app/outputs/logs/manifest-merger-debug-report.txt`

  Record every permission and the library that adds it for the PR. If `pro_video_editor` or any `androidx.media3` artifact adds a media or storage permission (`READ_MEDIA_*`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `ACCESS_MEDIA_LOCATION`), add `xmlns:tools="http://schemas.android.com/tools"` to `<manifest>` and `<uses-permission android:name="…" tools:node="remove"/>` for each one, then rebuild and recheck. The plugin's own manifest is empty, so expect no change. Run `df -h .` and run `flutter clean` if less than 5 GB is free.

- [ ] **Step 6: Verify** `flutter test test/features/ayah_share/reel_platform_test.dart`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, +3 → 1774.

- [ ] **Step 7: Format and commit**

```bash
dart format test/features/ayah_share/reel_platform_test.dart
git add pubspec.yaml pubspec.lock ios/Podfile.lock ios/Runner/Info.plist ios/Runner/ar.lproj/InfoPlist.strings ios/Runner.xcodeproj/project.pbxproj test/features/ayah_share/reel_platform_test.dart
git commit -m "feat(ayah-share): pin pro_video_editor 2.54.0 with the iOS photo library key in English and Arabic

Merged Android manifest permissions: <list from Step 5>.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
Add `android/app/src/main/AndroidManifest.xml` to `git add` only if Step 5 changed it.

---

### Task 2: ReelRepository, request mapping and implementation (seam 7, part 2)

**Files:**
- Create: `lib/features/ayah_share/domain/entities/reel_request.dart`, `lib/features/ayah_share/domain/repositories/reel_repository.dart`, `lib/features/ayah_share/domain/usecases/compose_ayah_reel.dart`, `lib/features/ayah_share/data/repositories/reel_repository_impl.dart`
- Modify: `lib/core/errors/failure.dart` (add `ReelCancelledFailure`), `lib/features/ayah_share/ayah_share_di.dart`
- Create (tests): `test/features/ayah_share/domain/entities/reel_request_test.dart`, `test/features/ayah_share/data/repositories/reel_repository_impl_test.dart`
- Modify (test): `test/features/ayah_share/ayah_share_di_test.dart` (add one test)
- Create (temporary, untracked, deleted in Step 5): `lib/reel_probe_main.dart`
- Read-only inputs, never staged: the session scratchpad's `recon/video/dl/006031.mp3` and `001001.mp3`, `tools/mp4probe` and `tools/mp4probe.swift` (`/private/tmp/claude-501/-Users-sameh-Documents-flutter-projects-quran-app/ea8deb78-9e2e-41bc-b4f2-1bd29185fb03/scratchpad/`)

**Interfaces:**
- Produces:
  - `class ReelAudio extends Equatable { const ReelAudio({required String path, required Duration duration}); }`
  - `class ReelClip { const ReelClip({required Uint8List frame, required List<ReelAudio> audio}); Duration get duration; }` (sum of `audio`)
  - `class ReelRequest { const ReelRequest({required AyahIdentifier first, required List<ReelClip> clips}); String get fileName; }`, where `fileName` is `ayah_<s>_<a>.mp4` for one clip and `ayah_<s>_<a>-<a+n−1>.mp4` for n clips.
  - `abstract class ReelRepository { Future<Either<Failure, Duration>> audioDuration(String path); Future<Either<Failure, String>> compose(ReelRequest request); Stream<double> get progress; Future<void> cancel(); }`
  - `class ReelCancelledFailure extends Failure { const ReelCancelledFailure() : super('cancelled'); }`
  - `class ComposeAyahReel { ComposeAyahReel(ReelRepository reels); Future<Either<Failure, String>> call(ReelRequest request); Stream<double> get progress; Future<void> cancel(); }` (delegates)
  - In `reel_repository_impl.dart`:
    - `typedef ReelFrame = ({int clip, Duration duration});`
    - `typedef ReelTrack = ({String path, Duration start});`
    - `typedef ReelPlan = ({List<ReelFrame> frames, List<ReelTrack> tracks});`
    - `const reelAndroidStep = 0.2;`, `const reelIosStep = 1 / 30;`, `const reelFrameRate = 5.0;`
    - `ReelPlan reelPlan(ReelRequest request, {required bool ios, double iosStep = reelIosStep})`
    - `class ReelRepositoryImpl implements ReelRepository { ReelRepositoryImpl({ProVideoEditor? editor, Future<Directory> Function() directory = getApplicationSupportDirectory, bool? ios}); }`. The editor resolves lazily (`ProVideoEditor get _editor => _override ?? ProVideoEditor.instance;`) so DI and plain tests never touch the plugin. `ios` defaults to `Platform.isIOS`.

`reelPlan` (the rounding happens in exactly one place, so the remainder test is stable):
- `o_0 = 0` and `o_{i+1} = o_i + clips[i].duration`, in seconds as doubles. `step` is `reelAndroidStep` on Android and `iosStep` on iOS. `snap(t) = (t / step).round() * step`, in double seconds.
- Boundaries, each rounded once to whole microseconds: `bUs_i = (snap(o_i) * 1e6).round()` for `i < n`. `bUs_n = (snap(o_n) * 1e6).round()`, or `(o_n.ceilToDouble() * 1e6).round()` when `ios && iosStep == 1` (the fallback extends the last frame to cover the audio end).
- Everything after that is integer arithmetic: `spanUs = bUs_{i+1} − bUs_i`.
- Android: one frame per clip, `(clip: i, duration: Duration(microseconds: spanUs))`.
- iOS: per clip, `whole = spanUs ~/ 1000000` frames of 1 s, then `remUs = spanUs − whole * 1000000`, and one remainder frame of `remUs` when `remUs >= 33333`. Never compare a double remainder with `1 / 30`, and never snap with an integer 33 333 µs step: 181 × 33 333 = 6 033 273 leaves a 33 273 µs remainder and drops the frame the test expects. Checked in a scratch Dart run: `[6.031, 39.478]` gives 6 × 1 s, 33 333 µs, 39 × 1 s, 466 667 µs.
- Tracks: for clip i, its audio in order, starting at `o_i` and adding each previous file's duration (basmala first). They are exact, never snapped.

`compose` (Appendix B, exact shapes):
- `final n = ++_count;` first, synchronously, where `_count` is the per-instance counter used in the ids. `work = root/work/<n>`, one directory per request, so a compose still unwinding after a cancel never deletes a newer compose's frames.
- `root = <directory()>/ayah_share`. Delete `root/reels` (previous reels), then create `work` and `root/reels`.
- Write each clip's frame to `work/frame_<i>.png`.
- Pass 1: `renderStopMotionToFile(work/silent.mp4, StopMotionRenderData(id: 'reel-frames-<n>', frames: [for f in plan.frames StopMotionFrame(image: EditorLayerImage.file(File(frame_<f.clip>.png)), duration: f.duration)], frameRate: reelFrameRate, resolution: const Size(1080, 1920), fit: StopMotionFit.cover))`.
- Pass 2: `renderVideoToFile(reels/<fileName>, VideoRenderData(id: 'reel-audio-<n>', videoSegments: [VideoSegment(video: EditorVideo.file(File(silent)))], audioTracks: [for t in plan.tracks VideoAudioTrack(path: t.path, startTime: t.start)], shouldOptimizeForNetworkUse: true))`.
- During each pass, `progressStreamById(id)` maps `p` to `p / 2` in pass 1 and `0.5 + p / 2` in pass 2, into a broadcast `StreamController<double>`.
- Cancel state is per request, never one shared flag that a new compose resets:
  - `final _running = <String>{};` and `var _cancelledThrough = 0;`.
  - Each pass adds its id to `_running` just before its render call and removes it in that pass's own `finally`.
  - `bool _cancelled(int n) => n <= _cancelledThrough;`. After writing the frames and again after pass 1, `if (_cancelled(n)) throw const RenderCanceledException();`, so a cancel that lands during the frame writes or between the passes starts no further pass.
  - `cancel()`: `_cancelledThrough = _count;`, then `for (final id in [..._running])` `try { await _editor.cancel(id); } catch (_) {}`. With nothing running it only sets the mark and never touches the plugin, so `close()` after a finished reel never sends a stale id (the plugin throws `PlatformException` `TASK_NOT_FOUND` for one).
- `RenderCanceledException` → delete the output and return `Left(ReelCancelledFailure())`. Any other error → delete the output and return `Left(UnknownFailure('$e'))`. In a `finally`, delete `work` (`root/work/<n>`) recursively.
- `audioDuration`: `getMetadata(EditorVideo.file(File(path)))` → `Right(m.audioDuration ?? m.duration)`. Errors → `Left(UnknownFailure)`.

Test fake (in the impl test): `class _FakeEditor extends ProVideoEditor`.
- Override `initializeStream() {}`, `getMetadata`, `renderStopMotionToFile`, `renderVideoToFile` and `cancel`. `cancel` records the id in `cancelled` and throws `PlatformException(code: 'TASK_NOT_FOUND')` for an id that is not running, like the plugin.
- `getMetadata` returns `VideoMetadata(duration: duration, extension: 'mp3', fileSize: 0, resolution: Size.zero, rotation: 0, bitrate: 0, audioDuration: audioDuration)` from the two fields the test sets.
- Each pass can be held on its own `Completer<void>` (`pass1Gate`, `pass2Gate`) before it writes its output. Cancelling a running id only records it; the held pass still completes normally when its gate opens, which stands in for a cancel that lands just as the pass finishes.
- Record the render data. Assert that every frame file exists while pass 1 runs.
- Write one byte to each output path. Optionally throw `RenderCanceledException` or a `StateError` in a chosen pass.
- Push progress with `progressCtrl.add(ProgressModel(id: data.id, progress: p))`.
- Pass `directory: () async => tempDir`.

- [ ] **Step 1: Write the failing tests**
  - `reel_request_test.dart`, `'file names carry the ayah or the range'`: one clip of 6:31 → `ayah_6_31.mp4`. Three clips from 2:255 → `ayah_2_255-257.mp4`. `ReelClip.duration` sums its audio.
  - Mapping, in `reel_repository_impl_test.dart` under `group('reelPlan')`, with two local builders:
    - `ReelRequest request(double a, double b)`: `first` 1:1 and two clips, each `ReelClip(frame: Uint8List(0), audio: [ReelAudio(path: '/a$i.mp3', duration: Duration(microseconds: (d * 1e6).round()))])`.
    - `fractional`: 10 clips with durations `[6.031 + 3.217, 5.901, 4.444, 7.05, 2.333, 6.789, 3.001, 5.5, 4.123, 6.66]` s, all with `Uint8List(0)` frames. Clip 0 has two files, `/basmala.mp3` 6.031 s then `/a0.mp3` 3.217 s. Clips 1–9 have one file each, `/a<i>.mp3`.
    The mapping tests:
    - `'android shows one frame per card on 0.2 s steps'`: `reelPlan(request(6.031, 39.478), ios: false).frames` → `[(clip: 0, 6.0 s), (clip: 1, 39.6 s)]`.
    - `'ios splits each card into whole seconds and a remainder'`: the same request with `ios: true, iosStep: 1 / 30` (explicit, so the test pins the 1/30 rule whatever `reelIosStep` ends up as) gives 6 × `(0, 1 s)`, then `(0, 33 333 µs)`, then 39 × `(1, 1 s)` and `(1, 0.4667 s ± 1 µs)`. Every frame is ≤ 1 s.
    - `'card switches stay within one step of the audio offsets'`: on `fractional`, for `ios: false`, `ios: true` and `ios: true, iosStep: 1`, the cumulative start of each clip's first frame is within `step + 1 µs` of `o_i` for every i, and `|video total − audio total| ≤ step`. The fallback also has `video total ≥ audio total` and every frame exactly 1 s.
    - `'audio tracks start at the exact offsets, basmala first'`: `fractional` tracks are `[(basmala, 0), (a0, 6.031), (a1, 9.248), …]`.
  - Implementation (`_FakeEditor`, temp dir):
    - `'compose renders the silent video, then adds the audio, and cleans up'`: pass 1 has one frame per plan frame at `frameRate` 5, size 1080×1920 and `StopMotionFit.cover`. Pass 2 has the tracks and `shouldOptimizeForNetworkUse` true. The result is `Right(path)` with `path` ending in `reels/ayah_6_31.mp4`. `root/work/1` no longer exists.
    - `'a cancelled render returns ReelCancelledFailure and leaves no files'`: pass 2 throws `RenderCanceledException` → `Left(isA<ReelCancelledFailure>())`, `reels/` is empty and `root/work/1` is gone.
    - `'a render error returns an UnknownFailure'`: pass 1 throws `StateError` → `Left(isA<UnknownFailure>())`, and `root/work/1` is gone.
    - `'progress maps pass 1 to 0–0.5 and pass 2 to 0.5–1'`: pushing 0.5 in each pass emits `[0.25, 0.75]`.
    - `'cancel cancels the running pass'`: pass 1 waits on a completer, then `cancel()` → `fake.cancelled == ['reel-frames-1']`.
    - `'a cancel between passes skips pass 2 and leaves no files'`: hold pass 1 on `pass1Gate`, call `cancel()`, then open the gate → no `renderVideoToFile` call, `Left(isA<ReelCancelledFailure>())`, `reels/` empty and `root/work/1` gone.
    - `'cancel while idle does not throw'`: `cancel()` before any compose and again after a finished compose completes normally, and `fake.cancelled` stays empty.
    - `'a new compose deletes the previous reel'`: after two composes with different names, only the second output exists.
    - `'audioDuration prefers the audio track'`: metadata with `audioDuration` 5 s → 5 s. Metadata with `audioDuration` null and `duration` 7 s → 7 s.
  - `ayah_share_di_test.dart`, `'the reel use case resolves without touching the plugin'`: after `initAyahShare()`, `sl<ComposeAyahReel>()` resolves in a plain `test` (no binding) without throwing, which shows the impl never reads `ProVideoEditor.instance` at construction.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/domain/entities/reel_request_test.dart test/features/ayah_share/data/repositories/reel_repository_impl_test.dart test/features/ayah_share/ayah_share_di_test.dart`. Expected: FAIL (missing files).

- [ ] **Step 3: Implement** the entities, the repository interface, the failure, `ComposeAyahReel`, `reelPlan` and `ReelRepositoryImpl` with the signatures above. In `initAyahShare()`, add:
  - `sl.registerLazySingleton<ReelRepository>(ReelRepositoryImpl.new);`
  - `sl.registerLazySingleton(() => ComposeAyahReel(sl()));`

- [ ] **Step 4: Verify** the three test files, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, +15 → 1789.

- [ ] **Step 5: iOS simulator check** (the one iOS build in S2; spec §4.3 "seam 7 first checks"). It covers the remainder frame and `ar.lproj`.
  - Run `flutter clean`, then `df -h .`.
  - Create an **untracked, temporary** `lib/reel_probe_main.dart`. It calls `WidgetsFlutterBinding.ensureInitialized()`, paints two solid 1080×1920 PNGs (red, then blue) with `PictureRecorder`, and writes two silent WAVs to `getTemporaryDirectory()`: a 44-byte RIFF/`WAVE` header (PCM, 1 channel, 8000 Hz, 16-bit, byte rate 16 000, block align 2) followed by `2 × 8000 × seconds` zero bytes of sample data, so 22 400 data bytes for 1.4 s and 36 800 for 2.3 s. It then measures them with `ReelRepositoryImpl().audioDuration`, composes `ReelRequest(first: 1:1, clips: [red + 1.4 s, blue + 2.3 s])` and `debugPrint('REEL_PROBE $path')`.
  - Build, install and launch without `flutter run` (which never returns):
    - `flutter build ios --simulator --debug -t lib/reel_probe_main.dart`
    - `xcrun simctl boot "iPhone 17 Pro" || true` (it errors when the device is already booted)
    - `xcrun simctl install booted build/ios/iphonesimulator/Runner.app`
    - `xcrun simctl launch booted com.example.quranApp`
    - after ~20 s, `xcrun simctl spawn booted log show --last 3m --predicate 'eventMessage CONTAINS "REEL_PROBE"' --style compact` for the path (the spike's `ios_log2.txt` used the same query).
  - A probe that throws (for example, metadata or the render rejecting the WAV) is a probe bug, not a failed remainder check. The fallback uses the spike's two real MP3s and touches no tracked file:
    - Change the probe to skip the WAVs and read `<getTemporaryDirectory()>/006031.mp3` (39.478 s) and `001001.mp3` (6.031 s), composing `[red + 006031.mp3, blue + 001001.mp3]`.
    - Rebuild and reinstall as above, then copy the files into the app's own tmp before launching: `C=$(xcrun simctl get_app_container booted com.example.quranApp data) && cp /private/tmp/claude-501/-Users-sameh-Documents-flutter-projects-quran-app/ea8deb78-9e2e-41bc-b4f2-1bd29185fb03/scratchpad/recon/video/dl/006031.mp3 /private/tmp/claude-501/-Users-sameh-Documents-flutter-projects-quran-app/ea8deb78-9e2e-41bc-b4f2-1bd29185fb03/scratchpad/recon/video/dl/001001.mp3 "$C/tmp/"`, then `xcrun simctl launch booted com.example.quranApp`.
    - The card switch is then at `snap(39.478)` = 1184/30 ≈ 39.4667 s, so sample `39.40 39.43 39.50 39.53 45.40`. Expected: duration ≈ 45.5 s ± 1/30, the frames at ≤ 39.43 s red and ≥ 39.50 s blue.
    - This route has not been run yet. If it fails too, stop and report both errors rather than design a third probe.
  - Inspect the reel with `/private/tmp/claude-501/-Users-sameh-Documents-flutter-projects-quran-app/ea8deb78-9e2e-41bc-b4f2-1bd29185fb03/scratchpad/tools/mp4probe <path> <outDir> 1.30 1.37 1.43 1.50 3.60`. Expected for the WAV probe: duration 3.7 s ± 1/30, the frames at ≤ 1.37 s red and ≥ 1.43 s blue. `ffprobe` and `ffmpeg` are not installed on this Mac. If `tools/mp4probe` is missing (a reboot can clear the scratchpad), rebuild it with `swiftc -O /private/tmp/claude-501/-Users-sameh-Documents-flutter-projects-quran-app/ea8deb78-9e2e-41bc-b4f2-1bd29185fb03/scratchpad/tools/mp4probe.swift -o /private/tmp/claude-501/-Users-sameh-Documents-flutter-projects-quran-app/ea8deb78-9e2e-41bc-b4f2-1bd29185fb03/scratchpad/tools/mp4probe`. If the `.swift` source is gone too, stop and report.
  - Check the bundled strings: `test -f build/ios/iphonesimulator/Runner.app/ar.lproj/InfoPlist.strings`. If it is missing, fix the Task 1 pbxproj entries and add `ios/Runner.xcodeproj/project.pbxproj` to this task's `git add`.
  - **If the switch is off by more than 1/30 s or the remainder frame collapses,** set `const reelIosStep = 1.0;`. The fallback branch is already tested, and the `'ios splits…'` test passes `iosStep: 1 / 30` explicitly, so it stays valid. Then rerun `flutter test test/features/ayah_share/data/repositories/reel_repository_impl_test.dart`, `flutter test` and `flutter analyze --no-fatal-infos` before Step 6. Note the change in the commit body.
  - Delete `lib/reel_probe_main.dart` and confirm that `git status --short lib` does not list it. Run `df -h .`, then `flutter clean` if less than 5 GB is free.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/core/errors/failure.dart lib/features/ayah_share/domain/entities/reel_request.dart lib/features/ayah_share/domain/repositories/reel_repository.dart lib/features/ayah_share/domain/usecases/compose_ayah_reel.dart lib/features/ayah_share/data/repositories/reel_repository_impl.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/domain/entities/reel_request_test.dart test/features/ayah_share/data/repositories/reel_repository_impl_test.dart test/features/ayah_share/ayah_share_di_test.dart
git add lib/core/errors/failure.dart lib/features/ayah_share/domain/entities/reel_request.dart lib/features/ayah_share/domain/repositories/reel_repository.dart lib/features/ayah_share/domain/usecases/compose_ayah_reel.dart lib/features/ayah_share/data/repositories/reel_repository_impl.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/domain/entities/reel_request_test.dart test/features/ayah_share/data/repositories/reel_repository_impl_test.dart test/features/ayah_share/ayah_share_di_test.dart
git commit -m "feat(ayah-share): reel repository with two-pass render, audio-offset sync and cleanup

iOS simulator: <remainder frame result; step used>.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Reel frames (seam 8, part 1)

**Files:**
- Create: `lib/features/ayah_share/presentation/utils/reel_frame_painter.dart`
- Modify: `lib/features/ayah_share/presentation/utils/share_card_renderer.dart` (extract the paint steps; behaviour unchanged), `lib/features/ayah_share/presentation/utils/ayah_share_text.dart` (add `reelFooter`), `lib/features/ayah_share/ayah_share_di.dart`
- Create (test): `test/features/ayah_share/presentation/utils/reel_frame_painter_test.dart`
- Modify (test): `test/features/ayah_share/presentation/utils/ayah_share_text_test.dart` (add one)

**Interfaces:**
- Consumes: `ShareCardCrops`, `ShareCardLayout` (`textBottom`, `pitch`), `shareCardWidth`, `shareCardMargin`, `shareCardTafsirGap`, `MushafPaperColors`, `Reciter.arabicName`.
- Produces:
  - In `share_card_renderer.dart`, extracted from `compose`, which now calls them:
    - `const shareCardTextWidth = (shareCardWidth - 2 * shareCardMargin) / 3;`
    - `void paintCardPieces(Canvas canvas, ShareCardCrops crops, MushafPaperColors colors)` (the tint loop)
    - `TextPainter layoutTafsirHeading(MushafPaperColors colors)`: «التفسير الميسر» in `TS.bold14` with `colors.accent`, centred RTL, laid out at `shareCardTextWidth`. It does not depend on the body.
    - `({TextPainter heading, TextPainter body}) layoutTafsirBlock(String body, MushafPaperColors colors, TextStyle style)`: calls `layoutTafsirHeading(colors)`, and lays out the body at `shareCardTextWidth` with `style.copyWith(color: colors.ink2)`. `style` carries no colour: S1's `compose` passes `tafsirBodyStyle(tafsir)`, the reel passes `reelTafsirStyle`.
    - `double tafsirBlockHeight(({TextPainter heading, TextPainter body}) block)` = `36 + 3 * (heading.height + 8 + body.height)`
    - `void paintTafsirBlock(Canvas canvas, double top, ({TextPainter heading, TextPainter body}) block, MushafPaperColors colors)` (the rule, the diamond and the text at `top + 36` inside `scale(3)`)
  - In `reel_frame_painter.dart`:
    - `const reelWidth = 1080.0;`, `const reelHeight = 1920.0;`, `const reelFooterPad = 24.0;`
    - `final reelTafsirStyle = TS.regular12.copyWith(height: 1.8);`
    - `typedef ReelFrameGeometry = ({double scale, double tafsirMaxHeight});`
    - `ReelFrameGeometry reelFrameGeometry(ShareCardLayout layout, {required double footerHeight, required double headingHeight})`
    - `String? fitReelTafsir(String body, {required double maxHeight})`
    - `class ReelFramePainter { Future<Uint8List> paint(ShareCardCrops crops, {required MushafPaperColors colors, required String footer, String? tafsir}); }`
  - In `ayah_share_text.dart`: `String reelFooter(Reciter reciter, AyahIdentifier first, int count)` → `'${reciter.arabicName} · سورة ${quran.getSurahNameArabic(s)} $range'`. `range` is `a` or `a–(a+count−1)` (en dash), with digits from `toIndicNumerals('ar')`.

Rules (card px unless marked logical):
- `available = reelHeight − footerHeight`, `block = layout.textBottom + shareCardMargin`.
- If `block > available`: `scale = available / block` and `tafsirMaxHeight = 0` (no tafsir).
- Otherwise `scale = 1` and `tafsirMaxHeight` (logical) = `(available − shareCardMargin − tafsirTop − 36) / 3 − headingHeight − 8`, where `tafsirTop = layout.textBottom + shareCardTafsirGap · layout.pitch`.
- `fitReelTafsir`: lay out `reelTafsirStyle` at `shareCardTextWidth` RTL. Let `line` be its `preferredLineHeight`.
  - `maxHeight < 3 · line` → `null`.
  - The whole body fits → the body.
  - Otherwise take the longest prefix ending at a `.` that is followed by whitespace or the end, plus `' …'`, that fits. If none fits, take the longest whole-word prefix plus `' …'`.
- `paint`:
  - Measure the footer (`TS.regular10`, `colors.ink2`, centred, RTL, width `shareCardTextWidth`). `footerHeight = 3 · footer.height + 2 · reelFooterPad`.
  - When `tafsir != null`: `final probe = layoutTafsirHeading(colors);` read `probe.height`, dispose it, then `reelFrameGeometry(layout, footerHeight:, headingHeight: probe.height)`, then `fitReelTafsir(tafsir, maxHeight: geometry.tafsirMaxHeight)`, then, when that is non-null, `layoutTafsirBlock(fitted, colors, reelTafsirStyle)`. Without tafsir, call `reelFrameGeometry` with `headingHeight: 0`.
  - The content height is `tafsirTop + tafsirBlockHeight + shareCardMargin` with tafsir, or `block · scale` without. `dy = (available − content) / 2`.
  - Paint the background, then `save → translate((1080 − 1080·scale)/2, dy) → scale(scale) → paintCardPieces → paintTafsirBlock? → restore`.
  - Paint the footer at `translate(shareCardMargin, reelHeight − reelFooterPad − 3·footer.height)` inside `scale(3)`.
  - Export a 1080×1920 PNG. Dispose the painters, picture and image in a `finally`.

- [ ] **Step 1: Write the failing tests**
  - `reel_frame_painter_test.dart`, with `const deviceFooter = 3 * 18.75 + 2 * reelFooterPad;` (Cairo 10 pt; the test font is shorter):
    - `'a short card keeps its size and leaves room for tafsir'`: `reelFrameGeometry(layoutFor(6, 31), footerHeight: deviceFooter, headingHeight: 25)` → `scale` 1 and `tafsirMaxHeight > 3 * 21.6`.
    - `'2:282 shrinks into the space above the footer'`: `scale` closeTo `(1920 − deviceFooter) / (layoutFor(2, 282).textBottom + 72)` (1e-9), < 1, and `tafsirMaxHeight` 0.
    - `'only 2:282 and 4:12 are scaled'`: over every ayah of the 114 surahs (`quran.getVerseCount`), the set of ayat with `scale < 1` equals `{2:282, 4:12}`.
    - `'a tafsir that fits stays whole'`: `fitReelTafsir('جملة قصيرة.', maxHeight: 400)` equals the input.
    - `'a long tafsir is cut after the last full sentence that fits'`: with `body = List.generate(60, (i) => 'هذه جملة رقم $i.').join(' ')` and `maxHeight` = 5 preferred lines, the result ends with `. …`, is a prefix of the body plus `' …'`, and lays out ≤ `maxHeight`.
    - `'fewer than three lines of room drops the tafsir'`: 2.5 lines → `null`.
    - `'with no sentence end in reach it cuts at a word'`: one 300-word sentence with a single final `.` and 4 lines of room → it ends with ` …` and has no `.`.
    - `'a frame is a 1080×1920 PNG on the paper'`: in `tester.runAsync`, `ReelFramePainter().paint(ShareCardCrops(layout: layoutFor(6, 31), pieces: const [], basmalaOpacity: 0.42), colors: MushafPaper.night.colors, footer: 'x', tafsir: 'جملة.')` decodes to 1080×1920, and pixel (2, 2) is `MushafPaper.night.colors.background`.
    - `'a tall card with a long tafsir still exports 1080×1920'`: `layoutFor(2, 282)` with the 60-sentence body → 1080×1920 with no exception.
  - `ayah_share_text_test.dart`, `'the reel footer credits the reciter with Arabic digits'`:
    - `reelFooter(Reciter.alafasy, 6:31, 1) == '${Reciter.alafasy.arabicName} · سورة ${quran.getSurahNameArabic(6)} ٣١'`
    - `(2:255, 3)` ends with `٢٥٥–٢٥٧`.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/utils/reel_frame_painter_test.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**
  - Extract the five renderer helpers. `test/features/ayah_share/presentation/utils/share_card_renderer_test.dart` must pass **unchanged**.
  - Add `reel_frame_painter.dart` and `reelFooter`.
  - Register `sl.registerLazySingleton(() => ReelFramePainter());` in `initAyahShare()`.

- [ ] **Step 4: Verify** the two files and `share_card_renderer_test.dart`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, +10 → 1799. If `'only 2:282 and 4:12 are scaled'` fails, follow Deliberate reading 8 (`reelFooterPad` 20, then 16, else stop and report) and add `reelFooterPad = <value>` to the commit body.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/utils/reel_frame_painter.dart lib/features/ayah_share/presentation/utils/share_card_renderer.dart lib/features/ayah_share/presentation/utils/ayah_share_text.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/presentation/utils/reel_frame_painter_test.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart
git add lib/features/ayah_share/presentation/utils/reel_frame_painter.dart lib/features/ayah_share/presentation/utils/share_card_renderer.dart lib/features/ayah_share/presentation/utils/ayah_share_text.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/presentation/utils/reel_frame_painter_test.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart
git commit -m "feat(ayah-share): 1080x1920 reel frames with the reciter footer and a tafsir cut at a full sentence

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Reel audio, segments and caps (seam 8, part 2)

**Files:**
- Create: `lib/features/ayah_share/domain/entities/reel_segment.dart`, `lib/features/ayah_share/domain/usecases/prepare_ayah_audio.dart`
- Modify: `lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart`, `lib/features/ayah_share/presentation/cubit/ayah_share_state.dart`, `lib/features/ayah_share/ayah_share_di.dart`
- Create (test): `test/features/ayah_share/domain/usecases/prepare_ayah_audio_test.dart`
- Modify (tests): `test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart` (rewrite `setUp`, add a `reel` group), `test/features/ayah_share/ayah_share_fakes.dart` (new fakes, rewrite `registerFakeAyahShare`), `test/features/ayah_share/ayah_share_di_test.dart` (register a `QuranPlaybackRepo` stub)

**Interfaces:**
- Consumes: `QuranPlaybackRepo.prepareAyahAudio({required AyahIdentifier ayah, required Reciter reciter})`, `ReelRepository.audioDuration`, `ReelAudio` (Task 2), `ReelFramePainter.paint` and `reelFooter` (Task 3).
- Produces:
  - `const reelMaxAyat = 10;`, `const reelMaxDuration = Duration(seconds: 60);`
  - `class ReelSegment extends Equatable { const ReelSegment({required ShareCardContent content, required List<ReelAudio> audio}); AyahIdentifier get ayah; Duration get duration; }`
  - `class PrepareAyahAudio { PrepareAyahAudio({required QuranPlaybackRepo playback, required ReelRepository reels}); Future<Either<Failure, List<ReelAudio>>> call(AyahIdentifier ayah, Reciter reciter); }`. For `ayah.ayah == 1 && surah ∉ {1, 9}` it prepares and measures `1:1` first, then the ayah. The first `Left` is returned.
  - State additions:
    - `enum ShareFormat { image, reel }`
    - `enum ReelIssue { none, audioFailed, encodeFailed }`
    - `ShareExport` gains `preparing` and `encoding`.
    - Fields: `format` (default `image`), `reciter` (`Reciter?`), `reelSegments` (`List<ReelSegment>`, default `const []`), `reelCapped` (`bool`), `reelIssue` (default `none`). All of them go in `props` and `copyWith`. A `copyWith(reciter:)` that must keep the value uses `??`, since the reciter is never cleared.
    - Getters: `reelCount`; `reelDuration`; `reelOverLimit` (`reelDuration > reelMaxDuration`); `reelWorking` (`export == ShareExport.preparing || export == ShareExport.encoding`).
    - `canAddAyah`: reel format, `!busy`, segments non-empty, `!reelCapped`, `reelCount < reelMaxAyat`, `reelDuration < reelMaxDuration`, and the last ayah below `quran.getVerseCount(surah)`.
    - `canRemoveAyah`: reel format, `!busy`, `reelCount > 1`.
    - `busy` adds `preparing` and `encoding`; `progress` adds `preparing`.
  - Cubit:
    - The constructor adds `required PrepareAyahAudio prepareAudio, required ReelFramePainter framePainter`.
    - `Future<void> selectReel(Reciter reciter)`, `void selectImage()`, `Future<void> addAyah()`, `void removeAyah()`.
    - Private: `final _segmentCrops = <AyahIdentifier, ShareCardCrops>{}`, keyed by each later segment's ayah. Segment 0 uses `_crops`. All of them are disposed in `close()`, on a reciter reset, and on `removeAyah` for the removed one.
    - `_compose()`: first, `if (state.export == ShareExport.sharing || state.reelWorking) { _composeDeferred = true; return; }` (Deliberate reading 12). Then it paints the reel frame when `format == reel && reelSegments.isNotEmpty`, and the image card otherwise. Reel calls `_framePainter.paint(_crops!, colors: state.paper.colors, footer: reelFooter(state.reciter!, ayah, state.reelCount), tafsir: withTafsir ? state.tafsir : null)`.
    - `void _settle(AyahShareState next)`: `emit(next)`, then if `_composeDeferred`, clear it and `_compose()`. Every exit from `preparing` that does not compose right after goes through it. Below, `_settle(x: …)` is shorthand for `_settle(state.copyWith(x: …))`.
    - `setPaper`, `setIncludeTafsir` and `selectImage` return while `state.reelWorking` (Deliberate reading 12). `addAyah` and `removeAyah` are guarded by `canAddAyah` / `canRemoveAyah`.
  - Fakes:
    - `FakePrepareAyahAudio` holds `Map<AyahIdentifier, Duration> durations` (default 5 s), `Set<AyahIdentifier> failing`, `List<AyahIdentifier> requests` and an optional `Completer<void>? gate` awaited before it answers. It returns `[ReelAudio('/a/<s>_<a>.mp3', d)]`, with basmala `('/a/1_1.mp3', 6 s)` first when `ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9`, the same rule as `PrepareAyahAudio`.
    - `FakeReelFramePainter` records `calls`, a list of `(crops, colors, footer, tafsir)`, and returns `onePixelPng`.
    - `registerFakeAyahShare` gains `prepareAudio` and `framePainter` and keeps its record shape plus the two new fields.

`selectReel(reciter)`:
1. Return unless `status == ready && !busy && format == image`.
2. If `reciter != state.reciter`, dispose the segment crops and emit `reelSegments: const [], reelCapped: false`.
3. Emit `format: reel, reciter, reelIssue: none`.
4. If there are no segments, emit `preparing`, then `await _prepareAudio(ayah, reciter)`, then `if (isClosed) return;`.
   - On `Left`, `_settle(format: image, export: idle, reelIssue: audioFailed)` and return. `cardBytes` is still the image card, because the reel frame is never composed with zero segments (the deferral holds any recompose until here), and `_settle` runs a recompose that was deferred meanwhile, as the image.
   - On `Right`, clear `_composeDeferred` and emit `reelSegments: [ReelSegment(content: _content!, audio)], export: idle`.
5. `await _compose()`.

`addAyah()`:
1. Guard `canAddAyah`, then emit `export: preparing, reelIssue: none`, so a second failure fires the listener again. `next` is `AyahIdentifier(surah: last.surah, ayah: last.ayah + 1)`, where `last` is `reelSegments.last.ayah`.
2. Audio, then content, then `_renderer.prepare` (catching exceptions). After each await, if the cubit is closed, dispose what it holds and return.
3. Any failure → `_settle(export: idle, reelIssue: audioFailed)`.
4. If `reelDuration + segment.duration > reelMaxDuration`, dispose the crops and `_settle(reelCapped: true, export: idle)`.
5. Otherwise store the crops under `next`, append the segment, clear `_composeDeferred`, emit `export: idle` and `_compose()` (the footer range changes).

`selectImage()`:
1. Return if `state.reelWorking` or `format == image`.
2. Emit `format: image, reelIssue: none`. The segments, `_segmentCrops` and `reelCapped` are kept, so going back to the reel with the same reciter prepares nothing.
3. `_compose()`.

`removeAyah()`:
1. Guard `canRemoveAyah`.
2. Remove and dispose `_segmentCrops[last.ayah]`.
3. Emit the segments without the last one and `reelCapped: false`.
4. `_compose()` (the footer range changes).

- [ ] **Step 1: Write the failing tests**
  - `prepare_ayah_audio_test.dart` (fake `QuranPlaybackRepo` via `noSuchMethod` plus `prepareAyahAudio`, and a fake `ReelRepository` with durations per path):
    - `'ayah 1 of most surahs gets the basmala first'`: 2:1 → `[ReelAudio(basmalaPath, 6.031 s), ReelAudio(path2_1, 3.2 s)]`, with requests `[1:1, 2:1]`.
    - `'surahs 1 and 9 start without a basmala'`: 1:1 → one item; 9:1 → one item.
    - `'a later ayah is its own audio'`: 2:255 → one item.
    - `'a download failure is returned'`: `Left(NetworkFailure)` for 2:1's ayah → `Left`.
    - `'a duration failure is returned'`.
  - `ayah_share_cubit_test.dart`:
    - Add `late FakePrepareAyahAudio audio;` and `late FakeReelFramePainter painter;`, created in `setUp`, and pass them as `prepareAudio:` and `framePainter:` to the `setUp` cubit (still on 1:1 with `contentFor(1, 1)`, so the S1 tests are unchanged).
    - Add a local helper `Future<AyahShareCubit> reelCubit(AyahIdentifier a)`. It sets `content.result = null`, so `FakeGetShareCardContent` echoes each requested ayah and every segment carries its own `ayah`. It builds an `AyahShareCubit(ayah: a, paper: MushafPaper.cream, …)` with the same fakes, rebinds `states = []` and listens to it, registers `addTearDown(c.close)`, then `await c.load(); await pumpEventQueue();` and returns it. The `setUp` cubit is still closed by the existing `tearDown`.
    - Every test in `group('reel')` uses `reelCubit(...)`: 1:1 where no ayah is named, 112:4 and 2:1 where named.
  - In `group('reel')`, using `Reciter.alafasy`:
    - `'choosing the reel prepares the start ayah and previews its first frame'`: `format` reel, one segment, the painter called once with footer `reelFooter(Reciter.alafasy, ayah, 1)`, `renderId` incremented.
    - `'an audio failure returns to the image with an audio issue'`: `format` image, `reelIssue` audioFailed, `cardBytes` non-null.
    - `'adding an ayah prepares the next one and widens the footer range'`: 2 segments, and the last painter footer ends with `–٢` (start 1:1 in this test's cubit).
    - `'a failing «+» raises the audio issue each time'`: with 1:2 in `failing`, two `addAyah()` calls → the emitted `reelIssue` values are `none, audioFailed, none, audioFailed`, and `reelCount` stays 1.
    - `'«+» prepares only once on a double tap'`: with the gate open, `addAyah(); addAyah();` → `requests` grows by one.
    - `'«+» is disabled at the surah end'`: a cubit on 112:4 → `canAddAyah` false.
    - `'«+» is disabled at ten ayat'`: a cubit on 2:1 with 3 s durations, after 9 adds → `reelCount` 10 and `canAddAyah` false.
    - `'a start ayah over 60 s is allowed alone and blocks «+»'`: 75 s → `reelCount` 1, `reelOverLimit` true, `canAddAyah` false.
    - `'an ayah that would pass 60 s is not added'`: 40 s + 25 s → `reelCount` 1, `reelCapped` true, the prepared crops disposed.
    - `'removing an ayah disposes its crops and reopens «+»'`.
    - `'back to the image recomposes the card from the same crops'`: `renderer.prepareCount` unchanged, `composeCalls` + 1.
    - `'another reciter drops the old segments'`.
    - `'close disposes every segment crop'`.
    - `'a tafsir landing mid-prepare keeps preparing'`: on 1:1, `setIncludeTafsir(true)` (the tafsir completer is held), hold `audio.gate`, `selectReel`. Complete the tafsir with `Right(intro)` → `export` stays `preparing`, `canAddAyah` false, and neither `renderer.composeCalls` nor `painter.calls` grows. Open the gate → one painter call with `tafsir: intro.body` and `export` idle.
    - `'an audio failure after a deferred tafsir composes the image card'`: the same with 1:1 in `failing` → `format` image, `reelIssue` audioFailed, the last `renderer.composeCalls` entry has `tafsir: intro.body`, and `painter.calls` is empty.
  - `ayah_share_di_test.dart`: register `sl.registerLazySingleton<QuranPlaybackRepo>(_StubPlaybackRepo.new)` (`noSuchMethod`). The existing test keeps its assertions.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/domain/usecases/prepare_ayah_audio_test.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** the entity, the use case, the state and the cubit with the shapes above. DI:
  - `sl.registerLazySingleton(() => PrepareAyahAudio(playback: sl(), reels: sl()));`
  - pass `prepareAudio: sl(), framePainter: sl()` to the cubit factory.

- [ ] **Step 4: Verify** `flutter test test/features/ayah_share test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/bookmarks`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, +20 → 1819.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/domain/entities/reel_segment.dart lib/features/ayah_share/domain/usecases/prepare_ayah_audio.dart lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart lib/features/ayah_share/presentation/cubit/ayah_share_state.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/domain/usecases/prepare_ayah_audio_test.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart test/features/ayah_share/ayah_share_fakes.dart test/features/ayah_share/ayah_share_di_test.dart
git add lib/features/ayah_share/domain/entities/reel_segment.dart lib/features/ayah_share/domain/usecases/prepare_ayah_audio.dart lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart lib/features/ayah_share/presentation/cubit/ayah_share_state.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/domain/usecases/prepare_ayah_audio_test.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart test/features/ayah_share/ayah_share_fakes.dart test/features/ayah_share/ayah_share_di_test.dart
git commit -m "feat(ayah-share): reel segments with basmala audio, measured durations and the 10-ayah / 60 s caps

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Encode, cancel and share in the cubit (seam 9, part 1)

**Files:**
- Modify: `lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart`, `lib/features/ayah_share/presentation/cubit/ayah_share_state.dart`, `lib/features/ayah_share/ayah_share_di.dart`
- Modify (tests): `test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart` (extend `setUp` and `reelCubit`, add `group('encode')`), `test/features/ayah_share/ayah_share_fakes.dart` (`FakeComposeAyahReel`)

**Interfaces:**
- Consumes: `ComposeAyahReel` (Task 2), `ReelRequest` / `ReelClip`, `ReelSegment.audio`, `GetAyahTafsir`, `ScreenWake.hold(Object owner, {required bool on})`.
- Produces:
  - State fields `encodeProgress` (`double`, default 0) and `reelPath` (`String?`), both in `props`.
  - The constructor adds `required ComposeAyahReel composeReel, ScreenWake screenWake = const ScreenWake()`.
  - `Future<void> requestShare()` branches on `format`; image is unchanged.
  - `void cancelEncode()`.
  - `close()` also calls `_composeReel.cancel()` and `_reelToken?.cancel()`.
  - `FakeComposeAyahReel` holds `requests`, a `Completer<Either<Failure, String>>? completer` (default `Right('/reels/<fileName>')`), a `StreamController<double>.broadcast() progressCtrl` and `cancels`. Like the repository, `cancel()` completes a pending `completer` with `Left(ReelCancelledFailure())`. `registerFakeAyahShare` gains `composeReel`.

`Future<void> requestShare()` in reel format (S1's `void requestShare()` becomes `Future<void>`; the image path is unchanged and still emits `sharing` synchronously):
1. Return unless `ready`, `!busy` and the segments are non-empty.
2. `final generation = ++_encodeGeneration;`, then emit `export: encoding, encodeProgress: 0, reelIssue: none`. Capture `final withTafsir = state.includeTafsir && state.tafsirStatus == ShareTafsirStatus.ready;` (Deliberate reading 5).
3. Open the `try` (its `finally` is step 7) and, inside it, subscribe to `_composeReel.progress`, emitting `encodeProgress` (`if (isClosed) return;` first in the callback), then `await _wake.hold(this, on: true)` followed by the guard.
4. The **guard**, used after every await inside the `try`: `if (isClosed) return;` then `if (generation != _encodeGeneration) { _settle(export: idle, encodeProgress: 0, reelIssue: none); return; }`.
5. Still in the `try`, for each segment i (`crops_i` is `_crops!` for i == 0, `_segmentCrops[seg.ayah]!` otherwise):
   - tafsir: `null` when `!withTafsir`; `state.tafsir` for i == 0; otherwise `(await _getTafsir(surah: seg.ayah.surah, ayah: seg.ayah.ayah, page: seg.content.page, cancelToken: _reelToken ??= CancelToken())).fold((_) => null, (t) => t.body)`, followed by the guard.
   - `frame = await _framePainter.paint(crops_i, colors: state.paper.colors, footer: reelFooter(state.reciter!, ayah, state.reelCount), tafsir: tafsir)`, followed by the guard.
6. `result = await _composeReel(ReelRequest(first: ayah, clips: …))`, called synchronously right after the last guard, followed by the guard. Only when the generation still matches is the result mapped:
   - `Left(ReelCancelledFailure)` → `_settle(export: idle, encodeProgress: 0, reelIssue: none)`
   - other `Left`, or an error thrown anywhere in the `try` (caught, then `if (isClosed) return;`) → `_settle(export: idle, encodeProgress: 0, reelIssue: encodeFailed)`
   - `Right(path)` → emit `export: sharing, reelPath: path` (plain emit: a deferred compose stays deferred until `shareFinished`)
7. In a `finally`, cancel the subscription, then `_wake.hold(this, on: false)`. Both run on every exit, including the guard's returns.

A `Right(path)` dropped by the guard (the render finished just as the cancel landed) is never shared. Its file stays in `reels/` until the next compose deletes that directory, the same lifetime as any finished reel (Deliberate reading 6).

`cancelEncode()`: return unless `encoding`. Then `_encodeGeneration++`, `_reelToken?.cancel()`, `_reelToken = null` and `_composeReel.cancel()`. It does **not** emit: `export` stays `encoding`, so «مشاركة» stays disabled until the running `requestShare` unwinds. That run hits the guard after its next await, whether that await returns a painted frame, a tafsir, or `Left(ReelCancelledFailure)` from the cancelled render. The guard emits `export: idle, encodeProgress: 0, reelIssue: none` through `_settle`, and the `finally` releases the wake. A second encode therefore never overlaps the first's `work/<n>` cleanup or wake release.

- [ ] **Step 1: Write the failing tests**
  - Extend `setUp`: `late FakeComposeAyahReel compose;` and `late FakeScreenWake wake;` (from `mushaf_page_harness.dart`), both created fresh in `setUp`, and pass `composeReel: compose, screenWake: wake` to the `setUp` cubit. `reelCubit(...)` passes the same two, so `wake.calls` and `compose.requests` / `compose.cancels` are asserted through these fields.
  - In `group('encode')`, a reel of 2:255–2:256 built with `reelCubit(const AyahIdentifier(surah: 2, ayah: 255))` plus one `addAyah()`, with the tafsir off unless stated. The 2:1 test builds `reelCubit(const AyahIdentifier(surah: 2, ayah: 1))`.
  - `'share paints every segment and sends one request'`: painter calls 1 (preview) + 2 (encode). `request.first` is 2:255. `clips.length` is 2. The clips' audio equals the segments' audio.
  - `'the basmala leads the first clip of a reel from ayah 1'`: a cubit on 2:1 → `clips.first.audio.first.path` is the basmala path.
  - `'encode progress is mirrored into the state'`: `progressCtrl.add(0.4)` → `encodeProgress` 0.4.
  - `'a finished encode hands the path to the share listener'`: `export` sharing, `reelPath` `/reels/ayah_2_255-256.mp4`, then `shareFinished(ok: true)` → done.
  - `'cancel waits for the render to stop, then frees share'`: with a held completer, `cancelEncode()` → `cancels` 1, and `export` is still encoding with `canAddAyah` false. After `pumpEventQueue()` (the fake completes it as cancelled): `export` idle, `reelIssue` none, `wake.calls == [true, false]`. A new `requestShare()` → a second request.
  - `'an encode failure raises encodeFailed and share retries'`: `Left(UnknownFailure('x'))` → `reelIssue` encodeFailed. `requestShare()` → second request.
  - `'the screen stays awake only while encoding'`: `wake.calls == [true, false]` after success, and again after failure.
  - `'with the tafsir on each later ayah loads its own and a failure draws it without'`: switch on and the start tafsir ready. Encoding requests the tafsir of 2:256. Completing it with `Left` → that painter call has `tafsir: null`, and the start ayah's call has `state.tafsir`.
  - `'toggles are ignored while encoding'`: during `encoding`, `setPaper(night)`, `setIncludeTafsir(true)`, `selectImage()` and `addAyah()` change nothing, and `export` stays encoding.
  - `'close cancels a running encode and releases the wake'`.
  - `'a tafsir landing mid-encode does not leave encoding'`: `setIncludeTafsir(true)` with the start tafsir held (loading), then `requestShare()` with a held `compose.completer`. Complete the start tafsir with `Right(intro)` → `export` stays `encoding`, `renderer.composeCalls` and `painter.calls` do not grow, and every encode painter call had `tafsir: null`. Complete the render with `Right` → `sharing`; `shareFinished(ok: true)` → the deferred compose runs once, painting the reel frame with the tafsir.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** with the shapes above. DI passes `composeReel: sl()`.

- [ ] **Step 4: Verify** `flutter test test/features/ayah_share`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, +11 → 1830.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart lib/features/ayah_share/presentation/cubit/ayah_share_state.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart test/features/ayah_share/ayah_share_fakes.dart
git add lib/features/ayah_share/presentation/cubit/ayah_share_cubit.dart lib/features/ayah_share/presentation/cubit/ayah_share_state.dart lib/features/ayah_share/ayah_share_di.dart test/features/ayah_share/presentation/cubit/ayah_share_cubit_test.dart test/features/ayah_share/ayah_share_fakes.dart
git commit -m "feat(ayah-share): encode the reel with progress, cancel and a held screen wake

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Sheet reel mode (seam 9, part 2)

**Files:**
- Modify: `lib/features/ayah_share/presentation/widgets/ayah_share_sheet.dart`, `lib/features/ayah_share/presentation/utils/ayah_share_text.dart` (add `reelShareLabel`), `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`, `.claude/rules/feature-widgets.md`
- Modify (tests): `test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart` (rewrite `open()` and `expectDisabled`, add reel tests), `test/features/ayah_share/presentation/utils/ayah_share_text_test.dart` (add one)

**Interfaces:**
- Consumes: the Task 4/5 cubit API, `PlaybackCubit.state.reciter`, `AppSegmentedSelector`/`SegmentOption`, `ShareCardPreview` (unchanged), `FakePlayback` (`mushaf_page_harness.dart`).
- Produces:
  - `String reelShareLabel(BuildContext context, AyahIdentifier first, int count)`: for `count == 1` it is `ayahLabel(context, first, S.current)`. Otherwise it is `PendingS.current.ayah_range_label(surahDisplayName(context, s), first.ayah.toLocalized(context), (first.ayah + count - 1).toLocalized(context))`.
  - Strings (ar / en):

    | Key | Arabic | English |
    |---|---|---|
    | `ayahShare_image` | «صورة» | "Image" |
    | `ayahShare_reel` | «مقطع بالتلاوة» | "Recitation clip" |
    | `ayahShare_ayahCount` | «عدد الآيات» | "Number of ayat" |
    | `ayahShare_addAyah` | «إضافة آية» | "Add an ayah" |
    | `ayahShare_removeAyah` | «حذف آية» | "Remove an ayah" |
    | `ayahShare_recitedBy(String reciter)` | «بصوت {reciter}» | "Recited by {reciter}" |
    | `ayahShare_longClip` | «قد تقصّ بعض التطبيقات المقاطع الأطول من ٦٠ ثانية» | "Some apps may trim clips longer than 60 seconds" |
    | `ayahShare_encoding` | «جارٍ تجهيز المقطع» | "Preparing the clip" |
    | `ayahShare_encodeFailed` | «تعذّر تجهيز المقطع» | "Couldn't prepare the clip" |
    | `ayahShare_audioFailed` | «تعذّر تحميل التلاوة» | "Couldn't load the recitation" |
    | `ayah_range_label(String surah, String from, String to)` | «سورة {surah}، الآيات {from}–{to}» | "Surah {surah}, Ayat {from}–{to}" |

Sheet changes, keeping the S1 order and adding to it:
- Under the preview: `AppSegmentedSelector<ShareFormat>` (key `share-format`, `expand: true`, `enabled: ready && !busy`). `onChanged`: reel → `cubit.selectReel(context.read<PlaybackCubit>().state.reciter)`; image → `cubit.selectImage()`.
- A private `_ReelControls` (`BlocSelector` on `(format, reelCount, canAddAyah, canRemoveAyah, reciter, reelOverLimit)`) that renders `SizedBox.shrink()` unless `format == reel && reelCount > 0`, so no «٠» count shows while the start ayah is prepared or flashes before an audio failure returns to the image:
  - a row: the `ayahShare_ayahCount` label, then `IconButton` `reel-minus` (`HugeIcons.strokeRoundedMinusSign`, tooltip `ayahShare_removeAyah`), the count `toLocalized`, and `IconButton` `reel-plus` (`strokeRoundedPlusSign`, tooltip `ayahShare_addAyah`);
  - a caption with `ayahShare_recitedBy(reciter.arabicName)`;
  - `ayahShare_longClip` when `reelOverLimit`.
  - Captions use `TS.regular12` with `onSurfaceVariant`.
- While `export == encoding`, a private `_EncodeRow` (key `reel-encoding`): the `ayahShare_encoding` text, `LinearProgressIndicator(value: encodeProgress)` and a `TextButton` `reel-cancel` (`places_cancel`) → `cubit.cancelEncode`.
- When `format == reel && reelIssue == encodeFailed` (and not encoding), an inline `ayahShare_encodeFailed` plus `TextButton.icon` `reel-retry` (`mushaf_retry`) → `cubit.requestShare`. `selectImage` also resets `reelIssue`, so the row never lingers in image mode.
- The swatches and the tafsir switch are also disabled while `reelWorking`. They stay enabled during an S1 recompose.
- Listeners: replace the single `BlocListener` with a `MultiBlocListener` of two, so a `reelIssue` change never re-runs a stale `export` and a stale `audioFailed` never re-shows on a later `export` change:
  - the existing one, unchanged: `listenWhen: (a, b) => a.export != b.export`, `listener: _onExport`;
  - a new one: `listenWhen: (a, b) => a.reelIssue != b.reelIssue && b.reelIssue == ReelIssue.audioFailed`, whose listener only shows a SnackBar with `PendingS.current.ayahShare_audioFailed` in the sheet's messenger.
  - In `_onExport` sharing with `format == reel`, run `SharePlus.instance.share(ShareParams(files: [XFile(state.reelPath!, mimeType: 'video/mp4')], text: reelShareLabel(context, widget.ayah, state.reelCount), sharePositionOrigin: origin))`, then `shareFinished(ok:)`.

`feature-widgets.md`:
- Extend the `ayah_share` exception line with `quran_playback`'s `QuranPlaybackRepo` and `Reciter` (reel audio, through `PrepareAyahAudio`), and `PlaybackCubit.state.reciter`, read by the sheet when the reel is chosen.
- In the `ayah_share` utils line, add `reel_frame_painter.dart` (`ReelFramePainter`, `reelFrameGeometry`, `fitReelTafsir`: 1080×1920 reel frames with the footer and the tafsir cut). Add `reelFooter` and `reelShareLabel` to the `ayah_share_text.dart` entry.

- [ ] **Step 1: Write the failing tests**
  - Rewrite `open()` to wrap the app in `MultiBlocProvider` with the `SettingsCubit` value and `BlocProvider<PlaybackCubit>.value(value: FakePlayback(const PlaybackState(reciter: Reciter.husary)))`. Rewrite `expectDisabled` to also expect `AppSegmentedSelector.enabled` false.
  - `ayah_share_sheet_test.dart`:
    - `'the selector offers صورة and مقطع بالتلاوة, image first'`.
    - `'choosing the reel shows the stepper and the reciter'`: tap «مقطع بالتلاوة», then `pumpUntil` the painter is called. `'بصوت ${Reciter.husary.arabicName}'` is shown, the count is `'١'`, and `reel-minus` is disabled.
    - `'«+» adds an ayah and «−» removes it'`: count `'٢'`, then `'١'`.
    - `'a start ayah over 60 s shows the trim caption and no «+»'`: durations 75 s → `ayahShare_longClip` text, and `reel-plus` `onPressed` null.
    - `'share encodes with progress, then shares the MP4 with the range label'`: two ayat, a held compose completer, tap «مشاركة» → `reel-encoding` is shown. `progressCtrl.add(0.5)` → `LinearProgressIndicator.value` 0.5. Complete with `Right(path)`, where `path` is an empty file `ayah_6_31-32.mp4` that the test creates in a temp dir, → `shared.single['paths']` single ends with `ayah_6_31-32.mp4`, `mimeTypes` is `['video/mp4']`, and the text is `'سورة ${quran.getSurahNameArabic(6)}، الآيات ٣١–٣٢'`.
    - `'in English a reel shares the English range label'`: `'Surah ${quran.getSurahName(6)}, Ayat 31–32'`.
    - `'cancel stops the encode without a message'`: tap `reel-cancel`, then `pumpUntil` `reel-encoding` is gone → `cancels` 1, no `SnackBar`, and «مشاركة» is enabled again.
    - `'an encode failure shows the message with a retry'`: `reel-retry` → a second request.
    - `'an audio failure shows the SnackBar and keeps the image'`: the start ayah is failing → SnackBar `'تعذّر تحميل التلاوة'` is findable while the sheet is open, and the selector shows image.
    - `'the audio SnackBar shows once'`: after that failure, let the SnackBar go (`ScaffoldMessenger.of(…).removeCurrentSnackBar()`, then `pump()`), then tap «مشاركة» for the image share → `find.text('تعذّر تحميل التلاوة')` finds nothing.
    - `'fits at 2x text in 360 px in reel mode with the trim caption'`: `takeException()` null.
  - `ayah_share_text_test.dart`, `'reelShareLabel names one ayah or the range'` (testWidgets, ar): count 1 equals the `ayah_label` text, and count 3 from 2:255 → `'سورة ${quran.getSurahNameArabic(2)}، الآيات ٢٥٥–٢٥٧'`.

- [ ] **Step 2: Run** `flutter test test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** the strings (both ARBs and `PendingS`, next to the `ayahShare_*` block), `reelShareLabel`, the sheet changes and `feature-widgets.md`.

- [ ] **Step 4: Verify**
  - Run `flutter test test/features/ayah_share test/core/localization/pending_s_test.dart test/config/theme/typography_ratchet_test.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_study_leaf_test.dart test/features/bookmarks`, then `flutter test`, then `flutter analyze --no-fatal-infos`. Expected: PASS, +12 → 1842 (the start + 71).
  - `git diff --stat lib/generated` is empty.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/ayah_share/presentation/widgets/ayah_share_sheet.dart lib/features/ayah_share/presentation/utils/ayah_share_text.dart lib/core/localization/pending_s.dart test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart
git add lib/features/ayah_share/presentation/widgets/ayah_share_sheet.dart lib/features/ayah_share/presentation/utils/ayah_share_text.dart lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart .claude/rules/feature-widgets.md test/features/ayah_share/presentation/widgets/ayah_share_sheet_test.dart test/features/ayah_share/presentation/utils/ayah_share_text_test.dart
git commit -m "feat(ayah-share): reel mode in the share sheet with stepper, first-frame preview, progress, cancel and share

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## After Task 6: S2 PR checks (owner or orchestrator, not a task)

From spec §6 and §7, recorded in the stacked PR into `feature/ayah-share`:
- The merged Android manifest permissions from Task 1.
- The iOS simulator remainder result and the step used, from Task 2.
- Encode times for a 60 s, 10-ayah reel on one real Android phone and one real iPhone.
- An Android reel shared to WhatsApp Status and Instagram plays upright.
- The Media3 lift (risk 6): play a surah range with the basmala, seek, background it with the media notification, interrupt it with a call or the adhan, then download a surah and play it offline. Any regression blocks S2 and falls back to `ffmpeg_kit_flutter_new_min`.
- Reinstall the real app on emulator-5554 and the iPhone 17 Pro simulator before QA, because the spike replaced it.
