import '../../core/di/dependency_injection.dart';
import '../quran_playback/domain/entities/ayah_identifier.dart';
import '../settings/presentation/cubit/settings_cubit.dart';
import 'domain/usecases/get_share_card_content.dart';
import 'presentation/cubit/ayah_share_cubit.dart';
import 'presentation/utils/share_card_renderer.dart';

void initAyahShare() {
  sl.registerLazySingleton(
    () => GetShareCardContent(getMushafPage: sl(), pageService: sl()),
  );
  sl.registerLazySingleton(() => ShareCardRenderer());
  sl.registerFactoryParam<AyahShareCubit, AyahIdentifier, void>(
    (ayah, _) => AyahShareCubit(
      ayah: ayah,
      paper: sl<SettingsCubit>().state.settingsModel.mushafPaper,
      getContent: sl(),
      renderer: sl(),
      getTafsir: sl(),
    ),
  );
}
