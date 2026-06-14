import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/generated/l10n.dart';

/// Modal sheet to jump to a Mushaf page. Resolves with the chosen page (1–604)
/// or null if dismissed / input was invalid.
class PageJumpSheet extends StatefulWidget {
  const PageJumpSheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const PageJumpSheet(),
    );
  }

  @override
  State<PageJumpSheet> createState() => _PageJumpSheetState();
}

class _PageJumpSheetState extends State<PageJumpSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final n = int.tryParse(raw);
    if (n == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(n.clamp(1, 604));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.goToPage, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '1 – 604',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('page-jump-go'),
                onPressed: _submit,
                child: Text(s.goToPage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
