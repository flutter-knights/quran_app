import 'package:flutter/material.dart';

extension DeviceSize on BuildContext {
  double get height => MediaQuery.of(this).size.height;
  double get width => MediaQuery.of(this).size.width;
  double get aspectRatio => MediaQuery.of(this).size.aspectRatio;
  TextScaler get fontScaler => MediaQuery.of(this).textScaler;
  double responsiveFont(
    double size, {
    double baseWidth = 412,
    double min = 12,
    double max = 40,
  }) {
    final scale = width / baseWidth;
    return (size * scale).clamp(min, max);
  }
}
