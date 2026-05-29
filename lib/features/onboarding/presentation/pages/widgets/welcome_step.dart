import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/generated/l10n.dart';

/// Step 1 — minimal hero: the app name alone at the top, headline + subtitle
/// centered. No glyph in the body (per design).
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Text(
            s.app_name,
            style: TS.bold16.copyWith(color: Colors.white, letterSpacing: 1.5),
          ).animate().fadeIn(duration: 500.ms, delay: 150.ms),
          const Spacer(),
          Text(
                s.onb_welcome_headline,
                textAlign: TextAlign.center,
                style: TS.bold24
                    .copyWith(color: Colors.white, height: 1.4)
                    .amiri,
              )
              .animate()
              .fadeIn(duration: 600.ms, delay: 300.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 12),
          Text(
            s.onb_welcome_subtitle,
            textAlign: TextAlign.center,
            style: TS.regular14.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.65,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 450.ms),
          const Spacer(),
        ],
      ),
    );
  }
}
