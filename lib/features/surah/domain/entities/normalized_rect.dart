import 'package:equatable/equatable.dart';

class NormalizedRect extends Equatable {
  final double x;
  final double y;
  final double w;
  final double h;

  const NormalizedRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  @override
  List<Object?> get props => [x, y, w, h];
}
