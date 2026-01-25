import '../../domain/entities/user_entity.dart';
import '../models/user_dto.dart';

class UserMapper {
  const UserMapper();

  UserEntity toEntity(UserDto dto) {
    return UserEntity(id: dto.id, email: dto.email, name: dto.name);
  }
}
