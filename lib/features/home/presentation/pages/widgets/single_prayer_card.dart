import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/core/widgets/toggle_widget.dart';

class SinglePrayerCard extends StatelessWidget {
  const SinglePrayerCard({
    super.key,
    required this.time24,
    required this.is24,
    required this.isCurrent,
    required this.prayerName,
    required this.iconDir,
  });
  final String time24;
  final String prayerName;
  final String iconDir;
  final bool isCurrent;
  final bool is24;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fg = isCurrent ? scheme.secondary : scheme.onSurfaceVariant;
    final timeStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: fg,
    );
    return Expanded(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 11),
        decoration: BoxDecoration(
          color: isCurrent ? scheme.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? scheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prayerName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isCurrent ? scheme.secondary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 18,
              child: SvgPicture.asset(
                iconDir,
                colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 5),
            ToggleWidget(
              targetChild: Text(time24.toLocalized(context), style: timeStyle),
              defaultChild: Text(
                time24.parse24hTime().format12h(context).toLocalized(context),
                style: timeStyle,
              ),
              value: is24,
            ),
            if (isCurrent) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
