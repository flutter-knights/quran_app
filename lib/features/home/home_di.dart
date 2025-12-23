import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/data/datasources/remote/location_remote_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/data/repositories/location_repository_impl.dart';
import 'package:quran_app/features/home/data/repositories/prayer_times_repository_impl.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';

void initHome() {
  // Data sources
  sl.registerLazySingleton(() => LocationRemoteDataSource(dio: sl()));
  sl.registerLazySingleton(() => PrayerTimeRemoteDataSource(dio: sl()));

  // Repositories
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<PrayerTimesRepository>(
    () => PrayerTimesRepositoryImpl(prayerTimeRemoteDataSource: sl()),
  );

  // UseCases
  sl.registerLazySingleton(
    () => GetDailyPrayerContext(
      prayerTimesRepository: sl(),
      locationRepository: sl(),
    ),
  );

  // Cubit
  sl.registerFactory(
    () => DailyPrayerContextCubit(getDailyPrayerContext: sl()),
  );
  sl.registerFactory(() => PrayerCountdownCubit());
}
