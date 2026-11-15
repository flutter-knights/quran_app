import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/notifications/domain/services/alerts_status_resolver.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AlertsStatusLine extends StatelessWidget {
  const AlertsStatusLine({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsCubit, SettingsState, (int, ColorPalette)>(
      selector: (state) =>
          (state.settingsModel.enabledAlertCount, state.settingsModel.palette),
      builder: (context, data) =>
          BlocBuilder<ReliabilityCubit, ReliabilityState>(
            builder: (context, state) =>
                _line(context, state, data.$1, data.$2),
          ),
    );
  }

  Widget _line(
    BuildContext context,
    ReliabilityState state,
    int enabledCount,
    ColorPalette palette,
  ) {
    final s = PendingS.of(context);
    final lang = context.langCode;
    final scheme = context.colorScheme;
    if (state is ReliabilityLoading) {
      return Skeletonizer(
        child: _StatusRow(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          iconColor: scheme.onSurfaceVariant,
          text: s.alerts_status_ok(alertsDateLabel(DateTime.now(), lang)),
        ),
      );
    }
    final status = switch (state) {
      ReliabilityLoaded(:final status) => status,
      _ => null,
    };
    final kind = status == null
        ? AlertsStatusKind.okNoDate
        : resolveAlertsStatus(
            enabledCount: enabledCount,
            status: status,
            isAndroid: defaultTargetPlatform == TargetPlatform.android,
            now: DateTime.now(),
          );
    final text = switch (kind) {
      AlertsStatusKind.allOff => enabledCountLabel(s, 0, lang),
      AlertsStatusKind.off => s.alerts_status_off,
      AlertsStatusKind.attention => s.alerts_status_attention,
      AlertsStatusKind.ok => s.alerts_status_ok(
        alertsDateLabel(status!.scheduledUntil!, lang),
      ),
      AlertsStatusKind.okNoDate => s.alerts_status_okNoDate,
    };
    final ok = kind == AlertsStatusKind.ok || kind == AlertsStatusKind.okNoDate;
    return _StatusRow(
      icon: switch (kind) {
        AlertsStatusKind.allOff ||
        AlertsStatusKind.off => HugeIcons.strokeRoundedNotificationOff01,
        AlertsStatusKind.attention => HugeIcons.strokeRoundedInformationCircle,
        _ => HugeIcons.strokeRoundedCheckmarkCircle02,
      },
      iconColor: ok ? palette.primaryInk : scheme.onSurfaceVariant,
      text: text,
      onTap: onTap,
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.onTap,
  });

  final List<List<dynamic>> icon;
  final Color iconColor;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        child: Row(
          spacing: 10,
          children: [
            HugeIcon(icon: icon, color: iconColor, size: 20),
            Expanded(
              child: Text(
                text,
                style: TS.semi14.copyWith(color: scheme.onSurface),
              ),
            ),
            if (onTap != null)
              HugeIcon(
                icon: forwardArrowIcon(context),
                color: scheme.onSurfaceVariant,
                size: 18,
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      liveRegion: true,
      child: onTap == null ? row : PrettierTap(onTap: onTap, child: row),
    );
  }
}
