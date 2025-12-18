import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class GetPrayerTimesUseCase
    extends UseCase<Either<Failure, PrayerTimes>, Location> {
  final PrayerTimesRepository prayerTimesRepository;

  GetPrayerTimesUseCase({required this.prayerTimesRepository});

  @override
  Future<Either<Failure, PrayerTimes>> call(Location location) {
    return prayerTimesRepository.getPrayerTimes(location);
  }
}
