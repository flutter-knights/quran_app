import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

class QiblaCompassDial extends StatelessWidget {
  const QiblaCompassDial({
    super.key,
    required this.pointerAngle, // degrees; null => static (fallback)
    required this.size,
  });

  final double? pointerAngle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final angle = (pointerAngle ?? 0) * math.pi / 180.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dial face + ticks
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainer,
              border: context.cardBorder(),
            ),
            child: CustomPaint(
              painter: _DialPainter(
                tick: scheme.onSurface.withValues(alpha: 0.12),
                cardinal: scheme.onSurfaceVariant,
              ),
            ),
          ),
          // Cardinal letters
          _Letter('N', Alignment.topCenter, scheme.secondary),
          _Letter('E', Alignment.centerRight, scheme.onSurfaceVariant),
          _Letter('S', Alignment.bottomCenter, scheme.onSurfaceVariant),
          _Letter('W', Alignment.centerLeft, scheme.onSurfaceVariant),
          // Rotating needle
          AnimatedRotation(
            turns: angle / (2 * math.pi),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: _Needle(size: size, color: scheme.primary, accent: scheme.secondary),
          ),
          // Hub
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondary,
              border: Border.all(color: scheme.surface, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter(this.text, this.alignment, this.color);
  final String text;
  final Alignment alignment;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
        ),
      );
}

class _Needle extends StatelessWidget {
  const _Needle({required this.size, required this.color, required this.accent});
  final double size;
  final Color color;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: size * 0.08),
        // Kaaba marker
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: 2),
          ),
          child: const Icon(Icons.mosque, color: Color(0xFFC8A24A), size: 20),
        ),
        // Beam
        Container(
          width: 3, height: size * 0.25,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [accent, accent.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.tick, required this.cardinal});
  final Color tick;
  final Color cardinal;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 6;
    for (var deg = 0; deg < 360; deg += 6) {
      final isCardinal = deg % 90 == 0;
      final len = isCardinal ? 14.0 : (deg % 30 == 0 ? 10.0 : 6.0);
      final a = (deg - 90) * math.pi / 180.0;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * rOuter;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (rOuter - len);
      final paint = Paint()
        ..color = isCardinal ? cardinal : tick
        ..strokeWidth = isCardinal ? 2 : 1.5;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.tick != tick || old.cardinal != cardinal;
}
