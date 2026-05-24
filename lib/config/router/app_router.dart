import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/pages/ahadith_list_page.dart';
import 'package:quran_app/features/ahadith/presentation/pages/books_list_page.dart';
import 'package:quran_app/features/ahadith/presentation/pages/hadith_page.dart';
import 'package:quran_app/features/home/presentation/pages/home_page.dart';
import 'package:quran_app/features/home/presentation/pages/notifications_settings_page.dart';
import 'package:quran_app/features/splash/pages/splash_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/surah_list_page.dart';

import '../../core/di/dependency_injection.dart';

abstract class AppRouter {
  static const String homePath = "/home";
  static const String notificationsPath = "/notifications";
  static const String splashPath = "/splash";
  static const String mushafPath = "/mushaf";
  static const String mushafImagePath = "/mushafImage";
  static const String surahListPath = "/surahList";
  static const String booksPath = "/books";
  static const String ahadithPath = "/ahadith";
  static const String hadithPath = "/hadith";
  static const String settingsPath = "/settings";

  static final router = GoRouter(
    initialLocation: homePath,
    routes: [
      GoRoute(
        path: homePath,
        pageBuilder: GoTransitions.slide.toTop.build(
          builder: (context, state) => HomePage(),
        ),
      ),
      GoRoute(
        path: splashPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => SplashPage(),
        ),
      ),
      GoRoute(
        path: notificationsPath,
        pageBuilder: GoTransitions.fade.withFade.build(
          builder: (context, state) => const NotificationsSettingsPage(),
        ),
      ),
      GoRoute(
        path: booksPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => BooksListPage(),
        ),
      ),
      GoRoute(
        path: surahListPath,
        pageBuilder: GoTransitions.fade.withFade.build(
          builder: (context, state) => BlocProvider(
            create: (_) => sl<SurahCubit>()..fetchSurahs(),
            child: SurahListPage(),
          ),
        ),
      ),
      GoRoute(
        path: mushafPath,
        pageBuilder: GoTransitions.fade.withFade.build(
          builder: (context, state) {
            final int pageNo = (state.extra as int?) ?? 1;
            return BlocProvider(
              create: (_) => sl<MushafCubit>(param1: pageNo),
              child: MushafPage(initialPage: pageNo),
            );
          },
        ),
      ),
      GoRoute(
        path: mushafImagePath,
        pageBuilder: GoTransitions.fade.withFade.build(
          builder: (context, state) {
            final int pageNo = (state.extra as int?) ?? 1;
            return BlocProvider(
              create: (_) => sl<MushafCubit>(param1: pageNo),
              child: MushafPage(initialPage: pageNo),
            );
          },
        ),
      ),
      GoRoute(
        path: ahadithPath,

        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) {
            final bookSlug = state.extra as String;

            return AhadithListPage(bookSlug: bookSlug);
          },
        ),
      ),
      GoRoute(
        path: hadithPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) {
            final hadith = state.extra as Hadith;
            return HadithPage(hadith: hadith);
          },
        ),
      ),
    ],
  );
}
