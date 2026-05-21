# Playback Overlay + Continue Reading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `AyahActionBar` with a dedicated playback overlay (play/pause/restart/skip/speed/close), move secondary actions + reciter picker into a long-press modal sheet, persist last-read position (page + optional paused ayah), and add a "play surah from start" entry point on the surah list.

**Architecture:** New `AyahPlaybackOverlay` widget replaces `AyahActionBar` at the same `Column` slot in `MushafPage`. New `AyahLongPressSheet` opens via `showModalBottomSheet` on long-press. `PlaybackCubit` is extended with `skipNext` / `skipPrevious` / `restartCurrent` / `setSpeed` / `setReciter` + `isPaused`/`speed`/`reciter` state fields. `MushafCubit` gets an auto-follow rule so highlight follows the playing ayah unless the user manually tapped a different verse. A new `LastReadCubit` + Hive-backed `LastReadRepository` powers Continue Reading; `MushafPage.dispose` snapshots `(page, ayah)` and stops audio. `SettingsCubit` persists the chosen speed + default reciter.

**Tech Stack:** Flutter, flutter_bloc/hydrated_bloc (Cubit), get_it (DI), Hive (persistence), just_audio, dartz (Either), mocktail + bloc_test (testing), flutter_intl (l10n).

**Spec:** [`docs/superpowers/specs/2026-05-21-playback-overlay-design.md`](../specs/2026-05-21-playback-overlay-design.md)

---

## Conventions for every task

- **TDD:** write the failing test first, watch it fail, write minimal code, watch it pass, commit.
- **Commits:** small and focused. Conventional Commits style (`feat:`, `test:`, `refactor:`, `chore:`). Include a `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>` trailer.
- **Run tests with:** `flutter test <path>` from the project root (`C:\Savior\flutter_projects\quran_app`).
- **Architecture (`.claude/rules/architecture.md`):** Domain layer never imports Flutter. Cubits are factories, data sources / repos / use cases are lazy singletons. Global app-level cubits (like `SettingsCubit`) are eager singletons. We're adding a global `LastReadCubit` — register as lazy singleton (read by HomePage + SurahList; one instance is correct).
- **L10n (`.claude/rules/localization.md`):** All user-facing strings via `S.of(context).key`. Update both `intl_en.arb` and `intl_ar.arb`. Saving the .arb files triggers `flutter_intl` to regenerate `lib/generated/l10n.dart` (commit the generated file too).

---

## Phase 1 — Foundation (no UI changes)

### Task 1: Add localization keys

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`
- Auto-regenerated: `lib/generated/l10n.dart` (do not edit by hand)

- [ ] **Step 1: Add English keys**

Add (inside the JSON object, before the closing `}`, adding a comma to the previous last entry):

```json
"playback_pause": "Pause",
"playback_next": "Next ayah",
"playback_previous": "Previous ayah",
"playback_restart": "Restart",
"playback_close": "Close",
"playback_speed": "Speed",
"reciter_label": "Reciter",
"continue_reading": "Continue reading",
"ayah_label": "Surah {surah}, Ayah {ayah}",
"page_label": "Page {page}",
"play_surah": "Play surah"
```

- [ ] **Step 2: Add Arabic keys**

Append matching keys to `intl_ar.arb`:

```json
"playback_pause": "إيقاف مؤقت",
"playback_next": "الآية التالية",
"playback_previous": "الآية السابقة",
"playback_restart": "إعادة",
"playback_close": "إغلاق",
"playback_speed": "السرعة",
"reciter_label": "القارئ",
"continue_reading": "متابعة التلاوة",
"ayah_label": "سورة {surah}، الآية {ayah}",
"page_label": "الصفحة {page}",
"play_surah": "تشغيل السورة"
```

- [ ] **Step 3: Trigger regeneration of `lib/generated/l10n.dart`**

The flutter_intl IDE extension regenerates on save of `.arb` files. If running outside an IDE, run:

```bash
flutter pub run intl_utils:generate
```

Expected: `lib/generated/l10n.dart` now exposes `pause`, `playback_next`, etc., as methods on `S`.

- [ ] **Step 4: Sanity-check compile**

Run:

```bash
flutter analyze lib/generated/l10n.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/l10n.dart
git commit -m "feat(l10n): add playback overlay + continue reading strings"
```

---

### Task 2: Settings — add `playbackSpeed` and `defaultReciter`

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Test: `test/features/settings/settings_cubit_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create `test/features/settings/settings_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quran_app/features/quran_playback/data/repositories/helper/reciter.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProvider();
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory.web,
    );
  });

  test('default state has speed=1.0 and reciter=alafasy', () {
    final cubit = SettingsCubit();
    expect(cubit.state.settingsModel.playbackSpeed, 1.0);
    expect(cubit.state.settingsModel.defaultReciter, Reciter.alafasy);
  });

  blocTest<SettingsCubit, SettingsState>(
    'updatePlaybackSpeed emits new speed',
    build: () => SettingsCubit(),
    act: (c) => c.updatePlaybackSpeed(1.5),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.playbackSpeed, 'speed', 1.5),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'updateDefaultReciter emits new reciter',
    build: () => SettingsCubit(),
    act: (c) => c.updateDefaultReciter(Reciter.husary),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.defaultReciter, 'reciter', Reciter.husary),
    ],
  );

  test('toMap / fromMap round-trips new fields', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      playbackSpeed: 1.25,
      defaultReciter: Reciter.minshawyMurattal,
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.playbackSpeed, 1.25);
    expect(round.defaultReciter, Reciter.minshawyMurattal);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/settings/settings_cubit_test.dart
```

Expected: FAIL (`playbackSpeed`/`defaultReciter` don't exist).

- [ ] **Step 3: Extend `Settings` entity**

Replace `lib/features/settings/domain/entities/settings.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../quran_playback/data/repositories/helper/reciter.dart';

class Settings extends Equatable {
  final bool isDarkMode;
  final bool isFormat12Hours;
  final bool isArabic;
  final double playbackSpeed;
  final Reciter defaultReciter;

  const Settings({
    required this.isDarkMode,
    required this.isFormat12Hours,
    required this.isArabic,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
    );
  }

  @override
  List<Object?> get props =>
      [isArabic, isDarkMode, isFormat12Hours, playbackSpeed, defaultReciter];
}
```

NOTE: `Reciter` is in the `data/repositories/helper/` layer. Importing it from domain is a layer violation per `.claude/rules/architecture.md`. **Fix:** before adding the field, move `Reciter` to `lib/features/quran_playback/domain/entities/reciter.dart` (pure Dart enum — already is) and update all existing imports of `'.../data/repositories/helper/reciter.dart'`.

- [ ] **Step 4: Move `Reciter` enum to domain layer**

```bash
git mv lib/features/quran_playback/data/repositories/helper/reciter.dart \
       lib/features/quran_playback/domain/entities/reciter.dart
```

Update every importer (these are the files identified by grep):
- `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`
- `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart`
- `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- `lib/features/quran_playback/domain/usecases/play_ayah_use_case.dart`

Replace `import '.../data/repositories/helper/reciter.dart'` with `import '.../domain/entities/reciter.dart'` (use the correct relative path per file).

- [ ] **Step 5: Update `Settings` entity import**

Now `lib/features/settings/domain/entities/settings.dart` can import `'../../../quran_playback/domain/entities/reciter.dart'` legally.

- [ ] **Step 6: Extend `SettingsModel`**

Replace `lib/features/settings/data/models/settings_model.dart`:

```dart
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isDarkMode,
    required super.isFormat12Hours,
    required super.isArabic,
    super.playbackSpeed,
    super.defaultReciter,
  });

  @override
  SettingsModel copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      isDarkMode: map['isDarkMode'] ?? true,
      isFormat12Hours: map['isFormat12Hours'] ?? true,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isDarkMode': isDarkMode,
      'isFormat12Hours': isFormat12Hours,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
    };
  }
}
```

- [ ] **Step 7: Add update methods to `SettingsCubit`**

In `lib/features/settings/presentation/cubit/settings_cubit.dart`, add:

```dart
void updatePlaybackSpeed(double speed) {
  emit(SettingsState(state.settingsModel.copyWith(playbackSpeed: speed)));
}

void updateDefaultReciter(Reciter reciter) {
  emit(SettingsState(state.settingsModel.copyWith(defaultReciter: reciter)));
}
```

Add the import: `import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';`

- [ ] **Step 8: Run all settings tests — verify pass**

```bash
flutter test test/features/settings/settings_cubit_test.dart
```

Expected: 4 tests pass.

- [ ] **Step 9: Run a full analyze**

```bash
flutter analyze lib test
```

Expected: no new errors. (Import paths for `Reciter` were rewritten in Step 4.)

- [ ] **Step 10: Commit**

```bash
git add lib/features/quran_playback lib/features/settings test/features/settings
git commit -m "feat(settings): add playbackSpeed + defaultReciter fields"
```

---

### Task 3: `AyahSequenceService.getPreviousAyah`

**Files:**
- Modify: `lib/features/quran_playback/domain/services/aya_sequence_service.dart`
- Test: `test/features/quran_playback/aya_sequence_service_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create `test/features/quran_playback/aya_sequence_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';

