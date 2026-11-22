import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_places.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/remove_place.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/save_place.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';

import '../../place_fakes.dart';

void main() {
  const a25 = AyahIdentifier(surah: 2, ayah: 5);
  const a100 = AyahIdentifier(surah: 2, ayah: 100);
  const a1 = AyahIdentifier(surah: 1, ayah: 1);

  late InMemoryPlacesRepository repo;
  late DateTime clock;

  Future<SavedAyatCubit> build() async {
    final cubit = SavedAyatCubit(
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

  test('loads saved ayat newest first, skipping فواصل', () async {
    final older = savedPlace(a25, at: DateTime(2026, 11, 1));
    final newer = savedPlace(a100, at: DateTime(2026, 11, 2));
    repo = InMemoryPlacesRepository([
      older,
      fasilPlace(FasilSlot.wird, a1, at: DateTime(2026, 11, 3)),
      newer,
    ]);
    final cubit = await build();
    expect(cubit.state.items, [newer, older]);
    expect(cubit.state.loaded, isTrue);
  });

  test('save adds a dated, unmigrated place at the top', () async {
    repo = InMemoryPlacesRepository([
      savedPlace(a1, at: DateTime(2026, 11, 1)),
    ]);
    final cubit = await build();
    final saved = await cubit.save(a25);
    expect(saved!.ayah, a25);
    expect(saved.page, 2);
    expect(saved.slot, isNull);
    expect(saved.migrated, isFalse);
    expect(saved.createdAt, saved.updatedAt);
    expect(cubit.state.items.first, saved);
    expect(repo.places[saved.id], saved);
  });

  test('save of an ayah already saved returns null', () async {
    final cubit = await build();
    await cubit.save(a25);
    expect(await cubit.save(a25), isNull);
    expect(cubit.state.items, hasLength(1));
    expect(repo.places, hasLength(1));
  });

  test('save ignores the banner', () async {
    final cubit = await build();
    final result = await cubit.save(const AyahIdentifier(surah: 5, ayah: 0));
    expect(result, isNull);
    expect(cubit.state.items, isEmpty);
    expect(repo.places, isEmpty);
  });

  test('remove then restore keeps id and createdAt', () async {
    final cubit = await build();
    final saved = (await cubit.save(a25))!;
    await cubit.remove(saved);
    expect(cubit.state.items, isEmpty);
    expect(repo.places, isEmpty);
    await cubit.restore(saved);
    expect(cubit.state.items, [saved]);
    expect(repo.places, {saved.id: saved});
  });

  test('restore skips an ayah saved again meanwhile', () async {
    final cubit = await build();
    final first = (await cubit.save(a25))!;
    await cubit.remove(first);
    final second = (await cubit.save(a25))!;
    await cubit.restore(first);
    expect(cubit.state.items, [second]);
    expect(repo.places, {second.id: second});
  });

  test('a failing remove sets the error and keeps the item', () async {
    final cubit = await build();
    final saved = (await cubit.save(a25))!;
    repo.failNext = true;
    await cubit.remove(saved);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.items, [saved]);
    expect(repo.places, {saved.id: saved});
  });

  test('contains and find look up by ayah', () async {
    final cubit = await build();
    final saved = (await cubit.save(a25))!;
    expect(cubit.state.contains(a25), isTrue);
    expect(cubit.state.contains(a100), isFalse);
    expect(cubit.state.find(a25), saved);
    expect(cubit.state.find(a100), isNull);
  });

  test('a success after a failure clears the error', () async {
    final cubit = await build();
    repo.failNext = true;
    await cubit.save(a25);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.items, isEmpty);
    await cubit.save(a25);
    expect(cubit.state.error, isNull);
    expect(cubit.state.items, hasLength(1));
  });
}
