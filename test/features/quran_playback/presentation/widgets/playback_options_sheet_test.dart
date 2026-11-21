import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/playback_options_sheet.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/playback_repeat_options.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState());

  double? speed;
  Reciter? reciter;

  @override
  Future<void> setSpeed(double s) async => speed = s;

  @override
  Future<void> setReciter(Reciter r) async => reciter = r;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(
  WidgetTester tester,
  _FakePlayback playback,
  String locale,
) => tester.pumpWidget(
  MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: BlocProvider<PlaybackCubit>.value(
        value: playback,
        child: const PlaybackOptionsSheet(),
      ),
    ),
  ),
);

void main() {
  testWidgets('speed labels read in Arabic-Indic digits in Arabic', (
    tester,
  ) async {
    await _pump(tester, _FakePlayback(), 'ar');
    for (final label in ['٠٫٥×', '٠٫٧٥×', '١×', '١٫٢٥×', '١٫٥×', '٢×']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('speed labels read in Latin digits in English', (tester) async {
    await _pump(tester, _FakePlayback(), 'en');
    for (final label in ['0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('a speed chip calls setSpeed', (tester) async {
    final playback = _FakePlayback();
    await _pump(tester, playback, 'ar');
    await tester.ensureVisible(find.text('١٫٢٥×'));
    await tester.tap(find.text('١٫٢٥×'));
    expect(playback.speed, 1.25);
  });

  testWidgets('a reciter chip calls setReciter', (tester) async {
    final playback = _FakePlayback();
    await _pump(tester, playback, 'ar');
    await tester.tap(find.text(Reciter.husary.arabicName));
    expect(playback.reciter, Reciter.husary);
  });

  testWidgets('shows the title and the repeat options', (tester) async {
    await _pump(tester, _FakePlayback(), 'ar');
    expect(find.text('خيارات التلاوة'), findsOneWidget);
    expect(find.byType(PlaybackRepeatOptions), findsOneWidget);
  });

  testWidgets('every chip is at least 48 high', (tester) async {
    await _pump(tester, _FakePlayback(), 'ar');
    final chips = find.byType(OptionChip);
    expect(chips, findsWidgets);
    for (final chip in chips.evaluate()) {
      expect(
        tester.getSize(find.byWidget(chip.widget)).height,
        greaterThanOrEqualTo(48),
      );
    }
  });
}
