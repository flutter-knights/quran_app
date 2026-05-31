// lib/features/search/presentation/cubit/search_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/search_quran.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._search) : super(SearchState.idle());

  final SearchQuran _search;
  Timer? _debounce;
  static const _debounceMs = 200;

  void queryChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      emit(SearchState.idle());
      return;
    }
    // Reflect the active query immediately so the UI swaps to results mode,
    // then run the (cheap, in-memory) search after a short debounce.
    emit(state.copyWith(query: q, isSearching: true));
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      final results = _search(q);
      emit(SearchState(query: q, results: results, isSearching: false));
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
