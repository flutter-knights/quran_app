import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';

class PalettePickerWidget extends StatelessWidget {
  const PalettePickerWidget({
    super.key,
    required this.currentPalette,
    required this.onSelect,
  });

  final ColorPalette currentPalette;
  final ValueChanged<ColorPalette> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: ColorPalette.values
          .map(
            (p) => _PaletteTile(
              palette: p,
              isSelected: p == currentPalette,
              onTap: () => onSelect(p),
            ),
          )
          .toList(),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final ColorPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (palette) {
        ColorPalette.neutralDark => 'Neutral Dark',
        ColorPalette.neutralLight => 'Neutral Light',
        ColorPalette.slateDark => 'Slate Dark',
        ColorPalette.slateLight => 'Slate Light',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.secondary : palette.surface,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 30, 0),
              child: Text(
                _label,
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
              ),
            ),
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: palette.secondary,
                  size: 14,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
