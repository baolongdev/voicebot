import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../core/errors/failure.dart';
import '../../core/network/dio_client.dart';

typedef ApiResult<R> = Either<Failure, R>;

class ApiService {
  ApiService({required DioClient client}) : _client = client;

  final DioClient _client;

  Future<ApiResult<Map<String, dynamic>>> get(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      if (response.data != null) {
        return right(response.data!);
      }
      return left(const ServerFailure(message: 'Empty response'));
    } on DioException catch (e) {
      return left(_handleDioError(e));
    } catch (e) {
      return left(ServerFailure(message: e.toString()));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      if (response.data != null) {
        return right(response.data!);
      }
      return left(const ServerFailure(message: 'Empty response'));
    } on DioException catch (e) {
      return left(_handleDioError(e));
    } catch (e) {
      return left(ServerFailure(message: e.toString()));
    }
  }

  Failure _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(message: e.message ?? 'Connection timeout');
      case DioExceptionType.connectionError:
        return NetworkFailure(message: e.message ?? 'Connection error');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        if (statusCode == 401) {
          return UnauthorizedFailure(message: e.message ?? 'Unauthorized');
        }
        return ServerFailure(
          message: e.message ?? 'Server error',
          code: statusCode.toString(),
        );
      default:
        return ServerFailure(message: e.message ?? 'Unknown error');
    }
  }
}
