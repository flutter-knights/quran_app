import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';

const String homePath = "/home";

final appRouter = GoRouter(
  initialLocation: homePath,
  routes: [
    GoRoute(
      path: homePath,
      pageBuilder: GoTransitions.slide.toTop.withScale.build(
        builder: (context, state) => Placeholder(),
      ),
    ),
  ],
);
