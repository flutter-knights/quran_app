import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/hadith_bookmark.dart';
import '../../domain/usecases/get_hadith_bookmarks.dart';
import '../../domain/usecases/toggle_hadith_bookmark.dart';
import 'hadith_bookmark_state.dart';

class HadithBookmarkCubit extends Cubit<HadithBookmarkState> {
  HadithBookmarkCubit({
    required this.getBookmarks,
    required this.toggleBookmark,
  }) : super(const HadithBookmarkState()) {
    _load();
  }

  final GetHadithBookmarks getBookmarks;
  final ToggleHadithBookmark toggleBookmark;

  Future<void> _load() async {
    final result = await getBookmarks();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(loaded: true, error: f.message)),
      (set) => emit(state.copyWith(loaded: true, bookmarks: set, error: null)),
    );
  }

  Future<void> toggle(HadithBookmark bookmark) async {
    if (!state.loaded) return;
    final result = await toggleBookmark(bookmark);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (nowBookmarked) {
        final next = Set<HadithBookmark>.from(state.bookmarks);
        if (nowBookmarked) {
          next.add(bookmark);
        } else {
          next.remove(bookmark);
        }
        emit(state.copyWith(bookmarks: next, error: null));
      },
    );
  }
}
