import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.icon,
    required this.title,
    this.lead,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String? lead;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 12,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: HugeIcon(icon: icon, color: Colors.white, size: 26),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TS.bold20.copyWith(color: Colors.white),
        ),
        if (lead case final lead?)
          Text(
            lead,
            textAlign: TextAlign.center,
            style: TS.regular14.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.6,
            ),
          ),
      ],
    );
  }
}
