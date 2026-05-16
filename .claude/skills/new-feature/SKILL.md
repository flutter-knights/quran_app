---
name: new-feature
description: Scaffold a complete new feature following Clean Architecture (entity, model, data source, repository, use case, cubit, DI)
user-invocable: true
argument-hint: "<feature-name>"
---

# New Feature Scaffold

When the user asks to create a new feature, invoke these sub-skills in order using the Skill tool:

1. **`/new-entity`** — Create the entity + model pair
2. **`/new-usecase`** — Create the use case(s), repository interface/impl, data source
3. **`/new-cubit`** — Create the cubit + state
4. **`/new-screen`** — Create the screen/page with routing

After all sub-skills complete, finish with:

## 5. Dependency injection (`<feature_name>_di.dart`)
```dart
import 'package:quran_app/core/di/dependency_injection.dart';

void initFeatureName() {
  // Data sources
  sl.registerLazySingleton<FeatureRemoteDataSource>(
    () => FeatureRemoteDataSourceImpl(dio: sl()),
  );
  // Repository
  sl.registerLazySingleton<FeatureRepository>(
    () => FeatureRepositoryImpl(remoteDataSource: sl()),
  );
  // Use cases
  sl.registerLazySingleton(() => GetItems(repository: sl()));
  // Cubits (Factory, not Singleton)
  sl.registerFactory(() => ItemsCubit(getItems: sl()));
}
```

## 6. Register in `core/di/dependency_injection.dart`
Call `initFeatureName()` alongside existing feature inits inside `initGetIt()`.

## 7. Add route to go_router config in `config/router/app_router.dart`

## Folder structure reference
```
lib/features/<feature_name>/
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   └── remote/
│   ├── models/
│   └── repositories/<feature_name>_repository_impl.dart
├── domain/
│   ├── entities/
│   ├── repositories/<feature_name>_repository.dart
│   └── usecases/
├── presentation/
│   ├── cubit/
│   │   ├── <cubit_name>_cubit.dart
│   │   └── <cubit_name>_state.dart
│   ├── pages/
│   │   └── <view_name>_page.dart
│   └── widgets/
└── <feature_name>_di.dart
```
