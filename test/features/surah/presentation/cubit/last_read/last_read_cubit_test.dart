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

  setUpAll(() {
    registerFallbackValue(const LastRead(page: 1));
  });

  setUp(() => repo = _MockRepo());

  blocTest<LastReadCubit, LastRead?>(
    'loads initial value from repository.get on construction',
    build: () {
      when(() => repo.watch()).thenAnswer((_) => const Stream.empty());
      when(() => repo.get()).thenAnswer((_) async => const LastRead(page: 7));
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
}
