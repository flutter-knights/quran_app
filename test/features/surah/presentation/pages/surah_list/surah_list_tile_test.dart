import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_button.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart';

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

class _FakeDownloads extends Cubit<SurahDownloadState>
    implements SurahDownloadCubit {
  _FakeDownloads(this.downloads) : super(const SurahDownloadState());

  final List<(Reciter, int)> downloads;

  @override
  void download(Reciter reciter, int surah) => downloads.add((reciter, surah));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _surah = SurahEntity(
  number: 2,
  name: 'البقرة',
  englishName: 'Al-Baqarah',
  qcfSurahName: 'سُورَةُ ٱلْبَقَرَةِ',
  revelationType: 'مدنية',
  numberOfAyahs: 286,
  pageNumber: 2,
);

Future<Object?> _tap(
  WidgetTester tester,
  _FakePlayback playback,
  Finder target, [
  List<(Reciter, int)>? downloads,
]) async {
  Object? extra;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<PlaybackCubit>.value(value: playback),
            BlocProvider<SurahDownloadCubit>.value(
              value: _FakeDownloads(downloads ?? []),
            ),
          ],
          child: Scaffold(body: SurahListTile(surah: _surah)),
        ),
      ),
      GoRoute(
        path: '/mushaf',
        builder: (_, state) {
          extra = state.extra;
          return const SizedBox();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
  return extra;
}

void expectOpenedSurah(Object? extra) {
  final args = extra as MushafArgs;
  expect(args.page, 2);
  expect(args.openedSurah, 2);
  expect(args.origin, MushafOrigin.normal);
}

void main() {
  testWidgets('play button plays the whole surah as a range', (tester) async {
    final playback = _FakePlayback();
    final extra = await _tap(
      tester,
      playback,
      find.byIcon(Icons.play_circle_outline),
    );
    expect(playback.rangeStart, const AyahIdentifier(surah: 2, ayah: 1));
    expect(playback.rangeEnd, const AyahIdentifier(surah: 2, ayah: 286));
    expectOpenedSurah(extra);
  });

  testWidgets('tapping the tile opens the surah from its start', (
    tester,
  ) async {
    final extra = await _tap(tester, _FakePlayback(), find.text('البقرة'));
    expectOpenedSurah(extra);
  });

  testWidgets('the tile carries the download button for its surah', (
    tester,
  ) async {
    final downloads = <(Reciter, int)>[];
    final extra = await _tap(
      tester,
      _FakePlayback(),
      find.byIcon(Icons.download_for_offline_outlined),
      downloads,
    );
    expect(extra, isNull);
    expect(downloads, [(Reciter.alafasy, 2)]);
    expect(
      tester
          .widget<SurahDownloadButton>(find.byType(SurahDownloadButton))
          .surah,
      2,
    );
  });
}
