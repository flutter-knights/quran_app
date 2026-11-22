import 'package:equatable/equatable.dart';

import '../../domain/entities/fasil_slot.dart';
import '../../domain/entities/place.dart';

class FasilState extends Equatable {
  const FasilState({this.slots = const {}, this.loaded = false, this.error});

  final Map<FasilSlot, Place> slots;
  final bool loaded;
  final String? error;

  List<Place> onPage(int page) => [
    for (final slot in FasilSlot.values)
      if (slots[slot]?.page == page) slots[slot]!,
  ];

  FasilState copyWith({
    Map<FasilSlot, Place>? slots,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) => FasilState(
    slots: slots ?? this.slots,
    loaded: loaded ?? this.loaded,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [slots, loaded, error];
}
