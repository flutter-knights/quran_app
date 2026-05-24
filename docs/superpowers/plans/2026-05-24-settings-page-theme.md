# Settings Page & 4-Palette Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the settings bottom sheet with a full settings page and swap the single dark/light palette for a 4-way `ColorPalette` enum that drives the entire app theme.

**Architecture:** A pure-Dart `ColorPalette` enum (domain-safe) is extended by `AppPaletteX` in the config layer, which adds Flutter `Color`/`ThemeData` getters. `SettingsCubit` stores `ColorPalette` instead of `isDarkMode`; `MaterialApp` receives `palette.toThemeData()` directly — no `darkTheme`/`themeMode` needed.

**Tech Stack:** Flutter, flutter_bloc / HydratedBloc, GoRouter, HugeIcons, GetIt (`sl<>()`), existing `TS` typography helpers, `context.colorScheme` extension.

---

## File Map

| File | Action |
|---|---|
| `lib/core/constants/color_palette.dart` | Create |
| `lib/config/theme/app_palette.dart` | Create |
| `lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart` | Create |
| `lib/features/settings/presentation/pages/settings_page.dart` | Create |
| `lib/features/settings/domain/entities/settings.dart` | Modify |
| `lib/features/settings/data/models/settings_model.dart` | Modify |
| `lib/features/settings/presentation/cubit/settings_cubit.dart` | Modify |
| `lib/config/theme/app_colors.dart` | Modify (strip to error only) |
| `lib/config/theme/color_scheme.dart` | Modify (remove ColorScheme constants) |
| `lib/config/router/app_router.dart` | Modify (add route + constant) |
| `lib/main.dart` | Modify (use palette.toThemeData()) |
| `lib/features/home/presentation/pages/widgets/home_app_bar.dart` | Modify (push instead of showSettings) |
| `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_app_bar.dart` | Modify (push instead of showSettings) |
| `lib/config/theme/dark_theme.dart` | Delete |
| `lib/config/theme/light_theme.dart` | Delete |
| `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart` | Delete |
| `test/core/constants/color_palette_test.dart` | Create |
| `test/config/theme/app_palette_test.dart` | Create |
| `test/features/settings/data/models/settings_model_test.dart` | Create |

---

## Task 1: ColorPalette Enum

**Files:**
- Create: `lib/core/constants/color_palette.dart`
- Create: `test/core/constants/color_palette_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/constants/color_palette_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/color_palette.dart';

void main() {
  test('ColorPalette has exactly 4 values', () {
    expect(ColorPalette.values.length, 4);
  });

  test('values are named correctly', () {
    expect(ColorPalette.neutralDark.name, 'neutralDark');
    expect(ColorPalette.neutralLight.name, 'neutralLight');
    expect(ColorPalette.slateDark.name, 'slateDark');
    expect(ColorPalette.slateLight.name, 'slateLight');
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```
flutter test test/core/constants/color_palette_test.dart
```
Expected: Error — `color_palette.dart` not found.

- [ ] **Step 3: Create the enum**

```dart
// lib/core/constants/color_palette.dart
enum ColorPalette { neutralDark, neutralLight, slateDark, slateLight }
```

- [ ] **Step 4: Run test — expect PASS**

```
flutter test test/core/constants/color_palette_test.dart
```
Expected: All tests pass.

- [ ] **Step 5: Commit**

```
git add lib/core/constants/color_palette.dart test/core/constants/color_palette_test.dart
git commit -m "feat(theme): add ColorPalette enum"
```

---

## Task 2: AppPalette Extension

**Files:**
- Create: `lib/config/theme/app_palette.dart`
- Create: `test/config/theme/app_palette_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/config/theme/app_palette_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';

