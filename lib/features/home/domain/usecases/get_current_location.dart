import 'package:quran_app/features/home/domain/entities/location.dart';

abstract class GetCurrentLocationUseCase {
  Future<Location> call();
}
