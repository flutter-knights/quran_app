import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';

class _StubPageService implements QuranPageService {
  @override
  int getPageForAyah(int surah, int ayah) => 1;
  @override
  AyahIdentifier? getFirstAyahOfPage(int page) => null;
}

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

MushafCubit _cubit(ValueNotifier<AyahIdentifier?> notifier) => MushafCubit(
  args: const MushafArgs(page: 1),
  currentAyahNotifier: notifier,
  pageService: _StubPageService(),
  getMushafPage: GetMushafPage(_StubMushafRepo()),
);

void main() {
  test(
    'toggleChrome flips chromeVisible; default false; setChrome sets it',
    () {
      final notifier = ValueNotifier<AyahIdentifier?>(null);
      final cubit = _cubit(notifier);

      expect(cubit.state.chromeVisible, isFalse);

      cubit.toggleChrome();
      expect(cubit.state.chromeVisible, isTrue);

      cubit.setChrome(false);
      expect(cubit.state.chromeVisible, isFalse);

      cubit.close();
      notifier.dispose();
    },
  );

  test('clearing chrome keeps the highlighted ayah', () {
    final notifier = ValueNotifier<AyahIdentifier?>(null);
    final cubit = _cubit(notifier);

    const ayah = AyahIdentifier(surah: 2, ayah: 255);
    cubit.toggleSelection(ayah);
    cubit.setChrome(false);

    expect(cubit.state.selectedAyah, equals(ayah));
    expect(cubit.state.chromeVisible, isFalse);

    cubit.close();
    notifier.dispose();
  });
}
