import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/router/fade_page.dart';

Widget _app() => WidgetsApp(
  color: const Color(0xFF000000),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  ),
  home: Builder(
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(const FadePage(child: Text('next')).createRoute(context)),
      child: const Text('open'),
    ),
  ),
);

void main() {
  group('route transitions', () {
    late String router;

    setUpAll(() {
      router = File(
        'lib/config/router/app_router.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
    });

    test('only splash, home and onboarding use go_transitions', () {
      expect(RegExp(r'GoTransitions\.').allMatches(router).length, 3);
    });

    test('every other route builds its page with _fadePage', () {
      final routes = RegExp(r'GoRoute\(').allMatches(router).length;
      final faded = RegExp(r'_fadePage\(\s*builder:').allMatches(router).length;
      expect(faded, routes - 3);
    });
  });

  group('FadePage', () {
    testWidgets('fades in without scaling or sliding', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      final opacities = find
          .ancestor(
            of: find.text('next'),
            matching: find.byType(FadeTransition),
          )
          .evaluate()
          .map((e) => (e.widget as FadeTransition).opacity.value);
      expect(opacities.any((v) => v > 0 && v < 1), isTrue);
      expect(
        find.ancestor(
          of: find.text('next'),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('next'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('finishes within 200 ms', (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
