import '../../../../core/result/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity>> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }
}
