import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/ayah_share/presentation/utils/ayah_share_text.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  final verse112 = quran.getVerse(112, 1).split(' ').skip(4).join(' ');
  final basmalaWords = quran.getVerse(2, 1).split(' ').take(4);
  final basmalaPrefix = basmalaWords.join(' ');
  final basmalaWord = basmalaWords.first;

  test('2:1 drops the basmala', () {
    expect(ayahVerseText(const AyahIdentifier(surah: 2, ayah: 1)), 'الم');
  });

  test('112:1 drops the basmala', () {
    expect(ayahVerseText(const AyahIdentifier(surah: 112, ayah: 1)), verse112);
  });

  test('1:1 and 9:1 stay whole', () {
    expect(
      ayahVerseText(const AyahIdentifier(surah: 1, ayah: 1)),
      quran.getVerse(1, 1),
    );
    expect(
      ayahVerseText(const AyahIdentifier(surah: 9, ayah: 1)),
      quran.getVerse(9, 1),
    );
  });

  test('no verse 1 keeps the basmala', () {
    for (var surah = 2; surah <= 114; surah++) {
      if (surah == 9) continue;
      final raw = quran.getVerse(surah, 1);
      final text = ayahVerseText(AyahIdentifier(surah: surah, ayah: 1));
      expect(raw, startsWith(basmalaPrefix), reason: 'surah $surah raw');
      expect(text, isNot(startsWith(basmalaWord)), reason: 'surah $surah');
      expect(
        text,
        raw.split(' ').skip(4).join(' '),
        reason: 'surah $surah rest',
      );
    }
  });

  testWidgets('ayahShareText quotes the verse and names it', (tester) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          S.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) {
            text = ayahShareText(
              context,
              const AyahIdentifier(surah: 112, ayah: 1),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(text, '$verse112 — سورة الإخلاص، الآية ١');
  });

  test('the reel footer credits the reciter with Arabic digits', () {
    expect(
      reelFooter(Reciter.alafasy, const AyahIdentifier(surah: 6, ayah: 31), 1),
      '${Reciter.alafasy.arabicName} · سورة ${quran.getSurahNameArabic(6)} ٣١',
    );
    expect(
      reelFooter(Reciter.alafasy, const AyahIdentifier(surah: 2, ayah: 255), 3),
      endsWith('٢٥٥–٢٥٧'),
    );
  });
}
