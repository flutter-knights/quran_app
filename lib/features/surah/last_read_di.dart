import 'package:hive_flutter/hive_flutter.dart';

import '../../core/di/dependency_injection.dart';
import 'data/datasources/last_read_local_data_source.dart';
import 'data/models/last_read_hive_model.dart';
import 'data/repositories/last_read_repository_impl.dart';
import 'domain/repositories/last_read_repository.dart';
import 'presentation/cubit/last_read/last_read_cubit.dart';

void initLastRead() {
  sl.registerLazySingleton<LastReadLocalDataSource>(
    () => LastReadLocalDataSource(box: Hive.box<LastReadHiveModel>('last_read')),
  );
  sl.registerLazySingleton<LastReadRepository>(
    () => LastReadRepositoryImpl(local: sl<LastReadLocalDataSource>()),
  );
  sl.registerLazySingleton<LastReadCubit>(
    () => LastReadCubit(repository: sl<LastReadRepository>()),
  );
}
