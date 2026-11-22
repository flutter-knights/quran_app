import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_labels.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class FasilRowSummary extends StatelessWidget {
  const FasilRowSummary({
    super.key,
    required this.slot,
    required this.place,
    this.below = const [],
    this.trailing,
  });

  final FasilSlot slot;
  final Place? place;
  final List<Widget> below;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final placed = place;
    return Row(
      spacing: 12,
      children: [
        Container(
          width: 12,
          height: 24,
          decoration: BoxDecoration(
            color: fasilRibbon(
              slot,
              dark: scheme.brightness == Brightness.dark,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fasilName(context, slot, placed), style: TS.bold14),
              Text(
                placed == null
                    ? s.fasil_notPlaced
                    : s.places_position(
                        ayahPlace(context, placed.ayah),
                        placed.page.toLocalized(context),
                      ),
                style: TS.medium14.copyWith(color: scheme.onSurfaceVariant),
              ),
              ...below,
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
