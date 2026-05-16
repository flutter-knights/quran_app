import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class BookmarkState extends Equatable {
  final Set<AyahIdentifier> bookmarks;
  final bool loaded;
  final String? error;

  const BookmarkState({
    this.bookmarks = const {},
    this.loaded = false,
    this.error,
  });

  BookmarkState copyWith({
    Set<AyahIdentifier>? bookmarks,
    bool? loaded,
    Object? error = _sentinel,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      loaded: loaded ?? this.loaded,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  bool contains(AyahIdentifier ayah) => bookmarks.contains(ayah);

  @override
  List<Object?> get props => [bookmarks, loaded, error];
}

const Object _sentinel = Object();
