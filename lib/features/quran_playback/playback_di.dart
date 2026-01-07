import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/core/di/dependency_injection.dart';

import 'data/datasources/local/quran_playback_local_data_source.dart';
import 'data/datasources/remote/quran_playback_remote_data_source.dart';
import 'data/repositories/quran_playback_repo_impl.dart';
import 'domain/repositories/quran_playback_repo.dart';
import 'presentation/cubit/playback/playback_cubit.dart';

void initPlayback() {
  final audioCacheBox = Hive.box<String>('ayahAudioCache');
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
    ),
  );
  sl.registerFactory<PlaybackCubit>(
    () => PlaybackCubit(sl<QuranPlaybackRepo>()),
  );
}
