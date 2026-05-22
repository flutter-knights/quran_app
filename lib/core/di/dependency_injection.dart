import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/ahadith/ahadith_di.dart';
import 'package:quran_app/features/bookmarks/bookmarks_di.dart';
import 'package:quran_app/features/home/home_di.dart';
import 'package:quran_app/features/notifications/notifications_di.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../features/quran_playback/playback_di.dart';
import '../../features/surah/presentation/pages/mushaf/mushaf_di.dart';
import '../../features/surah/last_read_di.dart';
import '../../features/surah/presentation/pages/surah_list/surah_list_di.dart';

final sl = GetIt.instance;

Future<void> initGetIt() async {
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerSingleton<SettingsCubit>(SettingsCubit());
  initHome();
  initNotifications();
  initSurahList();
  initMushaf();
  initAhadith();
  initPlayback();
  initBookmarks();
  initLastRead();
}
