import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_labels.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  final now = DateTime(2026, 11, 21, 12);

  group('placeWhen', () {
    test('today', () {
      expect(
        placeWhen(DateTime(2026, 11, 21, 6, 10), now: now, localeCode: 'ar'),
        'اليوم ٦:١٠ ص',
      );
    });

    test('yesterday by calendar day, even under 24 hours', () {
      expect(
        placeWhen(DateTime(2026, 11, 20, 21, 40), now: now, localeCode: 'ar'),
        'أمس ٩:٤٠ م',
      );
    });

    test('older this year', () {
      expect(
        placeWhen(DateTime(2026, 11, 14, 8), now: now, localeCode: 'ar'),
        '١٤ نوفمبر',
      );
    });

    test('another year adds it', () {
      expect(
        placeWhen(DateTime(2025, 11, 14), now: now, localeCode: 'ar'),
        '١٤ نوفمبر ٢٠٢٥',
      );
    });

    test('english', () {
      expect(
        placeWhen(DateTime(2026, 11, 21, 6, 10), now: now, localeCode: 'en'),
        'Today 6:10 AM',
      );
    });

    test('24-hour clock', () {
      expect(
        placeWhen(
          DateTime(2026, 11, 20, 21, 40),
          now: now,
          localeCode: 'ar',
          use24h: true,
        ),
        'أمس ٢١:٤٠',
      );
    });
  });

  testWidgets('ayahPlace and fasilName read the locale', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      ayahPlace(context, const AyahIdentifier(surah: 3, ayah: 6)),
      'آل عمران ٦',
    );
    expect(fasilName(context, FasilSlot.hifz, null), 'الحفظ');
    final named = Place(
      id: 'a',
      ayah: const AyahIdentifier(surah: 3, ayah: 6),
      page: 50,
      slot: FasilSlot.hifz,
      name: 'حفظ رمضان',
      createdAt: now,
      updatedAt: now,
    );
    expect(fasilName(context, FasilSlot.hifz, named), 'حفظ رمضان');
  });
}
