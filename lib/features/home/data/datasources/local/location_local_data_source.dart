import 'package:hive/hive.dart';
import 'package:quran_app/features/home/data/models/location_hive_model.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';

class LocationLocalDataSource {
  Box<LocationHiveModel> locationHiveBox;
  LocationLocalDataSource({required this.locationHiveBox});

  Future<void> cache(Location location) async {
    locationHiveBox.put('userLocation', location.toHive());
  }

  Location? getCached() {
    final locationHiveModel = locationHiveBox.get('userLocation');
    if (locationHiveModel == null) return null;
    return locationHiveModel.toEntity();
  }

  void clearCache() {
    locationHiveBox.clear();
  }
}
