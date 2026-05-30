import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/generated/l10n.dart';

/// Shown on Home when prayer times can't load because location permission is
/// missing. [actionLabel] + [onAction] are supplied by the host so the same
/// card serves both "request permission" and "open settings" (denied-forever).
class LocationRecoveryCard extends StatelessWidget {
  const LocationRecoveryCard({
    super.key,
    required this.actionLabel,
    required this.onAction,
  });

  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                color: scheme.primary,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                s.home_locationCard_title,
                textAlign: TextAlign.center,
                style: TS.bold16.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                s.home_locationCard_body,
                textAlign: TextAlign.center,
                style: TS.regular14.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
