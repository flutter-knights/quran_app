import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/place.dart';

class SavedAyatState extends Equatable {
  const SavedAyatState({
    this.items = const [],
    this.loaded = false,
    this.loadFailed = false,
    this.error,
  });

  final List<Place> items;
  final bool loaded;
  final bool loadFailed;
  final String? error;

  bool get loading => !loaded && !loadFailed;

  Place? find(AyahIdentifier ayah) =>
      items.where((p) => p.ayah == ayah).firstOrNull;

  bool contains(AyahIdentifier ayah) => find(ayah) != null;

  SavedAyatState copyWith({
    List<Place>? items,
    bool? loaded,
    bool? loadFailed,
    String? error,
    bool clearError = false,
  }) => SavedAyatState(
    items: items ?? this.items,
    loaded: loaded ?? this.loaded,
    loadFailed: loadFailed ?? this.loadFailed,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [items, loaded, loadFailed, error];
}
