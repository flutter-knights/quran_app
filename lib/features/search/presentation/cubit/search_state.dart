// lib/features/search/presentation/cubit/search_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/search_result.dart';

class SearchState extends Equatable {
  final String query; // trimmed; empty == idle (browse mode)
  final SearchResults results;
  final bool isSearching;

  const SearchState({
    required this.query,
    required this.results,
    required this.isSearching,
  });

  factory SearchState.idle() => const SearchState(
        query: '',
        results: SearchResults.empty,
        isSearching: false,
      );

  bool get isActive => query.isNotEmpty;

  SearchState copyWith({
    String? query,
    SearchResults? results,
    bool? isSearching,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        isSearching: isSearching ?? this.isSearching,
      );

  @override
  List<Object?> get props => [query, results, isSearching];
}
