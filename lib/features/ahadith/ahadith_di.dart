import 'package:hive/hive.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';

void initAhadith() async {
  final hadithBox = Hive.box<HadithHiveModel>('ahadithCache');
  sl.registerLazySingleton<AhadithRemoteDataSource>(
    () => AhadithRemoteDataSource(dio: sl()),
  );

  sl.registerLazySingleton<AhadithLocalDataSource>(
    () => AhadithLocalDataSource(hadithBox: hadithBox),
  );
}
