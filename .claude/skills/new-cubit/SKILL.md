---
name: new-cubit
description: Create a new Cubit + State for an existing feature
user-invocable: true
argument-hint: "<cubit-name>"
---

# Add Cubit

Place cubit files at: `lib/features/<feature>/presentation/cubit/`

## Cubit Class

```dart
// <name>_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part '<name>_state.dart';

class ExampleCubit extends Cubit<ExampleState> {
  final GetExampleData getExampleData;

  ExampleCubit({required this.getExampleData}) : super(const ExampleInitial());

  Future<void> loadData() async {
    if (isClosed) return;
    emit(const ExampleLoading());

    final result = await getExampleData();

    if (isClosed) return;
    result.fold(
      (failure) => emit(ExampleError(message: failure.message)),
      (data) => emit(ExampleLoaded(data: data)),
    );
  }
}
```

## State file

```dart
// <name>_state.dart
part of '<name>_cubit.dart';

sealed class ExampleState extends Equatable {
  const ExampleState();

  @override
  List<Object?> get props => [];
}

final class ExampleInitial extends ExampleState {
  const ExampleInitial();
}

final class ExampleLoading extends ExampleState {
  const ExampleLoading();
}

final class ExampleLoaded extends ExampleState {
  final String data;
  
  const ExampleLoaded({required this.data});
  
  @override
  List<Object?> get props => [data];
}

final class ExampleError extends ExampleState {
  final String message;
  
  const ExampleError({required this.message});
  
  @override
  List<Object?> get props => [message];
}
```

## DI Registration
Cubits are usually **Factory** (not Singleton) unless they maintain app-wide state:
```dart
sl.registerFactory(() => ExampleCubit(getExampleData: sl()));
```

## Rules
- Always check `if (isClosed) return;` before emitting after async operations.
- Use `sealed class` for states extending `Equatable`.
- Use `final class` for each state variant.
