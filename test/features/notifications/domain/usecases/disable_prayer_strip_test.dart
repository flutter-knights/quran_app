import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late DisablePrayerStrip useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = DisablePrayerStrip(repository: repo);
  });

  test('delegates to repository.disableStrip', () async {
    when(() => repo.disableStrip()).thenAnswer((_) async => const Right(unit));
    final result = await useCase.call(NoParams());
    expect(result.isRight(), true);
    verify(() => repo.disableStrip()).called(1);
  });
}
