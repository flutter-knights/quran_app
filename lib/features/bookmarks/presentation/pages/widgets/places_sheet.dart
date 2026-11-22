import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/places_groups.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/generated/l10n.dart';

class PlacesOpen extends Equatable {
  const PlacesOpen({required this.page, this.focus});

  final int page;
  final AyahIdentifier? focus;

  @override
  List<Object?> get props => [page, focus];
}

class PlacesSheet extends StatelessWidget {
  const PlacesSheet({
    super.key,
    required this.controller,
    this.now = DateTime.now,
  });

  final ScrollController controller;
  final DateTime Function() now;

  static Future<PlacesOpen?> show(
    BuildContext context, {
    DateTime Function() now = DateTime.now,
  }) => showModalBottomSheet<PlacesOpen>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colorScheme.surface,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) => PlacesSheet(controller: controller, now: now),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    PendingS.of(context).menu_places,
                    style: TS.bold16,
                  ),
                ),
                TextButton(
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(48, 48)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.of(context).playback_close, style: TS.bold14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PlacesGroups(
              now: now,
              onOpen: (page, focus) =>
                  Navigator.pop(context, PlacesOpen(page: page, focus: focus)),
            ),
          ],
        ),
      ),
    );
  }
}
