import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/surah_caption.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  Future<String> caption(WidgetTester tester, String locale, int surah) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) {
            text = surahCaption(context, surah);
            return const SizedBox();
          },
        ),
      ),
    );
    return text;
  }

  testWidgets('a Madani surah in Arabic uses Arabic-Indic digits', (
    tester,
  ) async {
    expect(await caption(tester, 'ar', 3), 'مدنية، ٢٠٠ آية');
  });

  testWidgets('a Makki surah in English', (tester) async {
    expect(await caption(tester, 'en', 18), contains('Makkiyya'));
  });
}
