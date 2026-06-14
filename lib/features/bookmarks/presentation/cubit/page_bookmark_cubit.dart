import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_page_bookmarks.dart';
import '../../domain/usecases/toggle_page_bookmark.dart';
import 'page_bookmark_state.dart';

class PageBookmarkCubit extends Cubit<PageBookmarkState> {
  PageBookmarkCubit({
    required this.getPageBookmarks,
    required this.togglePageBookmark,
  }) : super(const PageBookmarkState()) {
    _load();
  }

  final GetPageBookmarks getPageBookmarks;
  final TogglePageBookmark togglePageBookmark;

  Future<void> _load() async {
    final result = await getPageBookmarks();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(loaded: true, error: failure.message)),
      (set) => emit(state.copyWith(loaded: true, pages: set, error: null)),
    );
  }

  Future<void> toggle(int page) async {
    if (!state.loaded) return;
    final result = await togglePageBookmark(page);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (nowSaved) {
        final next = Set<int>.from(state.pages);
        if (nowSaved) {
          next.add(page);
        } else {
          next.remove(page);
        }
        emit(state.copyWith(pages: next, error: null));
      },
    );
  }
}
