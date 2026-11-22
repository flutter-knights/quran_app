import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';

import '../../core/di/dependency_injection.dart';
import 'data/datasources/local/tafsir_local_data_source.dart';
import 'data/datasources/remote/tafsir_remote_data_source.dart';
import 'data/repositories/tafsir_repository_impl.dart';
import 'domain/repositories/tafsir_repository.dart';
import 'domain/usecases/get_ayah_tafsir.dart';

void initTafsir() {
  sl.registerLazySingleton<TafsirRemoteDataSource>(
    () => TafsirRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<TafsirLocalDataSource>(
    () => TafsirLocalDataSource(box: Hive.box<String>('tafsirCache')),
  );
  sl.registerLazySingleton<TafsirRepository>(
    () => TafsirRepositoryImpl(
      remote: sl<TafsirRemoteDataSource>(),
      local: sl<TafsirLocalDataSource>(),
    ),
  );
  sl.registerLazySingleton<GetAyahTafsir>(
    () => GetAyahTafsir(sl<TafsirRepository>()),
  );
}
