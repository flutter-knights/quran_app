import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_button.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/player_leaf.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);

  final calls = <String>[];

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> retry() async => calls.add('retry');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> skipNext() async => calls.add('skipNext');

  @override
  Future<void> skipPrevious() async => calls.add('skipPrevious');

  @override
  Future<void> playRange({
    required AyahIdentifier start,
    required AyahIdentifier end,
  }) async => calls.add('playRange');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDownloads extends Cubit<SurahDownloadState>
    implements SurahDownloadCubit {
  _FakeDownloads() : super(const SurahDownloadState());

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Calls {
  var newPlay = 0;
  var returned = 0;
}

AyahIdentifier _a(int surah, int ayah) =>
    AyahIdentifier(surah: surah, ayah: ayah);

Widget _host(
  _FakePlayback playback,
  _Calls calls, {
  AyahIdentifier? awayAyah,
  int? awayPage,
  double scale = 1,
}) => MaterialApp(
  locale: const Locale('ar'),
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: S.delegate.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: MultiBlocProvider(
      providers: [
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<SurahDownloadCubit>.value(value: _FakeDownloads()),
      ],
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 360,
          child: PlayerLeaf(
            colors: MushafPaper.cream.colors,
            onReturnToPlaying: () => calls.returned++,
            onNewPlay: () => calls.newPlay++,
            awayAyah: awayAyah,
            awayPage: awayPage,
          ),
        ),
      ),
    ),
  ),
);

Future<_FakePlayback> _pump(
  WidgetTester tester,
  PlaybackState state, {
  _Calls? calls,
  AyahIdentifier? awayAyah,
  int? awayPage,
  double scale = 1,
}) async {
  final playback = _FakePlayback(state);
  await tester.pumpWidget(
    _host(
      playback,
      calls ?? _Calls(),
      awayAyah: awayAyah,
      awayPage: awayPage,
      scale: scale,
    ),
  );
  return playback;
}

Finder _key(String k) => find.byKey(ValueKey(k));

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(_key(key)).onPressed != null;

