import 'dart:convert';
import 'dart:io';

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
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';
import 'package:quran_app/generated/l10n.dart';

import '../../../../../bookmarks/place_fakes.dart';
import '../mushaf_page_harness.dart';

MushafPageEntity _realPage(int page) {
  final name = page.toString().padLeft(3, '0');
  final json =
      jsonDecode(
            File('assets/mushaf/bounds/page_$name.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return MushafPageEntity(
    pageNumber: page,
    ayahs: [
      for (final a in json['ayahs'] as List)
        AyahBoundEntity(
          ayah: AyahIdentifier(
            surah: (a as Map)['surah'] as int,
            ayah: a['ayah'] as int,
          ),
          lines: [
            for (final l in a['lines'] as List)
              NormalizedRect(
                x: ((l as Map)['x'] as num).toDouble(),
                y: (l['y'] as num).toDouble(),
                w: (l['w'] as num).toDouble(),
                h: (l['h'] as num).toDouble(),
              ),
          ],
        ),
    ],
  );
}

class _RealRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(_realPage(pageNumber));
}

void main() {
  final sl = GetIt.instance;
  const pageWidth = 360.0;

  setUp(() {
    if (sl.isRegistered<GetMushafPage>()) sl.unregister<GetMushafPage>();
    sl.registerSingleton<GetMushafPage>(GetMushafPage(_RealRepo()));
  });

  test('the margin never reaches the text on any of the 604 pages', () {
    for (var page = 1; page <= 604; page++) {
      final ayahs = _realPage(page).ayahs;
      final textLeft = pageTextLeftOf(ayahs)!;
      final geometry = FasilGeometry.forPage(
        pageWidth: pageWidth,
        textLeft: textLeft,
      );

      expect(
        geometry.margin,
        lessThanOrEqualTo(textLeft * pageWidth),
        reason: 'page $page',
      );
    }
  });

  for (final page in [1, 2, 50, 106, 443, 604]) {
    testWidgets(
      'at 360 px page $page: no ribbon, tail or cluster touches text',
      (tester) async {
        tester.view.physicalSize = const Size(pageWidth, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final entity = _realPage(page);
        final real = [
          for (final b in entity.ayahs)
            if (b.ayah.ayah > 0) b.ayah,
        ];
        final fasil = FasilState(
          slots: {
            FasilSlot.wird: fasilPlace(FasilSlot.wird, real.first),
            FasilSlot.hifz: fasilPlace(FasilSlot.hifz, real[real.length ~/ 2]),
            FasilSlot.muraja: fasilPlace(FasilSlot.muraja, real.last),
          },
          loaded: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
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
                BlocProvider<MushafCubit>.value(
                  value: FakeMushaf(MushafState(currentPage: page)),
                ),
                BlocProvider<PlaybackCubit>.value(value: FakePlayback()),
                BlocProvider<FasilCubit>.value(value: FakeFasilCubit(fasil)),
                BlocProvider<SavedAyatCubit>.value(
                  value: FakeSavedAyatCubit(const SavedAyatState(loaded: true)),
                ),
              ],
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: MushafPageView(
                    pageNumber: page,
                    onOpenFawasil: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final box = tester.getRect(find.byType(AspectRatio));
        expect(box.width, pageWidth);
        final lines = [
          for (final b in entity.ayahs)
            for (final l in b.lines)
              Rect.fromLTWH(
                box.left + l.x * box.width,
                box.top + l.y * box.height,
                l.w * box.width,
                l.h * box.height,
              ),
        ];
        final covers = [
          for (final slot in FasilSlot.values) ...[
            'fasil-strip-${slot.name}',
            'fasil-tail-${slot.name}',
          ],
          'fasil-cluster',
        ];
        for (final key in covers) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.left, greaterThanOrEqualTo(box.left), reason: key);
          for (final line in lines) {
            expect(
              rect.overlaps(line),
              isFalse,
              reason: '$key $rect overlaps a line $line',
            );
          }
        }
      },
    );
  }
}
