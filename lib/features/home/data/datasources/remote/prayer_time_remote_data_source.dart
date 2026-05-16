import 'package:dio/dio.dart';
import 'package:quran_app/features/home/data/models/prayer_times_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class PrayerTimeRemoteDataSource {
  final Dio dio;
  PrayerTimeRemoteDataSource({required this.dio});

  Future<List<PrayerTimes>> getPrayerTimesList(
    Location location, {
    int? year,
    int? month,
  }) async {
    final queryParameters = <String, dynamic>{
      'latitude': location.latitude,
      'longitude': location.longitude,
    };
    if (year != null) queryParameters['year'] = year;
    if (month != null) queryParameters['month'] = month;

    final Response prayerTimesResponse = await dio.get(
      'http://api.aladhan.com/v1/calendar',
      queryParameters: queryParameters,
    );
    final prayerTimesResponseData = prayerTimesResponse.data['data'];
    return prayerTimesResponseData
        .map<PrayerTimesModel>(
          (dayPrayerTimes) => PrayerTimesModel.fromJson(dayPrayerTimes),
        )
        .toList();
  }
}
