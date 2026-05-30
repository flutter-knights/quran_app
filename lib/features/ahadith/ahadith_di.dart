import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/daily_hadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_search_repository_impl.dart';
import 'package:quran_app/features/ahadith/data/repositories/daily_hadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';
import 'package:quran_app/features/ahadith/domain/repositories/daily_hadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/repositories/hadith_bookmark_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/download_ahadith_book_use_case.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_ahadith_page_use_case.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_book_chapters.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_book_statuses.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_filtered_ahadith_page_use_case.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_hadith_by_number.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_daily_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_hadith_bookmarks.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_previous_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/toggle_hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/daily_hadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/search_hadith_cubit.dart';

void initAhadith() async {
  final hadithBox = Hive.box<HadithHiveModel>('ahadithCache');
  final Map<String, dynamic> chaptersJson = await getChapters();
  sl.registerSingleton<Map<String, dynamic>>(
    chaptersJson,
    instanceName: 'chapters',
  );
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
      allChapters: sl(instanceName: 'chapters'),
    ),
  );

  sl.registerLazySingleton<GetAhadithPageUseCase>(
    () => GetAhadithPageUseCase(ahadithRepository: sl()),
  );
  sl.registerLazySingleton<GetBookChapters>(() => GetBookChapters(sl()));
  sl.registerLazySingleton<GetBookStatuses>(() => GetBookStatuses(sl()));
  sl.registerLazySingleton<GetFilteredAhadithPageUseCase>(
    () => GetFilteredAhadithPageUseCase(ahadithRepository: sl()),
  );
  sl.registerLazySingleton<DownloadAhadithBookUseCase>(
    () => DownloadAhadithBookUseCase(ahadithRepository: sl()),
  );
  sl.registerFactory<AhadithCubit>(
    () => AhadithCubit(
      getAhadithPageUseCase: sl(),
      getFilteredAhadithPageUseCase: sl(),
      getBookChapters: sl(),
      getBookStatuses: sl(),
    ),
  );
  // App-level: shared so download progress survives navigation and every
  // consumer (books page, search) sees the same live state.
  sl.registerLazySingleton<DownloadBookCubit>(
    () => DownloadBookCubit(downloadAhadithBookUseCase: sl()),
  );

  // Hadith bookmarks
  sl.registerLazySingleton<HadithBookmarkLocalDataSource>(
    () => HadithBookmarkLocalDataSource(
      box: Hive.box<List>('hadith_bookmarks'),
    ),
  );
  sl.registerLazySingleton<HadithBookmarkRepository>(
    () => HadithBookmarkRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton<GetHadithBookmarks>(() => GetHadithBookmarks(sl()));
  sl.registerLazySingleton<ToggleHadithBookmark>(
    () => ToggleHadithBookmark(sl()),
  );
  sl.registerLazySingleton<HadithBookmarkCubit>(
    () => HadithBookmarkCubit(
      getBookmarks: sl(),
      toggleBookmark: sl(),
    ),
  );

  // Hadith page navigation (previous / next)
  sl.registerLazySingleton<GetNextHadith>(() => GetNextHadith(sl()));
  sl.registerLazySingleton<GetPreviousHadith>(() => GetPreviousHadith(sl()));
  sl.registerLazySingleton<GetHadithByNumber>(() => GetHadithByNumber(sl()));

  // Hadith of the day
  sl.registerLazySingleton<DailyHadithLocalDataSource>(
    () => DailyHadithLocalDataSource(
      box: Hive.box<HadithHiveModel>('daily_hadith'),
    ),
  );
  sl.registerLazySingleton<DailyHadithRepository>(
    () => DailyHadithRepositoryImpl(
      remote: sl(),
      local: sl(),
      ahadithRepository: sl(),
    ),
  );
  sl.registerLazySingleton<GetDailyHadith>(() => GetDailyHadith(sl()));
  sl.registerFactory<DailyHadithCubit>(
    () => DailyHadithCubit(getDailyHadith: sl()),
  );
}

void initAhadithSearch() {
  sl.registerLazySingleton<AhadithArabicSearchLocalDataSource>(
    () => AhadithArabicSearchLocalDataSource(),
  );
  sl.registerLazySingleton<AhadithSearchRepository>(
    () => AhadithSearchRepositoryImpl(
      ahadithLocalDataSource: sl(),
      ahadithRemoteDataSource: sl(),
      arabicSearchDataSource: sl(),
    ),
  );
  sl.registerFactory<SearchHadithCubit>(
    () => SearchHadithCubit(
      ahadithSearchRepository: sl(),
      downloadBookCubit: sl(),
    ),
  );
}

Future<Map<String, dynamic>> getChapters() async {
  final String response = await rootBundle.loadString(
    AssetsDir.jsonDir('all_chapters.json'),
  );
  final Map<String, dynamic> chaptersJson = json.decode(response);
  return chaptersJson;
}
