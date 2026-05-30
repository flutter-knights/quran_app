import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// The splash "working…" indicator — the classic three-dot bounce
/// ([SpinKitThreeBounce]), fading in after the wordmark settles.
class SplashLoader extends StatelessWidget {
  const SplashLoader({super.key, this.color, this.size = 28});

  /// Dot colour; defaults to white (the splash sits on the primary backdrop).
  final Color? color;

  /// Overall width of the three-dot animation.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SpinKitThreeBounce(
      color: color ?? Colors.white,
      size: size,
    ).animate().fadeIn(delay: 700.ms, duration: 600.ms);
  }
}
