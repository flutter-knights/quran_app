import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/fasil_row_summary.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/place_tap_target.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_labels.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

sealed class FasilChoice extends Equatable {
  const FasilChoice();
}

final class FasilGo extends FasilChoice {
  const FasilGo(this.place);

  final Place place;

  @override
  List<Object?> get props => [place];
}

final class FasilMoveHere extends FasilChoice {
  const FasilMoveHere(this.slot);

  final FasilSlot slot;

  @override
  List<Object?> get props => [slot];
}

const _wideStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
);

class FasilChooser extends StatelessWidget {
  const FasilChooser({
    super.key,
    required this.slots,
    this.selected,
    this.preselect,
  });

  final Map<FasilSlot, Place> slots;
  final AyahIdentifier? selected;
  final FasilSlot? preselect;

  static Future<FasilChoice?> show(
    BuildContext context, {
    required Map<FasilSlot, Place> slots,
    AyahIdentifier? selected,
    FasilSlot? preselect,
  }) => showModalBottomSheet<FasilChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colorScheme.surface,
    builder: (_) =>
        FasilChooser(slots: slots, selected: selected, preselect: preselect),
  );

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.fasil_title, style: TS.bold16),
            const SizedBox(height: 8),
            for (final slot in FasilSlot.values)
              _FasilRow(
                slot: slot,
                place: slots[slot],
                canMove: selected != null && slots[slot]?.ayah != selected,
                filled: slot == preselect,
              ),
          ],
        ),
      ),
    );
  }
}

class _FasilRow extends StatelessWidget {
  const _FasilRow({
    required this.slot,
    required this.place,
    required this.canMove,
    required this.filled,
  });

  final FasilSlot slot;
  final Place? place;
  final bool canMove;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final name = fasilName(context, slot, place);
    final placed = place;
    final label = switch ((placed != null, filled)) {
      (true, true) => s.fasil_moveNamedHere(name),
      (true, false) => s.fasil_moveHere,
      (false, true) => s.fasil_placeNamedHere(name),
      (false, false) => s.fasil_placeHere,
    };
    final spoken = placed != null
        ? s.fasil_moveNamedHere(name)
        : s.fasil_placeNamedHere(name);
    final choice = FasilMoveHere(slot);
    final child = Text(label, style: TS.bold14, semanticsLabel: spoken);
    return Padding(
      key: ValueKey('fasil-row-${slot.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: FasilRowSummary(
              slot: slot,
              place: placed,
              trailing: placed == null
                  ? null
                  : TextButton(
                      key: ValueKey('fasil-go-${slot.name}'),
                      style: placeTapTarget,
                      onPressed: () => Navigator.pop(context, FasilGo(placed)),
                      child: Text(s.menu_go, style: TS.bold14),
                    ),
            ),
          ),
          if (canMove)
            filled
                ? FilledButton(
                    key: ValueKey('fasil-move-${slot.name}'),
                    style: _wideStyle,
                    onPressed: () => Navigator.pop(context, choice),
                    child: child,
                  )
                : OutlinedButton(
                    key: ValueKey('fasil-move-${slot.name}'),
                    style: _wideStyle,
                    onPressed: () => Navigator.pop(context, choice),
                    child: child,
                  ),
        ],
      ),
    );
  }
}
