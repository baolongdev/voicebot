import '../repositories/form_repository.dart';
import '../models/server_form_data.dart';

// Ported from Android Kotlin: SubmitFormUseCase.kt
class SubmitFormUseCase {
  const SubmitFormUseCase(this._repository);

  final FormRepository _repository;

  Future<Result<void>> call(ServerFormData formData) async {
    try {
      await _repository.submitForm(formData);
      return Result.success();
    } on Exception catch (e) {
      return Result.failure<void>(e);
    }
  }
}

// Ported from Android Kotlin: SubmitFormUseCase.kt
class Result<T> {
  const Result._(this.value, this.error);

  final T? value;
  final Exception? error;

  bool get isSuccess => error == null;

  static Result<void> success() => const Result<void>._(null, null);

  static Result<T> failure<T>(Exception error) => Result<T>._(null, error);
}
