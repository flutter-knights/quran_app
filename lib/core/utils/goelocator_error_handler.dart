// ⚙️ lib/core/utils/geolocator_error_handler.dart

import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';

class GeolocatorErrorHandler {
  static Failure handle(Object error) {
    if (error is LocationServiceDisabledException) {
      return const LocationServiceDisabledFailure(
        'Location services are disabled. Please enable GPS in settings.',
      );
    }

    if (error is LocationPermissionDeniedForeverException) {
      return const LocationPermissionDeniedForeverFailure(
        'Location permission is permanently denied. You must enable it manually in your device settings.',
      );
    }

    if (error is LocationPermissionDeniedException) {
      return const LocationPermissionDeniedFailure(
        'Location permission was denied. Please accept the request to use location.',
      );
    }

    if (error is LocationTimeoutException) {
      return const TimeoutFailure(
        'Failed to get location within the specified time.',
      );
    }

    return UnknownFailure(
      'An unexpected location error occurred: ${error.toString()}',
    );
  }
}
