---
description: Clean Architecture enforcement — layer boundaries and dependency direction for the Quran App
paths: ["lib/**/*.dart"]
---

# Architecture Rules

## Layer boundaries (STRICT)

- **Domain** → no imports from data/, config/, or presentation/. No Flutter framework imports.
  - ❌ No `package:flutter/*`, no `dart:ui`, no `generated/l10n.dart` (pulls Flutter transitively), no `config/theme/*`.
  - ✅ Pure Dart only: entities, abstract repos, use cases, enums, value objects.
  - Any extension that uses `S`, `Color`, `BuildContext`, or widgets belongs in **`presentation/`**, never in `domain/entities/extensions/`.
  - Canonical home for enum presentation extensions (`.localized()`, `.color`): `features/<feature>/presentation/utils/`, e.g. `enum_localization.dart` and `enum_colors.dart` side by side.
- **Data** → can import domain/ and config/ (hive init, etc.). No imports from presentation/.
- **Presentation** → can import domain/, config/, and core/. Never import data/ directly.

## Dependency injection

- GetIt, aliased `sl`.
- Data sources, repositories, use cases: **LazySingleton**.
- Cubits: **Factory**, a new instance per screen.
  - Except app-wide cubits that must share one instance. `main.dart`'s `MultiBlocProvider` provides `SettingsCubit` (`registerSingleton`), `BookmarkCubit`, `PageBookmarkCubit`, `LastReadCubit`, `PlaybackCubit`, `DownloadBookCubit` and `AlertsSyncCubit` (`registerLazySingleton`). `HadithBookmarkCubit` is a lazy singleton handed to each screen with `BlocProvider.value(value: sl<HadithBookmarkCubit>())`. Add a singleton only when two screens must see the same instance.
- Register in `features/<feature>/<feature>_di.dart`, called from `core/di/dependency_injection.dart`.

## Caching

- Hive. Hive models (`LocationHiveModel`, `HadithHiveModel`…) live in `data/models/`, are named `*_model.dart` (the only files `build.yaml` generates adapters for), and never leak into domain/ or presentation/. Register each adapter in `config/hive_config.dart`.

## Naming conventions

- Use cases: verb + noun (`GetPrayerTimes`, `GetSurahDetails`, `GetAhadith`).
- Cubits: noun + `Cubit` (`MushafCubit`, `PrayerCountdownCubit`).
- Data sources: `<Entity>RemoteDataSource` (abstract) + `<Entity>RemoteDataSourceImpl`, or `<Entity>LocalDataSource`.
- Repositories: `<Entity>Repository` (abstract in domain/) + `<Entity>RepositoryImpl` (in data/).
- Models: `<Entity>Model` or `<Entity>HiveModel`, extending or mapping to the domain `<Entity>`.

## Error handling

- Repositories and use cases return `Either<Failure, T>` (dartz).
- Map exceptions to `Failure` in the repository: `Failure.fromException(e)` routes `DioException` to `DioErrorHandler` and `LocationException` to `GeolocatorErrorHandler`, anything else to `UnknownFailure`. Catch `CacheException` yourself and return `CacheFailure`. Never let an exception escape a repository.
