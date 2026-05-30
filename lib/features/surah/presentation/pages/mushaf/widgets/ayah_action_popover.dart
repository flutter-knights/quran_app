import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../../../../../../generated/l10n.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_cubit.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_state.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

// ---------------------------------------------------------------------------
// Placement logic — pure function, easy to unit-test.
// ---------------------------------------------------------------------------

enum PopoverPlacement { above, below }

PopoverPlacement popoverPlacement({required double verseCenterY}) =>
    verseCenterY > 0.5 ? PopoverPlacement.above : PopoverPlacement.below;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class AyahActionPopover {
  AyahActionPopover._();

  static void show(
    BuildContext context,
    AyahIdentifier ayah, {
    required Rect anchorGlobal,
    required PopoverPlacement placement,
  }) {
    // Capture everything from the triggering context BEFORE inserting the
    // overlay so the entry is not dependent on a potentially-gone context.
    final bookmarkCubit = context.read<BookmarkCubit>();
    final mushafCubit = context.read<MushafCubit>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final overlay = Overlay.of(context);
    final s = S.of(context);
    final startPage = mushafCubit.state.currentPage;

    late OverlayEntry entry;
    StreamSubscription<MushafState>? subscription;

    void dismiss() {
      subscription?.cancel();
      subscription = null;
      if (entry.mounted) entry.remove();
    }

    subscription = mushafCubit.stream.listen((state) {
      if (state.currentPage != startPage) dismiss();
    });

    entry = OverlayEntry(
      builder: (_) => _AyahActionPopoverOverlay(
        ayah: ayah,
        anchorGlobal: anchorGlobal,
        placement: placement,
        bookmarkCubit: bookmarkCubit,
        scaffoldMessenger: scaffoldMessenger,
        strings: _PopoverStrings(s),
        onDismiss: dismiss,
      ),
    );

    overlay.insert(entry);
  }
}

// ---------------------------------------------------------------------------
// Internal strings bag (captured once from the triggering context)
// ---------------------------------------------------------------------------

class _PopoverStrings {
  _PopoverStrings(S s)
      : tafsir = s.tafsir,
        translation = s.translation,
        bookmark = s.bookmark,
        share = s.share,
        comingSoon = s.coming_soon,
        shareFailed = s.share_failed;

  final String tafsir;
  final String translation;
  final String bookmark;
  final String share;
  final String comingSoon;
  final String shareFailed;
}

// ---------------------------------------------------------------------------
// Overlay widget
// ---------------------------------------------------------------------------

const double _cardWidth = 260.0;
const double _cardHeight = 72.0;
const double _gap = 8.0; // space between anchor edge and card

class _AyahActionPopoverOverlay extends StatelessWidget {
  const _AyahActionPopoverOverlay({
    required this.ayah,
    required this.anchorGlobal,
    required this.placement,
    required this.bookmarkCubit,
    required this.scaffoldMessenger,
    required this.strings,
    required this.onDismiss,
  });

  final AyahIdentifier ayah;
  final Rect anchorGlobal;
  final PopoverPlacement placement;
  final BookmarkCubit bookmarkCubit;
  final ScaffoldMessengerState scaffoldMessenger;
  final _PopoverStrings strings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookmarkCubit>.value(
      value: bookmarkCubit,
      child: _AyahActionPopoverContent(
        ayah: ayah,
        anchorGlobal: anchorGlobal,
        placement: placement,
        scaffoldMessenger: scaffoldMessenger,
        strings: strings,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _AyahActionPopoverContent extends StatelessWidget {
  const _AyahActionPopoverContent({
    required this.ayah,
    required this.anchorGlobal,
    required this.placement,
    required this.scaffoldMessenger,
    required this.strings,
    required this.onDismiss,
  });

  final AyahIdentifier ayah;
  final Rect anchorGlobal;
  final PopoverPlacement placement;
  final ScaffoldMessengerState scaffoldMessenger;
  final _PopoverStrings strings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Horizontal: center card on anchor midpoint, clamped to screen edges.
    final anchorMidX = anchorGlobal.center.dx;
    double left = anchorMidX - _cardWidth / 2;
    left = left.clamp(8.0, screenSize.width - _cardWidth - 8.0);

    // Vertical: above or below the anchor rect.
    double top;
    if (placement == PopoverPlacement.above) {
      top = anchorGlobal.top - _cardHeight - _gap;
    } else {
      top = anchorGlobal.bottom + _gap;
    }
    // Clamp to screen bounds.
    top = top.clamp(
      mediaQuery.padding.top + 8.0,
      screenSize.height - _cardHeight - mediaQuery.padding.bottom - 8.0,
    );

    return Stack(
      children: [
        // Full-screen barrier — dismiss on tap outside.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        // The popover card.
        Positioned(
          left: left,
          top: top,
          width: _cardWidth,
          height: _cardHeight,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionButton(
                    icon: Icons.menu_book_outlined,
                    label: strings.tafsir,
                    onTap: () {
                      // coming soon — keep popover open
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(strings.comingSoon)),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.translate,
                    label: strings.translation,
                    onTap: () {
                      // coming soon — keep popover open
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(strings.comingSoon)),
                      );
                    },
                  ),
                  _BookmarkButton(ayah: ayah, label: strings.bookmark),
                  _ActionButton(
                    icon: Icons.share,
                    label: strings.share,
                    onTap: () => _onShare(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onShare(BuildContext context) async {
    try {
      final text = quran.getVerse(ayah.surah, ayah.ayah);
      onDismiss();
      await SharePlus.instance.share(
        ShareParams(text: '$text — ${ayah.surah}:${ayah.ayah}'),
      );
    } catch (_) {
      onDismiss();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(strings.shareFailed)),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Action button widgets (same as the old sheet's _ActionButton / _BookmarkButton)
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.ayah, required this.label});

  final AyahIdentifier ayah;
  final String label;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkCubit, BookmarkState>(
      buildWhen: (a, b) => a.contains(ayah) != b.contains(ayah),
      builder: (context, state) {
        final on = state.contains(ayah);
        return _ActionButton(
          icon: on ? Icons.bookmark : Icons.bookmark_border,
          label: label,
          onTap: () => context.read<BookmarkCubit>().toggle(ayah),
        );
      },
    );
  }
}
