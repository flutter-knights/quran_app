import 'package:equatable/equatable.dart';

import '../../domain/entities/fasil_slot.dart';
import '../../domain/entities/place.dart';

class FasilState extends Equatable {
  const FasilState({
    this.slots = const {},
    this.loaded = false,
    this.loadFailed = false,
    this.error,
  });

  final Map<FasilSlot, Place> slots;
  final bool loaded;
  final bool loadFailed;
  final String? error;

  bool get loading => !loaded && !loadFailed;

  FasilState copyWith({
    Map<FasilSlot, Place>? slots,
    bool? loaded,
    bool? loadFailed,
    String? error,
    bool clearError = false,
  }) => FasilState(
    slots: slots ?? this.slots,
    loaded: loaded ?? this.loaded,
    loadFailed: loadFailed ?? this.loadFailed,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [slots, loaded, loadFailed, error];
}
