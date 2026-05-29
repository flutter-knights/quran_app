import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_ahadith_page_use_case.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_book_chapters.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_book_statuses.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_filtered_ahadith_page_use_case.dart';
import 'package:quran_app/features/ahadith/presentation/utils/hadith_list_filter.dart';

part 'ahadith_state.dart';

class AhadithCubit extends Cubit<AhadithState> {
  final GetAhadithPageUseCase getAhadithPageUseCase;
  final GetFilteredAhadithPageUseCase getFilteredAhadithPageUseCase;
  final GetBookChapters getBookChapters;
  final GetBookStatuses getBookStatuses;
  AhadithCubit({
    required this.getAhadithPageUseCase,
    required this.getFilteredAhadithPageUseCase,
    required this.getBookChapters,
    required this.getBookStatuses,
  }) : super(AhadithInitial());
  final List<Hadith> ahadith = [];

  /// Full chapter catalogue for the current book (Arabic + English), loaded
  /// from the bundled data the moment the book opens.
  List<Chapter> chapters = const [];

  /// Grades present in the current book — drives which status chips are shown.
  Set<HadithStatus> availableStatuses = const {
    HadithStatus.sahih,
    HadithStatus.hasan,
    HadithStatus.daeef,
  };
  bool lastPage = false;
  int pageNumber = 1;
  String? currentBookSlug;

  HadithListFilter _filter = const HadithListFilter();
  bool _isDownloaded = false;

  /// Online + filtered ⇒ ask the API for filtered pages instead of paging the
  /// whole book client-side. Downloaded books filter from cache in the view.
  bool get _useServerFilter => _filter.isActive && !_isDownloaded;

  /// Re-runs the browse with a new filter. Only the online server-filtered path
  /// refetches; offline books filter the already-loaded list in the view.
  void applyFilter(HadithListFilter filter, {required bool isDownloaded}) {
    _filter = filter;
    _isDownloaded = isDownloaded;
    if (currentBookSlug == null || isDownloaded) return;
    _reset();
    fetchAhadith(bookSlug: currentBookSlug!);
  }

  Future<void> fetchAhadith({required String bookSlug}) async {
    if (state is AhadithLoadingMore || lastPage) return;

    if (currentBookSlug != bookSlug) {
      _reset();
      currentBookSlug = bookSlug;
      chapters = getBookChapters.call(bookSlug);
      availableStatuses = getBookStatuses.call(bookSlug);
    }

    emit(
      pageNumber == 1
          ? AhadithLoading()
          : AhadithLoadingMore(oldAhadith: List.from(ahadith)),
    );
    final result = _useServerFilter
        ? await getFilteredAhadithPageUseCase.call(
            pageNumber: pageNumber,
            bookSlug: bookSlug,
            status: _filter.status,
            chapterId: _filter.chapterId,
          )
        : await getAhadithPageUseCase.call(
            AhadithPageParams(pageNumber: pageNumber, bookSlug: bookSlug),
          );

    result.fold(
      (failure) {
        if (isClosed) return;
        emit(AhadithError(failure.message, paginationError: pageNumber > 1));
      },
      (ahadithPage) {
        ahadith.addAll(ahadithPage.ahadithList);
        pageNumber++;
        if (ahadithPage.lastPage) {
          lastPage = true;
        }
        if (isClosed) return;
        emit(AhadithLoaded(ahadith: List.from(ahadith), lastPage: lastPage));
      },
    );
  }

  void _reset() {
    ahadith.clear();
    lastPage = false;
    pageNumber = 1;
  }
}