void main() {
  group('isDark', () {
    test('neutralDark is dark', () => expect(ColorPalette.neutralDark.isDark, true));
    test('neutralLight is not dark', () => expect(ColorPalette.neutralLight.isDark, false));
    test('slateDark is dark', () => expect(ColorPalette.slateDark.isDark, true));
    test('slateLight is not dark', () => expect(ColorPalette.slateLight.isDark, false));
  });

  group('bg colors', () {
    test('neutralDark bg', () => expect(ColorPalette.neutralDark.bg, const Color(0xFF0D0D0D)));
    test('neutralLight bg', () => expect(ColorPalette.neutralLight.bg, const Color(0xFFF4F4F4)));
    test('slateDark bg', () => expect(ColorPalette.slateDark.bg, const Color(0xFF0A0C10)));
    test('slateLight bg', () => expect(ColorPalette.slateLight.bg, const Color(0xFFF0F3F8)));
  });

  group('family color sharing', () {
    test('neutral palettes share primary', () {
      expect(ColorPalette.neutralDark.primary, ColorPalette.neutralLight.primary);
    });
    test('slate palettes share secondary', () {
      expect(ColorPalette.slateDark.secondary, ColorPalette.slateLight.secondary);
    });
  });

  group('toThemeData', () {
    test('neutralDark produces dark brightness', () {
      final theme = ColorPalette.neutralDark.toThemeData();
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
    test('slateLight produces light brightness', () {
      final theme = ColorPalette.slateLight.toThemeData();
      expect(theme.colorScheme.brightness, Brightness.light);
    });
    test('theme uses palette primary as colorScheme.primary', () {
      final theme = ColorPalette.slateDark.toThemeData();
      expect(theme.colorScheme.primary, ColorPalette.slateDark.primary);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```
flutter test test/config/theme/app_palette_test.dart
```
Expected: Error — `app_palette.dart` not found.

- [ ] **Step 3: Create the extension**

```dart
// lib/config/theme/app_palette.dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_colors.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/color_palette.dart';

extension AppPaletteX on ColorPalette {
  bool get isDark =>
      this == ColorPalette.neutralDark || this == ColorPalette.slateDark;

  Color get bg => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF0D0D0D),
        ColorPalette.neutralLight => const Color(0xFFF4F4F4),
        ColorPalette.slateDark => const Color(0xFF0A0C10),
        ColorPalette.slateLight => const Color(0xFFF0F3F8),
      };

  Color get surface => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF1A1A1A),
        ColorPalette.neutralLight => const Color(0xFFEAEAEA),
        ColorPalette.slateDark => const Color(0xFF141820),
        ColorPalette.slateLight => const Color(0xFFE2E8F2),
      };

  Color get primary => switch (this) {
        ColorPalette.neutralDark || ColorPalette.neutralLight =>
          const Color(0xFF2E5244),
        ColorPalette.slateDark || ColorPalette.slateLight =>
          const Color(0xFF1C4558),
      };

  Color get secondary => switch (this) {
        ColorPalette.neutralDark || ColorPalette.neutralLight =>
          const Color(0xFF5C8070),
        ColorPalette.slateDark || ColorPalette.slateLight =>
          const Color(0xFF4878A0),
      };

  Color get onSurface => switch (this) {
        ColorPalette.neutralDark => const Color(0xFFF5F5F5),
        ColorPalette.neutralLight => const Color(0xFF141414),
        ColorPalette.slateDark => const Color(0xFFF0F4F8),
        ColorPalette.slateLight => const Color(0xFF0A0C12),
      };

  Color get onSurfaceVar => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF8A8A8A),
        ColorPalette.neutralLight => const Color(0xFF686868),
        ColorPalette.slateDark => const Color(0xFF8A92A0),
        ColorPalette.slateLight => const Color(0xFF5E6880),
      };

  Color get mushafBg => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF1C1A14),
        ColorPalette.neutralLight => const Color(0xFFFFFCF5),
        ColorPalette.slateDark => const Color(0xFF111620),
        ColorPalette.slateLight => const Color(0xFFF8FBFF),
      };

  Color get mushafText => switch (this) {
        ColorPalette.neutralDark => const Color(0xFFD4C5B0),
        ColorPalette.neutralLight => const Color(0xFF1A1208),
        ColorPalette.slateDark => const Color(0xFFC8D4E0),
        ColorPalette.slateLight => const Color(0xFF0A0E14),
      };

  // rgba(255,255,255,0.06) for dark; rgba(0,0,0,0.06) for light
  Color get mushafBorderColor =>
      isDark ? const Color(0x0FFFFFFF) : const Color(0x0F000000);

  ColorScheme get colorScheme => ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: const Color(0xFFF5F5F5),
        secondary: secondary,
        onSecondary: const Color(0xFFF5F5F5),
        error: AppColors.error,
        onError: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
        surface: bg,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVar,
        surfaceContainer: surface,
      );

  ThemeData toThemeData() => ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          suffixIconColor: onSurface,
          prefixIconColor: onSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: TS.regular15.copyWith(color: onSurface),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
}
```

- [ ] **Step 4: Run tests — expect PASS**

```
flutter test test/config/theme/app_palette_test.dart
```
Expected: All 11 tests pass.

- [ ] **Step 5: Commit**

```
git add lib/config/theme/app_palette.dart test/config/theme/app_palette_test.dart
git commit -m "feat(theme): add AppPaletteX extension with 4-palette ThemeData"
```

---

## Task 3: Domain + Data + Cubit Migration (Atomic — do NOT commit mid-task)

This task removes `isDarkMode` from the entire stack and replaces it with `ColorPalette`. All steps must be completed before the project will compile. Run `flutter analyze` only at Step 14 to verify.

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Modify: `lib/config/theme/app_colors.dart`
- Modify: `lib/config/theme/color_scheme.dart`
- Modify: `lib/main.dart`
- Modify: `lib/config/router/app_router.dart` (add constant only)
- Modify: `lib/features/home/presentation/pages/widgets/home_app_bar.dart`
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_app_bar.dart`
- Delete: `lib/config/theme/dark_theme.dart`
- Delete: `lib/config/theme/light_theme.dart`
- Delete: `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`
- Create: `test/features/settings/data/models/settings_model_test.dart`

- [ ] **Step 1: Write the failing serialization tests**

```dart
// test/features/settings/data/models/settings_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  group('SettingsModel.toMap', () {
    test('writes palette name, no isDarkMode key', () {
      const model = SettingsModel(
        isFormat12Hours: true,
        isArabic: false,
        palette: ColorPalette.slateDark,
      );
      final map = model.toMap();
      expect(map['palette'], 'slateDark');
      expect(map.containsKey('isDarkMode'), false);
    });
  });

  group('SettingsModel.fromMap', () {
    test('restores palette from name', () {
      final model = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': false,
        'palette': 'slateLight',
      });
      expect(model.palette, ColorPalette.slateLight);
    });

    test('defaults to neutralDark when palette key absent', () {
      final model = SettingsModel.fromMap({'isArabic': true, 'isFormat12Hours': true});
      expect(model.palette, ColorPalette.neutralDark);
    });

    test('ignores stale isDarkMode key without crashing', () {
      final model = SettingsModel.fromMap({
        'isArabic': true,
        'isFormat12Hours': true,
        'isDarkMode': true, // legacy key — must be silently ignored
      });
      expect(model.palette, ColorPalette.neutralDark);
    });
  });

  group('round-trip', () {
    test('toMap then fromMap preserves all fields', () {
      const original = SettingsModel(
        isFormat12Hours: false,
        isArabic: true,
        palette: ColorPalette.neutralLight,
      );
      final restored = SettingsModel.fromMap(original.toMap());
      expect(restored.palette, original.palette);
      expect(restored.isFormat12Hours, original.isFormat12Hours);
      expect(restored.isArabic, original.isArabic);
    });
  });
}
```

- [ ] **Step 2: Update `lib/features/settings/domain/entities/settings.dart`**

Replace the entire file:

```dart
import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isFormat12Hours;
  final bool isArabic;
  final ColorPalette palette;
  final double playbackSpeed;
  final Reciter defaultReciter;
  final bool isPrayerStripPinned;
  final Map<PrayerName, bool> adhanEnabledByPrayer;
  final Map<PrayerName, int> reminderMinutesByPrayer;

  static const Map<PrayerName, bool> defaultAdhanEnabled = {
    PrayerName.fajr: true,
    PrayerName.dhuhr: true,
    PrayerName.asr: true,
    PrayerName.maghrib: true,
    PrayerName.isha: true,
  };

  static const Map<PrayerName, int> defaultReminderMinutes = {
    PrayerName.fajr: 0,
    PrayerName.dhuhr: 0,
    PrayerName.asr: 0,
    PrayerName.maghrib: 0,
    PrayerName.isha: 0,
  };

  static const List<int> validReminderMinutes = [0, 5, 10, 15];

  const Settings({
    required this.isFormat12Hours,
    required this.isArabic,
    this.palette = ColorPalette.neutralDark,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
    this.isPrayerStripPinned = false,
    this.adhanEnabledByPrayer = defaultAdhanEnabled,
    this.reminderMinutesByPrayer = defaultReminderMinutes,
  });

  Settings copyWith({
    bool? isFormat12Hours,
    bool? isArabic,
    ColorPalette? palette,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      palette: palette ?? this.palette,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer:
          reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
    );
  }

  @override
  List<Object?> get props => [
        isArabic,
        isFormat12Hours,
        palette,
        playbackSpeed,
        defaultReciter,
        isPrayerStripPinned,
        adhanEnabledByPrayer,
        reminderMinutesByPrayer,
      ];
}
```

- [ ] **Step 3: Update `lib/features/settings/data/models/settings_model.dart`**

Replace the entire file:

```dart
import 'package:collection/collection.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isFormat12Hours,
    required super.isArabic,
    super.palette,
    super.playbackSpeed,
    super.defaultReciter,
    super.isPrayerStripPinned,
    super.adhanEnabledByPrayer,
    super.reminderMinutesByPrayer,
  });

  @override
  SettingsModel copyWith({
    bool? isFormat12Hours,
    bool? isArabic,
    ColorPalette? palette,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      palette: palette ?? this.palette,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer:
          reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      isFormat12Hours: map['isFormat12Hours'] ?? true,
      palette: ColorPalette.values.firstWhere(
        (p) => p.name == (map['palette'] as String?),
        orElse: () => ColorPalette.neutralDark,
      ),
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
      isPrayerStripPinned: map['isPrayerStripPinned'] ?? false,
      adhanEnabledByPrayer: _readEnabledMap(map['adhanEnabledByPrayer']),
      reminderMinutesByPrayer: _readReminderMap(map['reminderMinutesByPrayer']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isFormat12Hours': isFormat12Hours,
      'palette': palette.name,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
      'isPrayerStripPinned': isPrayerStripPinned,
      'adhanEnabledByPrayer': {
        for (final e in adhanEnabledByPrayer.entries) e.key.name: e.value,
      },
      'reminderMinutesByPrayer': {
        for (final e in reminderMinutesByPrayer.entries) e.key.name: e.value,
      },
    };
  }

  static Map<PrayerName, bool> _readEnabledMap(dynamic raw) {
    if (raw is! Map) return Settings.defaultAdhanEnabled;
    final result = <PrayerName, bool>{...Settings.defaultAdhanEnabled};
    for (final e in raw.entries) {
      if (e.key is! String) continue;
      final p = PrayerName.values.firstWhereOrNull((x) => x.name == e.key);
      final v = e.value;
      if (p != null && v is bool) result[p] = v;
    }
    return result;
  }

  static Map<PrayerName, int> _readReminderMap(dynamic raw) {
    if (raw is! Map) return Settings.defaultReminderMinutes;
    final result = <PrayerName, int>{...Settings.defaultReminderMinutes};
    for (final e in raw.entries) {
      if (e.key is! String) continue;
      final p = PrayerName.values.firstWhereOrNull((x) => x.name == e.key);
      final v = e.value;
      if (p != null && v is int && Settings.validReminderMinutes.contains(v)) {
        result[p] = v;
      }
    }
    return result;
  }
}
```

- [ ] **Step 4: Update `lib/features/settings/presentation/cubit/settings_cubit.dart`**

Replace the entire file:

```dart
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit()
      : super(
          SettingsState(
            SettingsModel(
              palette: ColorPalette.neutralDark,
              isFormat12Hours: true,
              isArabic: true,
            ),
          ),
        );

  void updateSettings({bool? isFormat12Hours, bool? isArabic}) {
    emit(
      SettingsState(
        state.settingsModel.copyWith(
          isFormat12Hours: isFormat12Hours,
          isArabic: isArabic,
        ),
      ),
    );
  }

  void updatePalette(ColorPalette palette) {
    emit(SettingsState(state.settingsModel.copyWith(palette: palette)));
  }

  void updatePlaybackSpeed(double speed) {
    emit(SettingsState(state.settingsModel.copyWith(playbackSpeed: speed)));
  }

  void updateDefaultReciter(Reciter reciter) {
    emit(SettingsState(state.settingsModel.copyWith(defaultReciter: reciter)));
  }

  void updatePrayerStripPinned(bool value) {
    emit(
      SettingsState(state.settingsModel.copyWith(isPrayerStripPinned: value)),
    );
  }

  void updateAdhanEnabled(PrayerName prayer, bool enabled) {
    final next = Map<PrayerName, bool>.from(
      state.settingsModel.adhanEnabledByPrayer,
    )..[prayer] = enabled;
    emit(SettingsState(state.settingsModel.copyWith(adhanEnabledByPrayer: next)));
  }

  void updateReminderMinutes(PrayerName prayer, int minutes) {
    assert(
      Settings.validReminderMinutes.contains(minutes),
      'reminder minutes must be one of ${Settings.validReminderMinutes}, got $minutes',
    );
    final next = Map<PrayerName, int>.from(
      state.settingsModel.reminderMinutesByPrayer,
    )..[prayer] = minutes;
    emit(SettingsState(state.settingsModel.copyWith(reminderMinutesByPrayer: next)));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    return SettingsState(SettingsModel.fromMap(json));
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    return state.settingsModel.toMap();
  }
}
```

- [ ] **Step 5: Strip `lib/config/theme/app_colors.dart`**

Replace the entire file:

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color error = Color(0xFFE67E7E);
}
```

