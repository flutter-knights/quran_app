import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_leaf.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

class _MockBookmarkCubit extends MockCubit<BookmarkState>
    implements BookmarkCubit {}

class _Calls {
  final taps = <String>[];
  VoidCallback tap(String name) =>
      () => taps.add(name);
}

Widget _host(
  BookmarkCubit cubit,
  AyahIdentifier ayah,
  _Calls calls, {
  double scale = 1,
}) => MaterialApp(
  localizationsDelegates: const [
    S.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: S.delegate.supportedLocales,
  locale: const Locale('ar'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: BlocProvider<BookmarkCubit>.value(
      value: cubit,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 360,
          child: AyahLeaf(
            ayah: ayah,
            colors: MushafPaper.cream.colors,
            onClose: calls.tap('close'),
            onListenFromHere: calls.tap('here'),
            onListenFromSurahStart: calls.tap('start'),
            onListenPage: calls.tap('page'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late _MockBookmarkCubit cubit;
  late _Calls calls;

  setUpAll(
    () => registerFallbackValue(const AyahIdentifier(surah: 1, ayah: 1)),
  );

  setUp(() {
    cubit = _MockBookmarkCubit();
    calls = _Calls();
    when(() => cubit.state).thenReturn(const BookmarkState());
    when(() => cubit.toggle(any())).thenAnswer((_) async {});
  });

  const ayah = AyahIdentifier(surah: 3, ayah: 7);

  testWidgets('ayah leaf labels are distinct', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    final labels = {'استماع من هنا', 'حفظ الآية', 'مشاركة'};
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(labels.length, 3);
  });

  testWidgets('title names the surah and ayah in Arabic-Indic digits', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    expect(find.text('آل عمران، الآية ٧'), findsOneWidget);
  });

  testWidgets('listen from here, close and save reach their handlers', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    await tester.tap(find.byKey(const ValueKey('leaf-listen')));
    await tester.tap(find.byKey(const ValueKey('leaf-close')));
    await tester.tap(find.byKey(const ValueKey('leaf-save')));
    expect(calls.taps, ['here', 'close']);
    verify(() => cubit.toggle(ayah)).called(1);
  });

  testWidgets('dragging down closes', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls));
    await tester.fling(find.byType(AyahLeaf), const Offset(0, 300), 1000);
    expect(calls.taps, ['close']);
  });

  testWidgets('a sajda ayah carries the badge', (tester) async {
    await tester.pumpWidget(
      _host(cubit, const AyahIdentifier(surah: 32, ayah: 15), calls),
    );
    expect(find.text('سجدة'), findsOneWidget);
    await tester.pumpWidget(
      _host(cubit, const AyahIdentifier(surah: 32, ayah: 14), calls),
    );
    expect(find.text('سجدة'), findsNothing);
  });

  testWidgets('the banner variant offers the surah actions only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(cubit, const AyahIdentifier(surah: 5, ayah: 0), calls),
    );
    expect(find.text('سورة المائدة'), findsOneWidget);
    expect(find.text('مدنية، ١٢٠ آية'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leaf-surah-start')));
    await tester.tap(find.byKey(const ValueKey('leaf-page')));
    expect(calls.taps, ['start', 'page']);
    expect(find.text('استماع من بداية السورة'), findsOneWidget);
    expect(find.text('استماع الصفحة كاملة'), findsOneWidget);
    expect(find.text('مشاركة'), findsNothing);
    expect(find.text('حفظ الآية'), findsNothing);
    expect(find.textContaining('الآية ٠'), findsNothing);
  });

  testWidgets('share text quotes the ayah and names it', (tester) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('ar'),
        home: Builder(
          builder: (context) {
            text = ayahShareText(
              context,
              const AyahIdentifier(surah: 112, ayah: 1),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, '${quran.getVerse(112, 1)} — سورة الإخلاص، الآية ١');
  });

  testWidgets('fits at 2x text', (tester) async {
    await tester.pumpWidget(_host(cubit, ayah, calls, scale: 2));
    expect(tester.takeException(), isNull);
  });
}
