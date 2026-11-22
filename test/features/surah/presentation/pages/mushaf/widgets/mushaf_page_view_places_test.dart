import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_state.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/fasil_rules.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../bookmarks/place_fakes.dart';
import '../mushaf_page_harness.dart';

const _first = AyahIdentifier(surah: 3, ayah: 1);
const _second = AyahIdentifier(surah: 3, ayah: 6);
const _elsewhere = AyahIdentifier(surah: 2, ayah: 255);

class _BoundsRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      const Right(
        MushafPageEntity(
          pageNumber: 50,
          ayahs: [
            AyahBoundEntity(
              ayah: _first,
              lines: [NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05)],
            ),
            AyahBoundEntity(
              ayah: _second,
              lines: [
                NormalizedRect(x: 0.1, y: 0.50, w: 0.8, h: 0.05),
                NormalizedRect(x: 0.1, y: 0.55, w: 0.8, h: 0.05),
              ],
            ),
          ],
        ),
      );
}

class _PendingRepo implements MushafRepository {
  final completer = Completer<Either<Failure, MushafPageEntity>>();

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) =>
      completer.future;
}

class _FailingRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      const Left(CacheFailure('x'));
}

void main() {
  final sl = GetIt.instance;
  late FakeMushaf mushaf;

  setUp(() {
    mushaf = FakeMushaf(const MushafState(currentPage: 50));
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_BoundsRepo()));
  });

  Future<List<FasilSlot?>> pumpView(
    WidgetTester tester, {
    FasilState fasil = const FasilState(loaded: true),
    SavedAyatState saved = const SavedAyatState(loaded: true),
    String locale = 'en',
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <FasilSlot?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: FakeSettings()),
            BlocProvider<MushafCubit>.value(value: mushaf),
            BlocProvider<PlaybackCubit>.value(value: FakePlayback()),
            BlocProvider<FasilCubit>.value(value: FakeFasilCubit(fasil)),
            BlocProvider<SavedAyatCubit>.value(
              value: FakeSavedAyatCubit(saved),
            ),
          ],
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MushafPageView(pageNumber: 50, onOpenFawasil: opened.add),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return opened;
  }

  FasilState placed(Map<FasilSlot, AyahIdentifier> at) => FasilState(
    slots: {for (final e in at.entries) e.key: fasilPlace(e.key, e.value)},
    loaded: true,
  );

  Rect page(WidgetTester tester) => tester.getRect(find.byType(AspectRatio));

  testWidgets('no placed فاصل draws no cluster', (tester) async {
    await pumpView(tester);

    expect(find.byKey(const ValueKey('fasil-cluster')), findsNothing);
  });

  testWidgets('the cluster opens the chooser with no preselect', (
    tester,
  ) async {
    final opened = await pumpView(
      tester,
      fasil: placed({FasilSlot.hifz: _elsewhere}),
    );

    await tester.tap(find.byKey(const ValueKey('fasil-cluster')));

    expect(opened, [null]);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('the cluster and tails hug the left edge in $locale', (
      tester,
    ) async {
      await pumpView(
        tester,
        fasil: placed({FasilSlot.hifz: _second}),
        saved: SavedAyatState(items: [savedPlace(_first)], loaded: true),
        locale: locale,
      );
      final left = page(tester).left;

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('fasil-cluster'))).dx,
        left,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('fasil-tail-hifz'))).dx,
        left,
      );
      expect(
        tester.getTopRight(find.byKey(const ValueKey('saved-dot-3:1'))).dx,
        page(tester).right - 6,
      );
    });
  }

  testWidgets('a فاصل on this page hangs its tail at the ayah line', (
    tester,
  ) async {
    final opened = await pumpView(
      tester,
      fasil: placed({FasilSlot.hifz: _second}),
    );
    final box = page(tester);
    final tail = tester.getRect(find.byKey(const ValueKey('fasil-tail-hifz')));
    final strip = tester.getRect(
      find.byKey(const ValueKey('fasil-strip-hifz')),
    );

    expect(tail.bottom - box.top, closeTo(0.55 * box.height, 1));
    expect(strip.top, box.top);
    expect(strip.bottom, closeTo(tail.top, 0.01));

    await tester.tap(find.byKey(const ValueKey('fasil-tail-hifz')));

    expect(opened, [FasilSlot.hifz]);
  });

  testWidgets('two فواصل on one ayah stack', (tester) async {
    await pumpView(
      tester,
      fasil: placed({FasilSlot.wird: _second, FasilSlot.hifz: _second}),
    );

    final wird = tester.getTopLeft(
      find.byKey(const ValueKey('fasil-tail-wird')),
    );
    final hifz = tester.getTopLeft(
      find.byKey(const ValueKey('fasil-tail-hifz')),
    );

    expect(hifz.dy, wird.dy + fasilTailHeight);
  });

  testWidgets('a فاصل on the first line stays below the cluster', (
    tester,
  ) async {
    await pumpView(tester, fasil: placed({FasilSlot.wird: _first}));

    final tail = tester.getTopLeft(
      find.byKey(const ValueKey('fasil-tail-wird')),
    );

    expect(tail.dy - page(tester).top, fasilClusterHeight);
  });

  testWidgets('a saved ayah on this page shows the dot', (tester) async {
    await pumpView(
      tester,
      saved: SavedAyatState(
        items: [savedPlace(_first), savedPlace(_elsewhere)],
        loaded: true,
      ),
    );

    expect(find.byKey(const ValueKey('saved-dot-3:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-dot-2:255')), findsNothing);
  });

  testWidgets('the cluster shows while the page bounds are loading', (
    tester,
  ) async {
    final repo = _PendingRepo();
    sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(repo));
    final opened = await pumpView(
      tester,
      fasil: placed({FasilSlot.hifz: _second}),
    );

    expect(find.byKey(const ValueKey('fasil-cluster')), findsOneWidget);
    expect(find.byKey(const ValueKey('fasil-tail-hifz')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('fasil-cluster')));

    expect(opened, [null]);
  });

  testWidgets('the cluster shows when the page bounds fail to load', (
    tester,
  ) async {
    sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_FailingRepo()));
    await pumpView(tester, fasil: placed({FasilSlot.hifz: _second}));

    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const ValueKey('fasil-cluster')), findsOneWidget);
    expect(find.byKey(const ValueKey('fasil-tail-hifz')), findsNothing);
  });
}
