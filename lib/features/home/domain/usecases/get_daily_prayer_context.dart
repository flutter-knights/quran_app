import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class GetDailyPrayerContext
    extends UseCase<Either<Failure, DailyPrayerContext>, NoParams> {
  final PrayerTimesRepository prayerTimesRepository;
  final LocationRepository locationRepository;

  GetDailyPrayerContext({
    required this.prayerTimesRepository,
    required this.locationRepository,
  });
  @override
  Future<Either<Failure, DailyPrayerContext>> call(NoParams params) async {
    final location = await locationRepository.getCurrentLocation();

    return location.fold((failure) => Left(failure), (location) async {
      final prayerTimes = await prayerTimesRepository.getPrayerTimes(location);
      return prayerTimes.fold(
        (failure) => left(failure),
        (prayerTimes) => Right(
          DailyPrayerContext(
            location: location,
            prayerTimes: prayerTimes,
            date: prayerTimes.date.gregorianDate,
          ),
        ),
      );
    });
  }
}
