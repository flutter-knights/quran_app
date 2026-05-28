import '../../domain/entities/hadith_bookmark.dart';

class HadithBookmarkState {
  const HadithBookmarkState({
    this.bookmarks = const <HadithBookmark>{},
    this.loaded = false,
    this.error,
  });

  final Set<HadithBookmark> bookmarks;
  final bool loaded;
  final String? error;

  bool contains(HadithBookmark b) => bookmarks.contains(b);

  HadithBookmarkState copyWith({
    Set<HadithBookmark>? bookmarks,
    bool? loaded,
    String? error,
  }) =>
      HadithBookmarkState(
        bookmarks: bookmarks ?? this.bookmarks,
        loaded: loaded ?? this.loaded,
        error: error,
      );
}
