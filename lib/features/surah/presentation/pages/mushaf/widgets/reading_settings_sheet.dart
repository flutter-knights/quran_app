import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

class ReadingSettingsSheet extends StatefulWidget {
  const ReadingSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // Transparent barrier + background so that, when the body fades during a
      // brightness drag, the page behind is fully visible.
      barrierColor: Colors.transparent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => BlocProvider.value(
        value: context.read<SettingsCubit>(),
        child: const ReadingSettingsSheet(),
      ),
    );
  }

  @override
  State<ReadingSettingsSheet> createState() => _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends State<ReadingSettingsSheet> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.readingSettings,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(s.paper, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: MushafPaper.values.map((p) {
                      final selected = p == model.mushafPaper;
                      return Expanded(
                        child: GestureDetector(
                          key: ValueKey('reading-paper-${p.name}'),
                          onTap: () => cubit.updateMushafPaper(p),
                          child: Container(
                            height: 54,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: p.colors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurface.withValues(alpha: 0.12),
                                width: selected ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(s.brightness,
                      style: Theme.of(context).textTheme.labelMedium),
                  Slider(
                    key: const ValueKey('reading-brightness-slider'),
                    min: 0.3,
                    max: 1.0,
                    value: model.pageBrightness,
                    onChangeStart: (_) => setState(() => _dragging = true),
                    onChanged: cubit.updatePageBrightness,
                    onChangeEnd: (_) => setState(() => _dragging = false),
                  ),
                  const SizedBox(height: 8),
                  Text(s.readingMode,
                      style: Theme.of(context).textTheme.labelMedium),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
