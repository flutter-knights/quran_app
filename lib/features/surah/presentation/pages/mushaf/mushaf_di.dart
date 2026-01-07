import 'package:quran_app/core/di/dependency_injection.dart';

import '../../../data/datasources/mushaf_local_data_source.dart';
import '../../../data/repositories/mushaf_repo_impl.dart';
import '../../../domain/repositories/mushaf_repo.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';

void initMushaf() {
  sl.registerLazySingleton<MushafLocalDataSource>(
    () => MushafLocalDataSource(),
  );
  sl.registerLazySingleton<MushafRepository>(() => MushafRepositoryImpl(sl()));

  sl.registerLazySingleton(() => GetMushafPage(sl()));

  sl.registerFactory(() => MushafCubit(sl()));
}
