import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_option_sheet.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_switch_row.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/strip_preview.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/notifications/presentation/utils/strip_style_colors.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class PrayerStripSettingsPage extends StatelessWidget {
  const PrayerStripSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(title: s.strip_title),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                children: [
                  const _PreviewSection(),
                  const SizedBox(height: 16),
                  const _SwitchesCard(),
                  const SizedBox(height: 16),
                  const _OptionsCard(),
                  AlertsNote(text: s.strip_note),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatefulWidget {
  const _PreviewSection();

  @override
  State<_PreviewSection> createState() => _PreviewSectionState();
}

class _PreviewSectionState extends State<_PreviewSection> {
  bool _showExpanded = true;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final localeCode = context.langCode;
    final palette = context.palette;
    final today = context.watch<TodayPrayerTimesCubit>().state;
    return BlocSelector<SettingsCubit, SettingsState, (StripStyle, bool)>(
      selector: (state) =>
          (state.settingsModel.stripStyle, state.settingsModel.isFormat12Hours),
      builder: (context, data) {
        final (style, use12Hour) = data;
        final allowed = style.expanded;
        final expanded = allowed && _showExpanded;
        return Column(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IgnorePointer(
              ignoring: !allowed,
              child: Opacity(
                opacity: allowed ? 1 : 0.38,
                child: AppSegmentedSelector(
                  expand: true,
                  selected: expanded,
                  onChanged: (v) => setState(() => _showExpanded = v),
                  options: [
                    SegmentOption(
                      value: false,
                      label: s.strip_previewCollapsed,
                    ),
                    SegmentOption(value: true, label: s.strip_previewExpanded),
                  ],
                ),
              ),
            ),
            StripPreview(
              day: _previewDay(
                today,
                localeCode: localeCode,
                use24Hour: !use12Hour,
                nextInLabel: s.strip_nextIn,
              ),
              style: style,
              expanded: expanded,
              palette: palette,
            ),
          ],
        );
      },
    );
  }
}

PrayerStripState? _previewDay(
  PrayerTimes? today, {
  required String localeCode,
  required bool use24Hour,
  required String Function(String prayerLabel) nextInLabel,
}) {
  if (today == null) return null;
  final now = DateTime.now();
  return PrayerStripStateBuilder.build(
    prayerTimes: today,
    nextPrayer: NextPrayerResolver.resolve(timings: today.timings, now: now),
    localeCode: localeCode,
    isFriday: now.weekday == DateTime.friday,
    use24Hour: use24Hour,
    nextInLabel: nextInLabel,
  );
}

class _SwitchesCard extends StatelessWidget {
  const _SwitchesCard();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return BlocSelector<SettingsCubit, SettingsState, (bool, StripStyle)>(
      selector: (state) => (
        state.settingsModel.isPrayerStripPinned,
        state.settingsModel.stripStyle,
      ),
      builder: (context, data) {
        final (pinned, style) = data;
        final cubit = context.read<SettingsCubit>();
        return SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              AlertsSwitchRow(
                title: s.strip_show,
                value: pinned,
                onChanged: cubit.updatePrayerStripPinned,
              ),
              const AlertsRowDivider(),
              AlertsSwitchRow(
                title: s.strip_expanded,
                value: style.expanded,
                onChanged: pinned
                    ? (v) => cubit.updateStripStyle(style.copyWith(expanded: v))
                    : null,
              ),
              const AlertsRowDivider(),
              AlertsSwitchRow(
                title: s.strip_countdown,
                subtitle: s.strip_countdownNote,
                value: style.showCountdown,
                onChanged: pinned
                    ? (v) => cubit.updateStripStyle(
                        style.copyWith(showCountdown: v),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final palette = context.palette;
    final night = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final chevron = HugeIcon(
      icon: forwardArrowIcon(context),
      color: context.colorScheme.onSurfaceVariant,
      size: 20,
    );
    Color highlight(StripHighlight h) =>
        stripHighlightSwatch(h, palette, night: night);
    Color background(StripBackground b) =>
        stripBackgroundSwatch(b, night: night) ?? stripShadeColor(night: night);
    return BlocSelector<SettingsCubit, SettingsState, (bool, StripStyle)>(
      selector: (state) => (
        state.settingsModel.isPrayerStripPinned,
        state.settingsModel.stripStyle,
      ),
      builder: (context, data) {
        final (pinned, style) = data;
        final cubit = context.read<SettingsCubit>();
        final accent = highlight(style.highlight);
        return SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              AppSettingsTile(
                leading: _SwatchDot(color: accent),
                title: s.strip_highlight,
                subtitle: stripHighlightLabel(s, style.highlight),
                trailing: chevron,
                enabled: pinned,
                onTap: () => showAppOptionSheet(
                  context: context,
                  title: s.strip_highlight,
                  selected: style.highlight,
                  onSelected: (h) =>
                      cubit.updateStripStyle(style.copyWith(highlight: h)),
                  options: [
                    for (final h in StripHighlight.values)
                      AppOption(
                        value: h,
                        label: stripHighlightLabel(s, h),
                        leading: _SwatchDot(color: highlight(h)),
                      ),
                  ],
                ),
              ),
              const AlertsRowDivider(),
              AppSettingsTile(
                leading: _SwatchDot(color: background(style.background)),
                title: s.strip_background,
                subtitle: stripBackgroundLabel(s, style.background),
                trailing: chevron,
                enabled: pinned,
                onTap: () => showAppOptionSheet(
                  context: context,
                  title: s.strip_background,
                  selected: style.background,
                  onSelected: (b) =>
                      cubit.updateStripStyle(style.copyWith(background: b)),
                  options: [
                    for (final b in StripBackground.values)
                      AppOption(
                        value: b,
                        label: stripBackgroundLabel(s, b),
                        leading: _SwatchDot(color: background(b)),
                      ),
                  ],
                ),
              ),
              const AlertsRowDivider(),
              AppSettingsTile(
                leading: StripShapeGlyph(shape: style.shape, color: accent),
                title: s.strip_shape,
                subtitle: stripShapeLabel(s, style.shape),
                trailing: chevron,
                enabled: pinned,
                onTap: () => showAppOptionSheet(
                  context: context,
                  title: s.strip_shape,
                  selected: style.shape,
                  onSelected: (shape) =>
                      cubit.updateStripStyle(style.copyWith(shape: shape)),
                  options: [
                    for (final shape in StripShape.values)
                      AppOption(
                        value: shape,
                        label: stripShapeLabel(s, shape),
                        leading: StripShapeGlyph(shape: shape, color: accent),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }
}
