import 'package:dartz/dartz.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerTimesRepository {
  Future<Either<Failure, PrayerTimes>> getPrayerTimes(Location location);
}
