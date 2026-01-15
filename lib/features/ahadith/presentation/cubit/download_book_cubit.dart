import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/domain/usecases/download_ahadith_book_use_case.dart';

part 'download_book_state.dart';

class DownloadBookCubit extends HydratedCubit<DownloadBookState> {
  final DownloadAhadithBookUseCase downloadAhadithBookUseCase;
  DownloadBookCubit({required this.downloadAhadithBookUseCase})
    : super(DownloadBookInitial(downloadedBooks: []));

  Future<void> downloadBook({required String bookSlug}) async {
    if (state.downloadedBooks.contains(bookSlug)) return;
    final result = downloadAhadithBookUseCase.call(bookSlug);
    emit(
      DownloadingBook(
        downloadedBooks: state.downloadedBooks,
        downloadingProgress: {},
      ),
    );
    result.listen(
      (downloadProgress) {
        final Map<String, int> currentProgress = state is DownloadingBook
            ? Map<String, int>.from(
                (state as DownloadingBook).downloadingProgress,
              )
            : {};
        currentProgress[bookSlug] = downloadProgress.progress;
        emit(
          DownloadingBook(
            downloadedBooks: state.downloadedBooks,
            downloadingProgress: currentProgress,
          ),
        );
      },
      onError: (e) {
        emit(
          DownloadFailure(e.toString(), downloadedBooks: state.downloadedBooks),
        );
      },
      onDone: () {
        emit(
          DownloadSuccess(
            downloadedBooks: [...state.downloadedBooks, bookSlug],
          ),
        );
      },
    );
  }

  @override
  DownloadBookState? fromJson(Map<String, dynamic> json) {
    final List<String> downloadedBooks = List<String>.from(
      json['downloadedBooks'],
    );
    return DownloadBookInitial(downloadedBooks: downloadedBooks);
  }

  @override
  Map<String, dynamic>? toJson(DownloadBookState state) {
    return {'downloadedBooks': state.downloadedBooks};
  }
}
