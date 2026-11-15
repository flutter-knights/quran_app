import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Compact segmented control. The selected segment is filled with the theme
/// accent. Generic over the option value type. Set [expand] to make the
/// segments share the full available width (each segment Expanded); otherwise
/// the control hugs its content.
class AppSegmentedSelector<T> extends StatelessWidget {
  const AppSegmentedSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.enabled = true,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final last = options.length - 1;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final (i, option) in options.indexed)
            if (expand)
              Expanded(
                child: _segment(option, first: i == 0, last: i == last),
              )
            else
              _segment(option, first: i == 0, last: i == last),
        ],
      ),
    );
  }

  Widget _segment(
    SegmentOption<T> option, {
    required bool first,
    required bool last,
  }) => _Segment(
    label: option.label,
    selected: option.value == selected,
    expand: expand,
    first: first,
    last: last,
    onTap: enabled ? () => onChanged(option.value) : null,
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.expand,
    required this.first,
    required this.last,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    const track = Radius.circular(10);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onTap != null,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: expand ? null : 1,
              heightFactor: 1,
              child: Container(
                width: expand ? double.infinity : null,
                padding: EdgeInsetsDirectional.fromSTEB(
                  first ? 3 : 0,
                  3,
                  last ? 3 : 0,
                  3,
                ),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadiusDirectional.horizontal(
                    start: first ? track : Radius.zero,
                    end: last ? track : Radius.zero,
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: expand ? 8 : 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
