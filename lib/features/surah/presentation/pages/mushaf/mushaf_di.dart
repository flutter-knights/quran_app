import '../../../../../core/di/dependency_injection.dart';
import '../../../../../features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../data/datasources/mushaf_local_data_source.dart';
import '../../../data/repositories/mushaf_repo_impl.dart';
import '../../../domain/repositories/mushaf_repo.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../utils/current_ayah_notifier.dart';

void initMushaf() {
  sl.registerLazySingleton<CurrentAyahNotifier>(
    () => CurrentAyahNotifier(playbackCubit: sl<PlaybackCubit>()),
  );
  sl.registerLazySingleton<MushafLocalDataSource>(
    () => MushafLocalDataSource(),
  );
  sl.registerLazySingleton<MushafRepository>(
    () => MushafRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton(() => GetMushafPage(sl()));
  sl.registerFactoryParam<MushafCubit, int, void>(
    (initialPage, _) => MushafCubit(
      initialPage: initialPage,
      currentAyahNotifier: sl<CurrentAyahNotifier>(),
    ),
  );
}
