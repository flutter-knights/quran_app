import 'package:hive_ce/hive.dart';

import '../../core/di/dependency_injection.dart';
import 'data/datasources/local/tafsir_local_data_source.dart';
import 'data/datasources/remote/tafsir_remote_data_source.dart';
import 'data/repositories/tafsir_repository_impl.dart';
import 'domain/repositories/tafsir_repository.dart';
import 'domain/usecases/get_ayah_tafsir.dart';
import 'presentation/cubit/tafsir_cubit.dart';

void initTafsir() {
  sl.registerLazySingleton<TafsirRemoteDataSource>(
    () => TafsirRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton(
    () => TafsirLocalDataSource(box: Hive.box<String>('tafsirCache')),
  );
  sl.registerLazySingleton<TafsirRepository>(
    () => TafsirRepositoryImpl(remote: sl(), local: sl()),
  );
  sl.registerLazySingleton(() => GetAyahTafsir(sl()));
  sl.registerFactory(() => TafsirCubit(getAyahTafsir: sl(), pageService: sl()));
}
