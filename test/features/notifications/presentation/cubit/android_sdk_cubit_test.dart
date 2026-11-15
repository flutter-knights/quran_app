import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_android_sdk_int.dart';
import 'package:quran_app/features/notifications/presentation/cubit/android_sdk_cubit.dart';

class _MockGetSdk extends Mock implements GetAndroidSdkInt {}

void main() {
  late _MockGetSdk getSdk;

  setUpAll(() => registerFallbackValue(NoParams()));
  setUp(() => getSdk = _MockGetSdk());

  blocTest<AndroidSdkCubit, int?>(
    'load emits the SDK level',
    setUp: () =>
        when(() => getSdk(any())).thenAnswer((_) async => const Right(30)),
    build: () => AndroidSdkCubit(getSdk),
    act: (c) => c.load(),
    expect: () => [30],
  );

  blocTest<AndroidSdkCubit, int?>(
    'a failure keeps null',
    setUp: () => when(
      () => getSdk(any()),
    ).thenAnswer((_) async => const Left(UnknownNotificationFailure('x'))),
    build: () => AndroidSdkCubit(getSdk),
    act: (c) => c.load(),
    expect: () => [],
  );
}
