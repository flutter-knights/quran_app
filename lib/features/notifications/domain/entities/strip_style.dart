import 'package:equatable/equatable.dart';

enum StripHighlight { app, darkGreen, emerald, blue, indigo, maroon, bronze }

enum StripBackground { auto, mint, sand, sky, rose }

enum StripShape { none, rounded, pill, outline }

class StripStyle extends Equatable {
  final bool expanded;
  final bool showCountdown;
  final StripHighlight highlight;
  final StripBackground background;
  final StripShape shape;

  const StripStyle({
    this.expanded = false,
    this.showCountdown = true,
    this.highlight = StripHighlight.app,
    this.background = StripBackground.auto,
    this.shape = StripShape.rounded,
  });

  StripStyle copyWith({
    bool? expanded,
    bool? showCountdown,
    StripHighlight? highlight,
    StripBackground? background,
    StripShape? shape,
  }) {
    return StripStyle(
      expanded: expanded ?? this.expanded,
      showCountdown: showCountdown ?? this.showCountdown,
      highlight: highlight ?? this.highlight,
      background: background ?? this.background,
      shape: shape ?? this.shape,
    );
  }

  @override
  List<Object?> get props => [
    expanded,
    showCountdown,
    highlight,
    background,
    shape,
  ];
}
