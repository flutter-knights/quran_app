import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/usecases/get_current_location.dart';
import 'package:quran_app/features/qibla/data/datasources/compass_data_source.dart';
import 'package:quran_app/features/qibla/data/repositories/compass_repository_impl.dart';
import 'package:quran_app/features/qibla/domain/repositories/compass_repository.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/watch_compass_heading.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';

void initQibla() {
  // Data sources
  sl.registerLazySingleton(() => CompassDataSource());

  // Repositories
  sl.registerLazySingleton<CompassRepository>(
    () => CompassRepositoryImpl(dataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(
    () => GetCurrentLocationUseCase(locationRepository: sl<LocationRepository>()),
  );
  sl.registerLazySingleton(() => GetQiblaDirection());
  sl.registerLazySingleton(() => GetMagneticDeclination());
  sl.registerLazySingleton(() => WatchCompassHeading(repository: sl()));

  // Cubit
  sl.registerFactory(
    () => QiblaCubit(
      getCurrentLocation: sl(),
      getQiblaDirection: sl(),
      getMagneticDeclination: sl(),
      watchCompassHeading: sl(),
    ),
  );
}
