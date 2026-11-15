import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_option_sheet.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';
import 'package:quran_app/features/notifications/presentation/cubit/android_sdk_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_switch_row.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/strip_preview.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/notifications/presentation/utils/strip_style_colors.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class PrayerStripSettingsPage extends StatelessWidget {
  const PrayerStripSettingsPage({super.key, this.now = DateTime.now});

  final DateTime Function() now;

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
                  _PreviewSection(now: now),
                  const SizedBox(height: 16),
                  const _SettingsCards(),
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
  const _PreviewSection({required this.now});

  final DateTime Function() now;

  @override
  State<_PreviewSection> createState() => _PreviewSectionState();
}

class _PreviewSectionState extends State<_PreviewSection> {
  bool _showExpanded = true;
  late final Timer _minute;

  @override
  void initState() {
    super.initState();
    _minute = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _minute.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final localeCode = context.langCode;
    final palette = context.palette;
    final today = context.watch<TodayPrayerTimesCubit>().state;
    final sdkInt = context.watch<AndroidSdkCubit>().state;
    return BlocSelector<SettingsCubit, SettingsState, (StripStyle, bool)>(
      selector: (state) =>
          (state.settingsModel.stripStyle, state.settingsModel.is24HourFormat),
      builder: (context, data) {
        final (style, use24Hour) = data;
        final now = widget.now();
        final allowed = style.expanded;
        final expanded = allowed && _showExpanded;
        final times = switch (today) {
          TodayPrayerTimesLoading() => null,
          TodayPrayerTimesLoaded(:final times) => times,
          TodayPrayerTimesEmpty() => _sampleTimes,
        };
        return Column(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSegmentedSelector(
              expand: true,
              enabled: allowed,
              selected: expanded,
              onChanged: (v) => setState(() => _showExpanded = v),
              options: [
                SegmentOption(value: false, label: s.strip_previewCollapsed),
                SegmentOption(value: true, label: s.strip_previewExpanded),
              ],
            ),
            StripPreview(
              strip: times == null
                  ? null
                  : _previewStrip(
                      times,
                      now: now,
                      localeCode: localeCode,
                      use24Hour: use24Hour,
                      nextInLabel: s.strip_nextIn,
                    ),
              style: style,
              expanded: expanded,
              palette: palette,
              now: now,
              tintable: stripTintable(sdkInt),
            ),
          ],
        );
      },
    );
  }
}

final _sampleTimes = PrayerTimes(
  key: 'sample',
  timings: const {
    PrayerName.fajr: '04:50',
    PrayerName.sunrise: '06:18',
    PrayerName.dhuhr: '11:39',
    PrayerName.asr: '14:38',
    PrayerName.maghrib: '16:59',
    PrayerName.isha: '18:19',
  },
  date: Date(
    month: 'جمادى الآخرة',
    weekDay: 'الأحد',
    day: '5',
    year: '1448',
    enMonth: 'Jumada al-Akhirah',
    enWeekDay: 'Sunday',
    gregorianDate: '',
  ),
);

PrayerStripState _previewStrip(
  PrayerTimes times, {
  required DateTime now,
  required String localeCode,
  required bool use24Hour,
  required String Function(String prayerLabel) nextInLabel,
}) => PrayerStripStateBuilder.build(
  prayerTimes: times,
  nextPrayer: NextPrayerResolver.resolve(timings: times.timings, now: now),
  localeCode: localeCode,
  isFriday: now.weekday == DateTime.friday,
  use24Hour: use24Hour,
  nextInLabel: nextInLabel,
);

class _SettingsCards extends StatelessWidget {
  const _SettingsCards();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final palette = context.palette;
    final night = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
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
        void update(StripStyle next) => cubit.updateStripStyle(next);
        final accent = highlight(style.highlight);
        return Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SurfaceCard(
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
                        ? (v) => update(style.copyWith(expanded: v))
                        : null,
                  ),
                  const AlertsRowDivider(),
                  AlertsSwitchRow(
                    title: s.strip_countdown,
                    subtitle: s.strip_countdownNote,
                    value: style.showCountdown,
                    onChanged: pinned
                        ? (v) => update(style.copyWith(showCountdown: v))
                        : null,
                  ),
                ],
              ),
            ),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _StyleOptionTile(
                    title: s.strip_highlight,
                    selected: style.highlight,
                    values: StripHighlight.values,
                    label: (h) => stripHighlightLabel(s, h),
                    leading: (h) => _SwatchDot(color: highlight(h)),
                    enabled: pinned,
                    onSelected: (h) => update(style.copyWith(highlight: h)),
                  ),
                  const AlertsRowDivider(),
                  _StyleOptionTile(
                    title: s.strip_background,
                    selected: style.background,
                    values: StripBackground.values,
                    label: (b) => stripBackgroundLabel(s, b),
                    leading: (b) => _SwatchDot(color: background(b)),
                    enabled: pinned,
                    onSelected: (b) => update(style.copyWith(background: b)),
                  ),
                  const AlertsRowDivider(),
                  _StyleOptionTile(
                    title: s.strip_shape,
                    selected: style.shape,
                    values: StripShape.values,
                    label: (shape) => stripShapeLabel(s, shape),
                    leading: (shape) =>
                        StripShapeGlyph(shape: shape, color: accent),
                    enabled: pinned,
                    onSelected: (shape) => update(style.copyWith(shape: shape)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StyleOptionTile<T> extends StatelessWidget {
  const _StyleOptionTile({
    required this.title,
    required this.selected,
    required this.values,
    required this.label,
    required this.leading,
    required this.enabled,
    required this.onSelected,
  });

  final String title;
  final T selected;
  final List<T> values;
  final String Function(T value) label;
  final Widget Function(T value) leading;
  final bool enabled;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppSettingsTile(
      leading: leading(selected),
      title: title,
      subtitle: label(selected),
      trailing: const AlertsChevron(),
      enabled: enabled,
      onTap: () => showAppOptionSheet(
        context: context,
        title: title,
        selected: selected,
        onSelected: onSelected,
        options: [
          for (final value in values)
            AppOption(
              value: value,
              label: label(value),
              leading: leading(value),
            ),
        ],
      ),
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
