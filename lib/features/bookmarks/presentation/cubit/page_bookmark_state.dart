import 'package:equatable/equatable.dart';

class PageBookmarkState extends Equatable {
  final Set<int> pages;
  final bool loaded;
  final String? error;

  const PageBookmarkState({
    this.pages = const {},
    this.loaded = false,
    this.error,
  });

  PageBookmarkState copyWith({
    Set<int>? pages,
    bool? loaded,
    Object? error = _sentinel,
  }) {
    return PageBookmarkState(
      pages: pages ?? this.pages,
      loaded: loaded ?? this.loaded,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  bool contains(int page) => pages.contains(page);

  @override
  List<Object?> get props => [pages, loaded, error];
}

const Object _sentinel = Object();
