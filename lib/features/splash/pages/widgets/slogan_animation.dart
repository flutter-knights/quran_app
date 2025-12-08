import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class SloganAnimation extends StatelessWidget {
  const SloganAnimation({super.key, required this.slogan});
  final String slogan;
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      textDirection: Directionality.of(context),
      mainAxisAlignment: .center,
      children: slogan
          .split(' ')
          .map(
            (word) => Text(
              word,
              style: TypographyStyles.body16.copyWith(letterSpacing: 0.4).cairo,
            ),
          )
          .toList()
          .animate(interval: 2.seconds)
          .slideY(
            begin: 1,
            end: 0,
            duration: 2.seconds,
            curve: Curves.decelerate,
          )
          .fadeIn(duration: 2.seconds),
    );
  }
}
