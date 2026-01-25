import '../../../../core/result/result.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class CheckAuthUseCase {
  const CheckAuthUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity?>> call() {
    return _repository.restoreSession();
  }
}
