---
name: new-entity
description: Create a new entity + model pair
user-invocable: true
argument-hint: "<entity-name>"
---

# Add Entity + Model

## 1. Create the entity in `domain/entities/`

```dart
import 'package:equatable/equatable.dart';

class Example extends Equatable {
  final int id;
  final String name;

  const Example({
    required this.id,
    required this.name,
  });

  @override
  List<Object?> get props => [id, name];
}
```

- Use `const` constructor
- Extend `Equatable` for easy value comparisons.

## 2. Create the model in `data/models/`

If caching with Hive:
```dart
import 'package:hive/hive.dart';
import '../../domain/entities/example.dart';

part 'example_hive_model.g.dart';

@HiveType(typeId: 10) // Make sure to use a unique typeId
class ExampleHiveModel extends Example {
  @HiveField(0)
  final int hiveId;

  @HiveField(1)
  final String hiveName;

  const ExampleHiveModel({
    required this.hiveId,
    required this.hiveName,
  }) : super(id: hiveId, name: hiveName);
  
  // Optionally fromJson/toJson if it also comes from API
}
```

If pure API Model:
```dart
class ExampleModel extends Example {
  const ExampleModel({
    required super.id,
    required super.name,
  });

  factory ExampleModel.fromJson(Map<String, dynamic> json) => ExampleModel(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}
```

## Rules
- Model extends Entity (not separate classes)
- Use `super.field` syntax in model constructor when not using Hive.
- When using Hive, use separate fields with `@HiveField` and pass to `super`.
- Handle nulls defensively in fromJson.
