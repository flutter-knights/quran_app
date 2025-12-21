import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/data/datasources/location_remote_data_source.dart';
import 'package:quran_app/features/home/data/repositories/location_repository_impl.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/usecases/get_current_location.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';

void initHome() {
  // Cubit
  sl.registerFactory(
    () => DailyPrayerContextCubit(getDailyPrayerContext: sl()),
  );

  // UseCases
  sl.registerLazySingleton(
    () => GetCurrentLocationUseCase(locationRepository: sl()),
  );

  // Repositories
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton(() => LocationRemoteDataSource(dio: sl()));
}
