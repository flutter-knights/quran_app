import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

class HomeButton extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final VoidCallback action;
  const HomeButton({
    super.key,
    required this.title,
    required this.icon,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return PrettierTap(
      onTap: action,
      child: AspectRatio(
        aspectRatio: 0.9,
        child: Column(
          crossAxisAlignment: .stretch,

          spacing: 8,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: HugeIcon(
                    icon: icon,
                    strokeWidth: 1,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            Text(
              title,
              overflow: .ellipsis,
              maxLines: 1,
              textAlign: .center,
              style: TS.semi14,
            ),
          ],
        ),
      ),
    );
  }
}
