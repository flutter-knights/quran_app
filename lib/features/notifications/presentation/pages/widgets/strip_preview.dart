import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/presentation/utils/strip_style_colors.dart';
import 'package:quran_app/generated/l10n.dart';
import 'package:skeletonizer/skeletonizer.dart';

class StripPreview extends StatelessWidget {
  const StripPreview({
    super.key,
    required this.strip,
    required this.style,
    required this.expanded,
    required this.palette,
    required this.now,
    this.tintable = true,
  });

  final PrayerStripState? strip;
  final StripStyle style;
  final bool expanded;
  final ColorPalette palette;
  final DateTime now;
  final bool tintable;

  @override
  Widget build(BuildContext context) {
    final night = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final colors = _StripColors(
      stripRenderStyle(style, palette),
      night: night,
      tintable: tintable,
    );
    final shown = strip ?? _placeholder;
    final fill = colors.background;
    final body = expanded
        ? _ExpandedRows(strip: shown, colors: colors)
        : _CompactCells(strip: shown, colors: colors);
    final frame = DecoratedBox(
      decoration: BoxDecoration(
        color: stripShadeColor(night: night),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 14),
        child: Column(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(strip: strip, colors: colors, now: now),
            if (fill == null)
              body
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: tintable ? BorderRadius.circular(12) : null,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                  child: body,
                ),
              ),
          ],
        ),
      ),
    );
    return strip == null ? Skeletonizer(child: frame) : frame;
  }
}

class StripShapeGlyph extends StatelessWidget {
  const StripShapeGlyph({super.key, required this.shape, required this.color});

  final StripShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 18,
      child: shape == StripShape.none
          ? Center(
              child: Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          : DecoratedBox(
              decoration: _highlightBox(shape, color, tintable: true),
            ),
    );
  }
}

BoxDecoration _highlightBox(
  StripShape shape,
  Color color, {
  required bool tintable,
}) {
  if (shape == StripShape.none) return const BoxDecoration();
  if (!tintable) return BoxDecoration(color: color);
  return switch (shape) {
    StripShape.pill => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    StripShape.outline => BoxDecoration(
      border: Border.all(color: color, width: 1.5),
      borderRadius: BorderRadius.circular(8),
    ),
    _ => BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
  };
}

final _placeholder = PrayerStripState(
  cells: [
    for (var i = 0; i < 5; i++)
      const PrayerCell(label: '-----', timeFormatted: '--:--', minutes: 0),
  ],
  nextPrayerIndex: 2,
  dateKey: '',
  hijriDateLabel: '-------------',
  weekdayLabel: '-----',
  localeCode: 'ar',
  isFriday: false,
);

class _StripColors {
  const _StripColors(
    this.render, {
    required this.night,
    required this.tintable,
  });

  final StripRenderStyle render;
  final bool night;
  final bool tintable;

  Color? get background {
    final argb = night ? render.backgroundNight : render.backgroundDay;
    return argb == null ? null : Color(argb);
  }

  Color text(int index, int next) {
    if (index == next) {
      return stripNextText(render, night: night, tintable: tintable);
    }
    return stripInk(
      index < next ? StripInk.passed : StripInk.primary,
      night: night,
    );
  }

  BoxDecoration cell(int index, int next) => index == next
      ? _highlightBox(
          render.shape,
          Color(night ? render.highlightNight : render.highlightDay),
          tintable: tintable,
        )
      : const BoxDecoration();
}

class _Header extends StatelessWidget {
  const _Header({required this.strip, required this.colors, required this.now});

  final PrayerStripState? strip;
  final _StripColors colors;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final color = stripInk(StripInk.muted, night: colors.night);
    final appName = S.of(context).app_name;
    final shown = strip;
    final next = shown?.cells.elementAtOrNull(shown.nextPrayerIndex);
    final text = colors.render.countdown && shown != null && next != null
        ? [
            appName,
            if (next.nextLabel.isNotEmpty) next.nextLabel,
            _countdown(next.minutes, now).toIndicNumerals(shown.localeCode),
          ].join(' · ')
        : appName;
    return Row(
      spacing: 6,
      children: [
        HugeIcon(icon: HugeIcons.strokeRoundedMosque02, color: color, size: 14),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TS.regular12.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _countdown(int minutes, DateTime now) {
  var left =
      Duration(minutes: minutes) -
      Duration(hours: now.hour, minutes: now.minute, seconds: now.second);
  if (left.isNegative) left += const Duration(days: 1);
  String two(int n) => n.toString().padLeft(2, '0');
  final mmss =
      '${two(left.inMinutes.remainder(60))}:${two(left.inSeconds.remainder(60))}';
  return left.inHours == 0 ? mmss : '${left.inHours}:$mmss';
}

class _CompactCells extends StatelessWidget {
  const _CompactCells({required this.strip, required this.colors});

  final PrayerStripState strip;
  final _StripColors colors;

  @override
  Widget build(BuildContext context) {
    final next = strip.nextPrayerIndex;
    return Row(
      children: [
        for (final (i, cell) in strip.cells.take(5).indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
              child: DecoratedBox(
                decoration: colors.cell(i, next),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _line(
                        cell.label,
                        TS.bold14.copyWith(
                          fontSize: 13,
                          color: colors.text(i, next),
                        ),
                      ),
                      _line(
                        cell.timeFormatted,
                        TS.semi12.copyWith(
                          fontSize: 11,
                          color: colors.text(i, next),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpandedRows extends StatelessWidget {
  const _ExpandedRows({required this.strip, required this.colors});

  final PrayerStripState strip;
  final _StripColors colors;

  @override
  Widget build(BuildContext context) {
    final next = strip.nextPrayerIndex;
    final tag = PendingS.forLanguage(strip.localeCode).strip_next;
    final date = [
      strip.weekdayLabel,
      strip.hijriDateLabel,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 4),
          child: _line(
            date,
            TS.semi12.copyWith(
              fontSize: 13,
              color: stripMutedText(colors.render, night: colors.night),
            ),
            align: TextAlign.start,
          ),
        ),
        for (final (i, cell) in strip.cells.take(5).indexed)
          DecoratedBox(
            decoration: colors.cell(i, next),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Row(
                        spacing: 8,
                        children: [
                          Flexible(
                            child: _line(
                              cell.label,
                              (i == next ? TS.bold14 : TS.semi14).copyWith(
                                color: colors.text(i, next),
                              ),
                            ),
                          ),
                          if (i == next && tag.isNotEmpty)
                            _line(
                              tag,
                              TS.bold12.copyWith(color: colors.text(i, next)),
                            ),
                        ],
                      ),
                    ),
                    _line(
                      cell.timeFull,
                      TS.bold16.copyWith(
                        fontSize: 15,
                        color: colors.text(i, next),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Text _line(String text, TextStyle style, {TextAlign? align}) => Text(
  text,
  maxLines: 1,
  softWrap: false,
  overflow: TextOverflow.ellipsis,
  textAlign: align,
  style: style,
);