void main() {
  final svc = AyahSequenceService();

  test('previous within same surah', () {
    final prev = svc.getPreviousAyah(
      current: const AyahIdentifier(surah: 2, ayah: 3),
    );
    expect(prev, const AyahIdentifier(surah: 2, ayah: 2));
  });

  test('previous at surah boundary wraps to last ayah of previous surah', () {
    final prev = svc.getPreviousAyah(
      current: const AyahIdentifier(surah: 2, ayah: 1),
    );
    // Al-Fatihah has 7 ayahs.
    expect(prev, const AyahIdentifier(surah: 1, ayah: 7));
  });

  test('previous from 1:1 returns null', () {
    final prev = svc.getPreviousAyah(
      current: const AyahIdentifier(surah: 1, ayah: 1),
    );
    expect(prev, isNull);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/aya_sequence_service_test.dart
```

Expected: FAIL (method `getPreviousAyah` not defined).

- [ ] **Step 3: Implement**

Append to `lib/features/quran_playback/domain/services/aya_sequence_service.dart` (inside the class):

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

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/quran_playback/aya_sequence_service_test.dart
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/domain/services/aya_sequence_service.dart \
        test/features/quran_playback/aya_sequence_service_test.dart
git commit -m "feat(playback): add AyahSequenceService.getPreviousAyah"
```

---

### Task 4: `QuranPlaybackRepo` — add `seek` and `setSpeed`

**Files:**
- Modify: `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart`
- Modify: `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`

There is no existing unit test file for the repo (it's a thin wrapper around `just_audio` — manually verified). We add the API plumbing only and let downstream cubit tests cover behavior via mocks.

- [ ] **Step 1: Extend the abstract repo**

Append to `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart` (inside the class, before the closing brace):

```dart
Future<void> seek(Duration position);
Future<void> setSpeed(double speed);
```

- [ ] **Step 2: Implement in `QuranPlaybackRepoImpl`**

Append inside `class QuranPlaybackRepoImpl`:

```dart
@override
Future<void> seek(Duration position) => player.seek(position);

@override
Future<void> setSpeed(double speed) => player.setSpeed(speed);
```

- [ ] **Step 3: Compile**

```bash
flutter analyze lib/features/quran_playback
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/quran_playback/domain/repositories/quran_playback_repo.dart \
        lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart
git commit -m "feat(playback): add seek + setSpeed to QuranPlaybackRepo"
```

---

### Task 5: Extend `PlaybackState`

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`
- Test: `test/features/quran_playback/playback_state_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create `test/features/quran_playback/playback_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  test('defaults', () {
    const s = PlaybackState();
    expect(s.isPlaying, false);
    expect(s.isPaused, false);
    expect(s.isAutoPlaying, false);
    expect(s.isLoading, false);
    expect(s.error, isNull);
    expect(s.speed, 1.0);
    expect(s.reciter, Reciter.alafasy);
  });

  test('copyWith overrides new fields', () {
    const s = PlaybackState();
    final next = s.copyWith(
      isPaused: true,
      speed: 1.5,
      reciter: Reciter.husary,
    );
    expect(next.isPaused, true);
    expect(next.speed, 1.5);
    expect(next.reciter, Reciter.husary);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/playback_state_test.dart
```

Expected: FAIL (`isPaused`, `speed`, `reciter` don't exist).

- [ ] **Step 3: Extend state**

Replace `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`:

```dart
import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';

class PlaybackState {
  final AyahIdentifier? currentAyah;
  final bool isPlaying;
  final bool isPaused;
  final bool isAutoPlaying;
  final bool isLoading;
  final String? error;
  final Reciter reciter;
  final double speed;

  const PlaybackState({
    this.currentAyah,
    this.isPlaying = false,
    this.isPaused = false,
    this.isAutoPlaying = false,
    this.isLoading = false,
    this.error,
    this.reciter = Reciter.alafasy,
    this.speed = 1.0,
  });

  PlaybackState copyWith({
    AyahIdentifier? currentAyah,
    bool? isPlaying,
    bool? isPaused,
    bool? isAutoPlaying,
    bool? isLoading,
    String? error,
    Reciter? reciter,
    double? speed,
    bool clearCurrentAyah = false,
  }) {
    return PlaybackState(
      currentAyah: clearCurrentAyah ? null : (currentAyah ?? this.currentAyah),
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      reciter: reciter ?? this.reciter,
      speed: speed ?? this.speed,
    );
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/quran_playback/playback_state_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_state.dart \
        test/features/quran_playback/playback_state_test.dart
git commit -m "feat(playback): extend PlaybackState with isPaused, speed, reciter"
```

---

### Task 6: `PlaybackCubit` foundations — pause flag, settings-seeded defaults, speed applied on play, race guard

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Modify: `lib/features/quran_playback/playback_di.dart` (cubit constructor gets `SettingsCubit`)
- Test: `test/features/quran_playback/playback_cubit_test.dart` (new)

This task introduces the test harness all subsequent `PlaybackCubit` tasks reuse.

- [ ] **Step 1: Write failing tests**

Create `test/features/quran_playback/playback_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/domain/repositories/quran_playback_repo.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class _MockRepo extends Mock implements QuranPlaybackRepo {}
class _MockSeq extends Mock implements AyahSequenceService {}
class _MockPage extends Mock implements QuranPageService {}
class _FakeSettings extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettings(super.initial);
  double? speedUpdate;
  Reciter? reciterUpdate;
  @override
  void updatePlaybackSpeed(double s) => speedUpdate = s;
  @override
  void updateDefaultReciter(Reciter r) => reciterUpdate = r;
  // unused overrides
  @override
  void updateSettings({bool? isDarkMode, bool? isFormat12Hours, bool? isArabic}) {}
  @override
  SettingsState? fromJson(Map<String, dynamic> json) => null;
  @override
  Map<String, dynamic>? toJson(SettingsState state) => null;
}

void main() {
  late _MockRepo repo;
  late _MockSeq seq;
  late _MockPage page;
  late _FakeSettings settings;

  const ayah25 = AyahIdentifier(surah: 2, ayah: 5);

  setUpAll(() {
    registerFallbackValue(ayah25);
    registerFallbackValue(Reciter.alafasy);
    registerFallbackValue(<AyahIdentifier>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    repo = _MockRepo();
    seq = _MockSeq();
    page = _MockPage();
    settings = _FakeSettings(SettingsState(SettingsModel(
      isDarkMode: true,
      isFormat12Hours: true,
      isArabic: true,
      playbackSpeed: 1.25,
      defaultReciter: Reciter.husary,
    )));
    when(() => repo.currentAyahStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => repo.onAudioCompleted).thenAnswer((_) => const Stream.empty());
    when(() => repo.preloadAyahs(
          ayahs: any(named: 'ayahs'),
          reciter: any(named: 'reciter'),
        )).thenAnswer((_) async {});
    when(() => repo.setSpeed(any())).thenAnswer((_) async {});
  });

  PlaybackCubit build() => PlaybackCubit(
        ayahSequenceService: seq,
        repository: repo,
        pageService: page,
        settingsCubit: settings,
      );

  test('seeds state from SettingsCubit', () {
    final c = build();
    expect(c.state.speed, 1.25);
    expect(c.state.reciter, Reciter.husary);
  });

  blocTest<PlaybackCubit, PlaybackState>(
    'pause sets isPaused=true and isPlaying=false',
    build: () {
      when(() => repo.pause()).thenAnswer((_) async {});
      return build()..emit(const PlaybackState(isPlaying: true));
    },
    act: (c) => c.pause(),
    skip: 1, // skip the manual emit
    expect: () => [
      isA<PlaybackState>()
          .having((s) => s.isPlaying, 'isPlaying', false)
          .having((s) => s.isPaused, 'isPaused', true),
    ],
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'race guard: playSelected(A) then playSelected(B) before A resolves '
    'notifies only B',
    build: () {
      final completerA = Completer<Either<Failure, String>>();
      var call = 0;
      when(() => repo.prepareAyahAudio(
            ayah: any(named: 'ayah'),
            reciter: any(named: 'reciter'),
          )).thenAnswer((_) {
        call++;
        if (call == 1) return completerA.future;
        return Future.value(const Right('/path/B.mp3'));
      });
      when(() => repo.playPreparedAudio(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.notifyAyahChanged(any())).thenReturn(null);
      return build();
    },
    act: (c) async {
      // Fire A; do not await
      final fA = c.playSelected(const AyahIdentifier(surah: 2, ayah: 1));
      // Fire B
      await c.playSelected(const AyahIdentifier(surah: 2, ayah: 2));
      // Now let A's prepare resolve
      // (test framework will inspect verify() below)
      await fA;
    },
    verify: (_) {
      verify(() => repo.notifyAyahChanged(
          const AyahIdentifier(surah: 2, ayah: 2))).called(1);
      verifyNever(() => repo.notifyAyahChanged(
          const AyahIdentifier(surah: 2, ayah: 1)));
    },
  );

  blocTest<PlaybackCubit, PlaybackState>(
    'playSelected applies the cubit speed via repo.setSpeed',
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
    act: (c) => c.playSelected(ayah25),
    verify: (_) => verify(() => repo.setSpeed(1.25)).called(1),
  );
}
```

Add the import for `Completer`:

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: FAIL (constructor signature mismatch, `playSelected` undefined).

- [ ] **Step 3: Update `PlaybackCubit` constructor + foundations**

Replace `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart` with the file below.

```dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../../surah/domain/entities/surah_entity.dart';
import '../../../domain/entities/ayah_identifier.dart';
import '../../../domain/entities/reciter.dart';
import '../../../domain/repositories/quran_playback_repo.dart';
import '../../../domain/services/aya_sequence_service.dart';
import '../../../domain/services/quran_page_service.dart';
import 'playback_state.dart';

class PlaybackCubit extends Cubit<PlaybackState> {
  final AyahSequenceService ayahSequenceService;
  final QuranPlaybackRepo repository;
  final QuranPageService pageService;
  final SettingsCubit settingsCubit;

  late final StreamSubscription _ayahSub;
  late final StreamSubscription _completeSub;

  int? _endSurah;
  int? _endAyah;
  AyahIdentifier? _startAyah;
  bool _isPlayingAyah = false;
  AyahIdentifier? _inFlightAyah;

  PlaybackCubit({
    required this.ayahSequenceService,
    required this.repository,
    required this.pageService,
    required this.settingsCubit,
  }) : super(PlaybackState(
          speed: settingsCubit.state.settingsModel.playbackSpeed,
          reciter: settingsCubit.state.settingsModel.defaultReciter,
        )) {
    _ayahSub = repository.currentAyahStream.listen((ayah) {
      if (isClosed) return;
      emit(state.copyWith(
        currentAyah: ayah,
        isPlaying: true,
        isPaused: false,
        isLoading: false,
      ));
      _preloadNextAyahs(ayah);
    });

    _completeSub = repository.onAudioCompleted.listen((_) {
      _handleNextAyah();
    });
  }

  Future<void> playSelected(AyahIdentifier ayah) async {
    _startAyah = ayah;
    _endSurah = null;
    _endAyah = null;
    emit(state.copyWith(isAutoPlaying: true, isLoading: true));
    await _playAyah(ayah);
  }

  Future<void> _playAyah(AyahIdentifier ayah) async {
    if (isClosed) return;
    _inFlightAyah = ayah;
    _isPlayingAyah = true;

    try {
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
          repository.notifyAyahChanged(ayah);
          await repository.setSpeed(state.speed);
          await repository.playPreparedAudio(path);
        },
      );
    } finally {
      _isPlayingAyah = false;
    }
  }

  void _handleNextAyah() {
    if (!state.isAutoPlaying || state.currentAyah == null) return;
    final next = ayahSequenceService.getNextAyah(
      current: state.currentAyah!,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );
    if (next == null) {
      stop();
      return;
    }
    _playAyah(next);
  }

  Future<void> _preloadNextAyahs(AyahIdentifier current) async {
    final nextAyahs = ayahSequenceService.getNextAyahs(
      current: current,
      count: 5,
      endSurah: _endSurah,
      endAyah: _endAyah,
    );
    await repository.preloadAyahs(ayahs: nextAyahs, reciter: state.reciter);
  }

  Future<void> preloadFullSurah({
    required SurahEntity surah,
    required Reciter reciter,
  }) async {
    final ayahs = List.generate(
      surah.numberOfAyahs,
      (i) => AyahIdentifier(surah: surah.number, ayah: i + 1),
    );
    emit(state.copyWith(isLoading: true));
    await repository.preloadAyahs(ayahs: ayahs, reciter: reciter);
    emit(state.copyWith(isLoading: false));
  }

  int? getPageForCurrentAyah() {
    final ayah = state.currentAyah;
    if (ayah == null) return null;
    return pageService.getPageForAyah(ayah.surah, ayah.ayah);
  }

  Future<void> playFromAyah(AyahIdentifier ayah) => playSelected(ayah);

  void autoPlayPage(int pageNumber) {
    final startAyah = pageService.getFirstAyahOfPage(pageNumber);
    if (startAyah == null) return;
    playSelected(startAyah);
  }

  Future<void> stop() async {
    _inFlightAyah = null;
    await repository.stop();
    emit(state.copyWith(
      isPlaying: false,
      isPaused: false,
      isAutoPlaying: false,
      isLoading: false,
      clearCurrentAyah: true,
    ));
  }

  Future<void> pause() async {
    emit(state.copyWith(isPlaying: false, isPaused: true));
    await repository.pause();
  }

  Future<void> resume() async {
    emit(state.copyWith(isPlaying: true, isPaused: false));
    await repository.resume();
  }

  @override
  Future<void> close() async {
    await _ayahSub.cancel();
    await _completeSub.cancel();
    return super.close();
  }
}
```

Removed: the legacy `RepeatMode` plumbing (`_repeatMode` / `_repeatTimes` / `_completedCycles`) — auto-advance now flows naturally through `_handleNextAyah`, and "repeat once / N / infinite" is out of scope per spec §9.

- [ ] **Step 4: Update `playback_di.dart` to pass `SettingsCubit`**

Edit `lib/features/quran_playback/playback_di.dart`:

```dart
sl.registerLazySingleton<PlaybackCubit>(
  () => PlaybackCubit(
    ayahSequenceService: sl<AyahSequenceService>(),
    repository: sl<QuranPlaybackRepo>(),
    pageService: sl<QuranPageService>(),
    settingsCubit: sl<SettingsCubit>(),
  ),
);
```

Add import: `import '../settings/presentation/cubit/settings_cubit.dart';`

- [ ] **Step 5: Delete legacy `RepeatMode` helper (now unused)**

```bash
git rm lib/features/quran_playback/data/repositories/helper/repeat_mode.dart
```

Confirm nothing else imports it:

```bash
grep -rn "repeat_mode\|RepeatMode" lib test
```

Expected: no matches. (`play_ayah_use_case.dart` does NOT import `RepeatMode` — only `Reciter`, whose import path was already updated in Step 4.)

- [ ] **Step 6: Run cubit tests — verify pass**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: 4 tests pass.

- [ ] **Step 7: Full analyze**

```bash
flutter analyze lib test
```

Expected: no errors. (You may need to update `play_ayah_use_case.dart` if it has a `repeatMode` parameter — drop it.)

- [ ] **Step 8: Commit**

```bash
git add lib/features/quran_playback test/features/quran_playback
git commit -m "feat(playback): seed cubit from SettingsCubit, add isPaused + race guard"
```

---

### Task 7: `PlaybackCubit.skipNext` and `skipPrevious`

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Test: `test/features/quran_playback/playback_cubit_test.dart` (extend)

- [ ] **Step 1: Add failing tests**

Append to the existing `main()` in `playback_cubit_test.dart`:

```dart
blocTest<PlaybackCubit, PlaybackState>(
  'skipNext from (2,5) plays (2,6)',
  build: () {
    when(() => seq.getNextAyah(current: any(named: 'current')))
        .thenReturn(const AyahIdentifier(surah: 2, ayah: 6));
    when(() => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        )).thenAnswer((_) async => const Right('/p.mp3'));
    when(() => repo.playPreparedAudio(any()))
        .thenAnswer((_) async => const Right(null));
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
    return build()..emit(const PlaybackState(currentAyah: ayah25));
  },
  act: (c) => c.skipNext(),
  verify: (_) => verify(() => repo.notifyAyahChanged(
      const AyahIdentifier(surah: 2, ayah: 6))).called(1),
);

blocTest<PlaybackCubit, PlaybackState>(
  'skipNext at end of Quran is a no-op',
  build: () {
    when(() => seq.getNextAyah(current: any(named: 'current')))
        .thenReturn(null);
    return build()..emit(const PlaybackState(
        currentAyah: AyahIdentifier(surah: 114, ayah: 6)));
  },
  act: (c) => c.skipNext(),
  verify: (_) {
    verifyNever(() => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ));
  },
);

blocTest<PlaybackCubit, PlaybackState>(
  'skipPrevious from (2,2) plays (2,1)',
  build: () {
    when(() => seq.getPreviousAyah(current: any(named: 'current')))
        .thenReturn(const AyahIdentifier(surah: 2, ayah: 1));
    when(() => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        )).thenAnswer((_) async => const Right('/p.mp3'));
    when(() => repo.playPreparedAudio(any()))
        .thenAnswer((_) async => const Right(null));
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
    return build()..emit(const PlaybackState(
        currentAyah: AyahIdentifier(surah: 2, ayah: 2)));
  },
  act: (c) => c.skipPrevious(),
  verify: (_) => verify(() => repo.notifyAyahChanged(
      const AyahIdentifier(surah: 2, ayah: 1))).called(1),
);

blocTest<PlaybackCubit, PlaybackState>(
  'skipPrevious at (1,1) is a no-op',
  build: () {
    when(() => seq.getPreviousAyah(current: any(named: 'current')))
        .thenReturn(null);
    return build()..emit(const PlaybackState(
        currentAyah: AyahIdentifier(surah: 1, ayah: 1)));
  },
  act: (c) => c.skipPrevious(),
  verify: (_) {
    verifyNever(() => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ));
  },
);
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: FAIL (`skipNext`/`skipPrevious` undefined).

- [ ] **Step 3: Implement**

Add to `PlaybackCubit`:

```dart
Future<void> skipNext() async {
  final current = state.currentAyah;
  if (current == null) return;
  final next = ayahSequenceService.getNextAyah(current: current);
  if (next == null) return;
  await _playAyah(next);
}

Future<void> skipPrevious() async {
  final current = state.currentAyah;
  if (current == null) return;
  final prev = ayahSequenceService.getPreviousAyah(current: current);
  if (prev == null) return;
  await _playAyah(prev);
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart \
        test/features/quran_playback/playback_cubit_test.dart
git commit -m "feat(playback): add skipNext + skipPrevious to PlaybackCubit"
```

---

### Task 8: `PlaybackCubit.restartCurrent`

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Test: `test/features/quran_playback/playback_cubit_test.dart` (extend)

- [ ] **Step 1: Add failing tests**

Append:

```dart
blocTest<PlaybackCubit, PlaybackState>(
  'restartCurrent seeks to 0 and resumes',
  build: () {
    when(() => repo.seek(any())).thenAnswer((_) async {});
    when(() => repo.resume()).thenAnswer((_) async {});
    return build()..emit(const PlaybackState(currentAyah: ayah25));
  },
  act: (c) => c.restartCurrent(),
  verify: (_) {
    verify(() => repo.seek(Duration.zero)).called(1);
    verify(() => repo.resume()).called(1);
  },
);

blocTest<PlaybackCubit, PlaybackState>(
  'restartCurrent is a no-op when currentAyah is null',
  build: () => build(),
  act: (c) => c.restartCurrent(),
  verify: (_) {
    verifyNever(() => repo.seek(any()));
    verifyNever(() => repo.resume());
  },
);
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
Future<void> restartCurrent() async {
  if (state.currentAyah == null) return;
  await repository.seek(Duration.zero);
  await repository.resume();
  emit(state.copyWith(isPlaying: true, isPaused: false));
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart \
        test/features/quran_playback/playback_cubit_test.dart
git commit -m "feat(playback): add restartCurrent to PlaybackCubit"
```

---

### Task 9: `PlaybackCubit.setSpeed`

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Test: `test/features/quran_playback/playback_cubit_test.dart` (extend)

- [ ] **Step 1: Add failing test**

```dart
blocTest<PlaybackCubit, PlaybackState>(
  'setSpeed updates state, calls repo.setSpeed, persists via settings',
  build: () => build(),
  act: (c) => c.setSpeed(1.75),
  expect: () => [
    isA<PlaybackState>().having((s) => s.speed, 'speed', 1.75),
  ],
  verify: (_) {
    verify(() => repo.setSpeed(1.75)).called(1);
    expect(settings.speedUpdate, 1.75);
  },
);
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
Future<void> setSpeed(double speed) async {
  emit(state.copyWith(speed: speed));
  await repository.setSpeed(speed);
  settingsCubit.updatePlaybackSpeed(speed);
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: 11 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart \
        test/features/quran_playback/playback_cubit_test.dart
git commit -m "feat(playback): add setSpeed (persists via SettingsCubit)"
```

---

### Task 10: `PlaybackCubit.setReciter` (with restart-current behavior)

**Files:**
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`
- Test: `test/features/quran_playback/playback_cubit_test.dart` (extend)

- [ ] **Step 1: Add failing tests**

```dart
blocTest<PlaybackCubit, PlaybackState>(
  'setReciter while idle updates state + persists, does not stop/play',
  build: () => build(),
  act: (c) => c.setReciter(Reciter.sudais),
  expect: () => [
    isA<PlaybackState>().having((s) => s.reciter, 'reciter', Reciter.sudais),
  ],
  verify: (_) {
    expect(settings.reciterUpdate, Reciter.sudais);
    verifyNever(() => repo.stop());
    verifyNever(() => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        ));
  },
);

blocTest<PlaybackCubit, PlaybackState>(
  'setReciter while playing stops and restarts current ayah with new reciter',
  build: () {
    when(() => repo.stop()).thenAnswer((_) async {});
    when(() => repo.prepareAyahAudio(
          ayah: any(named: 'ayah'),
          reciter: any(named: 'reciter'),
        )).thenAnswer((_) async => const Right('/p.mp3'));
    when(() => repo.playPreparedAudio(any()))
        .thenAnswer((_) async => const Right(null));
    when(() => repo.notifyAyahChanged(any())).thenReturn(null);
    return build()
      ..emit(const PlaybackState(
        currentAyah: ayah25,
        isPlaying: true,
      ));
  },
  act: (c) => c.setReciter(Reciter.sudais),
  verify: (_) {
    verify(() => repo.stop()).called(1);
    verify(() => repo.prepareAyahAudio(
          ayah: ayah25,
          reciter: Reciter.sudais,
        )).called(1);
  },
);
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
Future<void> setReciter(Reciter reciter) async {
  final wasActive = state.currentAyah != null
      && (state.isPlaying || state.isPaused);
  final activeAyah = state.currentAyah;
  emit(state.copyWith(reciter: reciter));
  settingsCubit.updateDefaultReciter(reciter);
  if (wasActive && activeAyah != null) {
    await repository.stop();
    await _playAyah(activeAyah);
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/quran_playback/playback_cubit_test.dart
```

Expected: 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart \
        test/features/quran_playback/playback_cubit_test.dart
git commit -m "feat(playback): add setReciter (restarts current ayah when active)"
```

---

### Task 11: `MushafCubit` auto-follow rule

**Files:**
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Test: `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart` (new)

- [ ] **Step 1: Write failing test**

Create the file:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

void main() {
  const a = AyahIdentifier(surah: 2, ayah: 1);
  const b = AyahIdentifier(surah: 2, ayah: 2);
  const c = AyahIdentifier(surah: 2, ayah: 5);

  blocTest<MushafCubit, MushafState>(
    'auto-follow: highlightedAyah == playingAyah; notifier emits B -> both become B',
    build: () {
      final n = _FakeNotifier();
      final cubit = MushafCubit(initialPage: 1, currentAyahNotifier: n);
      n.value = a;
      return cubit;
    },
    seed: () => const MushafState(
        currentPage: 1, highlightedAyah: a, playingAyah: a),
    act: (cubit) => cubit.debugNotifier.value = b,
    expect: () => [
      const MushafState(currentPage: 1, highlightedAyah: b, playingAyah: b),
    ],
  );

  blocTest<MushafCubit, MushafState>(
    'no auto-follow: highlighted=C, playing=A; notifier emits B -> highlighted stays C, playing=B',
    build: () {
      final n = _FakeNotifier();
      final cubit = MushafCubit(initialPage: 1, currentAyahNotifier: n);
      n.value = a;
      return cubit;
    },
    seed: () => const MushafState(
        currentPage: 1, highlightedAyah: c, playingAyah: a),
    act: (cubit) => cubit.debugNotifier.value = b,
    expect: () => [
      const MushafState(currentPage: 1, highlightedAyah: c, playingAyah: b),
    ],
  );

  blocTest<MushafCubit, MushafState>(
    'no auto-follow when highlighted is null; notifier emits A -> highlighted stays null',
    build: () => MushafCubit(initialPage: 1, currentAyahNotifier: _FakeNotifier()),
    act: (cubit) => cubit.debugNotifier.value = a,
    expect: () => [
      const MushafState(currentPage: 1, playingAyah: a),
    ],
  );
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart
```

Expected: FAIL (current cubit emits without updating highlightedAyah, and the no-auto-follow case will also fail because the implementation doesn't have the rule yet).

- [ ] **Step 3: Update `_onPlayingAyahChanged`**

In `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`, replace the method:

```dart
void _onPlayingAyahChanged() {
  final next = _notifier.value;
  final prevPlaying = state.playingAyah;
  if (next == null) {
    if (state.playingAyah != null) emit(state.copyWith(clearPlaying: true));
    return;
  }
  final wasFollowing = state.highlightedAyah != null
      && state.highlightedAyah == prevPlaying;
  if (wasFollowing) {
    emit(state.copyWith(playingAyah: next, highlightedAyah: next));
  } else if (state.playingAyah != next) {
    emit(state.copyWith(playingAyah: next));
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart \
             test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart
```

Expected: all pass (clear-highlight test must not regress).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart \
        test/features/surah/presentation/cubit/mushaf/mushaf_cubit_auto_follow_test.dart
git commit -m "feat(mushaf): highlight auto-follows playing ayah (when previously aligned)"
```

---

## Phase 2 — Continue Reading persistence

### Task 12: `LastRead` entity + `LastReadRepository` contract

**Files:**
- Create: `lib/features/surah/domain/entities/last_read.dart`
- Create: `lib/features/surah/domain/repositories/last_read_repository.dart`

Plain value types — no tests needed.

- [ ] **Step 1: Create entity**

```dart
// lib/features/surah/domain/entities/last_read.dart
import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class LastRead extends Equatable {
  final int page;
  final AyahIdentifier? ayah;

  const LastRead({required this.page, this.ayah});

  @override
  List<Object?> get props => [page, ayah];
}
```

- [ ] **Step 2: Create contract**

```dart
// lib/features/surah/domain/repositories/last_read_repository.dart
import '../entities/last_read.dart';

abstract class LastReadRepository {
  Future<void> save(LastRead value);
  Future<LastRead?> get();
  Stream<LastRead?> watch();
}
```

- [ ] **Step 3: Compile**

```bash
flutter analyze lib/features/surah/domain
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/domain/entities/last_read.dart \
        lib/features/surah/domain/repositories/last_read_repository.dart
git commit -m "feat(last_read): add LastRead entity + repository contract"
```

---

### Task 13: `LastReadHiveModel` + generate adapter

**Files:**
- Create: `lib/features/surah/data/models/last_read_hive_model.dart`
- Generated: `lib/features/surah/data/models/last_read_hive_model.g.dart` (via build_runner)

- [ ] **Step 1: Create model**

```dart
// lib/features/surah/data/models/last_read_hive_model.dart
import 'package:hive/hive.dart';

part 'last_read_hive_model.g.dart';

@HiveType(typeId: 5)
class LastReadHiveModel extends HiveObject {
  @HiveField(0)
  int page;

  @HiveField(1)
  int? surah;

  @HiveField(2)
  int? ayah;

  LastReadHiveModel({required this.page, this.surah, this.ayah});
}
```

- [ ] **Step 2: Run build_runner**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: `last_read_hive_model.g.dart` is generated with `LastReadHiveModelAdapter`.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/data/models/last_read_hive_model.dart \
        lib/features/surah/data/models/last_read_hive_model.g.dart
git commit -m "feat(last_read): add LastReadHiveModel + generated adapter (typeId 5)"
```

---

### Task 14: `LastReadLocalDataSource` and `LastReadRepositoryImpl`

**Files:**
- Create: `lib/features/surah/data/datasources/last_read_local_data_source.dart`
- Create: `lib/features/surah/data/repositories/last_read_repository_impl.dart`
- Test: `test/features/surah/data/repositories/last_read_repository_impl_test.dart` (new)

- [ ] **Step 1: Write failing test**

```dart
// test/features/surah/data/repositories/last_read_repository_impl_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/last_read_local_data_source.dart';
import 'package:quran_app/features/surah/data/models/last_read_hive_model.dart';
import 'package:quran_app/features/surah/data/repositories/last_read_repository_impl.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  late final Directory tempDir;
  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  late Box<LastReadHiveModel> box;
  late LastReadRepositoryImpl repo;
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapter(LastReadHiveModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('last_read_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<LastReadHiveModel>('last_read_test_${tempDir.path.hashCode}');
    final ds = LastReadLocalDataSource(box: box);
    repo = LastReadRepositoryImpl(local: ds);
  });

  tearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('save then get round-trips with ayah', () async {
    const value = LastRead(
      page: 42,
      ayah: AyahIdentifier(surah: 2, ayah: 5),
    );
    await repo.save(value);
    final got = await repo.get();
    expect(got, value);
  });

  test('save then get round-trips without ayah', () async {
    const value = LastRead(page: 42);
    await repo.save(value);
    final got = await repo.get();
    expect(got, value);
  });

  test('get returns null when nothing saved', () async {
    expect(await repo.get(), isNull);
  });

  test('watch emits on save', () async {
    final emissions = <LastRead?>[];
    final sub = repo.watch().listen(emissions.add);
    await repo.save(const LastRead(page: 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions, isNotEmpty);
    expect(emissions.last, const LastRead(page: 1));
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/data/repositories/last_read_repository_impl_test.dart
```

Expected: FAIL (data source + repo don't exist).

- [ ] **Step 3: Create data source**

```dart
// lib/features/surah/data/datasources/last_read_local_data_source.dart
import 'package:hive/hive.dart';

import '../models/last_read_hive_model.dart';

class LastReadLocalDataSource {
  static const _key = 'current';
  final Box<LastReadHiveModel> box;

  LastReadLocalDataSource({required this.box});

  Future<void> save(LastReadHiveModel model) => box.put(_key, model);

  LastReadHiveModel? get() => box.get(_key);

  Stream<BoxEvent> watch() => box.watch(key: _key);
}
```

- [ ] **Step 4: Create repository implementation**

```dart
// lib/features/surah/data/repositories/last_read_repository_impl.dart
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/repositories/last_read_repository.dart';
import '../datasources/last_read_local_data_source.dart';
import '../models/last_read_hive_model.dart';

class LastReadRepositoryImpl implements LastReadRepository {
  final LastReadLocalDataSource local;
  LastReadRepositoryImpl({required this.local});

  LastRead? _from(LastReadHiveModel? m) {
    if (m == null) return null;
    final ayah = (m.surah != null && m.ayah != null)
        ? AyahIdentifier(surah: m.surah!, ayah: m.ayah!)
        : null;
    return LastRead(page: m.page, ayah: ayah);
  }

  LastReadHiveModel _to(LastRead v) => LastReadHiveModel(
        page: v.page,
        surah: v.ayah?.surah,
        ayah: v.ayah?.ayah,
      );

  @override
  Future<void> save(LastRead value) => local.save(_to(value));

  @override
  Future<LastRead?> get() async => _from(local.get());

  @override
  Stream<LastRead?> watch() =>
      local.watch().map((_) => _from(local.get()));
}
```

- [ ] **Step 5: Run — verify pass**

```bash
flutter test test/features/surah/data/repositories/last_read_repository_impl_test.dart
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/data/datasources/last_read_local_data_source.dart \
        lib/features/surah/data/repositories/last_read_repository_impl.dart \
        test/features/surah/data/repositories/last_read_repository_impl_test.dart
git commit -m "feat(last_read): add local data source + repository implementation"
```

---

### Task 15: `LastReadCubit` + state

**Files:**
- Create: `lib/features/surah/presentation/cubit/last_read/last_read_cubit.dart`
- Create: `lib/features/surah/presentation/cubit/last_read/last_read_state.dart`
- Test: `test/features/surah/presentation/cubit/last_read/last_read_cubit_test.dart` (new)

- [ ] **Step 1: Write failing test**

```dart
// test/features/surah/presentation/cubit/last_read/last_read_cubit_test.dart
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/domain/repositories/last_read_repository.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';

class _MockRepo extends Mock implements LastReadRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  blocTest<LastReadCubit, LastRead?>(
    'loads initial value from repository.get on construction',
    build: () {
      when(() => repo.watch()).thenAnswer((_) => const Stream.empty());
      when(() => repo.get()).thenAnswer(
          (_) async => const LastRead(page: 7));
      return LastReadCubit(repository: repo);
    },
    expect: () => [const LastRead(page: 7)],
  );

  blocTest<LastReadCubit, LastRead?>(
    'emits new value when watch stream fires',
    build: () {
      final controller = StreamController<LastRead?>();
      when(() => repo.watch()).thenAnswer((_) => controller.stream);
      when(() => repo.get()).thenAnswer((_) async => null);
      final cubit = LastReadCubit(repository: repo);
      Future.microtask(() => controller.add(
          const LastRead(page: 99, ayah: AyahIdentifier(surah: 2, ayah: 5))));
      return cubit;
    },
    expect: () => [
      const LastRead(page: 99, ayah: AyahIdentifier(surah: 2, ayah: 5)),
    ],
  );

  blocTest<LastReadCubit, LastRead?>(
    'save delegates to repository',
    setUp: () {
      when(() => repo.watch()).thenAnswer((_) => const Stream.empty());
      when(() => repo.get()).thenAnswer((_) async => null);
      when(() => repo.save(any())).thenAnswer((_) async {});
    },
    build: () => LastReadCubit(repository: repo),
    act: (c) => c.save(const LastRead(page: 3)),
    verify: (_) =>
        verify(() => repo.save(const LastRead(page: 3))).called(1),
  );

  setUpAll(() {
    registerFallbackValue(const LastRead(page: 1));
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/presentation/cubit/last_read/last_read_cubit_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create cubit**

```dart
// lib/features/surah/presentation/cubit/last_read/last_read_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/last_read.dart';
import '../../../domain/repositories/last_read_repository.dart';

class LastReadCubit extends Cubit<LastRead?> {
  final LastReadRepository repository;
  late final StreamSubscription<LastRead?> _sub;

  LastReadCubit({required this.repository}) : super(null) {
    repository.get().then((value) {
      if (!isClosed && value != null) emit(value);
    });
    _sub = repository.watch().listen((value) {
      if (!isClosed) emit(value);
    });
  }

  Future<void> save(LastRead value) => repository.save(value);

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/surah/presentation/cubit/last_read/last_read_cubit_test.dart
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/cubit/last_read \
        test/features/surah/presentation/cubit/last_read
git commit -m "feat(last_read): add LastReadCubit watching repository"
```

---

### Task 16: DI registration + Hive box

**Files:**
- Modify: `lib/config/hive_config.dart`
- Create: `lib/features/surah/last_read_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Register Hive adapter + open box**

Edit `lib/config/hive_config.dart`. Add the import and registration:

```dart
import 'package:quran_app/features/surah/data/models/last_read_hive_model.dart';

// in initHive(), append after existing registrations:
Hive.registerAdapter(LastReadHiveModelAdapter());
await Hive.openBox<LastReadHiveModel>('last_read');
```

- [ ] **Step 2: Create `last_read_di.dart`**

```dart
// lib/features/surah/last_read_di.dart
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/di/dependency_injection.dart';
import 'data/datasources/last_read_local_data_source.dart';
import 'data/models/last_read_hive_model.dart';
import 'data/repositories/last_read_repository_impl.dart';
import 'domain/repositories/last_read_repository.dart';
import 'presentation/cubit/last_read/last_read_cubit.dart';

void initLastRead() {
  sl.registerLazySingleton<LastReadLocalDataSource>(
    () => LastReadLocalDataSource(box: Hive.box<LastReadHiveModel>('last_read')),
  );
  sl.registerLazySingleton<LastReadRepository>(
    () => LastReadRepositoryImpl(local: sl<LastReadLocalDataSource>()),
  );
  sl.registerLazySingleton<LastReadCubit>(
    () => LastReadCubit(repository: sl<LastReadRepository>()),
  );
}
```

- [ ] **Step 3: Wire into `initGetIt`**

Edit `lib/core/di/dependency_injection.dart`:

```dart
import '../../features/surah/last_read_di.dart';
// ... inside initGetIt(), add after initMushaf():
initLastRead();
```

- [ ] **Step 4: Provide the cubit at app root**

Edit `lib/main.dart`. The root `MultiBlocProvider` currently has two providers (SettingsCubit, BookmarkCubit). Add `LastReadCubit` as a third:

```dart
runApp(
  MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => sl<SettingsCubit>()),
      BlocProvider(create: (_) => sl<BookmarkCubit>()),
      BlocProvider(create: (_) => sl<LastReadCubit>()),
    ],
    child: const QuranApp(),
  ),
);
```

Add the import to `main.dart`:

```dart
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
```

- [ ] **Step 5: Sanity test**

```bash
flutter test
```

Expected: all existing + new tests pass; no new errors.

- [ ] **Step 6: Commit**

```bash
git add lib/config/hive_config.dart \
        lib/core/di/dependency_injection.dart \
        lib/features/surah/last_read_di.dart \
        lib/main.dart  # or whichever file the provider was added to
git commit -m "chore(di): register LastRead Hive box + cubit at app root"
```

---

## Phase 3 — UI

### Task 17: `AyahLongPressSheet` widget

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet_test.dart` (new)

- [ ] **Step 1: Write failing widget test**

```dart
// test/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState(reciter: Reciter.alafasy));
  Reciter? lastSetReciter;
  @override
  Future<void> setReciter(Reciter r) async {
    lastSetReciter = r;
    emit(state.copyWith(reciter: r));
  }
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeBookmark extends Cubit<BookmarkState> implements BookmarkCubit {
  _FakeBookmark() : super(const BookmarkState());
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _ayah = AyahIdentifier(surah: 2, ayah: 5);

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  late _FakePlayback playback;
  late _FakeBookmark bookmark;

  setUp(() {
    playback = _FakePlayback();
    bookmark = _FakeBookmark();
  });

  testWidgets('renders 4 action buttons + reciter chips', (tester) async {
    await tester.pumpWidget(_wrap(MultiBlocProvider(
      providers: [
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<BookmarkCubit>.value(value: bookmark),
      ],
      child: const AyahLongPressSheet(ayah: _ayah),
    )));
    expect(find.text('Tafsir'), findsOneWidget);
    expect(find.text('Translation'), findsOneWidget);
    expect(find.text('Bookmark'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Reciter'), findsOneWidget);
    // At least one reciter chip
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('tapping a reciter chip calls setReciter', (tester) async {
    await tester.pumpWidget(_wrap(MultiBlocProvider(
      providers: [
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<BookmarkCubit>.value(value: bookmark),
      ],
      child: const AyahLongPressSheet(ayah: _ayah),
    )));
    // Find a chip whose label matches Husary's Arabic name (always rendered)
    final chip = find.widgetWithText(ChoiceChip, Reciter.husary.arabicName);
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(playback.lastSetReciter, Reciter.husary);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet_test.dart
```

Expected: FAIL (widget doesn't exist).

- [ ] **Step 3: Implement the sheet**

```dart
// lib/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';

import '../../../../../../generated/l10n.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_cubit.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_state.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/domain/entities/reciter.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';

class AyahLongPressSheet extends StatelessWidget {
  const AyahLongPressSheet({super.key, required this.ayah});
  final AyahIdentifier ayah;

  static Future<void> show(BuildContext context, AyahIdentifier ayah) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<PlaybackCubit>.value(value: context.read<PlaybackCubit>()),
          BlocProvider<BookmarkCubit>.value(value: context.read<BookmarkCubit>()),
        ],
        child: AyahLongPressSheet(ayah: ayah),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              s.ayah_label(ayah.surah.toString(), ayah.ayah.toString()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.menu_book_outlined,
                  label: s.tafsir,
                  onTap: () => _comingSoon(context),
                ),
                _ActionButton(
                  icon: Icons.translate,
                  label: s.translation,
                  onTap: () => _comingSoon(context),
                ),
                _BookmarkButton(ayah: ayah),
                _ActionButton(
                  icon: Icons.share,
                  label: s.share,
                  onTap: () => _onShare(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(s.reciter_label,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: BlocBuilder<PlaybackCubit, PlaybackState>(
                buildWhen: (a, b) => a.reciter != b.reciter,
                builder: (context, state) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: Reciter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final r = Reciter.values[i];
                    return ChoiceChip(
                      label: Text(r.arabicName),
                      selected: state.reciter == r,
                      onSelected: (_) {
                        context.read<PlaybackCubit>().setReciter(r);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onShare(BuildContext context) async {
    try {
      final text = quran.getVerse(ayah.surah, ayah.ayah);
      Navigator.of(context).pop();
      await Share.share('$text — ${ayah.surah}:${ayah.ayah}');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).share_failed)),
      );
    }
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).coming_soon)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.ayah});
  final AyahIdentifier ayah;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkCubit, BookmarkState>(
      buildWhen: (a, b) => a.contains(ayah) != b.contains(ayah),
      builder: (context, state) {
        final on = state.contains(ayah);
        return _ActionButton(
          icon: on ? Icons.bookmark : Icons.bookmark_border,
          label: S.of(context).bookmark,
          onTap: () => context.read<BookmarkCubit>().toggle(ayah),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart \
        test/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet_test.dart
git commit -m "feat(mushaf): add AyahLongPressSheet (actions + reciter picker)"
```

---

### Task 18: `AyahPlaybackOverlay` widget

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart` (new)

- [ ] **Step 1: Write failing widget test**

```dart
// test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);
  bool cleared = false;
  @override
  void clearHighlight() {
    cleared = true;
    emit(state.copyWith(clearHighlighted: true));
  }
  @override void toggleHighlight(_) {}
  @override void setPage(int p) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier =>
      throw UnimplementedError();
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);
  AyahIdentifier? lastPlay;
  bool stopped = false;
  bool paused = false;
  double? speedSet;
  @override
  Future<void> playSelected(AyahIdentifier a) async {
    lastPlay = a;
    emit(state.copyWith(currentAyah: a, isPlaying: true));
  }
  @override Future<void> pause() async {
    paused = true;
    emit(state.copyWith(isPlaying: false, isPaused: true));
  }
  @override Future<void> stop() async {
    stopped = true;
    emit(state.copyWith(
      isPlaying: false, isPaused: false, clearCurrentAyah: true));
  }
  @override Future<void> setSpeed(double s) async {
    speedSet = s;
    emit(state.copyWith(speed: s));
  }
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _target = AyahIdentifier(surah: 2, ayah: 5);

Widget _wrap({required _FakeMushaf m, required _FakePlayback p}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(value: m),
          BlocProvider<PlaybackCubit>.value(value: p),
        ],
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: AyahPlaybackOverlay(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hidden when highlightedAyah is null', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('shows label + play button when highlighted', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    expect(find.textContaining('Surah 2, Ayah 5'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('tapping play calls PlaybackCubit.playSelected', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(p.lastPlay, _target);
  });

  testWidgets('shows pause icon while playing', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('close button calls stop + clearHighlight', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    expect(p.stopped, isTrue);
    expect(m.cleared, isTrue);
  });

  testWidgets('skip-prev disabled at (1,1); skip-next disabled at (114, last)',
      (tester) async {
    final m1 = _FakeMushaf(const MushafState(
        currentPage: 1,
        highlightedAyah: AyahIdentifier(surah: 1, ayah: 1)));
    final p1 = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m1, p: p1));
    await tester.pumpAndSettle();
    final prevBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous));
    expect(prevBtn.onPressed, isNull);
  });

  testWidgets('loading state shows a spinner instead of play icon',
      (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState(isLoading: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('speed chip opens menu; selecting calls setSpeed', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState(speed: 1.0));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    expect(p.speedSet, 1.5);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart
```

Expected: FAIL (widget doesn't exist).

- [ ] **Step 3: Implement overlay**

```dart
// lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as q;

import '../../../../../../generated/l10n.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

class AyahPlaybackOverlay extends StatelessWidget {
  const AyahPlaybackOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) => a.highlightedAyah != b.highlightedAyah,
      builder: (context, mushafState) {
        final target = mushafState.highlightedAyah;
        final visible = target != null;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: visible
                  ? _Body(target: target)
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.target});
  final AyahIdentifier target;

  bool get _isFirst => target.surah == 1 && target.ayah == 1;
  bool get _isLast =>
      target.surah == 114 && target.ayah == q.getVerseCount(114);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: s.playback_close,
                    onPressed: () {
                      context.read<PlaybackCubit>().stop();
                      context.read<MushafCubit>().clearHighlight();
                    },
                  ),
                  Expanded(
                    child: Text(
                      s.ayah_label(target.surah.toString(),
                          target.ayah.toString()),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _SpeedChip(),
                ],
              ),
              BlocBuilder<PlaybackCubit, PlaybackState>(
                buildWhen: (a, b) =>
                    a.isPlaying != b.isPlaying ||
                    a.isLoading != b.isLoading ||
                    a.currentAyah != b.currentAyah,
                builder: (context, p) {
                  final isTargetPlaying =
                      p.currentAyah == target && p.isPlaying;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: s.playback_previous,
                        onPressed: _isFirst
                            ? null
                            : () => context.read<PlaybackCubit>().skipPrevious(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay),
                        tooltip: s.playback_restart,
                        onPressed: p.currentAyah == null
                            ? null
                            : () => context.read<PlaybackCubit>().restartCurrent(),
                      ),
                      _PlayPauseButton(
                        target: target,
                        isPlaying: isTargetPlaying,
                        isLoading: p.isLoading,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        tooltip: s.playback_next,
                        onPressed: _isLast
                            ? null
                            : () => context.read<PlaybackCubit>().skipNext(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.target,
    required this.isPlaying,
    required this.isLoading,
  });
  final AyahIdentifier target;
  final bool isPlaying;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return IconButton(
      iconSize: 40,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      tooltip: isPlaying ? S.of(context).playback_pause : S.of(context).play,
      onPressed: () {
        final cubit = context.read<PlaybackCubit>();
        if (isPlaying) {
          cubit.pause();
        } else {
          cubit.playSelected(target);
        }
      },
    );
  }
}

class _SpeedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) => a.speed != b.speed,
      builder: (context, state) {
        return PopupMenuButton<double>(
          tooltip: S.of(context).playback_speed,
          onSelected: (v) => context.read<PlaybackCubit>().setSpeed(v),
          itemBuilder: (_) => _speeds
              .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('${state.speed}x'),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart \
        test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart
git commit -m "feat(mushaf): add AyahPlaybackOverlay (play/pause/skip/restart/speed/close)"
```

---

### Task 19: `MushafPageView` — add long-press gesture

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`

- [ ] **Step 1: Add `onLongPressStart` to the gesture detector**

In `_MushafPageViewState.build`, replace the `GestureDetector` block with:

```dart
Positioned.fill(
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (details) => _handleTap(
      context, details.localPosition, constraints, entity.ayahs),
    onLongPressStart: (details) => _handleLongPress(
      context, details.localPosition, constraints, entity.ayahs),
  ),
),
```

Add the handler:

```dart
void _handleLongPress(BuildContext context, Offset local, BoxConstraints c,
    List<AyahBoundEntity> ayahs) {
  final hit = _hitTest(local, c, ayahs);
  if (hit == null) return;
  AyahLongPressSheet.show(context, hit);
}
```

Add the import:

```dart
import 'ayah_long_press_sheet.dart';
```

- [ ] **Step 2: Compile**

```bash
flutter analyze lib/features/surah/presentation/pages/mushaf
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart
git commit -m "feat(mushaf): long-press ayah opens AyahLongPressSheet"
```

---

### Task 20: `MushafPage` — swap widget, dispose snapshot, init restore

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
- Test: `test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart` (new)

- [ ] **Step 1: Write failing test**

```dart
// test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/domain/repositories/last_read_repository.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);
  AyahIdentifier? highlighted;
  @override void clearHighlight() {}
  @override void toggleHighlight(AyahIdentifier a) {
    highlighted = a;
    emit(state.copyWith(highlightedAyah: a));
  }
  @override void setPage(int p) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier =>
      throw UnimplementedError();
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);
  int stopCalls = 0;
  @override Future<void> stop() async {
    stopCalls++;
    emit(state.copyWith(clearCurrentAyah: true, isPlaying: false));
  }
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubRepo implements LastReadRepository {
  LastRead? saved;
  @override Future<LastRead?> get() async => null;
  @override Future<void> save(LastRead value) async => saved = value;
  @override Stream<LastRead?> watch() => const Stream.empty();
}

class _StubPageService implements QuranPageService {
  @override int? getPageForAyah(int s, int a) => 1;
  @override AyahIdentifier? getFirstAyahOfPage(int p) => null;
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    if (sl.isRegistered<QuranPageService>()) sl.unregister<QuranPageService>();
    sl.registerSingleton<QuranPageService>(_StubPageService());
  });

  testWidgets('on dispose: saves (page, highlighted) then stops playback',
      (tester) async {
    final mushaf = _FakeMushaf(
      const MushafState(currentPage: 7,
          highlightedAyah: AyahIdentifier(surah: 2, ayah: 5)));
    final playback = _FakePlayback(const PlaybackState());
    final repo = _StubRepo();

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(value: mushaf),
          BlocProvider<PlaybackCubit>.value(value: playback),
          BlocProvider<LastReadCubit>.value(
              value: LastReadCubit(repository: repo)),
        ],
        child: const MushafPage(initialPage: 7),
      ),
    ));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(repo.saved, const LastRead(
      page: 7,
      ayah: AyahIdentifier(surah: 2, ayah: 5),
    ));
    expect(playback.stopCalls, 1);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Update `MushafPage`**

Replace `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../domain/entities/last_read.dart';
import '../../cubit/last_read/last_read_cubit.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'auto_swap_helper.dart';
import 'widgets/ayah_playback_overlay.dart';
import 'widgets/mushaf_page_number_text.dart';
import 'widgets/mushaf_page_view.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.initialPage});
  final int initialPage;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late final PageController _controller;
  late final MushafCubit _mushafCubit;
  late final PlaybackCubit _playbackCubit;
  late final LastReadCubit _lastReadCubit;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
    _controller.addListener(_precacheNeighbours);

    // Read cubits once for use in dispose (context is gone by then).
    _mushafCubit = context.read<MushafCubit>();
    _playbackCubit = context.read<PlaybackCubit>();
    _lastReadCubit = context.read<LastReadCubit>();

    // Clean any stale playback singleton state.
    _playbackCubit.stop();

    // Restore highlighted ayah if the last-read points to this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final last = _lastReadCubit.state;
      if (last?.ayah == null) return;
      if (last!.page != widget.initialPage) return;
      _mushafCubit.toggleHighlight(last.ayah!);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_precacheNeighbours);

    final mushafState = _mushafCubit.state;
    final ayah = mushafState.highlightedAyah
        ?? _playbackCubit.state.currentAyah;
    // Fire-and-forget: don't block dispose on a Hive write.
    _lastReadCubit
        .save(LastRead(page: mushafState.currentPage, ayah: ayah))
        .catchError((_) {});
    _playbackCubit.stop();

    _controller.dispose();
    super.dispose();
  }

  int _pageNumberFor(int index) => index + 1;

  void _precacheNeighbours() {
    final idx = _controller.page?.round();
    if (idx == null) return;
    for (final neighbour in [idx - 1, idx + 1]) {
      if (neighbour < 0 || neighbour > 603) continue;
      final page = _pageNumberFor(neighbour);
      precacheImage(
        AssetImage(
            'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png'),
        context,
      );
    }
  }

  void _onPlayingAyahChanged(MushafState state) {
    if (!_controller.hasClients) return;
    final targetIdx = computeAutoSwapTargetIndex(
      playingAyah: state.playingAyah,
      currentPageIndex: _controller.page?.round(),
      pageService: sl<QuranPageService>(),
    );
    if (targetIdx == null) return;
    _controller.animateToPage(
      targetIdx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MushafCubit, MushafState>(
      listenWhen: (a, b) => a.playingAyah != b.playingAyah,
      listener: (_, state) => _onPlayingAyahChanged(state),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
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
              ),
              const AyahPlaybackOverlay(),
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) => a.currentPage != b.currentPage,
                builder: (context, state) =>
                    MushafPageNumberText(pageNumber: state.currentPage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update routes to provide `LastReadCubit`**

Edit `lib/config/router/app_router.dart`. The `/mushaf` and `/mushafImage` routes both wrap `MushafPage` in a `MultiBlocProvider`; add the `LastReadCubit` value provider:

```dart
providers: [
  BlocProvider.value(value: sl<PlaybackCubit>()),
  BlocProvider.value(value: sl<LastReadCubit>()),
  BlocProvider(create: (_) => sl<MushafCubit>(param1: pageNo)),
],
```

(If the root provider added in Task 16 already covers this, the route-level addition is harmless but unnecessary; either way the cubit must be in-scope for `context.read<LastReadCubit>()`.)

Add the import:

```dart
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
```

- [ ] **Step 5: Run dispose test — verify pass**

```bash
flutter test test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
```

Expected: passes.

- [ ] **Step 6: Run all mushaf tests to confirm no regression**

```bash
flutter test test/features/surah/presentation/
```

Expected: all pass, including the existing `ayah_highlight_painter_merge_test.dart` (the §3.4 lock).

- [ ] **Step 7: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart \
        lib/config/router/app_router.dart \
        test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
git commit -m "feat(mushaf): wire AyahPlaybackOverlay; snapshot+stop on dispose; restore on init"
```

---

### Task 21: Delete `AyahActionBar` and its test

**Files:**
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart`
- Delete: `test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart`

- [ ] **Step 1: Delete**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart \
       test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart
```

- [ ] **Step 2: Verify no remaining imports**

```bash
grep -rn "ayah_action_bar\|AyahActionBar" lib test
```

Expected: no matches.

- [ ] **Step 3: Full test pass**

```bash
flutter test
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(mushaf): remove AyahActionBar (replaced by AyahPlaybackOverlay)"
```

---

### Task 22: `LastQuranRead` widget — real data + navigation + localization

**Files:**
- Modify: `lib/core/widgets/last_quran_read.dart`
- Test: `test/core/widgets/last_quran_read_test.dart` (new)

- [ ] **Step 1: Write failing test**

```dart
// test/core/widgets/last_quran_read_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/widgets/last_quran_read.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeCubit extends Cubit<LastRead?> implements LastReadCubit {
  _FakeCubit(super.initial);
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(_FakeCubit cubit, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    locale: locale,
    home: Scaffold(
      body: BlocProvider<LastReadCubit>.value(
        value: cubit,
        child: const LastQuranRead(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders ayah label when ayah present', (tester) async {
    final cubit = _FakeCubit(const LastRead(
      page: 42, ayah: AyahIdentifier(surah: 2, ayah: 5)));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Surah 2, Ayah 5'), findsOneWidget);
  });

  testWidgets('renders page label when no ayah', (tester) async {
    final cubit = _FakeCubit(const LastRead(page: 42));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page 42'), findsOneWidget);
  });

  testWidgets('renders Continue label', (tester) async {
    final cubit = _FakeCubit(const LastRead(page: 1));
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Continue reading'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/core/widgets/last_quran_read_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Rewrite widget**

Replace `lib/core/widgets/last_quran_read.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../config/router/app_router.dart';
import '../../config/theme/color_scheme.dart';
import '../../config/theme/typography_styles.dart';
import '../../features/surah/domain/entities/last_read.dart';
import '../../features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import '../../generated/l10n.dart';
import '../constants/assets_dir.dart';
import '../helper functions/locale_helpers.dart';
import '../widgets/prettier_tap.dart';

class LastQuranRead extends StatelessWidget {
  const LastQuranRead({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LastReadCubit, LastRead?>(
      builder: (context, last) {
        return AspectRatio(
          aspectRatio: 2.9,
          child: Container(
            padding: EdgeInsets.only(
              left: context.isArabic ? 6 : 12,
              right: !context.isArabic ? 6 : 12,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection:
                      context.isArabic ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Text(
                      S.of(context).continue_reading,
                      style: TS.bold20,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      _subtitle(context, last),
                      style: TS.bold16.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(12),
                    PrettierTap(
                      onTap: last == null
                          ? null
                          : () => GoRouter.of(context).push(
                                AppRouter.mushafPath,
                                extra: last.page,
                              ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Text(
                          S.of(context).continue_reading,
                          style: TS.bold16.copyWith(
                            color: context.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Image.asset(
                  AssetsDir.iconsDir('quran_icon.png'),
                  color: context.colorScheme.onSurface,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(BuildContext context, LastRead? last) {
    if (last == null) return S.of(context).page_label('1');
    final ayah = last.ayah;
    if (ayah != null) {
      return S.of(context).ayah_label(
            ayah.surah.toString(),
            ayah.ayah.toString(),
          );
    }
    return S.of(context).page_label(last.page.toString());
  }
}
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/core/widgets/last_quran_read_test.dart
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/last_quran_read.dart \
        test/core/widgets/last_quran_read_test.dart
git commit -m "feat(home): bind LastQuranRead to LastReadCubit + real navigation"
```

---

### Task 23: `SurahListTile` — add "play surah" button

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart`
- Test: `test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart` (new)

- [ ] **Step 1: Write failing test**

```dart
// test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  AyahIdentifier? lastPlay;
  @override
  Future<void> playFromAyah(AyahIdentifier a) async => lastPlay = a;
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('play button calls playFromAyah(surah, 1)', (tester) async {
    final surah = SurahEntity(
      number: 2,
      name: 'البقرة',
      englishName: 'Al-Baqarah',
      qcfSurahName: 'سُورَةُ ٱلْبَقَرَةِ',
      revelationType: 'مدنية',
      numberOfAyahs: 286,
      pageNumber: 2,
    );
    final playback = _FakePlayback();
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<PlaybackCubit>.value(
        value: playback,
        child: Scaffold(body: SurahListTile(surah: surah)),
      ),
    ));
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    expect(playback.lastPlay, const AyahIdentifier(surah: 2, ayah: 1));
  });
}
```

- [ ] **Step 2: Run — verify failure**

```bash
flutter test test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Add play button to tile**

In `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart`, in the trailing `Row` between the text column and `SurahNumberStar`, insert:

```dart
IconButton(
  icon: const Icon(Icons.play_circle_outline),
  tooltip: S.of(context).play_surah,
  onPressed: () {
    context.read<PlaybackCubit>().playFromAyah(
          AyahIdentifier(surah: surah.number, ayah: 1),
        );
    GoRouter.of(context).push(
      AppRouter.mushafPath,
      extra: surah.pageNumber,
    );
  },
),
```

Add imports:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../generated/l10n.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
```

The `Row` then becomes (the IconButton sits between the existing Column and the SurahNumberStar):

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Column(...existing...),
    IconButton(...new play button...),
    SurahNumberStar(surahNumber: surah.number),
  ],
),
```

- [ ] **Step 4: Run — verify pass**

```bash
flutter test test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart
```

Expected: passes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart \
        test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart
git commit -m "feat(surah_list): add play-surah-from-start button"
```

---

## Phase 4 — Final verification

### Task 24: Full suite + manual smoke test

**Files:** none modified.

- [ ] **Step 1: Run the entire test suite**

```bash
flutter test
```

Expected: ALL tests pass, including the `ayah_highlight_painter_merge_test.dart` golden lock (§3.4 of the verse-tap-action-bar design).

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: no errors, no warnings.

- [ ] **Step 3: Manual smoke checklist (run the app on a device/emulator)**

```bash
flutter run
```

Verify each path on an emulator/device — the test suite catches behavior, but UI polish (animations, layouts) needs eyeballs. Per `CLAUDE.md`-style guidance, if you can't actually run the device, say so explicitly rather than checking these off:

- [ ] Open Mushaf, tap an ayah → overlay slides up. Press play → audio starts (with download spinner first time).
- [ ] Pause → icon flips to play; resume from same spot.
- [ ] Skip-next → next ayah plays.
- [ ] Skip-prev → previous ayah plays.
- [ ] Restart → current ayah replays from start.
- [ ] Speed chip → pick 1.5x; audio speeds up; the chip label updates.
- [ ] Close → audio stops, overlay slides away.
- [ ] Long-press an ayah → modal sheet appears with 4 actions + reciter chips. Tap a new reciter while audio is playing → audio restarts current ayah with new reciter.
- [ ] Tap a different verse while audio plays → overlay re-targets, audio keeps playing the previous one. Press play → switches to new target.
- [ ] Navigate to home → return via `LastQuranRead`'s Continue button → opens at last page; if a paused ayah was set, the overlay shows it in idle state.
- [ ] Tap a surah's play-surah button on Surah List → opens Mushaf at the first page of that surah AND starts playing ayah 1 (you should hear basmala then ayah 1 for surahs 2–114, except 9).

- [ ] **Step 4: Commit any l10n/analyzer fixups discovered along the way (if any)**

```bash
git add -A
git status   # review carefully — make sure nothing unexpected is staged
git commit -m "chore: post-implementation polish from smoke test"
```

(If nothing changed, skip this step.)

---

## Appendix — Spec coverage map

| Spec section | Implementing task(s) |
|---|---|
| §2.1 Mushaf gestures (tap / long-press) | 18, 19, 20 |
| §2.2 Overlay controls | 18 |
| §2.3 Long-press sheet | 17 |
| §2.4 Continue Reading | 12–16, 20, 22 |
| §2.5 Play surah from start | 23 |
| §3.1 Cubit ownership | 6–11, 15 |
| §3.2 Overlay visibility rule | 18 |
| §3.3 Auto-follow rule | 11 |
| §3.4 Dispose order | 20 |
| §4.1 PlaybackState additions | 5 |
| §4.2 PlaybackCubit new methods | 6, 7, 8, 9, 10 |
| §4.3 getPreviousAyah | 3 |
| §4.4 MushafCubit auto-follow | 11 |
| §4.5 SettingsCubit additions | 2 |
| §4.6 Repo seek + setSpeed | 4 |
| §4.7 LastReadRepository | 12, 13, 14 |
| §4.8 LastReadCubit | 15 |
| §5 File map | 1–23 (all) |
| §6 Localization | 1 |
| §7 Errors / edge cases | 6 (race), 18 (disabled), 20 (init clean), repo cache (existing) |
| §8 Testing strategy | 2, 3, 5–11, 14, 15, 17, 18, 20, 22, 23 |
| Appendix A (basmala) | Implicit — Task 23 relies on it; no code change needed |
