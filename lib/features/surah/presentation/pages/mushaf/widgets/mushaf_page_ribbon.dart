import 'package:flutter/material.dart';

/// A silk bookmark ribbon hanging from the top-trailing corner of a saved
/// page. Must be a child of a [Stack]. Tapping it removes the page bookmark.
class MushafPageRibbon extends StatelessWidget {
  const MushafPageRibbon({super.key, required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 0,
      end: 18,
      child: GestureDetector(
        key: const ValueKey('mushaf-page-ribbon'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          size: const Size(18, 46),
          painter: _RibbonPainter(color),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 10) // forked notch
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}
