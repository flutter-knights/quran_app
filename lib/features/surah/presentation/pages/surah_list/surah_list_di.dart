import 'package:quran_app/core/di/dependency_injection.dart';

import '../../../data/datasources/surah_local_data_source.dart';
import '../../../data/repositories/surah_repo_impl.dart';
import '../../../domain/repositories/surah_repo.dart';
import '../../../domain/usecases/get_surah_list.dart';
import '../../cubit/surah/surah_cubit.dart';

void initSurahList() {
  sl.registerLazySingleton<SurahLocalDataSource>(
    () => SurahLocalDataSourceImpl(),
  );

  sl.registerLazySingleton<SurahRepository>(() => SurahRepositoryImpl(sl()));

  sl.registerLazySingleton(() => GetSurahList(sl()));

  sl.registerFactory(() => SurahCubit(sl()));
}
