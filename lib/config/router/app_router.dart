import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/pages/ahadith_list_page.dart';
import 'package:quran_app/features/ahadith/presentation/pages/books_list_page.dart';
import 'package:quran_app/features/ahadith/presentation/pages/hadith_page.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/bookmarks_page.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/presentation/pages/qibla_page.dart';
import 'package:quran_app/features/home/presentation/pages/home_page.dart';
import 'package:quran_app/features/home/presentation/pages/notifications_settings_page.dart';
import 'package:quran_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:quran_app/features/settings/presentation/pages/settings_page.dart';
import 'package:quran_app/features/splash/pages/splash_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/surah_list_page.dart';

import '../../core/di/dependency_injection.dart';

abstract class AppRouter {
  static const String homePath = "/home";
  static const String notificationsPath = "/notifications";
  static const String splashPath = "/splash";
  static const String onboardingPath = "/onboarding";
  static const String mushafPath = "/mushaf";
  static const String mushafImagePath = "/mushafImage";
  static const String surahListPath = "/surahList";
  static const String booksPath = "/books";
  static const String ahadithPath = "/ahadith";
  static const String hadithPath = "/hadith";
  static const String settingsPath = "/settings";
  static const String bookmarksPath = "/bookmarks";
  static const String qiblaPath = "/qibla";

  /// Builds the router once with a startup-computed [initialLocation] (see
  /// `QuranApp`): splash on first run / when the splash is enabled, otherwise
  /// straight to home.
  static GoRouter createRouter({required String initialLocation}) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: homePath,
        // Home is only ever entered via the splash's pushReplacement, so this
        // slide-up + fade is effectively the splash→home hand-off animation:
        // home rises into place as the splash content lifts away.
        pageBuilder: GoTransitions.slide.toTop.withFade
            .withStyle(curve: Curves.easeOutCubic)
            .build(
              settings: const GoTransitionSettings(
                duration: Duration(milliseconds: 500),
              ),
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
        path: onboardingPath,
        // Reached only via the splash on first run. A plain fade reads as the
        // splash "animating into" the wizard because both share the identical
        // SplashBackdrop — only the foreground content changes.
        pageBuilder: GoTransitions.fade
            .withStyle(curve: Curves.easeInOut)
            .build(
              settings: const GoTransitionSettings(
                duration: Duration(milliseconds: 450),
              ),
              builder: (context, state) => const OnboardingPage(),
            ),
      ),
      GoRoute(
        path: notificationsPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => const NotificationsSettingsPage(),
        ),
      ),
      GoRoute(
        path: settingsPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => const SettingsPage(),
        ),
      ),
      GoRoute(
        path: booksPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => BooksListPage(),
        ),
      ),
      GoRoute(
        path: bookmarksPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => const BookmarksPage(),
        ),
      ),
      GoRoute(
        path: qiblaPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => BlocProvider(
            create: (_) => sl<QiblaCubit>()..start(),
            child: const QiblaPage(),
          ),
        ),
      ),
      GoRoute(
        path: surahListPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => sl<SurahCubit>()..fetchSurahs()),
              BlocProvider(create: (_) => sl<LastReadCubit>()),
            ],
            child: SurahListPage(),
          ),
        ),
      ),
      GoRoute(
        path: mushafPath,
        pageBuilder: GoTransitions.fade.withScale.build(
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
        pageBuilder: GoTransitions.fade.withScale.build(
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
            final extra = state.extra as ({Hadith hadith, String bookSlug});
            return HadithPage(hadith: extra.hadith, bookSlug: extra.bookSlug);
          },
        ),
      ),
    ],
  );
}
