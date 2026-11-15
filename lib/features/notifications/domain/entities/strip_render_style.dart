import 'package:equatable/equatable.dart';

class StripRenderStyle extends Equatable {
  final bool expanded;
  final bool countdown;
  final int highlightDay;
  final int highlightNight;
  final int pillTextDay;
  final int pillTextNight;
  final int? backgroundDay;
  final int? backgroundNight;
  final String shape;

  const StripRenderStyle({
    required this.expanded,
    required this.countdown,
    required this.highlightDay,
    required this.highlightNight,
    required this.pillTextDay,
    required this.pillTextNight,
    this.backgroundDay,
    this.backgroundNight,
    required this.shape,
  });

  Map<String, Object> toJson() => {
    'expanded': expanded,
    'countdown': countdown,
    'highlightDay': _hex(highlightDay),
    'highlightNight': _hex(highlightNight),
    'pillTextDay': _hex(pillTextDay),
    'pillTextNight': _hex(pillTextNight),
    if (backgroundDay != null) 'backgroundDay': _hex(backgroundDay!),
    if (backgroundNight != null) 'backgroundNight': _hex(backgroundNight!),
    'shape': shape,
  };

  static String _hex(int argb) =>
      '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  @override
  List<Object?> get props => [
    expanded,
    countdown,
    highlightDay,
    highlightNight,
    pillTextDay,
    pillTextNight,
    backgroundDay,
    backgroundNight,
    shape,
  ];
}
