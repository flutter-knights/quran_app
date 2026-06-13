import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late RefreshPrayerStrip useCase;

  final window = PrayerStripWindow(days: [
    const PrayerStripState(
      cells: [PrayerCell(label: 'Fajr', timeFormatted: '04:15', minutes: 255)],
      nextPrayerIndex: 0,
      dateKey: '22-05-2026',
      hijriDateLabel: '5 Dhul-Hijjah',
      weekdayLabel: '',
      localeCode: 'en',
      isFriday: false,
    ),
  ]);

  setUp(() {
    repo = _MockRepo();
    useCase = RefreshPrayerStrip(repository: repo);
    registerFallbackValue(window);
  });

  test('delegates to repository.refreshStrip with the given window', () async {
    when(() => repo.refreshStrip(any())).thenAnswer((_) async => const Right(unit));
    final result = await useCase.call(RefreshPrayerStripParams(window: window));
    expect(result, const Right(unit));
    verify(() => repo.refreshStrip(window)).called(1);
  });
}
