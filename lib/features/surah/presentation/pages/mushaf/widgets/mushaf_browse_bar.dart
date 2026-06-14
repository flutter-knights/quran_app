import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted idle control bar shown when chrome is visible and no ayah is
/// selected / playing. Pure presentational — parent supplies callbacks + state.
class MushafBrowseBar extends StatelessWidget {
  const MushafBrowseBar({
    super.key,
    required this.isSaved,
    required this.onSettings,
    required this.onPlay,
    required this.onToggleSave,
  });

  final bool isSaved;
  final VoidCallback onSettings;
  final VoidCallback onPlay;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleButton(
                keyValue: 'browse-settings',
                icon: Icons.tune,
                onTap: onSettings,
              ),
              const SizedBox(width: 10),
              _CircleButton(
                keyValue: 'browse-play',
                icon: Icons.play_arrow,
                primary: true,
                color: scheme.primary,
                onTap: onPlay,
              ),
              const SizedBox(width: 10),
              _CircleButton(
                keyValue: 'browse-save',
                icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
                onTap: onToggleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.keyValue,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.color,
  });

  final String keyValue;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final size = primary ? 46.0 : 36.0;
    return GestureDetector(
      key: ValueKey(keyValue),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary
              ? (color ?? Theme.of(context).colorScheme.primary)
              : Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(icon, color: Colors.white, size: primary ? 24 : 20),
      ),
    );
  }
}
