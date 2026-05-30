import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Shared brand backdrop used by the splash and the first-run landing page:
/// the live theme primary colour, lifted by a soft white glow from the top and
/// a dark vignette at the bottom, over a faint ±60° diagonal geometric grid.
/// Mirrors the HTML redesign's `.sc-splash` treatment.
///
/// Reusing one backdrop across both screens is what makes the splash appear to
/// "animate into" the landing — the backdrop is identical, so only the
/// foreground content transitions.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key, this.child});

  /// Optional foreground laid over the backdrop (fills the available space).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: primary)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.1,
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1.1),
                radius: 0.9,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _SplashGridPainter())),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// Two families of faint parallel lines at ±60°, echoing the mockup's
/// repeating-linear-gradient grid.
class _SplashGridPainter extends CustomPainter {
  static const double _spacing = 36;
  static const double _angle = 60 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    final diagonal = math.sqrt(
      size.width * size.width + size.height * size.height,
    );

    for (final angle in [_angle, -_angle]) {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(angle);
      for (double x = -diagonal; x <= diagonal; x += _spacing) {
        canvas.drawLine(Offset(x, -diagonal), Offset(x, diagonal), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SplashGridPainter oldDelegate) => false;
}
