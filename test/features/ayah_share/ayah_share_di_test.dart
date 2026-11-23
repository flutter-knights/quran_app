import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ayah_share/ayah_share_di.dart';
import 'package:quran_app/features/ayah_share/presentation/cubit/ayah_share_cubit.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/tafsir/domain/repositories/tafsir_repository.dart';
import 'package:quran_app/features/tafsir/domain/usecases/get_ayah_tafsir.dart';

import '../surah/presentation/pages/mushaf/mushaf_page_harness.dart';

class _StubMushafRepo implements MushafRepository {
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async =>
      Right(MushafPageEntity(pageNumber: pageNumber, ayahs: const []));
}

class _StubTafsirRepo implements TafsirRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NightSettings extends FakeSettings {
  _NightSettings() {
    emit(
      SettingsState(
        state.settingsModel.copyWith(mushafPaper: MushafPaper.night),
      ),
    );
  }
}

void main() {
  tearDown(sl.reset);

  test('initAyahShare builds a cubit on the reader paper', () {
    sl.registerLazySingleton(() => GetMushafPage(_StubMushafRepo()));
    sl.registerLazySingleton<QuranPageService>(QuranPageServiceImpl.new);
    sl.registerLazySingleton(() => GetAyahTafsir(_StubTafsirRepo()));
    sl.registerSingleton<SettingsCubit>(_NightSettings());
    initAyahShare();

    final cubit = sl<AyahShareCubit>(
      param1: const AyahIdentifier(surah: 6, ayah: 31),
    );
    addTearDown(cubit.close);

    expect(cubit.ayah, const AyahIdentifier(surah: 6, ayah: 31));
    expect(cubit.state.paper, MushafPaper.night);
  });
}
