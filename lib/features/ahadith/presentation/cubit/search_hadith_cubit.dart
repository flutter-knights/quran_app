import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';

part 'search_hadith_state.dart';

class SearchHadithCubit extends Cubit<SearchHadithState> {
  final DownloadBookCubit downloadBookCubit;
  final AhadithSearchRepository ahadithSearchRepository;

  Timer? _debounce;

  SearchHadithCubit({
    required this.downloadBookCubit,
    required this.ahadithSearchRepository,
  }) : super(SearchHadithInitial());

  Future<void> searchAhadith(String query, String bookSlug) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      emit(SearchHadithInitial());
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      emit(SearchHadithLoading());

      final isDownloaded = downloadBookCubit.state.downloadedBooks.contains(
        bookSlug,
      );

      final result = await ahadithSearchRepository.searchHadiths(
        query: query,
        bookSlug: bookSlug,
        isDownloaded: isDownloaded,
      );

      result.fold(
        (failure) => emit(SearchHadithError(failure.message)),
        (ahadithList) => emit(SearchHadithLoaded(ahadithList)),
      );
    });
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
