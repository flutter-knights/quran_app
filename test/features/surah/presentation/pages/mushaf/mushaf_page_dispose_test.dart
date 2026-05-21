import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/last_read_repository.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeMushaf extends Cubit<MushafState> implements MushafCubit {
  _FakeMushaf(super.initial);
  AyahIdentifier? highlighted;
  @override
  void clearHighlight() {}
  @override
  void toggleHighlight(AyahIdentifier a) {
    highlighted = a;
    emit(state.copyWith(highlightedAyah: a));
  }

  @override
  void setPage(int p) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier => throw UnimplementedError();
}

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback(super.initial);
  int stopCalls = 0;
  @override
  Future<void> stop() async {
    stopCalls++;
    emit(state.copyWith(clearCurrentAyah: true, isPlaying: false));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubLastReadRepo implements LastReadRepository {
  LastRead? saved;
  @override
  Future<LastRead?> get() async => null;
  @override
  Future<void> save(LastRead value) async => saved = value;
  @override
  Stream<LastRead?> watch() => const Stream.empty();
}

class _StubPageService implements QuranPageService {
  @override
  int getPageForAyah(int s, int a) => 1;
  @override
  AyahIdentifier? getFirstAyahOfPage(int p) => null;
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    if (sl.isRegistered<QuranPageService>()) sl.unregister<QuranPageService>();
    sl.registerSingleton<QuranPageService>(_StubPageService());
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_StubMushafRepo()));
  });

  testWidgets('on dispose: saves (page, highlighted) then stops playback',
      (tester) async {
    final mushaf = _FakeMushaf(const MushafState(
        currentPage: 7,
        highlightedAyah: AyahIdentifier(surah: 2, ayah: 5)));
    final playback = _FakePlayback(const PlaybackState());
    final repo = _StubLastReadRepo();

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(value: mushaf),
          BlocProvider<PlaybackCubit>.value(value: playback),
          BlocProvider<LastReadCubit>.value(
              value: LastReadCubit(repository: repo)),
        ],
        child: const MushafPage(initialPage: 7),
      ),
    ));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(
        repo.saved,
        const LastRead(
          page: 7,
          ayah: AyahIdentifier(surah: 2, ayah: 5),
        ));
    expect(playback.stopCalls, 1);
  });
}
