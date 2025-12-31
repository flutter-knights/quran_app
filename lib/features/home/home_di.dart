import 'package:hive/hive.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/data/datasources/local/location_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/location_remote_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/data/models/location_hive_model.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
import 'package:quran_app/features/home/data/repositories/location_repository_impl.dart';
import 'package:quran_app/features/home/data/repositories/prayer_times_repository_impl.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';

void initHome() {
  final prayerTimesBox = Hive.box<PrayerTimesHiveModel>('prayerTimesCache');
  final locationHiveBox = Hive.box<LocationHiveModel>('userLocationCache');

  // Data sources
  sl.registerLazySingleton(
    () => PrayerTimesLocalDataSource(prayerTimesBox: prayerTimesBox),
  );
  sl.registerLazySingleton(
    () => LocationLocalDataSource(locationHiveBox: locationHiveBox),
  );
  sl.registerLazySingleton(() => LocationRemoteDataSource(dio: sl()));
  sl.registerLazySingleton(() => PrayerTimeRemoteDataSource(dio: sl()));

  // Repositories
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(
      prayerTimesLocalDataSource: sl(),
      locationLocalDataSource: sl(),
      locationRemoteDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<PrayerTimesRepository>(
    () => PrayerTimesRepositoryImpl(
      prayerTimeRemoteDataSource: sl(),
      prayerTimesLocalDataSource: sl(),
    ),
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
}
