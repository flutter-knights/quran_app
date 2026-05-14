import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart';
import 'package:quran_app/features/surah/presentation/utils/current_ayah_notifier.dart';

class _FakeUseCase extends Mock implements GetMushafPage {}

class _FakePlaybackCubit extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlaybackCubit() : super(const PlaybackState());
  @override
  // ignore: invalid_override_of_non_virtual_member
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

MushafPageEntity _entity() => MushafPageEntity(
      pageNumber: 5,
      ayahs: const [],
      surahNames: const [],
      surahHeadersIndexes: const [],
      basmalaIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
    );

MushafCubit _seededCubit(MushafState seed) {
  final pageCache = MushafPageCache(capacity: 1);
  final spansCache = MushafSpansCache(capacity: 1, pageCache: pageCache);
  final useCase = _FakeUseCase();
  when(() => useCase.call(any())).thenAnswer((_) async => Right(_entity()));
  final cubit = MushafCubit(
    useCase: useCase,
    pageCache: pageCache,
    spansCache: spansCache,
  );
  cubit.seedForTest(seed);
  return cubit;
}

void main() {
  late CurrentAyahNotifier notifier;

  setUp(() {
    notifier = CurrentAyahNotifier(playbackCubit: _FakePlaybackCubit());
    if (sl.isRegistered<CurrentAyahNotifier>()) {
      sl.unregister<CurrentAyahNotifier>();
    }
    sl.registerSingleton<CurrentAyahNotifier>(notifier);
  });

  tearDown(() {
    if (sl.isRegistered<CurrentAyahNotifier>()) {
      sl.unregister<CurrentAyahNotifier>();
    }
    notifier.dispose();
  });

  testWidgets('renders CircularProgressIndicator on MushafLoading', (tester) async {
    final cubit = _seededCubit(const MushafLoading());
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<MushafCubit>.value(
        value: cubit,
        child: const MushafPageContent(pageNumber: 5),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await cubit.close();
  });

  testWidgets('renders error text on MushafError', (tester) async {
    final cubit = _seededCubit(const MushafError('oh no'));
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<MushafCubit>.value(
        value: cubit,
        child: const MushafPageContent(pageNumber: 5),
      ),
    ));
    expect(find.text('oh no'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('renders no spinner on MushafLoaded with empty spans', (tester) async {
    final cubit = _seededCubit(MushafLoaded(
      page: _entity(),
      spans: const <InlineSpan>[],
      normalStyle: const TextStyle(),
      highlightedStyle: const TextStyle(),
      pageWidth: 300,
      fontSize: 14,
      lineHeight: 28,
    ));
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<MushafCubit>.value(
        value: cubit,
        child: const MushafPageContent(pageNumber: 5),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await cubit.close();
  });
}
