import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/qibla_di.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  test('initQibla wires QiblaCubit resolvable from GetIt', () {
    // LocationRepository is normally registered by initHome(); stub it here.
    sl.registerLazySingleton<LocationRepository>(
      () => _MockLocationRepository(),
    );
    initQibla();
    expect(sl.isRegistered<QiblaCubit>(), isTrue);
    final cubit = sl<QiblaCubit>(); // resolves the whole graph
    expect(cubit, isA<QiblaCubit>());
    sl.reset();
  });
}
