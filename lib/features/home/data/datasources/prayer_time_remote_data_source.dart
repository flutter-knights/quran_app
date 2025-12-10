import 'package:dio/dio.dart';
import 'package:quran_app/features/home/data/models/prayer_times_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimeRemoteDataSource {
  final Dio dio;
  PrayerTimeRemoteDataSource({required this.dio});

  Future<PrayerTimes> getPrayerTimes(Location location) async {
    Response prayerTimesResponse = await dio.get(
      'https://api.aladhan.com/v1/timings',
      queryParameters: {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    );

    final PrayerTimes prayerTimes = PrayerTimesModel.fromJson(
      prayerTimesResponse.data,
    );
    return prayerTimes;
  }
}