- [ ] **Step 6: Strip `lib/config/theme/color_scheme.dart`**

Replace the entire file (keep only the BuildContext extension):

```dart
import 'package:flutter/material.dart';

extension ColorSchemeExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
```

- [ ] **Step 7: Delete `lib/config/theme/dark_theme.dart`**

```
# PowerShell
Remove-Item "lib/config/theme/dark_theme.dart"
```

- [ ] **Step 8: Delete `lib/config/theme/light_theme.dart`**

```
# PowerShell
Remove-Item "lib/config/theme/light_theme.dart"
```

- [ ] **Step 9: Update `lib/main.dart`**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/config/hive_config.dart';
import 'package:quran_app/config/hydrated_bloc_config.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const AppLoader());
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await initHydratedCubit();
    await initHive();
    await initGetIt();
    if (!mounted) return;
    setState(() => _ready = true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      while (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      try {
        await sl<PrayerNotificationScheduler>().init();
      } catch (e, st) {
        debugPrint('PrayerNotificationScheduler.init failed: $e\n$st');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Use neutralDark bg for the pre-init splash
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF0D0D0D)),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider(create: (_) => sl<BookmarkCubit>()),
        BlocProvider(create: (_) => sl<LastReadCubit>()),
        BlocProvider(create: (_) => sl<PlaybackCubit>()),
      ],
      child: const QuranApp(),
    );
  }
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = state.settingsModel;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Quran',
          theme: settings.palette.toThemeData(),
          locale: settings.isArabic ? const Locale('ar') : const Locale('en'),
          supportedLocales: S.delegate.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
