import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_button.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState(reciter: Reciter.husary));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDownloads extends Cubit<SurahDownloadState>
    implements SurahDownloadCubit {
  _FakeDownloads([Map<String, SurahDownloadStatus> statuses = const {}])
    : super(SurahDownloadState(statuses: statuses));

  final downloads = <(Reciter, int)>[];
  final cancels = <(Reciter, int)>[];
  final deletes = <(Reciter, int)>[];

  void push(Map<String, SurahDownloadStatus> statuses) =>
      emit(SurahDownloadState(statuses: statuses));

  @override
  SurahDownloadStatus statusOf(Reciter reciter, int surah) =>
      state.statuses[reciter.downloadKey(surah)] ?? const SurahNotDownloaded();

  @override
  void download(Reciter reciter, int surah) => downloads.add((reciter, surah));

  @override
  Future<void> cancel(Reciter reciter, int surah) async =>
      cancels.add((reciter, surah));

  @override
  Future<void> delete(Reciter reciter, int surah) async =>
      deletes.add((reciter, surah));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(WidgetTester tester, _FakeDownloads downloads) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<PlaybackCubit>.value(value: _FakePlayback()),
              BlocProvider<SurahDownloadCubit>.value(value: downloads),
            ],
            child: const SurahDownloadButton(surah: 2),
          ),
        ),
      ),
    );

void main() {
  testWidgets('not downloaded: the button starts the download for the '
      'current reciter', (tester) async {
    final downloads = _FakeDownloads();
    await _pump(tester, downloads);
    await tester.tap(find.byTooltip('تنزيل السورة'));
    expect(downloads.downloads, [(Reciter.husary, 2)]);
  });

  testWidgets('downloading: a 40% ring that cancels on tap', (tester) async {
    final handle = tester.ensureSemantics();
    final downloads = _FakeDownloads({'husary:2': const SurahDownloading(.4)});
    await _pump(tester, downloads);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, .4);
    expect(find.bySemanticsLabel(RegExp('جارٍ التنزيل ٤٠٪')), findsOneWidget);
    await tester.tap(find.byTooltip('إلغاء التنزيل'));
    expect(downloads.cancels, [(Reciter.husary, 2)]);
    handle.dispose();
  });

  testWidgets('downloaded: the saved icon offers to delete the download', (
    tester,
  ) async {
    final downloads = _FakeDownloads({'husary:2': const SurahDownloaded()});
    await _pump(tester, downloads);
    await tester.tap(find.byTooltip('محفوظة للاستماع دون إنترنت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف التنزيل'));
    await tester.pumpAndSettle();
    expect(downloads.deletes, [(Reciter.husary, 2)]);
  });

  testWidgets('failed: retries on tap and the failure shows a SnackBar', (
    tester,
  ) async {
    final downloads = _FakeDownloads();
    await _pump(tester, downloads);
    downloads.push({'husary:2': const SurahDownloadFailed()});
    await tester.pump();
    expect(find.text('تعذّر التنزيل، أعِد المحاولة'), findsOneWidget);
    await tester.tap(find.byTooltip('تعذّر التنزيل، أعِد المحاولة'));
    expect(downloads.downloads, [(Reciter.husary, 2)]);
  });

  testWidgets("another reciter's download does not show on this button", (
    tester,
  ) async {
    await _pump(tester, _FakeDownloads({'alafasy:2': const SurahDownloaded()}));
    expect(find.byTooltip('تنزيل السورة'), findsOneWidget);
  });
}
