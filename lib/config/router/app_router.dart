import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:quran_app/features/splash/pages/splash_page.dart';

const String homePath = "/home";
const String splashPath = "/splash";

final appRouter = GoRouter(
  initialLocation: splashPath,
  routes: [
    GoRoute(
      path: homePath,
      pageBuilder: GoTransitions.slide.toTop.withScale.build(
        builder: (context, state) => Placeholder(),
      ),
    ),
    GoRoute(
      path: splashPath,
      pageBuilder: GoTransitions.fade.withScale.build(
        builder: (context, state) => SplashPage(),
      ),
    ),
  ],
);
