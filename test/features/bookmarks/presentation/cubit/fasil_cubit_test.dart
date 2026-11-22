import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_places.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/remove_place.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/save_place.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';

import '../../place_fakes.dart';

void main() {
  const a25 = AyahIdentifier(surah: 2, ayah: 5);
  const a100 = AyahIdentifier(surah: 2, ayah: 100);

  late InMemoryPlacesRepository repo;
  late DateTime clock;

  Future<FasilCubit> build() async {
    final cubit = FasilCubit(
      getPlaces: GetPlaces(repo),
      savePlace: SavePlace(repo),
      removePlace: RemovePlace(repo),
      pageService: QuranPageServiceImpl(),
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
    await pumpEventQueue();
    return cubit;
  }

  setUp(() {
    repo = InMemoryPlacesRepository();
    clock = DateTime(2026, 11, 20);
  });

  test('loads only placed slots', () async {
    final hifz = fasilPlace(FasilSlot.hifz, a25);
    repo = InMemoryPlacesRepository([hifz, savedPlace(a100, at: clock)]);
    final cubit = await build();
    expect(cubit.state.slots, {FasilSlot.hifz: hifz});
    expect(cubit.state.loaded, isTrue);
  });

  test('two records on one slot keep the latest updatedAt', () async {
    final older = fasilPlace(FasilSlot.wird, a25, at: DateTime(2026, 11, 1));
    final newer = fasilPlace(FasilSlot.wird, a100, at: DateTime(2026, 11, 2));
    repo = InMemoryPlacesRepository([newer, older]);
    final cubit = await build();
    expect(cubit.state.slots, {FasilSlot.wird: newer});
  });

  test('move places an unset slot', () async {
    final cubit = await build();
    final result = await cubit.move(FasilSlot.wird, a25);
    expect(result!.previous, isNull);
    expect(result.moved.page, 2);
    expect(result.moved.createdAt, result.moved.updatedAt);
    expect(
      result.moved.id,
      result.moved.createdAt.microsecondsSinceEpoch.toString(),
    );
    expect(cubit.state.slots[FasilSlot.wird], result.moved);
    expect(repo.places[result.moved.id], result.moved);
  });

  test(
    'move keeps id, createdAt and name, updates ayah, page and updatedAt',
    () async {
      final cubit = await build();
      final first = (await cubit.move(FasilSlot.hifz, a25))!.moved;
      await cubit.rename(FasilSlot.hifz, 'حفظ');
      final result = (await cubit.move(FasilSlot.hifz, a100))!;
      expect(result.previous!.ayah, a25);
      expect(result.moved.id, first.id);
      expect(result.moved.createdAt, first.createdAt);
      expect(result.moved.name, 'حفظ');
      expect(result.moved.ayah, a100);
      expect(result.moved.page, 15);
      expect(result.moved.updatedAt.isAfter(first.updatedAt), isTrue);
      expect(repo.places, {first.id: result.moved});
    },
  );

  test('move ignores the banner', () async {
    final cubit = await build();
    final states = <Object>[];
    cubit.stream.listen(states.add);
    final result = await cubit.move(
      FasilSlot.wird,
      const AyahIdentifier(surah: 5, ayah: 0),
    );
    await pumpEventQueue();
    expect(result, isNull);
    expect(states, isEmpty);
    expect(repo.places, isEmpty);
  });

  test('restore with null deletes the slot', () async {
    final cubit = await build();
    await cubit.move(FasilSlot.wird, a25);
    await cubit.restore(FasilSlot.wird, null);
    expect(cubit.state.slots, isEmpty);
    expect(repo.places, isEmpty);
  });

  test(
    'a failing restore with null sets the error and keeps the slot',
    () async {
      final cubit = await build();
      final placed = (await cubit.move(FasilSlot.wird, a25))!.moved;
      repo.failNext = true;
      await cubit.restore(FasilSlot.wird, null);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.slots, {FasilSlot.wird: placed});
      expect(repo.places, {placed.id: placed});
    },
  );

  test(
    'restore brings back the exact previous record even after a rename',
    () async {
      final cubit = await build();
      final first = (await cubit.move(FasilSlot.hifz, a25))!.moved;
      final result = (await cubit.move(FasilSlot.hifz, a100))!;
      await cubit.rename(FasilSlot.hifz, 'جديد');
      await cubit.restore(FasilSlot.hifz, result.previous);
      expect(cubit.state.slots[FasilSlot.hifz], first);
      expect(repo.places, {first.id: first});
    },
  );

  test('rename trims; blank resets to the default name', () async {
    final cubit = await build();
    await cubit.move(FasilSlot.hifz, a25);
    await cubit.rename(FasilSlot.hifz, '  حفظ رمضان ');
    expect(cubit.state.slots[FasilSlot.hifz]!.name, 'حفظ رمضان');
    await cubit.rename(FasilSlot.hifz, '   ');
    expect(cubit.state.slots[FasilSlot.hifz]!.name, isNull);
  });

  test('rename of an unset slot does nothing', () async {
    final cubit = await build();
    await cubit.rename(FasilSlot.hifz, 'x');
    expect(cubit.state.slots, isEmpty);
    expect(repo.places, isEmpty);
  });

  test('rename keeps updatedAt', () async {
    final cubit = await build();
    final placed = (await cubit.move(FasilSlot.hifz, a25))!.moved;
    await cubit.rename(FasilSlot.hifz, 'x');
    expect(cubit.state.slots[FasilSlot.hifz]!.updatedAt, placed.updatedAt);
  });

  test('a failed load blocks writes so a record is never duplicated', () async {
    final hifz = fasilPlace(FasilSlot.hifz, a25);
    repo = InMemoryPlacesRepository([hifz])..failNext = true;
    final cubit = await build();

    expect(cubit.state.loaded, isFalse);
    expect(cubit.state.loadFailed, isTrue);
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.error, isNotNull);
    expect(await cubit.move(FasilSlot.hifz, a100), isNull);
    expect(repo.places.values.toList(), [hifz]);
  });

  test('a failing save emits the error and keeps the slots', () async {
    final cubit = await build();
    final placed = (await cubit.move(FasilSlot.wird, a25))!.moved;
    repo.failNext = true;
    final result = await cubit.move(FasilSlot.wird, a100);
    expect(result, isNull);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.slots, {FasilSlot.wird: placed});
  });

  test('a success after a failure clears the error', () async {
    final cubit = await build();
    repo.failNext = true;
    await cubit.move(FasilSlot.wird, a25);
    expect(cubit.state.error, isNotNull);
    await cubit.move(FasilSlot.wird, a25);
    expect(cubit.state.error, isNull);
  });
}
