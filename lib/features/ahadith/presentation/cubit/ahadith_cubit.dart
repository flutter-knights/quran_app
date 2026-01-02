import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_ahadith_page_use_case.dart';

part 'ahadith_state.dart';

class AhadithCubit extends Cubit<AhadithState> {
  final GetAhadithPageUseCase getAhadithPageUseCase;
  AhadithCubit({required this.getAhadithPageUseCase}) : super(AhadithInitial());
  final List<Hadith> ahadith = [];
  bool lastPage = false;
  int pageNumber = 1;
  String? currentBookSlug;

  Future<void> fetchAhadith({required String bookSlug}) async {
    if (state is AhadithLoadingMore || lastPage) return;

    if (currentBookSlug != bookSlug) {
      _reset();
      currentBookSlug = bookSlug;
    }

    emit(
      pageNumber == 1
          ? AhadithLoading()
          : AhadithLoadingMore(oldAhadith: List.from(ahadith)),
    );
    final result = await getAhadithPageUseCase.call(
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
