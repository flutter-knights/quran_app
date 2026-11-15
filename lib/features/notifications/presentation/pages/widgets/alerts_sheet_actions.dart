import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class AlertsSheetActions extends StatelessWidget {
  const AlertsSheetActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.laterLabel,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String laterLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onPrimary,
          child: Text(primaryLabel, style: TS.semi16),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: context.palette.primaryInk,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(laterLabel, style: TS.semi14),
        ),
      ],
    );
  }
}
