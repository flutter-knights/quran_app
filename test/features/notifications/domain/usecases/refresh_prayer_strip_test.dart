import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late RefreshPrayerStrip useCase;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    weekdayLabel: '',
    localeCode: 'en',
    isFriday: false,
  );

  setUp(() {
    repo = _MockRepo();
    useCase = RefreshPrayerStrip(repository: repo);
    registerFallbackValue(state);
  });

  test('delegates to repository.refreshStrip with given state', () async {
    when(() => repo.refreshStrip(any()))
        .thenAnswer((_) async => const Right(unit));
    final result =
        await useCase.call(RefreshPrayerStripParams(state: state));
    expect(result.isRight(), true);
    verify(() => repo.refreshStrip(state)).called(1);
  });
}
