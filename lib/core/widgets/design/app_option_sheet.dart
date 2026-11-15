import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class AppOption<T> {
  const AppOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
}

Future<void> showAppOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppOption<T>> options,
  required T selected,
  required ValueChanged<T> onSelected,
  Widget? footer,
  VoidCallback? onClosed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surfaceContainer,
    builder: (sheetContext) => _AppOptionSheet<T>(
      title: title,
      options: options,
      selected: selected,
      footer: footer,
      onSelected: (value) {
        onSelected(value);
        Navigator.of(sheetContext).pop();
      },
    ),
  ).whenComplete(() => onClosed?.call());
}

class _AppOptionSheet<T> extends StatelessWidget {
  const _AppOptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.footer,
  });

  final String title;
  final List<AppOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
          child: Text(
            title,
            style: TS.semi16.copyWith(color: scheme.onSurface),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: RadioGroup<T>(
              groupValue: selected,
              onChanged: (value) {
                if (value is T) onSelected(value);
              },
              child: Column(
                children: [
                  for (final option in options)
                    RadioListTile<T>(
                      value: option.value,
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: option.trailing,
                      title: Row(
                        spacing: 10,
                        children: [
                          ?option.leading,
                          Flexible(
                            child: Text(
                              option.label,
                              style: TS.regular16.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(
                              option.subtitle!,
                              style: TS.regular14.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ?footer,
        const SizedBox(height: 16),
      ],
    );
  }
}
