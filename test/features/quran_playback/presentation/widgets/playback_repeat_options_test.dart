import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/playback_repeat_options.dart';
import 'package:quran_app/generated/l10n.dart';

class _MockPlaybackCubit extends MockCubit<PlaybackState>
    implements PlaybackCubit {}

void main() {
  late _MockPlaybackCubit cubit;

  setUpAll(() {
    registerFallbackValue(const AyahIdentifier(surah: 1, ayah: 1));
    registerFallbackValue(RepeatTarget.range);
  });

  setUp(() {
    cubit = _MockPlaybackCubit();
    when(
      () => cubit.state,
    ).thenReturn(const PlaybackState(eachAyahRepeat: 3, rangeRepeat: 1));
  });

  Widget host({VoidCallback? onNewPlay, Locale? locale}) => MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: BlocProvider<PlaybackCubit>.value(
        value: cubit,
        child: PlaybackRepeatOptions(onNewPlay: onNewPlay),
      ),
    ),
  );

  testWidgets('renders the four counters and the infinite toggle', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('range-from')), findsOneWidget);
    expect(find.byKey(const ValueKey('range-to')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-each')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-range')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-infinite-each')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-infinite-range')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-infinite')), findsNothing);
  });

  testWidgets('infinite toggle beside each-ayah targets eachAyah', (
    tester,
  ) async {
    when(() => cubit.setInfiniteRepeat(any(), any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('repeat-infinite-each')));
    await tester.pump();
    verify(
      () => cubit.setInfiniteRepeat(true, RepeatTarget.eachAyah),
    ).called(1);
  });

  testWidgets('infinite toggle on the other target stays off and switches', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const PlaybackState(
        infiniteRepeat: true,
        infiniteTarget: RepeatTarget.eachAyah,
      ),
    );
    when(() => cubit.setInfiniteRepeat(any(), any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('repeat-infinite-range')));
    await tester.pump();
    verify(() => cubit.setInfiniteRepeat(true, RepeatTarget.range)).called(1);
  });

  testWidgets('cross-surah range is read-only', (tester) async {
    when(() => cubit.state).thenReturn(
      const PlaybackState(
        rangeStart: AyahIdentifier(surah: 4, ayah: 176),
        rangeEnd: AyahIdentifier(surah: 5, ayah: 2),
      ),
    );
    await tester.pumpWidget(host(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'من ${quran.getSurahNameArabic(4)} ١٧٦ إلى ${quran.getSurahNameArabic(5)} ٢',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('range-from')), findsNothing);
    expect(find.byKey(const ValueKey('range-to')), findsNothing);
  });

  testWidgets('range-from edit is a new play, range-to edit is not', (
    tester,
  ) async {
    when(
      () => cubit.playRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async {});
    when(() => cubit.setRangeEnd(any())).thenReturn(null);
    var called = 0;
    await tester.pumpWidget(host(onNewPlay: () => called++));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('range-from')),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pump();
    verify(
      () => cubit.playRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).called(1);
    expect(called, 1);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('range-to')),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pump();
    expect(called, 1);
  });

  testWidgets('plus on each-ayah repeat calls setEachAyahRepeat(clamped)', (
    tester,
  ) async {
    when(() => cubit.setEachAyahRepeat(any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final plus = find.descendant(
      of: find.byKey(const ValueKey('repeat-each')),
      matching: find.byIcon(Icons.add),
    );
    await tester.tap(plus);
    await tester.pump();
    verify(() => cubit.setEachAyahRepeat(4)).called(1); // 3 + 1
  });

  testWidgets('infinite toggle beside the passage targets range', (
    tester,
  ) async {
    when(() => cubit.setInfiniteRepeat(any(), any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('repeat-infinite-range')));
    await tester.pump();

    verify(() => cubit.setInfiniteRepeat(true, RepeatTarget.range)).called(1);
  });

  testWidgets('non-numeric dialog input does not call setRangeRepeat', (
    tester,
  ) async {
    when(() => cubit.setRangeRepeat(any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Tap the value text inside the repeat-range counter to open the dialog
    final valueText = find.descendant(
      of: find.byKey(const ValueKey('repeat-range')),
      matching: find.text('1'),
    );
    await tester.tap(valueText);
    await tester.pumpAndSettle();

    // The dialog text field should be visible
    final textField = find.byKey(const ValueKey('counter-text-field'));
    expect(textField, findsOneWidget);

    // Enter a non-numeric string
    await tester.enterText(textField, 'abc');

    // Tap the confirm button
    final applyButton = find.text(S.current.filter_apply);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // Null parse → revert → setRangeRepeat must NOT be called
    verifyNever(() => cubit.setRangeRepeat(any()));
  });
}
