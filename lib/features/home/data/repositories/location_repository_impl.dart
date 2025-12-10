import 'package:quran_app/features/home/data/datasources/location_remote_data_source.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';

class LocationRepositoryImpl extends LocationRepository {
  final LocationRemoteDataSource remoteDataSource;
  LocationRepositoryImpl({required this.remoteDataSource});
  @override
  Future<Location> getCurrentLocation() async {
    return await remoteDataSource.getCurrentLocation();
  }
}
