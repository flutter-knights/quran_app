import 'package:dio/dio.dart';
import 'package:quran_app/features/home/data/models/prayer_times_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimeRemoteDataSource {
  final Dio dio;
  PrayerTimeRemoteDataSource({required this.dio});

  Future<List<PrayerTimes>> getPrayerTimesList(Location location) async {
    Response prayerTimesResponse = await dio.get(
      'http://api.aladhan.com/v1/calendar',
      queryParameters: {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    );
    final prayerTimesResponseData = prayerTimesResponse.data['data'];
    return prayerTimesResponseData
        .map<PrayerTimesModel>(
          (dayPrayerTimes) => PrayerTimesModel.fromJson(dayPrayerTimes),
        )
        .toList();
  }
}
