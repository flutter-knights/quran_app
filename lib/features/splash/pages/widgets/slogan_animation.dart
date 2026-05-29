import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class SloganAnimation extends StatelessWidget {
  const SloganAnimation({
    super.key,
    required this.slogan,
    required this.onLoaded,
    this.color,
  });
  final String slogan;
  final VoidCallback onLoaded;

  /// Overrides the slogan text colour. Defaults to the theme's text colour
  /// when null; the splash passes white so it reads on the primary backdrop.
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,

      mainAxisAlignment: .center,
      children: slogan
          .split(' ')
          .map(
            (word) => Text(
              word,
              style: TS.medium16
                  .copyWith(letterSpacing: 0.4, color: color)
                  .cairo,
            ),
          )
          .toList()
          .animate(interval: 1.6.seconds, delay: 2.seconds)
          .slideY(
            begin: 1,
            end: 0,
            duration: 1.6.seconds,
            curve: Curves.decelerate,
          )
          .fadeIn(duration: 1.6.seconds)
          .callback(delay: 4.8.seconds, callback: (_) => onLoaded()),
    );
  }
}
