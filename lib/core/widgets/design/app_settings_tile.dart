import 'package:flutter/widgets.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

class AppSettingsTile extends StatelessWidget {
  const AppSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.toggled,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        child: Row(
          spacing: 12,
          children: [
            ?leading,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TS.semi16.copyWith(color: scheme.onSurface),
                  ),
                  if (subtitle case final subtitle?)
                    Text(
                      subtitle,
                      style: TS.regular14.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    final tap = enabled ? onTap : null;
    return Semantics(
      button: onTap != null && toggled == null,
      toggled: toggled,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: tap == null ? row : PrettierTap(onTap: tap, child: row),
      ),
    );
  }
}
