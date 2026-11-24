import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/place_tap_target.dart';
import 'package:quran_app/generated/l10n.dart';

class PlaceRowMenu extends StatelessWidget {
  const PlaceRowMenu({
    super.key,
    required this.onShare,
    required this.onRemove,
  });

  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          key: const ValueKey('place-share'),
          onPressed: onShare,
          child: Text(S.of(context).share, style: TS.medium14),
        ),
        MenuItemButton(
          key: const ValueKey('place-remove'),
          onPressed: onRemove,
          child: Text(s.places_remove, style: TS.medium14),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: s.places_more,
        style: placeTapTarget,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedMoreVertical,
          color: context.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
