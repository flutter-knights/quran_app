import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahSearchBar extends StatefulWidget {
  const SurahSearchBar({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<SurahSearchBar> createState() => _SurahSearchBarState();
}

class _SurahSearchBarState extends State<SurahSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // refresh the clear button
    widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 14, color: scheme.onSurface),
      decoration: InputDecoration(
        isDense: true,
        hintText: S.of(context).search_surah_hint,
        hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        prefixIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedSearch01,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: _controller.text.isEmpty
            ? null
            : GestureDetector(
                onTap: _clear,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
