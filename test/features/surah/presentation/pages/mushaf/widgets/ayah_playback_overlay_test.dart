import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);
  @override
  void clearHighlight() {
    emit(state.copyWith(clearHighlighted: true));
  }

  @override
  void toggleHighlight(_) {}
  @override
  void setPage(int p) {}
  @override
  void setHighlightBounds(double centerY) {}
  @override
  void pinOverlay() {}
  @override
  void unpinOverlay() {
    emit(state.copyWith(isOverlayPinned: false, clearHighlighted: true));
  }

  @override
  void toggleChrome() {}
  @override
  void setChrome(bool visible) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier => throw UnimplementedError();
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);
  AyahIdentifier? lastPlay;
  bool stopped = false;
  bool paused = false;
  double? speedSet;
  @override
  Future<void> playSelected(AyahIdentifier a) async {
    lastPlay = a;
    emit(state.copyWith(currentAyah: a, isPlaying: true));
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
    emit(state.copyWith(isPlaying: false, isPaused: false, clearCurrentAyah: true));
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

Widget _wrap({required _FakeMushaf m, required _FakePlayback p}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(value: m),
          BlocProvider<PlaybackCubit>.value(value: p),
        ],
        child: const Stack(
          children: [AyahPlaybackOverlay()],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hidden when highlightedAyah is null', (tester) async {
    final m = _FakeMushaf(const MushafState(currentPage: 1));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('shows label + play button when highlighted', (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    expect(find.textContaining('Surah 2, Ayah 5'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('tapping play calls PlaybackCubit.playSelected', (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(p.lastPlay, _target);
  });

  testWidgets('paused on same target → tap play calls resume (not restart)',
      (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState(
      currentAyah: _target,
      isPlaying: false,
      isPaused: true,
    ));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(p.resumed, isTrue);
    expect(p.lastPlay, isNull); // no restart
  });

  testWidgets('shows pause icon while playing', (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(
        const PlaybackState(currentAyah: _target, isPlaying: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('close button clears highlight but leaves playback running',
      (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(
        const PlaybackState(currentAyah: _target, isPlaying: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(m.state.highlightedAyah, isNull);
    expect(p.stopped, isFalse);
  });

  testWidgets('skip-prev disabled at (1,1)', (tester) async {
    final m1 = _FakeMushaf(const MushafState(
        currentPage: 1,
        highlightedAyah: AyahIdentifier(surah: 1, ayah: 1)));
    final p1 = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m1, p: p1));
    await tester.pumpAndSettle();
    final prevBtn = tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.skip_previous));
    expect(prevBtn.onPressed, isNull);
  });

  testWidgets('loading state shows a spinner instead of play icon',
      (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState(isLoading: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    // CircularProgressIndicator animates infinitely — use pump() not pumpAndSettle()
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('overlay always shows expand_more (never close icon)',
      (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState());
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
      'pinned overlay: expand_more tap calls unpinOverlay and dismisses',
      (tester) async {
    final m = _FakeMushaf(const MushafState(
      currentPage: 1,
      isOverlayPinned: true,
    ));
    final p = _FakePlayback(
        const PlaybackState(currentAyah: _target, isPlaying: true));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    // After unpinning, isOverlayPinned becomes false
    expect(m.state.isOverlayPinned, isFalse);
  });

  testWidgets('pinned overlay falls back to PlaybackCubit.currentAyah as label',
      (tester) async {
    final m = _FakeMushaf(const MushafState(
      currentPage: 1,
      isOverlayPinned: true,
    ));
    final p = _FakePlayback(const PlaybackState(currentAyah: _target));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    // Label should show the currentAyah from playback since no highlight
    expect(find.textContaining('Surah 2, Ayah 5'), findsOneWidget);
  });

  testWidgets('speed chip opens menu; selecting calls setSpeed', (tester) async {
    final m = _FakeMushaf(
        const MushafState(currentPage: 1, highlightedAyah: _target));
    final p = _FakePlayback(const PlaybackState(speed: 1.0));
    await tester.pumpWidget(_wrap(m: m, p: p));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.0x'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    expect(p.speedSet, 1.5);
  });
}
