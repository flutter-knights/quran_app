import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());
  AyahIdentifier? lastPlay;
  @override
  Future<void> playFromAyah(AyahIdentifier a) async => lastPlay = a;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('play button calls playFromAyah(surah, 1)', (tester) async {
    final surah = SurahEntity(
      number: 2,
      name: 'البقرة',
      englishName: 'Al-Baqarah',
      qcfSurahName: 'سُورَةُ ٱلْبَقَرَةِ',
      revelationType: 'مدنية',
      numberOfAyahs: 286,
      pageNumber: 2,
    );
    final playback = _FakePlayback();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<PlaybackCubit>.value(
            value: playback,
            child: Scaffold(body: SurahListTile(surah: surah)),
          ),
        ),
        GoRoute(path: '/mushaf', builder: (_, __) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();
    expect(playback.lastPlay, const AyahIdentifier(surah: 2, ayah: 1));
  });
}
