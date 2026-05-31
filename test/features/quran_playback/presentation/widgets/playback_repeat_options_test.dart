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

  setUpAll(() => registerFallbackValue(const AyahIdentifier(surah: 1, ayah: 1)));

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
}
