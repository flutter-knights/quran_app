import 'package:hive_ce/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../domain/entities/place.dart';
import '../../models/place_record_model.dart';

class PlacesLocalDataSource {
  PlacesLocalDataSource({required this.box});
  final Box<PlaceRecordModel> box;

  List<Place> getAll() => [for (final record in box.values) record.toEntity()];

  Future<void> save(Place place) async {
    try {
      await box.put(place.id, PlaceRecordModel.fromEntity(place));
    } catch (e) {
      throw CacheException('place save failed: $e');
    }
  }

  Future<void> remove(String id) async {
    try {
      await box.delete(id);
    } catch (e) {
      throw CacheException('place remove failed: $e');
    }
  }
}
