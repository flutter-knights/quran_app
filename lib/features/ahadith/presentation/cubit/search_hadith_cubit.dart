import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/utils/hadith_list_filter.dart';

part 'search_hadith_state.dart';

class SearchHadithCubit extends Cubit<SearchHadithState> {
  final DownloadBookCubit downloadBookCubit;
  final AhadithSearchRepository ahadithSearchRepository;

  Timer? _debounce;
  String _lastQuery = '';
  String? _lastBookSlug;
  // ignore: unused_field
  HadithListFilter _lastFilter = const HadithListFilter();

  SearchHadithCubit({
    required this.downloadBookCubit,
    required this.ahadithSearchRepository,
  }) : super(SearchHadithInitial());

  Future<void> searchAhadith(
    String query,
    String bookSlug, {
    HadithListFilter filter = const HadithListFilter(),
  }) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _lastQuery = query;
    _lastBookSlug = bookSlug;
    _lastFilter = filter;

    if (query.trim().isEmpty) {
      emit(SearchHadithInitial());
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      emit(SearchHadithLoading());

      final isDownloaded =
          downloadBookCubit.state.downloadedBooks.contains(bookSlug);

      final result = await ahadithSearchRepository.searchHadiths(
        query: query,
        bookSlug: bookSlug,
        isDownloaded: isDownloaded,
        status: filter.status,
        chapterId: filter.chapterId,
      );

      if (isClosed) return;
      result.fold(
        (failure) => emit(SearchHadithError(failure.message)),
        (ahadithList) => emit(SearchHadithLoaded(ahadithList)),
      );
    });
  }

  /// Re-runs the current query under a new filter (called when the user changes
  /// the filter while a search is active). No-op if there is no active query.
  void reapplyFilter(HadithListFilter filter) {
    if (_lastBookSlug == null || _lastQuery.trim().isEmpty) {
      _lastFilter = filter;
      return;
    }
    searchAhadith(_lastQuery, _lastBookSlug!, filter: filter);
  }

  void initializeArabicBookSearch(String bookSlug) {
    ahadithSearchRepository.initializeArabicBookSearch(bookSlug);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    ahadithSearchRepository.dispose();
    return super.close();
  }
}
