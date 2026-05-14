import 'package:quran_app/core/di/dependency_injection.dart';

import '../../../../../features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../data/datasources/mushaf_local_data_source.dart';
import '../../../data/datasources/mushaf_page_cache.dart';
import '../../../data/datasources/mushaf_spans_cache.dart';
import '../../../data/repositories/mushaf_repo_impl.dart';
import '../../../domain/repositories/mushaf_repo.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../utils/current_ayah_notifier.dart';

void initMushaf() {
  sl.registerLazySingleton<MushafLocalDataSource>(
    () => const MushafLocalDataSource(),
  );

  sl.registerLazySingleton<MushafPageCache>(
    () => MushafPageCache(capacity: 30),
  );
  sl.registerLazySingleton<MushafSpansCache>(
    () => MushafSpansCache(capacity: 30, pageCache: sl()),
  );

  sl.registerLazySingleton<MushafRepository>(
    () => MushafRepositoryImpl(pageCache: sl()),
  );

  sl.registerLazySingleton(() => GetMushafPage(sl()));

  sl.registerLazySingleton<CurrentAyahNotifier>(
    () => CurrentAyahNotifier(playbackCubit: sl<PlaybackCubit>()),
  );

  sl.registerFactory(
    () => MushafCubit(useCase: sl(), pageCache: sl(), spansCache: sl()),
  );
}
