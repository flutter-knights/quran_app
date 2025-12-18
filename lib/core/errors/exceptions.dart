abstract class LocationException implements Exception {}

class LocationServiceDisabledException extends LocationException {}

class LocationPermissionDeniedException extends LocationException {}

class LocationPermissionDeniedForeverException extends LocationException {}

class LocationTimeoutException extends LocationException {}
