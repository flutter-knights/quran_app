import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import 'data/datasources/local/quran_playback_local_data_source.dart';
import 'data/datasources/remote/quran_playback_remote_data_source.dart';
import 'data/repositories/quran_playback_repo_impl.dart';
import 'domain/repositories/quran_playback_repo.dart';
import 'domain/services/quran_meta_service.dart';
import 'domain/services/quran_page_service.dart';
import 'presentation/cubit/playback/playback_cubit.dart';

void initPlayback() async {
  final audioCacheBox = Hive.box<String>('ayahAudioCache');
  final dir = await getApplicationDocumentsDirectory();

  sl.registerLazySingleton<QuranPlaybackRemoteDataSource>(
    () => QuranPlaybackRemoteDataSource(dio: sl()),
  );

  sl.registerLazySingleton<QuranPlaybackLocalDataSource>(
    () => QuranPlaybackLocalDataSource(audioBox: audioCacheBox),
  );
  sl.registerLazySingleton<QuranPlaybackRepo>(
    () => QuranPlaybackRepoImpl(
      player: sl<AudioPlayer>(),
      remote: sl<QuranPlaybackRemoteDataSource>(),
      local: sl<QuranPlaybackLocalDataSource>(),
      dir: dir,
    ),
  );
  sl.registerLazySingleton<AyahSequenceService>(() => AyahSequenceService());
  sl.registerLazySingleton<QuranPageService>(() => QuranPageServiceImpl());
  sl.registerLazySingleton<QuranMetaService>(
    () => QuranMetaServiceImpl(pageService: sl<QuranPageService>()),
  );

  sl.registerLazySingleton<PlaybackCubit>(
    () => PlaybackCubit(
      ayahSequenceService: sl<AyahSequenceService>(),
      repository: sl<QuranPlaybackRepo>(),
      pageService: sl<QuranPageService>(),
      settingsCubit: sl<SettingsCubit>(),
    ),
  );
}
