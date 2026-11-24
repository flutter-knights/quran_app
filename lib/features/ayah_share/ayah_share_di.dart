import '../../core/constants/mushaf_paper.dart';
import '../../core/di/dependency_injection.dart';
import '../quran_playback/domain/entities/ayah_identifier.dart';
import 'data/repositories/reel_repository_impl.dart';
import 'domain/repositories/reel_repository.dart';
import 'domain/usecases/compose_ayah_reel.dart';
import 'domain/usecases/get_share_card_content.dart';
import 'domain/usecases/prepare_ayah_audio.dart';
import 'domain/usecases/save_share_card.dart';
import 'presentation/cubit/ayah_share_cubit.dart';
import 'presentation/utils/reel_frame_painter.dart';
import 'presentation/utils/share_card_renderer.dart';

void initAyahShare() {
  sl.registerLazySingleton(
    () => GetShareCardContent(getMushafPage: sl(), pageService: sl()),
  );
  sl.registerLazySingleton(() => ShareCardRenderer());
  sl.registerLazySingleton(() => ReelFramePainter());
  sl.registerLazySingleton<ReelRepository>(ReelRepositoryImpl.new);
  sl.registerLazySingleton(() => ComposeAyahReel(sl()));
  sl.registerLazySingleton(() => PrepareAyahAudio(playback: sl(), reels: sl()));
  sl.registerLazySingleton(() => SaveShareCard(sl()));
  sl.registerFactoryParam<AyahShareCubit, AyahIdentifier, MushafPaper>(
    (ayah, paper) => AyahShareCubit(
      ayah: ayah,
      paper: paper,
      getContent: sl(),
      renderer: sl(),
      getTafsir: sl(),
      prepareAudio: sl(),
      framePainter: sl(),
      composeReel: sl(),
      saveCard: sl(),
    ),
  );
}
