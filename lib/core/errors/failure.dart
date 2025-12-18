abstract class Failure {
  final String message;
  const Failure(this.message);
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
