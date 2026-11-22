import 'package:hive_ce/hive.dart';

import '../../core/di/dependency_injection.dart';
import '../../core/errors/exceptions.dart';
import '../quran_playback/domain/services/quran_page_service.dart';
import '../surah/domain/usecases/get_mushaf_page.dart';
import 'data/datasources/local/place_migration.dart';
import 'data/datasources/local/places_local_data_source.dart';
import 'data/models/place_record_model.dart';
import 'data/repositories/places_repository_impl.dart';
import 'domain/repositories/places_repository.dart';
import 'domain/usecases/get_places.dart';
import 'domain/usecases/migrate_places.dart';
import 'domain/usecases/remove_place.dart';
import 'domain/usecases/save_place.dart';
import 'presentation/cubit/fasil_cubit.dart';
import 'presentation/cubit/saved_ayat_cubit.dart';

void initBookmarks() {
  sl.registerLazySingleton<PlacesLocalDataSource>(
    () => PlacesLocalDataSource(box: Hive.box<PlaceRecordModel>('places')),
  );
  sl.registerLazySingleton<PlaceMigration>(
    () => PlaceMigration(
      places: Hive.box<PlaceRecordModel>('places'),
      meta: Hive.box<bool>('places_meta'),
      ayahBookmarks: Hive.box<List>('ayah_bookmarks'),
      pageBookmarks: Hive.box<List>('page_bookmarks'),
      firstAyahOfPage: (page) async => (await sl<GetMushafPage>()(page)).fold(
        (_) => page >= 1 && page <= 604
            ? throw CacheException('mushaf page $page failed to load')
            : null,
        (e) => e.ayahs.where((b) => b.ayah.ayah > 0).firstOrNull?.ayah,
      ),
      pageOf: (ayah) =>
          sl<QuranPageService>().getPageForAyah(ayah.surah, ayah.ayah),
    ),
  );
  sl.registerLazySingleton<PlacesRepository>(
    () => PlacesRepositoryImpl(
      dataSource: sl<PlacesLocalDataSource>(),
      migration: sl<PlaceMigration>(),
    ),
  );
  sl.registerLazySingleton<GetPlaces>(() => GetPlaces(sl<PlacesRepository>()));
  sl.registerLazySingleton<SavePlace>(() => SavePlace(sl<PlacesRepository>()));
  sl.registerLazySingleton<RemovePlace>(
    () => RemovePlace(sl<PlacesRepository>()),
  );
  sl.registerLazySingleton<MigratePlaces>(
    () => MigratePlaces(sl<PlacesRepository>()),
  );
  sl.registerLazySingleton<FasilCubit>(
    () => FasilCubit(
      getPlaces: sl<GetPlaces>(),
      savePlace: sl<SavePlace>(),
      removePlace: sl<RemovePlace>(),
      pageService: sl<QuranPageService>(),
    ),
  );
  sl.registerLazySingleton<SavedAyatCubit>(
    () => SavedAyatCubit(
      getPlaces: sl<GetPlaces>(),
      savePlace: sl<SavePlace>(),
      removePlace: sl<RemovePlace>(),
      pageService: sl<QuranPageService>(),
    ),
  );
}
