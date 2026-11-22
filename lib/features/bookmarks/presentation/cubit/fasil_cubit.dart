import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/services/quran_page_service.dart';
import '../../domain/entities/fasil_slot.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_places.dart';
import '../../domain/usecases/remove_place.dart';
import '../../domain/usecases/save_place.dart';
import 'fasil_state.dart';

class FasilCubit extends Cubit<FasilState> {
  FasilCubit({
    required this.getPlaces,
    required this.savePlace,
    required this.removePlace,
    required this.pageService,
    this.now = DateTime.now,
  }) : super(const FasilState()) {
    _load();
  }

  final GetPlaces getPlaces;
  final SavePlace savePlace;
  final RemovePlace removePlace;
  final QuranPageService pageService;
  final DateTime Function() now;

  Future<void> _load() async {
    final result = await getPlaces();
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(state.copyWith(loadFailed: true, error: failure.message)),
      (places) {
        final slots = <FasilSlot, Place>{};
        for (final place in places) {
          final slot = place.slot;
          if (slot == null) continue;
          final current = slots[slot];
          if (current == null || place.updatedAt.isAfter(current.updatedAt)) {
            slots[slot] = place;
          }
        }
        emit(state.copyWith(loaded: true, slots: slots, clearError: true));
      },
    );
  }

  Future<({Place? previous, Place moved})?> move(
    FasilSlot slot,
    AyahIdentifier ayah,
  ) async {
    if (!state.loaded || ayah.ayah == 0) return null;
    final previous = state.slots[slot];
    final page = pageService.getPageForAyah(ayah.surah, ayah.ayah);
    final when = now();
    final moved =
        previous?.copyWith(ayah: ayah, page: page, updatedAt: when) ??
        Place(
          id: when.microsecondsSinceEpoch.toString(),
          ayah: ayah,
          page: page,
          slot: slot,
          createdAt: when,
          updatedAt: when,
        );
    if (!await _write(slot, moved)) return null;
    return (previous: previous, moved: moved);
  }

  Future<void> restore(FasilSlot slot, Place? previous) async {
    if (!state.loaded) return;
    if (previous != null) {
      await _write(slot, previous);
      return;
    }
    final current = state.slots[slot];
    if (current == null) return;
    final result = await removePlace(current.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (_) => emit(
        state.copyWith(slots: {...state.slots}..remove(slot), clearError: true),
      ),
    );
  }

  Future<bool> rename(FasilSlot slot, String name) async {
    final place = state.slots[slot];
    if (!state.loaded || place == null) return false;
    final trimmed = name.trim();
    return _write(
      slot,
      trimmed.isEmpty
          ? place.copyWith(clearName: true)
          : place.copyWith(name: trimmed),
    );
  }

  Future<bool> _write(FasilSlot slot, Place place) async {
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
            slots: {...state.slots, slot: place},
            clearError: true,
          ),
        );
        return true;
      },
    );
  }
}
