import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_listener.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState(reciter: Reciter.husary));

  void push(Reciter reciter) => emit(state.copyWith(reciter: reciter));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDownloads extends Cubit<SurahDownloadState>
    implements SurahDownloadCubit {
  _FakeDownloads() : super(const SurahDownloadState());

  final refreshes = <Reciter>[];

  void push(Map<String, SurahDownloadStatus> statuses) =>
      emit(SurahDownloadState(statuses: statuses));

  @override
  void refresh(Reciter reciter) => refreshes.add(reciter);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  const failedText = 'تعذّر التنزيل، أعِد المحاولة';
  late _FakePlayback playback;
  late _FakeDownloads downloads;

  setUp(() {
    playback = _FakePlayback();
    downloads = _FakeDownloads();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<SurahDownloadCubit>.value(value: downloads),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        builder: (_, child) => SurahDownloadListener(child: child!),
        home: const Scaffold(body: Text('home')),
      ),
    ),
  );

  testWidgets('a failure shows one SnackBar with no tile mounted', (
    tester,
  ) async {
    await pump(tester);
    downloads.push({'husary:2': const SurahDownloadFailed()});
    await tester.pump();
    expect(find.text(failedText), findsOneWidget);
    downloads.push({
      'husary:2': const SurahDownloadFailed(),
      'husary:3': const SurahDownloaded(),
    });
    await tester.pump();
    expect(find.text(failedText), findsOneWidget);
  });

  testWidgets('a second surah failing shows its own SnackBar', (tester) async {
    await pump(tester);
    downloads.push({'husary:2': const SurahDownloadFailed()});
    await tester.pump();
    ScaffoldMessenger.of(
      tester.element(find.text('home')),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    downloads.push({
      'husary:2': const SurahDownloadFailed(),
      'husary:3': const SurahDownloadFailed(),
    });
    await tester.pumpAndSettle();
    expect(find.text(failedText), findsOneWidget);
  });

  testWidgets('a reciter change refreshes the statuses for that reciter', (
    tester,
  ) async {
    await pump(tester);
    expect(downloads.refreshes, isEmpty);
    playback.push(Reciter.alafasy);
    await tester.pump();
    expect(downloads.refreshes, [Reciter.alafasy]);
  });
}