```

- [ ] **Step 10: Add `settingsPath` constant to `lib/config/router/app_router.dart`**

Add one line to the `AppRouter` abstract class body, directly after the existing path constants:

```dart
static const String settingsPath = "/settings";
```

Do NOT add the `GoRoute` yet — that happens in Task 6.

- [ ] **Step 11: Update `lib/features/home/presentation/pages/widgets/home_app_bar.dart`**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/generated/l10n.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key, required this.dailyPrayerContext});
  final DailyPrayerContext dailyPrayerContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: .start,
        mainAxisAlignment: .spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  S.current.hijriDateWithDay(
                    dailyPrayerContext.prayerTimes.date.weekDay,
                    dailyPrayerContext.prayerTimes.date.day.toLocalized(context),
                    dailyPrayerContext.prayerTimes.date.month,
                    dailyPrayerContext.prayerTimes.date.year.toLocalized(context),
                  ),
                  style: TS.extra20.cairo,
                ),
                Text(
                  [
                    dailyPrayerContext.location.city,
                    dailyPrayerContext.location.country,
                  ].where((s) => s != null && s.isNotEmpty).join(', '),
                  style: TS.medium14
                      .copyWith(color: context.colorScheme.onSurfaceVariant)
                      .cairo,
                ),
              ],
            ),
          ),
          PrettierTap(
            onTap: () => context.push(AppRouter.settingsPath),
            child: HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 28),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 12: Update `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_app_bar.dart`**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import '../../../../../../config/theme/color_scheme.dart';

class SurahListPageAppBar extends StatelessWidget {
  const SurahListPageAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
        textDirection: context.isArabic ? .ltr : .rtl,
        children: [
          IconButton(
            onPressed: () => context.push(AppRouter.settingsPath),
            icon: HugeIcon(
              icon: context.isArabic
                  ? HugeIcons.strokeRoundedArrowLeft02
                  : HugeIcons.strokeRoundedArrowRight02,
              size: 32,
              strokeWidth: 1,
              color: context.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 13: Delete `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`**

```
# PowerShell
Remove-Item "lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart"
```

- [ ] **Step 14: Verify — no compile errors**

```
flutter analyze
```
Expected: No errors. Warnings about unused imports are OK.

- [ ] **Step 15: Run serialization tests**

```
flutter test test/features/settings/data/models/settings_model_test.dart
```
Expected: All 4 tests pass.

- [ ] **Step 16: Commit**

```
git add -A
git commit -m "feat(theme): replace isDarkMode with ColorPalette across domain, data, cubit, and main"
```

---

## Task 4: PalettePickerWidget

**Files:**
- Create: `lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart`

- [ ] **Step 1: Create the widget**

```dart
// lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';

