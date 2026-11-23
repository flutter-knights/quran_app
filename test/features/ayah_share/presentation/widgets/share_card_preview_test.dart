import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/share_card_preview.dart';

import '../../ayah_share_fakes.dart';

void main() {
  Widget host(Uint8List? bytes) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 300,
        child: ShareCardPreview(
          bytes: bytes,
          paper: MushafPaper.cream,
          progress: false,
          loading: false,
          semanticLabel: 'card',
        ),
      ),
    ),
  );

  Future<bool> cached(Uint8List bytes) async {
    final key = await ResizeImage(
      MemoryImage(bytes),
      width: 300,
    ).obtainKey(ImageConfiguration.empty);
    return PaintingBinding.instance.imageCache.containsKey(key);
  }

  testWidgets(
    'a new card evicts the previous decode and dispose evicts the last',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final first = Uint8List.fromList(onePixelPng);
      final second = Uint8List.fromList(onePixelPng);
      await tester.pumpWidget(host(first));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(await cached(first), isTrue);

      await tester.pumpWidget(host(second));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(await cached(first), isFalse);
      expect(await cached(second), isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(await cached(second), isFalse);
    },
  );
}
