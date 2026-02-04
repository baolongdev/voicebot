import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/form_repository.dart';
import '../models/server_form_data.dart';

// Ported from Android Kotlin: SubmitFormUseCase.kt
class SubmitFormUseCase {
  const SubmitFormUseCase(this._repository);

  final FormRepository _repository;

  Future<Result<bool>> call(ServerFormData formData) async {
    try {
      await _repository.submitForm(formData);
      return Result.success(true);
    } catch (e) {
      return Result.failure(
        Failure(message: e.toString()),
      );
    }
  }
}
