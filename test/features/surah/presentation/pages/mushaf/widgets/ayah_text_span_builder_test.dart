import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart';

MushafPageEntity _page() => MushafPageEntity(
      pageNumber: 2,
      ayahs: const ['بسم', 'الله', 'الرحمن'],
      surahNames: const ['الفاتحة'],
      surahHeadersIndexes: const [0],
      basmalaIndexes: const [0],
      showBasmalaList: const [true],
      ayahIdentifiers: const [
        AyahIdentifier(surah: 1, ayah: 1),
        AyahIdentifier(surah: 1, ayah: 2),
        AyahIdentifier(surah: 1, ayah: 3),
      ],
    );

const _normal = TextStyle(color: Colors.black);
const _highlight = TextStyle(color: Colors.red);

void main() {
  testWidgets('buildBase produces header + basmala + N ayah spans', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      final spans = AyahTextSpanBuilder.buildBase(
        context: ctx,
        page: _page(),
        pageNumber: 2,
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        normalStyle: _normal,
      );
      // 1 header (WidgetSpan) + 1 basmala (TextSpan) + 3 ayah TextSpans = 5
      expect(spans, hasLength(5));
      expect(spans.whereType<WidgetSpan>(), hasLength(1));
      // No span should carry the highlight style
      expect(
        spans.whereType<TextSpan>().every((s) => s.style != _highlight),
        isTrue,
      );
      return const SizedBox();
    })));
  });

  test('buildHighlightOverlay returns the same instance when currentAyah is null', () {
    final base = <InlineSpan>[const TextSpan(text: 'x')];
    final result = AyahTextSpanBuilder.buildHighlightOverlay(
      baseSpans: base,
      page: _page(),
      currentAyah: null,
      highlightedStyle: _highlight,
      normalStyle: _normal,
    );
    expect(identical(result, base), isTrue);
  });

  test('buildHighlightOverlay returns the same instance when ayah is absent', () {
    final base = <InlineSpan>[const TextSpan(text: 'x')];
    final result = AyahTextSpanBuilder.buildHighlightOverlay(
      baseSpans: base,
      page: _page(),
      currentAyah: const AyahIdentifier(surah: 99, ayah: 99),
      highlightedStyle: _highlight,
      normalStyle: _normal,
    );
    expect(identical(result, base), isTrue);
  });

  testWidgets('buildHighlightOverlay highlights the matching ayah only', (tester) async {
    late List<InlineSpan> base;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      base = AyahTextSpanBuilder.buildBase(
        context: ctx,
        page: _page(),
        pageNumber: 2,
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        normalStyle: _normal,
      );
      return const SizedBox();
    })));
    final highlighted = AyahTextSpanBuilder.buildHighlightOverlay(
      baseSpans: base,
      page: _page(),
      currentAyah: const AyahIdentifier(surah: 1, ayah: 2),
      highlightedStyle: _highlight,
      normalStyle: _normal,
    );
    expect(identical(highlighted, base), isFalse);
    expect(highlighted, hasLength(base.length));
    final reds = highlighted.whereType<TextSpan>().where((s) => s.style == _highlight).toList();
    expect(reds, hasLength(1));
    expect(reds.single.text, 'الله');
  });
}
