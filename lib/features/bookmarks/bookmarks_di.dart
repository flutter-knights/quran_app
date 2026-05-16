import 'package:hive/hive.dart';

import '../../core/di/dependency_injection.dart';
import 'data/datasources/local/bookmark_local_data_source.dart';
import 'data/repositories/bookmark_repository_impl.dart';
import 'domain/repositories/bookmark_repository.dart';
import 'domain/usecases/get_bookmarks.dart';
import 'domain/usecases/toggle_bookmark.dart';
import 'presentation/cubit/bookmark_cubit.dart';

void initBookmarks() {
  sl.registerLazySingleton<BookmarkLocalDataSource>(
    () => BookmarkLocalDataSource(box: Hive.box<List>('ayah_bookmarks')),
  );
  sl.registerLazySingleton<BookmarkRepository>(
    () => BookmarkRepositoryImpl(dataSource: sl<BookmarkLocalDataSource>()),
  );
  sl.registerLazySingleton<GetBookmarks>(
    () => GetBookmarks(sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton<ToggleBookmark>(
    () => ToggleBookmark(sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton<BookmarkCubit>(
    () => BookmarkCubit(
      getBookmarks: sl<GetBookmarks>(),
      toggleBookmark: sl<ToggleBookmark>(),
    ),
  );
}
