import 'package:hive/hive.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_ahadith_page_use_case.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';

void initAhadith() async {
  final hadithBox = Hive.box<HadithHiveModel>('ahadithCache');
  sl.registerLazySingleton<AhadithRemoteDataSource>(
    () => AhadithRemoteDataSource(dio: sl()),
  );

  sl.registerLazySingleton<AhadithLocalDataSource>(
    () => AhadithLocalDataSource(hadithBox: hadithBox),
  );

  sl.registerLazySingleton<AhadithRepository>(
    () => AhadithRepositoryImpl(
      ahadithLocalDataSource: sl(),
      ahadithRemoteDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<GetAhadithPageUseCase>(
    () => GetAhadithPageUseCase(ahadithRepository: sl()),
  );
  sl.registerFactory<AhadithCubit>(
    () => AhadithCubit(getAhadithPageUseCase: sl()),
  );
}
