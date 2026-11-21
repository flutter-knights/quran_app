import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../notifications/presentation/alerts_test_harness.dart';

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);
  void push(MushafState s) => emit(s);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  void clearSelection() {
    emit(state.copyWith(clearSelected: true));
  }

  @override
  void toggleSelection(_) {}
  @override
  void setPage(int p, {required bool byUser}) {}
  @override
  void setHighlightBounds(double centerY) {}
  @override
  void pinOverlay() {}
  @override
  void unpinOverlay() {
    emit(state.copyWith(isOverlayPinned: false, clearSelected: true));
  }

  @override
  void toggleChrome() {}
  @override
  void setChrome(bool visible) {}
  bool resumed = false;
  @override
  void resumeFollow() {
    resumed = true;
    emit(state.copyWith(followPlayback: true));
  }

  @override
  int? get playingPage => 3;
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier =>
      throw UnimplementedError();
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);
  void push(PlaybackState s) => emit(s);
  AyahIdentifier? lastPlay;
  AyahIdentifier? lastRangeStart;
  AyahIdentifier? lastRangeEnd;
  bool stopped = false;
  bool paused = false;
  double? speedSet;
  bool skippedPrevious = false;
  bool skippedNext = false;
  bool retried = false;
  @override
  void setRange({required AyahIdentifier start, required AyahIdentifier end}) {}

  @override
  Future<void> skipPrevious() async {
    skippedPrevious = true;
  }

  @override
  Future<void> skipNext() async {
    skippedNext = true;
  }

  @override
  Future<void> retry() async {
    retried = true;
  }

  @override
  Future<void> playSelected(AyahIdentifier a) async {
    lastPlay = a;
    emit(state.copyWith(currentAyah: a, isPlaying: true));
  }

  @override
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async {
    lastRangeStart = start;
    lastRangeEnd = end;
    emit(state.copyWith(currentAyah: start, isPlaying: true));
  }

  @override
  Future<void> pause() async {
    paused = true;
    emit(state.copyWith(isPlaying: false, isPaused: true));
  }

  bool resumed = false;
  @override
  Future<void> resume() async {
    resumed = true;
    emit(state.copyWith(isPlaying: true, isPaused: false));
  }

  @override
  Future<void> stop() async {
    stopped = true;
    emit(
      state.copyWith(isPlaying: false, isPaused: false, clearCurrentAyah: true),
    );
  }

  @override
  Future<void> setSpeed(double s) async {
    speedSet = s;
    emit(state.copyWith(speed: s));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _target = AyahIdentifier(surah: 2, ayah: 5);

Widget _wrap({
  required _FakeMushaf m,
  required _FakePlayback p,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    locale: locale,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(value: m),
          BlocProvider<PlaybackCubit>.value(value: p),
        ],
        child: const Stack(children: [AyahPlaybackOverlay()]),
      ),
    ),
  );
}

final _name = quran.getSurahName(2);

Finder _opacity() => find.descendant(
  of: find.byType(AyahPlaybackOverlay),
  matching: find.byType(AnimatedOpacity),
);

