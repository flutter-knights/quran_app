import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class FadePage extends CustomTransitionPage<void> {
  const FadePage({super.key, required super.child})
    : super(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: _fade,
      );

  static Widget _fade(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
    child: child,
  );
}
