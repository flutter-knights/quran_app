import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('route transitions', () {
    late String router;

    setUpAll(() {
      router = File(
        'lib/config/router/app_router.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
    });

    test('go_transitions is used by the three entry routes and _fadePage', () {
      expect(RegExp(r'GoTransitions\.').allMatches(router).length, 4);
    });

    test('every other route builds its page with _fadePage', () {
      final routes = RegExp(r'GoRoute\(').allMatches(router).length;
      final faded = RegExp(r'_fadePage\(\s*builder:').allMatches(router).length;
      expect(faded, routes - 3);
    });

    test('_fadePage is a 200 ms easeInOut fade', () {
      final helper = router.substring(router.indexOf('_fadePage({'));
      expect(helper, contains('GoTransitions.fade'));
      expect(helper, contains('Curves.easeInOut'));
      expect(helper, contains('Duration(milliseconds: 200)'));
    });
  });
}
