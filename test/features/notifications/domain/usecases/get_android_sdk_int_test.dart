import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_android_sdk_int.dart';

class _MockRepository extends Mock implements NotificationsRepository {}

void main() {
  test('GetAndroidSdkInt returns the repository value', () async {
    final repository = _MockRepository();
    when(repository.androidSdkInt).thenAnswer((_) async => const Right(29));
    expect(
      await GetAndroidSdkInt(repository: repository)(NoParams()),
      const Right(29),
    );
  });
}
