import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:quran_app/features/home/presentation/pages/home_page.dart';
import 'package:quran_app/features/splash/pages/splash_page.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_pages.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/surah_list_page.dart';

abstract class AppRouter {
  static const String homePath = "/home";
  static const String splashPath = "/splash";
  static const String mushafPath = "/mushaf";
  static const String surahListPath = "/surahList";

  static final router = GoRouter(
    initialLocation: surahListPath,
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
        path: surahListPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => SurahListPage(),
        ),
      ),
      GoRoute(
        path: mushafPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => MushafPage(),
        ),
      ),
    ],
  );
}
