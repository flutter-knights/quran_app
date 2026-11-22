import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/places_repository.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

final _defaultAt = DateTime(2026, 11, 14, 8);

Place fasilPlace(
  FasilSlot slot,
  AyahIdentifier ayah, {
  String? name,
  DateTime? at,
}) {
  final when = at ?? _defaultAt;
  return Place(
    id: when.microsecondsSinceEpoch.toString(),
    ayah: ayah,
    page: quran.getPageNumber(ayah.surah, ayah.ayah),
    slot: slot,
    name: name,
    createdAt: when,
    updatedAt: when,
  );
}

Place savedPlace(AyahIdentifier ayah, {DateTime? at, bool migrated = false}) {
  final when = at ?? _defaultAt;
  return Place(
    id: when.microsecondsSinceEpoch.toString(),
    ayah: ayah,
    page: quran.getPageNumber(ayah.surah, ayah.ayah),
    createdAt: when,
    updatedAt: when,
    migrated: migrated,
  );
}

class InMemoryPlacesRepository implements PlacesRepository {
  InMemoryPlacesRepository([Iterable<Place> seed = const []])
    : places = {for (final p in seed) p.id: p};

  final Map<String, Place> places;
  bool failNext = false;

  Either<Failure, T> _result<T>(T value) {
    if (!failNext) return Right(value);
    failNext = false;
    return const Left(CacheFailure('boom'));
  }

  @override
  Future<Either<Failure, List<Place>>> getAll() async =>
      _result(places.values.toList());

  @override
  Future<Either<Failure, Unit>> save(Place place) async {
    final result = _result(unit);
    if (result.isRight()) places[place.id] = place;
    return result;
  }

  @override
  Future<Either<Failure, Unit>> remove(String id) async {
    final result = _result(unit);
    if (result.isRight()) places.remove(id);
    return result;
  }

  @override
  Future<Either<Failure, Unit>> migrate() async => const Right(unit);
}

class FakeFasilCubit extends Cubit<FasilState> implements FasilCubit {
  FakeFasilCubit([super.initial = const FasilState(loaded: true)]);

  final moves = <(FasilSlot, AyahIdentifier)>[];
  final restores = <(FasilSlot, Place?)>[];
  final renames = <(FasilSlot, String)>[];

  @override
  Future<({Place? previous, Place moved})?> move(
    FasilSlot slot,
    AyahIdentifier ayah,
  ) async {
    moves.add((slot, ayah));
    final previous = state.slots[slot];
    final moved = fasilPlace(slot, ayah);
    emit(state.copyWith(slots: {...state.slots, slot: moved}));
    return (previous: previous, moved: moved);
  }

  @override
  Future<void> restore(FasilSlot slot, Place? previous) async {
    restores.add((slot, previous));
    final slots = {...state.slots}..remove(slot);
    if (previous != null) slots[slot] = previous;
    emit(state.copyWith(slots: slots));
  }

  @override
  Future<void> rename(FasilSlot slot, String name) async =>
      renames.add((slot, name));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeSavedAyatCubit extends Cubit<SavedAyatState>
    implements SavedAyatCubit {
  FakeSavedAyatCubit([super.initial = const SavedAyatState(loaded: true)]);

  final saves = <AyahIdentifier>[];
  final removes = <Place>[];
  final restores = <Place>[];

  @override
  Future<Place?> save(AyahIdentifier ayah) async {
    saves.add(ayah);
    final place = savedPlace(
      ayah,
      at: _defaultAt.add(Duration(minutes: saves.length)),
    );
    emit(state.copyWith(items: [place, ...state.items]));
    return place;
  }

  @override
  Future<void> remove(Place place) async {
    removes.add(place);
    emit(
      state.copyWith(
        items: state.items.where((p) => p.id != place.id).toList(),
      ),
    );
  }

  @override
  Future<void> restore(Place place) async {
    restores.add(place);
    emit(state.copyWith(items: [place, ...state.items]));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