class PalettePickerWidget extends StatelessWidget {
  const PalettePickerWidget({
    super.key,
    required this.currentPalette,
    required this.onSelect,
  });

  final ColorPalette currentPalette;
  final ValueChanged<ColorPalette> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: ColorPalette.values
          .map(
            (p) => _PaletteTile(
              palette: p,
              isSelected: p == currentPalette,
              onTap: () => onSelect(p),
            ),
          )
          .toList(),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final ColorPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (palette) {
        ColorPalette.neutralDark => 'Neutral Dark',
        ColorPalette.neutralLight => 'Neutral Light',
        ColorPalette.slateDark => 'Slate Dark',
        ColorPalette.slateLight => 'Slate Light',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // use surface color when unselected so border is invisible but width is constant
            color: isSelected ? palette.secondary : palette.surface,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 30, 0),
              child: Text(
                _label,
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
              ),
            ),
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle_rounded,
                    color: palette.secondary, size: 14),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes cleanly**

```
flutter analyze lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart
git commit -m "feat(settings): add PalettePickerWidget (2x2 swatch grid)"
```

---

## Task 5: SettingsPage

**Files:**
- Create: `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Step 1: Create the page**

```dart
// lib/features/settings/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/feature_flags.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/settings/presentation/pages/widgets/palette_picker_widget.dart';
import 'package:quran_app/generated/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(S.current.settings, style: TS.bold20.cairo),
        backgroundColor: context.colorScheme.surface,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = state.settingsModel;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 24),
            children: [
              _SectionLabel('APPEARANCE'), // TODO: localize
              const SizedBox(height: 8),
              PalettePickerWidget(
                currentPalette: settings.palette,
                onSelect: (p) => sl<SettingsCubit>().updatePalette(p),
              ),
              const SizedBox(height: 24),
              _SectionLabel('GENERAL'), // TODO: localize
              const SizedBox(height: 8),
              SettingSwitch(
                settings: settings,
                settingTitle: S.current.twentyFourHourFormat,
                icons: const [
                  HugeIcons.strokeRoundedClock01,
                  HugeIcons.strokeRoundedTimeQuarterPass,
                ],
                value: settings.isFormat12Hours,
                action: () => sl<SettingsCubit>().updateSettings(
                  isFormat12Hours: !settings.isFormat12Hours,
                ),
              ),
              SettingSwitch(
                settings: settings,
                settingTitle: S.current.arabicLanguage,
                icons: const [
                  HugeIcons.strokeRoundedLanguageSquare,
                  HugeIcons.strokeRoundedLanguageSquare,
                ],
                value: settings.isArabic,
                action: () => sl<SettingsCubit>().updateSettings(
                  isArabic: !settings.isArabic,
                ),
              ),
              if (FeatureFlags.pinnedPrayerStripUi) ...[
                const SizedBox(height: 24),
                _SectionLabel('NOTIFICATIONS'), // TODO: localize
                const SizedBox(height: 8),
                ListTile(
                  leading:
                      HugeIcon(icon: HugeIcons.strokeRoundedNotification01),
                  title: Text(S.current.notifications, style: TS.regular16.cairo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRouter.notificationsPath),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes cleanly**

```
flutter analyze lib/features/settings/presentation/pages/settings_page.dart
```
Expected: No errors.

- [ ] **Step 3: Commit**

```
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat(settings): add SettingsPage with sectioned layout and palette picker"
```

---

## Task 6: Register Settings Route

**Files:**
- Modify: `lib/config/router/app_router.dart`

- [ ] **Step 1: Add the `GoRoute` for the settings page**

In `lib/config/router/app_router.dart`, add the following import at the top:

```dart
import 'package:quran_app/features/settings/presentation/pages/settings_page.dart';
```

Then inside `GoRouter(routes: [...])`, add the settings route alongside the existing routes (e.g., after the `notificationsPath` route):

```dart
GoRoute(
  path: settingsPath,
  pageBuilder: GoTransitions.fade.withFade.build(
    builder: (context, state) => const SettingsPage(),
  ),
),
```

- [ ] **Step 2: Full analyze**

```
flutter analyze
```
Expected: No issues.

- [ ] **Step 3: Run all tests**

```
flutter test
```
Expected: All tests pass.

- [ ] **Step 4: Commit**

```
git add lib/config/router/app_router.dart
git commit -m "feat(settings): register /settings route and complete settings page navigation"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** ColorPalette enum (Task 1) ✓ · AppPalette extension (Task 2) ✓ · Settings entity + model (Task 3) ✓ · SettingsCubit (Task 3) ✓ · AppColors stripped (Task 3) ✓ · color_scheme.dart stripped (Task 3) ✓ · dark_theme/light_theme deleted (Task 3) ✓ · main.dart wired (Task 3) ✓ · settingsPath constant (Task 3) ✓ · home_app_bar caller updated (Task 3) ✓ · surah_list_app_bar caller updated (Task 3) ✓ · bottom sheet deleted (Task 3) ✓ · PalettePickerWidget (Task 4) ✓ · SettingsPage sectioned (Task 5) ✓ · GoRoute registered (Task 6) ✓
- [x] **No placeholders:** All code steps are complete. No TBDs.
- [x] **Type consistency:** `ColorPalette` used consistently across Settings, SettingsModel, SettingsCubit, PalettePickerWidget, SettingsPage. `AppPaletteX` extension getters (`bg`, `surface`, `primary`, `secondary`, `onSurface`, `onSurfaceVar`, `mushafBg`, `mushafText`, `mushafBorderColor`, `toThemeData()`) match usage in tests and widgets.
