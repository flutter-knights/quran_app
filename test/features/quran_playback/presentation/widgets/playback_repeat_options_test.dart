import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
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
    when(() => cubit.state).thenReturn(
      const PlaybackState(eachAyahRepeat: 3, rangeRepeat: 1),
    );
  });

  Widget host() => MaterialApp(
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
            child: const PlaybackRepeatOptions(),
          ),
        ),
      );

  testWidgets('renders the four counters and the infinite toggle',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('range-from')), findsOneWidget);
    expect(find.byKey(const ValueKey('range-to')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-each')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-range')), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-infinite')), findsOneWidget);
  });

  testWidgets('plus on each-ayah repeat calls setEachAyahRepeat(clamped)',
      (tester) async {
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

  testWidgets(
      'tapping infinite toggle calls setInfiniteRepeat(true, range) when off',
      (tester) async {
    // State already has infiniteRepeat: false (default)
    when(() => cubit.setInfiniteRepeat(any(), any())).thenReturn(null);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('repeat-infinite')));
    await tester.pump();

    verify(() => cubit.setInfiniteRepeat(true, RepeatTarget.range)).called(1);
  });

  testWidgets(
      'non-numeric dialog input does not call setRangeRepeat',
      (tester) async {
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
