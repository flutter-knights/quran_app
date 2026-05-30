import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Qibla compass: a fixed dial (ticks + N/E/S/W) with a Kaaba needle that
/// rotates to point at the Qibla. With a live heading the needle angle is the
/// Qibla bearing relative to the phone's top (`bearing - trueHeading`), so it
/// swings as you turn and points straight up when you face the Kaaba. Without a
/// magnetometer ([trueHeading] null) it sits at the bearing clockwise from North.
/// Rotation always takes the shortest arc (no 359->0 long spin).
class QiblaCompassDial extends StatefulWidget {
  const QiblaCompassDial({
    super.key,
    required this.bearing,
    required this.trueHeading,
    required this.size,
  });

  final double bearing;
  final double? trueHeading;
  final double size;

  @override
  State<QiblaCompassDial> createState() => _QiblaCompassDialState();
}

class _QiblaCompassDialState extends State<QiblaCompassDial> {
  late double _needleTurns;

  @override
  void initState() {
    super.initState();
    _needleTurns = _needleTargetDeg() / 360.0;
  }

  @override
  void didUpdateWidget(QiblaCompassDial old) {
    super.didUpdateWidget(old);
    _needleTurns = _shortest(_needleTurns, _needleTargetDeg() / 360.0);
  }

  double _needleTargetDeg() {
    final heading = widget.trueHeading;
    // No heading => show the bearing clockwise from the (fixed) North mark.
    if (heading == null) return widget.bearing;
    // Live heading => point at the Qibla relative to the phone's top.
    return widget.bearing - heading;
  }

  /// Continuous turns value near [prev] whose fractional part equals
  /// [targetTurns]'s, taking the shortest direction.
  static double _shortest(double prev, double targetTurns) {
    var delta = (targetTurns - prev) % 1.0; // [0,1)
    if (delta > 0.5) delta -= 1.0;
    return prev + delta;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fixed dial face + ticks.
          Container(
            width: widget.size,
            height: widget.size,
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
          // Fixed cardinal letters (N tinted as the top reference).
          _Letter('N', Alignment.topCenter, scheme.secondary),
          _Letter('E', Alignment.centerRight, scheme.onSurfaceVariant),
          _Letter('S', Alignment.bottomCenter, scheme.onSurfaceVariant),
          _Letter('W', Alignment.centerLeft, scheme.onSurfaceVariant),
          // Rotating Kaaba needle.
          AnimatedRotation(
            turns: _needleTurns,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: _Needle(
                size: widget.size,
                color: scheme.primary,
                accent: scheme.secondary),
          ),
          // Center hub.
          Container(
            width: 16,
            height: 16,
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
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 14)),
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
        SizedBox(height: size * 0.06),
        // Kaaba marker at the needle tip.
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent, width: 2),
          ),
          alignment: Alignment.center,
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedKaaba01,
            color: Color(0xFFC8A24A),
            size: 26,
          ),
        ),
        // Beam from the hub up to the marker.
        Container(
          width: 3,
          height: size * 0.26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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
