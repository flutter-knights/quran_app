import 'package:flutter/material.dart';

import '../../../cubit/mushaf/mushaf_state.dart';
import 'mushaf_text.dart';

class MushafLayout extends StatelessWidget {
  const MushafLayout({
    super.key,
    required this.pageNumber,
    required this.loaded,
  });

  final int pageNumber;
  final MushafLoaded loaded;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.82,
              child: RepaintBoundary(
                child: MushafText(loaded: loaded, pageNumber: pageNumber),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(pageNumber.toString()),
      ],
    );
  }
}
