import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class AlertsNote extends StatelessWidget {
  const AlertsNote({
    super.key,
    required this.text,
    this.padding = const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 0),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            color: scheme.onSurfaceVariant,
            size: 18,
          ),
          Expanded(
            child: Text(
              text,
              style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class AlertsRowDivider extends StatelessWidget {
  const AlertsRowDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsetsDirectional.symmetric(horizontal: 16),
    color: context.colorScheme.onSurface.withValues(alpha: 0.06),
  );
}
