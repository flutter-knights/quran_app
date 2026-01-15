part of 'download_book_cubit.dart';

sealed class DownloadBookState extends Equatable {
  final List<String> downloadedBooks;
  const DownloadBookState({required this.downloadedBooks});

  String getBookProgress(String slug) {
    final currentState = this;
    if (currentState is DownloadingBook) {
      return currentState.downloadingProgress[slug]?.toString() ?? '0';
    }
    return '0';
  }

  bool isCurrentlyDownloading(String slug) {
    final currentState = this;
    return currentState is DownloadingBook &&
        currentState.downloadingProgress.containsKey(slug);
  }

  @override
  List<Object> get props => [downloadedBooks];
}

final class DownloadBookInitial extends DownloadBookState {
  const DownloadBookInitial({required super.downloadedBooks});
}

final class DownloadingBook extends DownloadBookState {
  final Map<String, int> downloadingProgress;
  const DownloadingBook({
    required super.downloadedBooks,
    required this.downloadingProgress,
  });
  @override
  List<Object> get props => [downloadedBooks, downloadingProgress];
}

final class DownloadFailure extends DownloadBookState {
  final String message;
  const DownloadFailure(this.message, {required super.downloadedBooks});
}

final class DownloadSuccess extends DownloadBookState {
  const DownloadSuccess({required super.downloadedBooks});
}
