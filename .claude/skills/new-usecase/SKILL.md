---
name: new-usecase
description: Add a new use case to an existing feature (use case, repository method, data source method, DI registration)
user-invocable: true
argument-hint: "<use-case-name>"
---

# Add Use Case

When adding a new use case to an existing feature, touch these files in order:

## 1. Domain — Create the use case

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';

class GetExampleData {
  final FeatureRepository repository;

  const GetExampleData({required this.repository});

  Future<Either<Failure, String>> call() async {
    return await repository.getExampleData();
  }
}
```

For mutations or complex queries, create a params class:
```dart
class GetExampleParams {
  final int id;
  const GetExampleParams({required this.id});
}

class GetExampleData {
  final FeatureRepository repository;
  const GetExampleData({required this.repository});

  Future<Either<Failure, String>> call(GetExampleParams params) async {
    return await repository.getExampleData(params.id);
  }
}
```

## 2. Domain — Add method to abstract repository

## 3. Data — Add method to remote or local data source (abstract + impl)

## 4. Data — Implement in repository impl
Catch exceptions and map them to `Failure`: `Failure.fromException(e)` for Dio and location errors, `CacheFailure` for `CacheException`/`HiveError`. Never let one escape the repository.

## 5. DI — Register the use case
```dart
sl.registerLazySingleton(() => GetExampleData(repository: sl()));
```

## 6. If needed — Add/update the Cubit to use the new use case
