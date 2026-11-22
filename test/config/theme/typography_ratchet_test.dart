import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseline = {
  'TextStyle(': 0,
  'fontFamily:': 1,
  'fontSize:': 8,
  'fontWeight:': 0,
  'Theme.of(context).textTheme': 0,
};

final _commentOrString = RegExp(
  [
    r'//[^\n]*',
    r'/\*[\s\S]*?\*/',
    r'r?"""[\s\S]*?"""',
    r"r?'''[\s\S]*?'''",
    r'r?"(?:\\.|[^"\\\n])*"',
    r"r?'(?:\\.|[^'\\\n])*'",
  ].join('|'),
);

final _patterns = {
  'TextStyle(': RegExp(r'\bTextStyle\s*\('),
  'fontFamily:': RegExp(r'\bfontFamily\s*:'),
  'fontSize:': RegExp(r'\bfontSize\s*:'),
  'fontWeight:': RegExp(r'\bfontWeight\s*:'),
  'Theme.of(context).textTheme': RegExp(r'Theme\.of\(context\)\.textTheme'),
};

void main() {
  final sources = <String>[];

  setUpAll(() {
    expect(
      File('lib/config/theme/typography_styles.dart').existsSync(),
      isTrue,
      reason: 'Run the ratchet from the package root.',
    );
    sources.addAll(
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('config/theme/typography_styles.dart') &&
                !f.uri.pathSegments.contains('generated'),
          )
          .map((f) => f.readAsStringSync().replaceAll(_commentOrString, ' ')),
    );
  });

  for (final MapEntry(key: name, value: pattern) in _patterns.entries) {
    test('$name count stays at or below its baseline', () {
      final total = sources.fold(
        0,
        (sum, code) => sum + pattern.allMatches(code).length,
      );
      final baseline = _baseline[name]!;
      if (total < baseline) {
        debugPrint(
          '$name is $total, under its baseline of $baseline: '
          "lower _baseline['$name'] to $total.",
        );
      }
      expect(
        total,
        lessThanOrEqualTo(baseline),
        reason:
            'lib/ has $total $name hits, the baseline allows $baseline. Use '
            'a TS.* token from lib/config/theme/typography_styles.dart '
            '(.claude/rules/theming.md).',
      );
    });
  }
}
