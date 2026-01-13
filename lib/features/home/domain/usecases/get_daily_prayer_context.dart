import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class GetDailyPrayerContext
    extends StreamUseCase<Either<Failure, DailyPrayerContext>, NoParams> {
  final PrayerTimesRepository prayerTimesRepository;
  final LocationRepository locationRepository;

  GetDailyPrayerContext({
    required this.prayerTimesRepository,
    required this.locationRepository,
  });

  @override
  Stream<Either<Failure, DailyPrayerContext>> call(NoParams params) async* {
    await for (final locationResult
        in locationRepository.getCurrentLocation()) {
      yield* locationResult.fold(
        (failure) async* {
          yield Left(failure);
        },
        (location) async* {
          final prayerResult = await prayerTimesRepository.getPrayerTimes(
            location,
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
