import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_lookups.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

void main() {
  test('generateChapterLookups maps book -> {chapterId: Chapter}', () {
    final raw = {
      'sahih-bukhari': [
        {'id': 10, 'chapterNumber': 1, 'chapterArabic': 'الوحى', 'chapterEnglish': 'Revelation'},
        {'id': 11, 'chapterNumber': 2, 'chapterArabic': 'الإيمان', 'chapterEnglish': 'Belief'},
      ],
    };

    final lookups = generateChapterLookups(raw);

    expect(lookups['sahih-bukhari']!.length, 2);
    expect(lookups['sahih-bukhari']![10]!.chapterNumber, 1);
    expect(lookups['sahih-bukhari']![11]!.chapterEnglish, 'Belief');
  });

  test('hadithStatusApiValue maps daeef to the back-tick API spelling', () {
    expect(hadithStatusApiValue[HadithStatus.sahih], 'Sahih');
    expect(hadithStatusApiValue[HadithStatus.hasan], 'Hasan');
    expect(hadithStatusApiValue[HadithStatus.daeef], 'Da`eef');
  });
}
