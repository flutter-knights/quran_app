import 'package:dio/dio.dart';

import '../utils/dio_error_handler.dart';
import '../utils/geolocator_error_handler.dart';
import 'exceptions.dart';

abstract class Failure {
  final String message;
  const Failure(this.message);
  factory Failure.fromException(dynamic exception) {
    if (exception is DioException) {
      return DioErrorHandler.handle(exception);
    } else if (exception is LocationException) {
      return GeolocatorErrorHandler.handle(exception);
    } else {
      return UnknownFailure("Unexpected error occurred.");
    }
  }
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message);
}

class BadRequestFailure extends Failure {
  const BadRequestFailure(super.message);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

class LocationServiceDisabledFailure extends Failure {
  const LocationServiceDisabledFailure(super.message);
}

class LocationPermissionDeniedFailure extends Failure {
  const LocationPermissionDeniedFailure(super.message);
}

class LocationPermissionDeniedForeverFailure extends Failure {
  const LocationPermissionDeniedForeverFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
