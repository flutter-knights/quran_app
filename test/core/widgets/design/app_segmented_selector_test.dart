import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';

void main() {
  Future<List<bool>> pump(
    WidgetTester tester, {
    bool enabled = true,
    bool expand = false,
  }) async {
    final picked = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ColorPalette.neutralLight.toThemeData(),
        home: Scaffold(
          body: Column(
            children: [
              AppSegmentedSelector(
                selected: false,
                enabled: enabled,
                expand: expand,
                onChanged: picked.add,
                options: const [
                  SegmentOption(value: false, label: '12h'),
                  SegmentOption(value: true, label: '24h'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('tapping an unselected segment fires onChanged with its value', (
    tester,
  ) async {
    final picked = await pump(tester);
    await tester.tap(find.text('24h'));
    await tester.pump();
    expect(picked, [true]);
  });

  testWidgets('a disabled selector ignores taps and dims itself', (
    tester,
  ) async {
    final picked = await pump(tester, enabled: false);
    await tester.tap(find.text('24h'), warnIfMissed: false);
    await tester.pump();
    expect(picked, isEmpty);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('24h'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.38);
  });

  for (final expand in [false, true]) {
    testWidgets('each segment is at least 48 high to tap (expand: $expand)', (
      tester,
    ) async {
      final picked = await pump(tester, expand: expand);
      final segment = find.ancestor(
        of: find.text('24h'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(segment).height, greaterThanOrEqualTo(48));
      final box = tester.getRect(segment);
      await tester.tapAt(Offset(box.center.dx, box.top + 1));
      await tester.pump();
      expect(picked, [true]);
    });
  }

  testWidgets('segments announce as buttons with their selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      tester.getSemantics(find.text('12h')),
      isSemantics(
        label: '12h',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('24h')),
      isSemantics(
        label: '24h',
        isButton: true,
        isSelected: false,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  for (final expand in [false, true]) {
    testWidgets('the track and pill keep their size inside the target '
        '(expand: $expand)', (tester) async {
      await pump(tester, expand: expand);
      final label = tester.getRect(find.text('12h'));
      final pill = tester.getRect(
        find
            .ancestor(
              of: find.text('12h'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final track = tester.getRect(
        find
            .ancestor(of: find.text('12h'), matching: find.byType(Container))
            .at(1),
      );
      final target = tester.getRect(
        find.ancestor(of: find.text('12h'), matching: find.byType(InkWell)),
      );
      expect(pill.height, label.height + 14);
      expect(pill.center.dy, label.center.dy);
      expect(track.height, pill.height + 6);
      expect(track.center.dy, target.center.dy);
      expect(target.height, 48);
    });
  }
}
