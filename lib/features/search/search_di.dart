import 'package:quran_app/core/di/dependency_injection.dart';

import 'data/quran_browse_service_impl.dart';
import 'data/quran_search_index_impl.dart';
import 'domain/repositories/quran_search_index.dart';
import 'domain/services/quran_browse_service.dart';
import 'domain/usecases/search_quran.dart';
import 'presentation/cubit/search_cubit.dart';

void initSearch() {
  sl.registerLazySingleton<QuranSearchIndex>(
    () => QuranSearchIndexImpl.build(),
  );
  sl.registerLazySingleton<QuranBrowseService>(
    () => QuranBrowseServiceImpl(),
  );
  sl.registerLazySingleton(() => SearchQuran(sl(), sl()));
  sl.registerFactory(() => SearchCubit(sl()));
}
