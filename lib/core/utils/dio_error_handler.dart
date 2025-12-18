import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';

class DioErrorHandler {
  static Failure handle(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const TimeoutFailure("Server took too long to respond.");

      case DioExceptionType.badCertificate:
        return const ServerFailure("Bad SSL certificate.");

      case DioExceptionType.connectionError:
        return const NetworkFailure("No internet connection.");

      case DioExceptionType.badResponse:
        return _handleBadResponse(error);

      case DioExceptionType.cancel:
        return const UnknownFailure("Request was cancelled.");

      default:
        return const UnknownFailure("Unexpected error occurred.");
    }
  }

  static Failure _handleBadResponse(DioException error) {
    final status = error.response?.statusCode ?? 0;

    switch (status) {
      case 400:
        return BadRequestFailure(
          error.response?.data["message"] ?? "Bad request.",
        );

      case 401:
      case 403:
        return UnauthorizedFailure("Unauthorized request.");

      case 404:
        return NotFoundFailure("Requested data not found.");

      case 500:
      case 502:
      case 503:
        return ServerFailure("Server error occurred.");

      default:
        return ServerFailure("Unknown server error ($status).");
    }
  }
}
