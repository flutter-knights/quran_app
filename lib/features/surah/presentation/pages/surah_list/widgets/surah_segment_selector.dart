import 'package:flutter/material.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../../config/theme/typography_styles.dart';

class SurahSegmentSelector extends StatefulWidget {
  const SurahSegmentSelector({super.key});

  @override
  State<SurahSegmentSelector> createState() => _SurahSegmentSelectorState();
}

class _SurahSegmentSelectorState extends State<SurahSegmentSelector> {
  int selected = 0;

  final List<String> options = ["سورة", "جزء", "صفحة", "علامة مرجعية"];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final segmentWidth = totalWidth / options.length;

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: context.isArabic ? null : segmentWidth * selected,
                right: context.isArabic ? segmentWidth * selected : null,
                width: segmentWidth - 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: List.generate(options.length, (index) {
                  final bool isSelected = index == selected;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => selected = index),
                      child: Center(
                        child: Text(
                          options[index],
                          style: TS.semi12.copyWith(
                            color: isSelected
                                ? context.colorScheme.onPrimary
                                : context.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
