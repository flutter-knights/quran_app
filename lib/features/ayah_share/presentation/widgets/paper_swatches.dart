import 'package:flutter/material.dart';

import '../../../../config/theme/color_scheme.dart';
import '../../../../core/constants/mushaf_paper.dart';
import '../../../surah/presentation/utils/enum_localization.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';

class PaperSwatches extends StatelessWidget {
  const PaperSwatches({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final MushafPaper selected;
  final ValueChanged<MushafPaper> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        for (final paper in MushafPaper.values)
          Semantics(
            button: true,
            selected: paper == selected,
            enabled: enabled,
            label: paper.localized(context),
            excludeSemantics: true,
            onTap: enabled ? () => onSelected(paper) : null,
            child: InkResponse(
              key: ValueKey('share-paper-${paper.name}'),
              onTap: enabled ? () => onSelected(paper) : null,
              child: SizedBox.square(
                dimension: 48,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: paper == selected
                            ? context.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: paper.colors.background,
                          border: Border.all(color: paper.colors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
