import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:quran_app/features/ahadith/presentation/pages/books_list_page.dart';
import 'package:quran_app/features/home/presentation/pages/home_page.dart';
import 'package:quran_app/features/splash/pages/splash_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_pages.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/surah_list_page.dart';

import '../../core/di/dependency_injection.dart';

abstract class AppRouter {
  static const String homePath = "/home";
  static const String splashPath = "/splash";
  static const String mushafPath = "/mushaf";
  static const String surahListPath = "/surahList";
  static const String booksPath = "/books";

  static final router = GoRouter(
    initialLocation: splashPath,
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

            return MushafPage(pageNumber: pageNo);
          },
        ),
      ),
    ],
  );
}
