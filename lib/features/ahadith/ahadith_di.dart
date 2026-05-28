import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/repositories/hadith_bookmark_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/download_ahadith_book_use_case.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_ahadith_page_use_case.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_hadith_bookmarks.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/toggle_hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';

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
  sl.registerLazySingleton<DownloadAhadithBookUseCase>(
    () => DownloadAhadithBookUseCase(ahadithRepository: sl()),
  );
  sl.registerFactory<AhadithCubit>(
    () => AhadithCubit(getAhadithPageUseCase: sl()),
  );
  sl.registerFactory<DownloadBookCubit>(
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

  // Next hadith navigation
  sl.registerLazySingleton<GetNextHadith>(() => GetNextHadith(sl()));
}

Future<Map<String, dynamic>> getChapters() async {
  final String response = await rootBundle.loadString(
    AssetsDir.jsonDir('all_chapters.json'),
  );
  final Map<String, dynamic> chaptersJson = json.decode(response);
  return chaptersJson;
}
