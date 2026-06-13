import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_window.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late EnablePrayerStrip useCase;

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
    useCase = EnablePrayerStrip(repository: repo);
    registerFallbackValue(window);
  });

  test('delegates to repository.enableStrip with the given window', () async {
    when(() => repo.enableStrip(any())).thenAnswer((_) async => const Right(unit));
    final result = await useCase.call(EnablePrayerStripParams(window: window));
    expect(result, const Right(unit));
    verify(() => repo.enableStrip(window)).called(1);
  });
}
