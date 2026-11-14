import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
import 'package:quran_app/features/home/domain/usecases/resolve_calculation_params.dart';

class GetDailyPrayerContextParams {
  const GetDailyPrayerContextParams({
    required this.method,
    required this.school,
  });
  final CalculationMethod method;
  final AsrSchool school;
}

class GetDailyPrayerContext
    extends StreamUseCase<Either<Failure, DailyPrayerContext>,
        GetDailyPrayerContextParams> {
  final PrayerTimesRepository prayerTimesRepository;
  final LocationRepository locationRepository;

  GetDailyPrayerContext({
    required this.prayerTimesRepository,
    required this.locationRepository,
  });

  @override
  Stream<Either<Failure, DailyPrayerContext>> call(
    GetDailyPrayerContextParams params,
  ) async* {
    await for (final locationResult
        in locationRepository.getCurrentLocation()) {
      yield* locationResult.fold(
        (failure) async* {
          yield Left(failure);
        },
        (location) async* {
          final resolved = resolveCalculationParams(
            method: params.method,
            school: params.school,
            enCountry: location.enCountry,
          );
          final prayerResult = await prayerTimesRepository.getPrayerTimes(
            location,
            method: resolved.method,
            school: resolved.school,
          );

          yield prayerResult.fold(
            (failure) => Left(failure),
            (prayerTimes) => Right(
              DailyPrayerContext(
                location: location,
                prayerTimes: prayerTimes,
                date: prayerTimes.date.gregorianDate,
              ),
            ),
          );
        },
      );
    }
  }
}
