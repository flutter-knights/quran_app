import 'package:quran_app/features/home/data/datasources/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

class PrayerTimesRepositoryImpl extends PrayerTimesRepository {
  final PrayerTimeRemoteDataSource prayerTimeRemoteDataSource;

  PrayerTimesRepositoryImpl({required this.prayerTimeRemoteDataSource});

  @override
  Future<PrayerTimes> getPrayerTimes(Location location) async {
    return await prayerTimeRemoteDataSource.getPrayerTimes(location);
  }
}