Future<void> _pump(WidgetTester tester, _FakeMushaf m, _FakePlayback p) async {
  await tester.pumpWidget(_wrap(m: m, p: p));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('hidden when idle with nothing selected or pinned', (
    tester,
  ) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    final overlay = find.byType(AyahPlaybackOverlay);
    final opacity = tester.widget<AnimatedOpacity>(_opacity());
    final pointer = tester.widget<IgnorePointer>(
      find.descendant(of: overlay, matching: find.byType(IgnorePointer)).first,
    );
    expect(opacity.opacity, 0);
    expect(pointer.ignoring, isTrue);
  });

  testWidgets('visible while audio plays with nothing selected', (
    tester,
  ) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    expect(tester.widget<AnimatedOpacity>(_opacity()).opacity, 1);
  });

  testWidgets('visible while paused with nothing selected', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPaused: true),
    );
    await _pump(tester, m, p);
    expect(tester.widget<AnimatedOpacity>(_opacity()).opacity, 1);
  });

  testWidgets('visible when the first play failed', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(
      const PlaybackState(requestedAyah: _target, error: 'x'),
    );
    await _pump(tester, m, p);
    expect(tester.widget<AnimatedOpacity>(_opacity()).opacity, 1);
  });

  testWidgets('shows label + play button when highlighted', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    expect(find.text('Surah $_name, Ayah 5'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('title uses the surah name and Arabic-Indic digits', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p, locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('سورة ${quran.getSurahNameArabic(2)}، الآية ٥'), findsOne);
  });

  testWidgets('title shows ayah 0 as ayah 1', (tester) async {
    final m = _FakeMushaf(
      const MushafState(
        currentPage: 1,
        selectedAyah: AyahIdentifier(surah: 2, ayah: 0),
      ),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    expect(find.text('Surah $_name, Ayah 1'), findsOneWidget);
  });

  testWidgets('tapping play calls PlaybackCubit.playRange to end of surah', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    // playRange should have been called with start = target and end = last ayah of surah 2
    expect(p.lastRangeStart, _target);
    expect(p.lastRangeEnd, const AyahIdentifier(surah: 2, ayah: 286));
    expect(m.resumed, isTrue);
  });

  testWidgets('paused on same target → tap play calls resume (not restart)', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(
        currentAyah: _target,
        isPlaying: false,
        isPaused: true,
      ),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(p.resumed, isTrue);
    expect(p.lastPlay, isNull); // no restart
  });

  testWidgets('shows pause icon while playing', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('stop button ends the recitation and hides the player', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byTooltip('End recitation'));
    await tester.pumpAndSettle();
    expect(p.stopped, isTrue);
    expect(m.state.selectedAyah, isNull);
    expect(tester.widget<AnimatedOpacity>(_opacity()).opacity, 0);
  });

  testWidgets('collapse button only appears while idle', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final idle = _FakePlayback(const PlaybackState());
    await _pump(tester, m, idle);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNothing);

    final playing = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, playing);
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('idle collapse button clears the highlight', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(m.state.selectedAyah, isNull);
    expect(p.stopped, isFalse);
  });

  testWidgets('pinned overlay: collapse unpins when idle', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, isOverlayPinned: true),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    // After unpinning, isOverlayPinned becomes false
    expect(m.state.isOverlayPinned, isFalse);
  });

  testWidgets('pinned overlay falls back to currentAyah as label', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, isOverlayPinned: true),
    );
    final p = _FakePlayback(const PlaybackState(currentAyah: _target));
    await _pump(tester, m, p);
    // Label should show the currentAyah from playback since no highlight
    expect(find.text('Surah $_name, Ayah 5'), findsOneWidget);
  });

  testWidgets('skip buttons disabled when idle', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(p.skippedPrevious, isFalse);
    expect(p.skippedNext, isFalse);
  });

  testWidgets('skip next disabled at the range end', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(
      const PlaybackState(
        currentAyah: AyahIdentifier(surah: 2, ayah: 7),
        rangeStart: _target,
        rangeEnd: AyahIdentifier(surah: 2, ayah: 7),
        isPlaying: true,
      ),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump();
    expect(p.skippedNext, isFalse);
    expect(p.skippedPrevious, isTrue);
  });

  testWidgets('skip buttons follow a range change', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    const at = AyahIdentifier(surah: 2, ayah: 7);
    final p = _FakePlayback(
      const PlaybackState(
        currentAyah: at,
        rangeStart: _target,
        rangeEnd: at,
        isPlaying: true,
      ),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(p.skippedNext, isFalse);

    p.push(
      p.state.copyWith(rangeEnd: const AyahIdentifier(surah: 2, ayah: 10)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(p.skippedNext, isTrue);
  });

  testWidgets('skip next re-arms follow', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(p.skippedNext, isTrue);
    expect(m.resumed, isTrue);
  });

  testWidgets('skip previous re-arms follow', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(
      const PlaybackState(
        currentAyah: AyahIdentifier(surah: 2, ayah: 7),
        rangeStart: _target,
        rangeEnd: AyahIdentifier(surah: 2, ayah: 10),
        isPlaying: true,
      ),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump();
    expect(p.skippedPrevious, isTrue);
    expect(m.resumed, isTrue);
  });

  testWidgets('title appears when the first play fails', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    expect(find.text('Surah $_name, Ayah 5'), findsNothing);

    p.push(const PlaybackState(requestedAyah: _target, error: 'x'));
    await tester.pumpAndSettle();
    expect(find.text('Surah $_name, Ayah 5'), findsOneWidget);
  });

  testWidgets('audio error shows a SnackBar with retry', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    p.push(const PlaybackState(requestedAyah: _target, error: 'x'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text("Couldn't play ayah 5"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(p.retried, isTrue);
  });

  testWidgets('turning away shows now-reciting with a way back', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, playingAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    m.push(m.state.copyWith(followPlayback: false));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Now reciting: $_name 5, page 3'), findsOneWidget);
    await tester.tap(find.text('Back to the recited ayah'));
    await tester.pump();
    expect(m.resumed, isTrue);
  });

  testWidgets('now-reciting SnackBar goes away when follow re-arms', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, playingAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    m.push(m.state.copyWith(followPlayback: false));
    await tester.pumpAndSettle();
    expect(find.text('Back to the recited ayah'), findsOneWidget);

    m.push(m.state.copyWith(followPlayback: true));
    await tester.pumpAndSettle();
    expect(find.text('Back to the recited ayah'), findsNothing);
  });

  testWidgets('now-reciting SnackBar goes away when the recitation ends', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, playingAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    m.push(m.state.copyWith(followPlayback: false));
    await tester.pumpAndSettle();
    expect(find.text('Back to the recited ayah'), findsOneWidget);

    p.push(const PlaybackState());
    await tester.pumpAndSettle();
    expect(find.text('Back to the recited ayah'), findsNothing);
  });

  testWidgets('audio error SnackBar goes away when the recitation ends', (
    tester,
  ) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    p.push(const PlaybackState(requestedAyah: _target, error: 'x'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    p.push(const PlaybackState());
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('audio error SnackBar goes away when a skip clears the error', (
    tester,
  ) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    p.push(const PlaybackState(requestedAyah: _target, error: 'x'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    p.push(
      const PlaybackState(
        currentAyah: AyahIdentifier(surah: 2, ayah: 6),
        isPlaying: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('now-reciting SnackBar leaves the stop button reachable', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, playingAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    m.push(m.state.copyWith(followPlayback: false));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.tap(find.byTooltip('End recitation'));
    await tester.pump();
    expect(p.stopped, isTrue);
  });

  testWidgets('now-reciting SnackBar times out', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, playingAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    m.push(m.state.copyWith(followPlayback: false));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('hiding the player SnackBar leaves an unrelated one alone', (
    tester,
  ) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    ScaffoldMessenger.of(
      tester.element(find.byType(AyahPlaybackOverlay)),
    ).showSnackBar(
      const SnackBar(content: Text('Bookmark saved'), persist: true),
    );
    await tester.pumpAndSettle();

    p.push(const PlaybackState(currentAyah: _target, isPlaying: true));
    await tester.pumpAndSettle();
    p.push(const PlaybackState());
    await tester.pumpAndSettle();
    m.push(m.state.copyWith(followPlayback: false));
    m.push(m.state.copyWith(followPlayback: true));
    await tester.pumpAndSettle();
    expect(find.text('Bookmark saved'), findsOneWidget);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('now-reciting SnackBar fits a 360 dp phone in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final m = _FakeMushaf(
        const MushafState(currentPage: 1, playingAyah: _target),
      );
      final p = _FakePlayback(
        const PlaybackState(currentAyah: _target, isPlaying: true),
      );
      await tester.pumpWidget(_wrap(m: m, p: p, locale: locale));
      await tester.pumpAndSettle();
      m.push(m.state.copyWith(followPlayback: false));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('swipe down keeps the player while a recitation is active', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(currentAyah: _target, isPlaying: true),
    );
    await _pump(tester, m, p);
    await tester.fling(
      find.text('Surah $_name, Ayah 5'),
      const Offset(0, 200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(m.state.selectedAyah, _target);
    expect(tester.widget<AnimatedOpacity>(_opacity()).opacity, 1);
  });

  testWidgets('swipe down dismisses the player while idle', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState());
    await _pump(tester, m, p);
    await tester.fling(
      find.text('Surah $_name, Ayah 5'),
      const Offset(0, 200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(m.state.selectedAyah, isNull);
    expect(tester.widget<AnimatedOpacity>(_opacity()).opacity, 0);
  });

  testWidgets('loading state shows a spinner instead of play icon', (
    tester,
  ) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState(isLoading: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    // CircularProgressIndicator animates infinitely — use pump() not pumpAndSettle()
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('options sheet speed chip calls setSpeed', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(const PlaybackState(speed: 1.0));
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(p.speedSet, 1.5);
  });

  testWidgets('options sheet range edit re-arms follow', (tester) async {
    final m = _FakeMushaf(
      const MushafState(currentPage: 1, selectedAyah: _target),
    );
    final p = _FakePlayback(
      const PlaybackState(
        rangeStart: _target,
        rangeEnd: AyahIdentifier(surah: 2, ayah: 10),
      ),
    );
    await _pump(tester, m, p);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('range-from')),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pump();
    expect(p.lastRangeStart, const AyahIdentifier(surah: 2, ayah: 6));
    expect(m.resumed, isTrue);
  });
}
