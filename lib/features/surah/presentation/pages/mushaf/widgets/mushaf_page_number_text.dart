import 'package:flutter/material.dart';

class MushafPageNumberText extends StatelessWidget {
  const MushafPageNumberText({super.key, required this.pageNumber});

  final int pageNumber;

  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String get _arabic =>
      pageNumber.toString().split('').map((c) => _digits[int.parse(c)]).join();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _arabic,
        locale: const Locale('ar'),
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
