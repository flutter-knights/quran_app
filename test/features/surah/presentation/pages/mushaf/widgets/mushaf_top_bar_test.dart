import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart';

void main() {
  setUp(() {
    if (!sl.isRegistered<QuranPageService>()) {
      sl.registerLazySingleton<QuranPageService>(() => QuranPageServiceImpl());
    }
    if (!sl.isRegistered<QuranMetaService>()) {
      sl.registerLazySingleton<QuranMetaService>(
          () => QuranMetaServiceImpl(pageService: sl<QuranPageService>()));
    }
  });
  tearDown(() => sl.reset());

  testWidgets('shows surah name + juz for page 2', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MushafTopBar(pageNumber: 2))));
    expect(find.text(quran.getSurahNameArabic(2)), findsOneWidget);
    expect(find.textContaining('الجزء'), findsOneWidget);
  });
}
