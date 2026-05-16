import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/usecases/get_bookmarks.dart';
import '../../domain/usecases/toggle_bookmark.dart';
import 'bookmark_state.dart';

class BookmarkCubit extends Cubit<BookmarkState> {
  BookmarkCubit({
    required this.getBookmarks,
    required this.toggleBookmark,
  }) : super(const BookmarkState()) {
    _load();
  }

  final GetBookmarks getBookmarks;
  final ToggleBookmark toggleBookmark;

  Future<void> _load() async {
    final result = await getBookmarks();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(loaded: true, error: failure.message)),
      (set) => emit(state.copyWith(loaded: true, bookmarks: set, error: null)),
    );
  }

  Future<void> toggle(AyahIdentifier ayah) async {
    if (!state.loaded) return;
    final result = await toggleBookmark(ayah);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (nowBookmarked) {
        final next = Set<AyahIdentifier>.from(state.bookmarks);
        if (nowBookmarked) {
          next.add(ayah);
        } else {
          next.remove(ayah);
        }
        emit(state.copyWith(bookmarks: next, error: null));
      },
    );
  }
}
