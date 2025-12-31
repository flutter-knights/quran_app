import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:quran_app/features/ahadith/presentation/pages/books_list_page.dart';
import 'package:quran_app/features/home/presentation/pages/home_page.dart';
import 'package:quran_app/features/splash/pages/splash_page.dart';

abstract class AppRouter {
  static const String homePath = "/home";
  static const String splashPath = "/splash";
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
    ],
  );
}
