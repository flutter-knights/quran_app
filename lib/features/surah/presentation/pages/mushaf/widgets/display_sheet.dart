import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/leaf_tap_action.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

class DisplaySheet extends StatefulWidget {
  const DisplaySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    barrierColor: Colors.transparent,
    backgroundColor: context.colorScheme.surface,
    builder: (_) => BlocProvider.value(
      value: context.read<SettingsCubit>(),
      child: const DisplaySheet(),
    ),
  );

  @override
  State<DisplaySheet> createState() => _DisplaySheetState();
}

class _DisplaySheetState extends State<DisplaySheet> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pending = PendingS.of(context);
    final scheme = context.colorScheme;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final model = state.settingsModel;
        final cubit = context.read<SettingsCubit>();
        return AnimatedOpacity(
          key: const ValueKey('reading-sheet-body'),
          opacity: _dragging ? 0.12 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pending.menu_display, style: TS.bold16),
                  const SizedBox(height: 16),
                  Text(pending.display_paper, style: TS.medium12),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final p in MushafPaper.values)
                        Expanded(
                          child: _PaperTile(
                            paper: p,
                            selected: p == model.mushafPaper,
                            onTap: () => cubit.updateMushafPaper(p),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(s.brightness, style: TS.medium12),
                  Slider(
                    key: const ValueKey('reading-brightness-slider'),
                    min: Settings.minPageBrightness,
                    max: 1.0,
                    value: model.pageBrightness,
                    onChangeStart: (_) => setState(() => _dragging = true),
                    onChanged: cubit.updatePageBrightness,
                    onChangeEnd: (_) => setState(() => _dragging = false),
                  ),
                  const SizedBox(height: 8),
                  Text(pending.display_readingMode, style: TS.medium12),
                  const SizedBox(height: 8),
                  AppSegmentedSelector<MushafReadingMode>(
                    key: const ValueKey('reading-mode-toggle'),
                    selected: model.readingMode,
                    expand: true,
                    onChanged: cubit.updateReadingMode,
                    options: [
                      SegmentOption(
                        value: MushafReadingMode.page,
                        label: s.pageByPage,
                      ),
                      SegmentOption(
                        value: MushafReadingMode.scroll,
                        label: s.continuousScroll,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(pending.display_tapAction, style: TS.medium12),
                  const SizedBox(height: 8),
                  AppSegmentedSelector<LeafTapAction>(
                    key: const ValueKey('tap-action-toggle'),
                    selected: model.tapAction,
                    expand: true,
                    onChanged: cubit.updateTapAction,
                    options: [
                      for (final a in LeafTapAction.values)
                        SegmentOption(value: a, label: a.localized(context)),
                    ],
                  ),
                  SwitchListTile(
                    key: const ValueKey('display-keep-awake'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      pending.display_keepScreenOn,
                      style: TS.medium14.copyWith(color: scheme.onSurface),
                    ),
                    value: model.keepScreenOn,
                    onChanged: cubit.updateKeepScreenOn,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('display-done'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(pending.display_done),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaperTile extends StatelessWidget {
  const _PaperTile({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final MushafPaper paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final name = paper.localized(context);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('reading-paper-${paper.name}'),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.12),
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PaperTilePainter(paper.colors),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TS.medium14.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperTilePainter extends CustomPainter {
  const _PaperTilePainter(this.colors);

  final MushafPaperColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);
    canvas.drawRect(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      Paint()
        ..color = colors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final ink = Paint()
      ..color = colors.ink
      ..strokeWidth = 2;
    for (final f in [0.4, 0.6]) {
      canvas.drawLine(
        Offset(size.width * 0.25, size.height * f),
        Offset(size.width * 0.75, size.height * f),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_PaperTilePainter old) => old.colors != colors;
}
