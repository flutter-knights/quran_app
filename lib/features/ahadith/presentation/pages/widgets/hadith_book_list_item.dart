import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

class HadithBookListItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const HadithBookListItem({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PrettierTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colorScheme.surfaceContainer,
        ),
        child: Text(title, style: TS.bold24),
      ),
    );
  }
}
