import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/features/home/home_di.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../features/surah/presentation/pages/surah_list_di.dart';

final sl = GetIt.instance;

Future<void> initGetIt() async {
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerSingleton<SettingsCubit>(SettingsCubit());
  initHome();
  initSurahList();
}
