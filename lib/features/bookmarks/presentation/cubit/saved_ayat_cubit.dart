import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/services/quran_page_service.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_places.dart';
import '../../domain/usecases/remove_place.dart';
import '../../domain/usecases/save_place.dart';
import 'saved_ayat_state.dart';

class SavedAyatCubit extends Cubit<SavedAyatState> {
  SavedAyatCubit({
    required this.getPlaces,
    required this.savePlace,
    required this.removePlace,
    required this.pageService,
    this.now = DateTime.now,
  }) : super(const SavedAyatState()) {
    _load();
  }

  final GetPlaces getPlaces;
  final SavePlace savePlace;
  final RemovePlace removePlace;
  final QuranPageService pageService;
  final DateTime Function() now;

  static List<Place> _newestFirst(Iterable<Place> places) =>
      places.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _load() async {
    final result = await getPlaces();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(loaded: true, error: failure.message)),
      (places) => emit(
        state.copyWith(
          loaded: true,
          items: _newestFirst(places.where((p) => p.slot == null)),
          clearError: true,
        ),
      ),
    );
  }

  Future<Place?> save(AyahIdentifier ayah) async {
    if (!state.loaded || ayah.ayah == 0 || state.contains(ayah)) return null;
    final when = now();
    final place = Place(
      id: when.microsecondsSinceEpoch.toString(),
      ayah: ayah,
      page: pageService.getPageForAyah(ayah.surah, ayah.ayah),
      createdAt: when,
      updatedAt: when,
    );
    return await _add(place) ? place : null;
  }

  Future<void> restore(Place place) async {
    if (!state.loaded) return;
    await _add(place);
  }

  Future<void> remove(Place place) async {
    if (!state.loaded) return;
    final result = await removePlace(place.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => emit(
        state.copyWith(
          items: state.items.where((p) => p.id != place.id).toList(),
          clearError: true,
        ),
      ),
    );
  }

  Future<bool> _add(Place place) async {
    final result = await savePlace(place);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(state.copyWith(error: failure.message));
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            items: _newestFirst([...state.items, place]),
            clearError: true,
          ),
        );
        return true;
      },
    );
  }
}
