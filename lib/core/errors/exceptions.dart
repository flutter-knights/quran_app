class CacheException implements Exception {
  CacheException(this.message);
  final String message;
  @override
  String toString() => 'CacheException: $message';
}

abstract class LocationException implements Exception {}

class LocationServiceDisabledException extends LocationException {}

class LocationPermissionDeniedException extends LocationException {}

class LocationPermissionDeniedForeverException extends LocationException {}

class LocationTimeoutException extends LocationException {}
