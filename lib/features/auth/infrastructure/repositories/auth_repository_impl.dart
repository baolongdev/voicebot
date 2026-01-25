import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_ds.dart';
import '../datasources/auth_remote_ds.dart';
import '../mappers/user_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.mapper,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final UserMapper mapper;

  @override
  Future<Result<UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await remote.login(email: email, password: password);
      await local.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return Result.success(mapper.toEntity(response.user));
    } on AuthApiException catch (error) {
      return Result.failure(
        Failure(message: 'Login failed', code: '${error.statusCode}'),
      );
    } catch (error) {
      return Result.failure(Failure(message: error.toString()));
    }
  }

  @override
  Future<void> logout() async {
    await local.clear();
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final dto = await local.getCurrentUser();
    return dto == null ? null : mapper.toEntity(dto);
  }

  @override
  Future<Result<UserEntity?>> restoreSession() async {
    try {
      final token = await local.getAccessToken();
      if (token == null || token.isEmpty) {
        return Result.success(null);
      }

      final userDto = await remote.getProfile(accessToken: token);
      return Result.success(mapper.toEntity(userDto));
    } on AuthApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await local.clearToken();
        return Result.success(null);
      }
      return Result.failure(
        Failure(message: 'Restore session failed', code: '${error.statusCode}'),
      );
    } catch (error) {
      return Result.failure(Failure(message: error.toString()));
    }
  }
}
