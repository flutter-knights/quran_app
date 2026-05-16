import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockGet extends Mock implements GetBookmarks {}
class _MockToggle extends Mock implements ToggleBookmark {}

void main() {
  late _MockGet get;
  late _MockToggle toggle;

  const a1 = AyahIdentifier(surah: 1, ayah: 1);
  const a2 = AyahIdentifier(surah: 2, ayah: 255);

  setUpAll(() {
    registerFallbackValue(a1);
  });

  setUp(() {
    get = _MockGet();
    toggle = _MockToggle();
  });

  blocTest<BookmarkCubit, BookmarkState>(
    'loads bookmarks on construction',
    build: () {
      when(() => get()).thenAnswer((_) async => Right({a1, a2}));
      return BookmarkCubit(getBookmarks: get, toggleBookmark: toggle);
    },
    expect: () => [
      BookmarkState(loaded: true, bookmarks: {a1, a2}),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'load failure emits error state',
    build: () {
      when(() => get()).thenAnswer(
          (_) async => const Left(CacheFailure('boom')));
      return BookmarkCubit(getBookmarks: get, toggleBookmark: toggle);
    },
    expect: () => [
      const BookmarkState(loaded: true, error: 'boom'),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'toggle adds ayah and updates state',
    setUp: () {
      when(() => get()).thenAnswer((_) async => const Right(<AyahIdentifier>{}));
      when(() => toggle(any())).thenAnswer((_) async => const Right(true));
    },
    build: () => BookmarkCubit(getBookmarks: get, toggleBookmark: toggle),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle(a1);
    },
    expect: () => [
      const BookmarkState(loaded: true),
      BookmarkState(loaded: true, bookmarks: {a1}),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'toggle removes ayah when already present',
    setUp: () {
      when(() => get()).thenAnswer((_) async => Right({a1}));
      when(() => toggle(any())).thenAnswer((_) async => const Right(false));
    },
    build: () => BookmarkCubit(getBookmarks: get, toggleBookmark: toggle),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle(a1);
    },
    expect: () => [
      BookmarkState(loaded: true, bookmarks: {a1}),
      const BookmarkState(loaded: true, bookmarks: <AyahIdentifier>{}),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'toggle failure sets error and leaves bookmarks unchanged',
    setUp: () {
      when(() => get()).thenAnswer((_) async => const Right(<AyahIdentifier>{}));
      when(() => toggle(any())).thenAnswer(
          (_) async => const Left(CacheFailure('save failed')));
    },
    build: () => BookmarkCubit(getBookmarks: get, toggleBookmark: toggle),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle(a1);
    },
    expect: () => [
      const BookmarkState(loaded: true),
      const BookmarkState(loaded: true, error: 'save failed'),
    ],
  );
}
