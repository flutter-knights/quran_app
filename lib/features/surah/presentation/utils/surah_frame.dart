import 'dart:math' as math;
import 'dart:ui';

const double _unitHeight = 101;
const double _cartouche = 390;
const double _panel = 204.7;
const double _innerStroke = 4.5 / (150 / _unitHeight);
const double _outerStroke = 5.5 / (150 / _unitHeight);
const double _midY = 50.5;

double _units(Size size) => size.width / (size.height / _unitHeight);

bool surahFrameIsNarrow(Size size) =>
    (_units(size) - _cartouche) / 2 - _panel < -2;

void paintSurahFrame(Canvas canvas, Rect rect, Color color) {
  final k = rect.height / _unitHeight;
  final w = _units(rect.size);
  final narrow = surahFrameIsNarrow(rect.size);
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _innerStroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()..color = color;

  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(k);
  canvas.drawRRect(
    RRect.fromLTRBR(1.9, 1.9, w - 1.9, 99.1, const Radius.circular(6)),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outerStroke,
  );
  canvas.drawRRect(
    RRect.fromLTRBR(9, 9, w - 9, 92, const Radius.circular(3)),
    stroke,
  );
  _side(canvas, w, narrow, stroke, fill);
  canvas.translate(w, 0);
  canvas.scale(-1, 1);
  _side(canvas, w, narrow, stroke, fill);
  canvas.restore();
}

void _side(Canvas canvas, double w, bool narrow, Paint stroke, Paint fill) {
  final xb = (w - _cartouche) / 2;
  final rc = narrow ? 66.0 : 167.7;

  canvas.drawPath(
    Path()
      ..moveTo(9, 24)
      ..lineTo(16, _midY)
      ..lineTo(9, 77),
    stroke,
  );
  canvas.drawPath(
    Path()
      ..moveTo(rc - 13, 18)
      ..lineTo(19, 18)
      ..lineTo(19, 83)
      ..lineTo(rc - 13, 83),
    stroke,
  );

  if (narrow) {
    for (final dot in const [Offset(27, 28), Offset(27, 73)]) {
      canvas.drawCircle(dot, 1.8, fill);
    }
  } else {
    canvas.drawCircle(const Offset(62, _midY), 19, stroke);
    canvas.drawCircle(const Offset(62, _midY), 11.5, stroke);
    canvas.drawCircle(const Offset(62, _midY), 2.4, fill);
    canvas.drawPath(
      Path()
        ..moveTo(19, 28)
        ..quadraticBezierTo(36, 28, 48.6, 37.1)
        ..moveTo(19, 73)
        ..quadraticBezierTo(36, 73, 48.6, 63.9)
        ..moveTo(77.6, 39.6)
        ..quadraticBezierTo(108, 14, 139, 30.4)
        ..moveTo(77.6, 61.4)
        ..quadraticBezierTo(108, 87, 139, 70.6),
      stroke,
    );
    for (final dot in const [
      Offset(30, _midY),
      Offset(108, 41.5),
      Offset(108, _midY),
      Offset(108, 59.5),
    ]) {
      canvas.drawCircle(dot, 1.8, fill);
    }
  }

  _rosette(canvas, Offset(rc, _midY), stroke, fill);

  final r0 = rc + 35;
  if (xb - r0 > 3) {
    canvas.drawPath(
      Path()
        ..moveTo(r0, 47.5)
        ..lineTo(xb, 47.5)
        ..moveTo(r0, 53.5)
        ..lineTo(xb, 53.5),
      stroke,
    );
  }

  canvas.drawPath(
    Path()
      ..moveTo(xb + 41, 9)
      ..lineTo(xb + 34, 16.5)
      ..arcToPoint(
        Offset(xb + 34, 84.5),
        radius: const Radius.circular(34),
        clockwise: false,
      )
      ..lineTo(xb + 41, 92),
    stroke,
  );
  canvas.drawPath(
    Path()
      ..moveTo(xb - 13, 15)
      ..lineTo(xb + 24, 15)
      ..lineTo(xb + 4, 27)
      ..close()
      ..moveTo(xb - 13, 86)
      ..lineTo(xb + 24, 86)
      ..lineTo(xb + 4, 74)
      ..close(),
    stroke,
  );
  canvas.drawCircle(Offset(xb + 5, 19), 1.6, fill);
  canvas.drawCircle(Offset(xb + 5, 82), 1.6, fill);
}

void _rosette(Canvas canvas, Offset c, Paint stroke, Paint fill) {
  canvas.drawCircle(c, 35, stroke);
  canvas.drawCircle(c, 29, stroke);
  canvas.drawCircle(c, 4, stroke);
  final petal = Path()
    ..moveTo(6, 0)
    ..quadraticBezierTo(13.5, -7.5, 21, 0)
    ..quadraticBezierTo(13.5, 7.5, 6, 0)
    ..close();
  for (var i = 0; i < 8; i++) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(i * math.pi / 4);
    canvas.drawPath(petal, stroke);
    canvas.restore();
    final a = (22.5 + i * 45) * math.pi / 180;
    canvas.drawCircle(
      c + Offset(25 * math.cos(a), 25 * math.sin(a)),
      1.7,
      fill,
    );
  }
}
