import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeBookmarks extends Cubit<BookmarkState> implements BookmarkCubit {
  _FakeBookmarks() : super(const BookmarkState(loaded: true));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf() : super(const MushafState(currentPage: 2));
  bool resumed = false;
  @override
  void resumeFollow() => resumed = true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  AyahIdentifier? rangeStart;
  AyahIdentifier? rangeEnd;
  @override
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async {
    rangeStart = start;
    rangeEnd = end;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('verse low on page -> popover above', () {
    expect(popoverPlacement(verseCenterY: 0.8), PopoverPlacement.above);
  });
  test('verse high on page -> popover below', () {
    expect(popoverPlacement(verseCenterY: 0.2), PopoverPlacement.below);
  });

  group('actions', () {
    late _FakeMushaf mushaf;
    late _FakePlayback playback;

    Future<void> open(WidgetTester tester, AyahIdentifier ayah) async {
      mushaf = _FakeMushaf();
      playback = _FakePlayback();
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) onError!(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<BookmarkCubit>.value(value: _FakeBookmarks()),
              BlocProvider<MushafCubit>.value(value: mushaf),
              BlocProvider<PlaybackCubit>.value(value: playback),
            ],
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AyahActionPopover.show(
                    context,
                    ayah,
                    anchorGlobal: const Rect.fromLTWH(100, 300, 100, 20),
                    placement: PopoverPlacement.below,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('banner long-press offers only listen from the start', (
      tester,
    ) async {
      await open(tester, const AyahIdentifier(surah: 2, ayah: 0));

      expect(find.text('Listen from the start of the surah'), findsOneWidget);
      expect(find.text('Bookmark'), findsNothing);
      expect(find.text('Share'), findsNothing);

      await tester.tap(find.text('Listen from the start of the surah'));
      await tester.pump();

      expect(playback.rangeStart, const AyahIdentifier(surah: 2, ayah: 1));
      expect(playback.rangeEnd, const AyahIdentifier(surah: 2, ayah: 286));
      expect(mushaf.resumed, isTrue);
      expect(find.text('Listen from the start of the surah'), findsNothing);
    });

    testWidgets('ayah long-press keeps its four actions', (tester) async {
      await open(tester, const AyahIdentifier(surah: 2, ayah: 5));

      expect(find.text('Tafsir'), findsOneWidget);
      expect(find.text('Translation'), findsOneWidget);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Listen from the start of the surah'), findsNothing);
    });
  });
}
