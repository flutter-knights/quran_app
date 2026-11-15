import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/home/domain/usecases/resolve_calculation_params.dart';

class PreCachePrayerTimesParams {
  final Location location;
  final DateTime? now;
  final CalculationMethod method;
  final AsrSchool school;
  PreCachePrayerTimesParams({
    required this.location,
    this.now,
    this.method = CalculationMethod.auto,
    this.school = AsrSchool.shafi,
  });
}

class PreCachePrayerTimes extends UseCase<void, PreCachePrayerTimesParams> {
  final PrayerTimesRepository prayerTimesRepository;

  PreCachePrayerTimes({required this.prayerTimesRepository});

  @override
  Future<void> call(PreCachePrayerTimesParams params) async {
    final now = params.now ?? DateTime.now();
    final resolved = resolveCalculationParams(
      method: params.method,
      school: params.school,
      enCountry: params.location.enCountry,
    );

    await prayerTimesRepository.preCacheMonth(
      location: params.location,
      year: now.year,
      month: now.month,
      method: resolved.method,
      school: resolved.school,
    );

    final next = DateTime(now.year, now.month + 1);
    await prayerTimesRepository.preCacheMonth(
      location: params.location,
      year: next.year,
      month: next.month,
      method: resolved.method,
      school: resolved.school,
    );
  }
}
