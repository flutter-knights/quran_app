import '../../core/constants/mushaf_paper.dart';
import '../../core/di/dependency_injection.dart';
import '../quran_playback/domain/entities/ayah_identifier.dart';
import 'domain/usecases/get_share_card_content.dart';
import 'presentation/cubit/ayah_share_cubit.dart';
import 'presentation/utils/share_card_renderer.dart';

void initAyahShare() {
  sl.registerLazySingleton(
    () => GetShareCardContent(getMushafPage: sl(), pageService: sl()),
  );
  sl.registerLazySingleton(() => ShareCardRenderer());
  sl.registerFactoryParam<AyahShareCubit, AyahIdentifier, MushafPaper>(
    (ayah, paper) => AyahShareCubit(
      ayah: ayah,
      paper: paper,
      getContent: sl(),
      renderer: sl(),
      getTafsir: sl(),
    ),
  );
}
