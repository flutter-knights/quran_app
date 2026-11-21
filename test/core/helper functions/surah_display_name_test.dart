import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';

void main() {
  for (final (code, expected) in [
    ('ar', quran.getSurahNameArabic(2)),
    ('en', quran.getSurahName(2)),
  ]) {
    testWidgets('surahDisplayName follows the $code locale', (tester) async {
      late String name;
      await tester.pumpWidget(
        Localizations(
          locale: Locale(code),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              name = surahDisplayName(context, 2);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(name, expected);
    });
  }
}
