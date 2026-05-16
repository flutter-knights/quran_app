---
description: Clean Architecture enforcement — layer boundaries and dependency direction for the Quran App
paths: ["lib/**/*.dart"]
---

# Architecture Rules

## Layer boundaries (STRICT)

- **Domain** → no imports from data/, config/, or presentation/. No Flutter framework imports.
  - ❌ No `package:flutter/*`, no `dart:ui`, no `generated/l10n.dart` (pulls Flutter transitively), no `config/theme/*`.
  - ✅ Pure Dart only: entities, abstract repos, use cases, enums, value objects.
  - Any extension that uses `S.context`, `Color`, `BuildContext`, or widgets belongs in **`presentation/`**, never in `domain/entities/extensions/`.
- **Data** → can import domain/ and config/ (for router, theme, hive init, etc.). No imports from presentation/.
- **Presentation** → can import domain/, config/, and core/. Never import data/ directly.

## Dependency injection

- Dependency Injection is managed via `GetIt` (alias `sl`).
- Data sources & Repositories: **LazySingleton**
- Use Cases: **LazySingleton**
- Cubits: **Factory** (new instance per screen generally, unless it is a global App-level cubit like SettingsCubit)
- Register feature dependencies in `features/<feature>/<feature>_di.dart` (e.g. `initSurah()`), and call it from `core/di/dependency_injection.dart`.

## Caching

- Data caching is implemented using `Hive`.
- Hive Models (e.g. `LocationHiveModel`) must be in `data/models/` and not leak into the `domain/` or `presentation/` layers. Ensure proper TypeAdapter registration in `config/hive_config.dart`.

## Naming conventions

- Use cases: verb + noun (`GetPrayerTimes`, `GetSurahDetails`, `GetAhadith`)
- Cubits: noun + `Cubit` (`MushafCubit`, `PrayerCountdownCubit`)
- Data sources: `<Entity>RemoteDataSource` (abstract) + `<Entity>RemoteDataSourceImpl` or `<Entity>LocalDataSource`.
- Repositories: `<Entity>Repository` (abstract in domain/) + `<Entity>RepositoryImpl` (in data/)
- Models: `<Entity>Model` or `<Entity>HiveModel` extending or implementing domain `<Entity>`

## Error Handling

- Use the `dartz` package for `Either<Failure, T>` return types in Repositories and UseCases.
- Map exceptions (e.g. `ServerException`, `CacheException`) to `Failure` instances (`ServerFailure`, `CacheFailure`) within the Repository layer.
