import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import 'data/datasources/local/quran_playback_local_data_source.dart';
import 'data/datasources/remote/quran_playback_remote_data_source.dart';
import 'data/repositories/quran_playback_repo_impl.dart';
import 'domain/repositories/quran_playback_repo.dart';
import 'domain/services/quran_meta_service.dart';
import 'domain/services/quran_page_service.dart';
import 'presentation/audio/media_art.dart';
import 'presentation/audio/playback_audio_focus.dart';
import 'presentation/audio/quran_audio_handler.dart';
import 'presentation/cubit/playback/playback_cubit.dart';
import 'presentation/cubit/surah_download/surah_download_cubit.dart';

Future<void> initPlayback() async {
  final audioCacheBox = Hive.box<String>('ayahAudioCache');
  final downloadsBox = Hive.box<bool>('surahDownloads');
  final dir = await getApplicationDocumentsDirectory();

  sl.registerLazySingleton<QuranPlaybackRemoteDataSource>(
    () => QuranPlaybackRemoteDataSource(dio: sl()),
  );

  sl.registerLazySingleton<QuranPlaybackLocalDataSource>(
    () => QuranPlaybackLocalDataSource(
      audioBox: audioCacheBox,
      downloadsBox: downloadsBox,
    ),
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

  sl.registerLazySingleton(() => SurahDownloadCubit(repository: sl()));

  final focus = await connectAudioFocus(
    session: () => AudioSession.instance,
    cubit: sl<PlaybackCubit>(),
  );
  if (focus != null) sl.registerSingleton(focus);

  String langCode() =>
      sl<SettingsCubit>().state.settingsModel.isArabic ? 'ar' : 'en';
  final artUri = Platform.isAndroid ? await mediaArtUri(dir: dir) : null;
  await connectMediaSession(
    init: () => AudioService.init(
      builder: () => QuranAudioHandler(
        player: sl<AudioPlayer>(),
        langCode: langCode,
        artUri: artUri,
      ),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.example.quran_app.playback',
        androidNotificationChannelName: PendingS.forLanguage(
          langCode(),
        ).playback_channelName,
        androidNotificationIcon: 'drawable/ic_stat_alfurqan',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ),
    cubit: sl<PlaybackCubit>(),
  );
}
