import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/core/localization/pending_s.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/intl_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Future<PendingS> _pending(WidgetTester tester, String locale) async {
  late PendingS result;
  await tester.pumpWidget(
    Localizations(
      locale: Locale(locale),
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Builder(
        builder: (context) {
          result = PendingS.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  final source = File(
    'lib/core/localization/pending_s.dart',
  ).readAsStringSync();
  final getter = RegExp(
    r"String get (\w+) =>\s*_ar\s*\?\s*'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)';",
  );
  final method = RegExp(
    r"String (\w+)\(([^)]*)\) =>\s*_ar\s*\?\s*'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)';",
  );

  String unescape(String s) => s.replaceAll(r"\'", "'").replaceAll(r'\$', r'$');

  String toArb(String dart) =>
      dart.replaceAllMapped(RegExp(r'\$(\w+)'), (m) => '{${m[1]}}');

  group('PendingS mirrors the ARB files', () {
    final ar = _arb('ar');
    final en = _arb('en');

    test('every simple getter matches both ARBs word for word', () {
      final matches = getter.allMatches(source).toList();
      expect(matches.length, 'String get '.allMatches(source).length);
      for (final m in matches) {
        expect(ar[m[1]], unescape(m[2]!), reason: 'ar ${m[1]}');
        expect(en[m[1]], unescape(m[3]!), reason: 'en ${m[1]}');
      }
    });

    test('every placeholder method matches both ARBs', () {
      final matches = method.allMatches(source).toList();
      expect(
        matches.length,
        RegExp(r'String \w+\(String').allMatches(source).length,
      );
      for (final m in matches) {
        expect(ar[m[1]], toArb(unescape(m[3]!)), reason: 'ar ${m[1]}');
        expect(en[m[1]], toArb(unescape(m[4]!)), reason: 'en ${m[1]}');
      }
    });

    test('plural keys exist in both ARBs', () {
      for (final key in ['alerts_minutes', 'alerts_enabledCount']) {
        expect(ar[key], contains('plural'));
        expect(en[key], contains('plural'));
      }
    });
  });

  group('plurals', () {
    testWidgets('Arabic minutes follow number agreement', (tester) async {
      final s = await _pending(tester, 'ar');
      expect(s.alerts_minutes(1), 'دقيقة واحدة');
      expect(s.alerts_minutes(2), 'دقيقتين');
      expect(s.alerts_minutes(3), '3 دقائق');
      expect(s.alerts_minutes(10), '10 دقائق');
      expect(s.alerts_minutes(11), '11 دقيقة');
      expect(s.alerts_minutes(60), '60 دقيقة');
    });

    testWidgets('English minutes', (tester) async {
      final s = await _pending(tester, 'en');
      expect(s.alerts_minutes(1), '1 minute');
      expect(s.alerts_minutes(15), '15 minutes');
    });

    testWidgets('Arabic enabled count', (tester) async {
      final s = await _pending(tester, 'ar');
      expect(s.alerts_enabledCount(0), 'متوقف لكل الصلوات');
      expect(s.alerts_enabledCount(1), 'مفعّل لصلاة واحدة');
      expect(s.alerts_enabledCount(2), 'مفعّل لصلاتين');
      expect(s.alerts_enabledCount(4), 'مفعّل لـ4 صلوات');
    });

    testWidgets('English enabled count', (tester) async {
      final s = await _pending(tester, 'en');
      expect(s.alerts_enabledCount(0), 'Off for all prayers');
      expect(s.alerts_enabledCount(1), 'On for 1 prayer');
      expect(s.alerts_enabledCount(5), 'On for 5 prayers');
    });
  });

  test('current follows the Intl default locale', () {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'ar';
    expect(PendingS.current.alerts_prayersSection, 'الصلوات');
    Intl.defaultLocale = 'en';
    expect(PendingS.current.alerts_prayersSection, 'Prayers');
    Intl.defaultLocale = previous;
  });

  test('forLanguage ignores the Intl default locale', () {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    addTearDown(() => Intl.defaultLocale = previous);
    expect(PendingS.forLanguage('ar').strip_next, 'التالية');
    expect(PendingS.forLanguage('ar').strip_nextIn('العصر'), 'العصر بعد');
    expect(PendingS.forLanguage('en').strip_next, 'Next');
  });
}