void main() {
  final reciter = Reciter.alafasy.arabicName;

  testWidgets('title names the requested ayah in Arabic-Indic digits', (
    tester,
  ) async {
    await _pump(tester, PlaybackState(requestedAyah: _a(3, 4)));
    expect(find.text('آل عمران، الآية ٤'), findsOneWidget);
  });

  testWidgets('subtitle names the reciter and the range scope', (tester) async {
    await _pump(
      tester,
      PlaybackState(
        currentAyah: _a(3, 4),
        rangeStart: _a(3, 4),
        rangeEnd: _a(3, 200),
      ),
    );
    expect(find.text('$reciter، حتى نهاية السورة'), findsOneWidget);

    await _pump(
      tester,
      PlaybackState(
        currentAyah: _a(4, 176),
        rangeStart: _a(4, 176),
        rangeEnd: _a(5, 2),
      ),
    );
    expect(find.text('$reciter، حتى نهاية الصفحة'), findsOneWidget);

    await _pump(tester, PlaybackState(currentAyah: _a(3, 4)));
    expect(find.text(reciter), findsOneWidget);
  });

  testWidgets('pause and resume', (tester) async {
    final playing = await _pump(
      tester,
      PlaybackState(currentAyah: _a(2, 5), isPlaying: true),
    );
    expect(
      find.descendant(
        of: _key('player-toggle'),
        matching: find.text('إيقاف مؤقت'),
      ),
      findsOneWidget,
    );
    await tester.tap(_key('player-toggle'));
    expect(playing.calls, ['pause']);

    final paused = await _pump(
      tester,
      PlaybackState(currentAyah: _a(2, 5), isPaused: true),
    );
    expect(
      find.descendant(of: _key('player-toggle'), matching: find.text('متابعة')),
      findsOneWidget,
    );
    await tester.tap(_key('player-toggle'));
    expect(paused.calls, ['resume']);
  });

  testWidgets('loading shows a slim bar and disables the toggle', (
    tester,
  ) async {
    await _pump(tester, PlaybackState(currentAyah: _a(2, 5), isLoading: true));
    expect(
      tester.widget(_key('player-loading')),
      isA<LinearProgressIndicator>(),
    );
    expect(_enabled(tester, 'player-toggle'), isFalse);
  });

  testWidgets('skips are disabled when idle', (tester) async {
    await _pump(tester, const PlaybackState());
    expect(_enabled(tester, 'player-previous'), isFalse);
    expect(_enabled(tester, 'player-next'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip next is disabled at the range end', (tester) async {
    await _pump(
      tester,
      PlaybackState(
        currentAyah: _a(2, 10),
        rangeStart: _a(2, 5),
        rangeEnd: _a(2, 10),
        isPlaying: true,
      ),
    );
    expect(_enabled(tester, 'player-next'), isFalse);
    expect(_enabled(tester, 'player-previous'), isTrue);
  });

  testWidgets('a skip calls onNewPlay', (tester) async {
    final calls = _Calls();
    final playback = await _pump(
      tester,
      PlaybackState(
        currentAyah: _a(2, 6),
        rangeStart: _a(2, 5),
        rangeEnd: _a(2, 10),
        isPlaying: true,
      ),
      calls: calls,
    );
    await tester.tap(_key('player-next'));
    expect(playback.calls, ['skipNext']);
    expect(calls.newPlay, 1);
    await tester.tap(_key('player-previous'));
    expect(playback.calls, ['skipNext', 'skipPrevious']);
    expect(calls.newPlay, 2);
  });

  testWidgets('a range edit in the options sheet calls onNewPlay', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(
      tester,
      PlaybackState(
        currentAyah: _a(2, 6),
        rangeStart: _a(2, 5),
        rangeEnd: _a(2, 10),
        isPlaying: true,
      ),
      calls: calls,
    );
    await tester.tap(_key('player-repeat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('range-from'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _key('range-from'), matching: find.byIcon(Icons.add)),
    );
    await tester.pump();
    expect(calls.newPlay, 1);
  });

  testWidgets('end recitation stops', (tester) async {
    final playback = await _pump(
      tester,
      PlaybackState(currentAyah: _a(2, 5), isPlaying: true),
    );
    await tester.tap(_key('player-end'));
    expect(playback.calls, ['stop']);
  });

  testWidgets('an audio error shows inline with retry and end', (tester) async {
    final handle = tester.ensureSemantics();
    final playback = await _pump(
      tester,
      PlaybackState(error: 'x', requestedAyah: _a(3, 13)),
    );
    expect(find.text('تعذّر تشغيل الآية ١٣ من سورة آل عمران'), findsOneWidget);
    expect(
      find.text('تحقق من الاتصال بالإنترنت، ثم أعِد المحاولة'),
      findsOneWidget,
    );
    expect(_key('player-toggle'), findsNothing);
    expect(_key('player-next'), findsNothing);
    expect(
      find.ancestor(
        of: find.text('تعذّر تشغيل الآية ١٣ من سورة آل عمران'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(_key('player-retry'));
    await tester.tap(_key('player-end'));
    expect(playback.calls, ['retry', 'stop']);
    handle.dispose();
  });

  testWidgets('listening-away shows where the recitation is and a way back', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(
      tester,
      PlaybackState(currentAyah: _a(3, 12), isPlaying: true),
      calls: calls,
      awayAyah: _a(3, 12),
      awayPage: 51,
    );
    expect(find.text('يُتلى الآن: آل عمران ١٢، صفحة ٥١'), findsOneWidget);
    expect(find.text('العودة إلى الآية المتلوّة'), findsOneWidget);
    await tester.tap(_key('player-return'));
    expect(calls.returned, 1);
  });

  testWidgets('the repeat chip summarises and opens the options sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      PlaybackState(currentAyah: _a(2, 5), eachAyahRepeat: 3),
    );
    expect(find.text('التكرار: الآية ×٣، المقطع ×١'), findsOneWidget);

    await _pump(tester, PlaybackState(currentAyah: _a(2, 5)));
    expect(find.text('التكرار: مرة واحدة'), findsOneWidget);

    await _pump(
      tester,
      PlaybackState(currentAyah: _a(2, 5), infiniteRepeat: true),
    );
    expect(find.text('التكرار: بلا توقف'), findsOneWidget);

    await tester.tap(_key('player-repeat'));
    await tester.pumpAndSettle();
    expect(find.text('خيارات التلاوة'), findsOneWidget);
  });

  testWidgets('download chip follows the playing surah', (tester) async {
    await _pump(tester, PlaybackState(currentAyah: _a(3, 4)));
    final button = tester.widget<SurahDownloadButton>(
      find.byType(SurahDownloadButton),
    );
    expect(button.surah, 3);
    expect(button.labelled, isTrue);
  });

  testWidgets('fits at 2x text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      PlaybackState(
        currentAyah: _a(2, 6),
        rangeStart: _a(2, 5),
        rangeEnd: _a(2, 10),
        isPlaying: true,
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
