import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeMushafCubit extends Cubit<MushafState> implements MushafCubit {
  _FakeMushafCubit(super.initial);
  bool clearCalled = false;
  @override
  void clearHighlight() {
    clearCalled = true;
    emit(state.copyWith(clearHighlighted: true));
  }
  @override
  void toggleHighlight(_) {}
  @override
  void setPage(int page) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier =>
      throw UnimplementedError();
}

class _FakeBookmarkCubit extends Cubit<BookmarkState> implements BookmarkCubit {
  _FakeBookmarkCubit(super.initial);
  AyahIdentifier? toggled;
  @override
  Future<void> toggle(AyahIdentifier ayah) async {
    toggled = ayah;
  }
  @override
  GetBookmarks get getBookmarks => throw UnimplementedError();
  @override
  ToggleBookmark get toggleBookmark => throw UnimplementedError();
}

class _MockPlayback extends Mock implements PlaybackCubit {}

const _ayah = AyahIdentifier(surah: 2, ayah: 255);

Widget _harness({
  required MushafState mushafState,
  required BookmarkState bookmarkState,
  required PlaybackCubit playback,
  _FakeMushafCubit? mushafCubit,
  _FakeBookmarkCubit? bookmarkCubit,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(
              value: mushafCubit ?? _FakeMushafCubit(mushafState)),
          BlocProvider<BookmarkCubit>.value(
              value: bookmarkCubit ?? _FakeBookmarkCubit(bookmarkState)),
          BlocProvider<PlaybackCubit>.value(value: playback),
        ],
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: AyahActionBar(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_ayah);
  });

  testWidgets('bar is offscreen and ignores pointers when no highlight',
      (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
    ));
    await tester.pump();

    final ignorePointer = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('ayah_action_bar_ignore')));
    expect(ignorePointer.ignoring, isTrue);
  });

  testWidgets('bar is visible when a highlight is present', (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
    ));
    await tester.pumpAndSettle();

    final ignorePointer = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('ayah_action_bar_ignore')));
    expect(ignorePointer.ignoring, isFalse);
  });

  testWidgets('tapping Play calls PlaybackCubit.playFromAyah and clears highlight',
      (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());
    when(() => playback.playFromAyah(any())).thenAnswer((_) async {});

    final mushaf = _FakeMushafCubit(
        const MushafState(currentPage: 1, highlightedAyah: _ayah));

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
      mushafCubit: mushaf,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ayah_bar_play')));
    await tester.pumpAndSettle();

    verify(() => playback.playFromAyah(_ayah)).called(1);
    expect(mushaf.clearCalled, isTrue);
  });

  testWidgets('tapping Bookmark calls BookmarkCubit.toggle', (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    final bookmark = _FakeBookmarkCubit(const BookmarkState(loaded: true));

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
      bookmarkCubit: bookmark,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ayah_bar_bookmark')));
    await tester.pumpAndSettle();

    expect(bookmark.toggled, _ayah);
  });

  testWidgets('tapping Tafsir shows a snackbar', (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ayah_bar_tafsir')));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
