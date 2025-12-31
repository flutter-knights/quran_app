import 'package:flutter/material.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../../config/theme/typography_styles.dart';

class CustomPressedButton extends StatelessWidget {
  const CustomPressedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: .symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.primary,
        borderRadius: .all(Radius.circular(8)),
      ),
      child: Text(
        "تابع التلاوة",
        style: TS.semi12.copyWith(color: context.colorScheme.onPrimary),
      ),
    );
  }
}
