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
    return Container(
      height: 36,

      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: context.isArabic ? null : _calculatePosition(selected),
            right: context.isArabic ? _calculatePosition(selected) : null,
            top: 0,
            bottom: 0,
            child: Container(
              width: _calculateWidth(selected),
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
                  onTap: () => setState(() => selected = index),
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: index == 3 ? 4 : 16,
                    ),
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
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  double _calculatePosition(int index) {
    final containerWidth = MediaQuery.of(context).size.width - 32;
    final segmentWidth = containerWidth / options.length;
    return (segmentWidth * index) + (index == 3 ? 4 : 16);
  }

  double _calculateWidth(int index) {
    final containerWidth = MediaQuery.of(context).size.width - 32;
    final segmentWidth = containerWidth / options.length;
    return segmentWidth - (index == 3 ? 8 : 32);
  }
}
