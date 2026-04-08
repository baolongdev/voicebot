import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/form_repository.dart';
import '../models/server_form_data.dart';

typedef EitherFailure<R> = Either<Failure, R>;

class SubmitFormUseCase {
  const SubmitFormUseCase(this._repository);

  final FormRepository _repository;

  Future<EitherFailure<bool>> call(ServerFormData formData) async {
    try {
      await _repository.submitForm(formData);
      return right(true);
    } on Failure catch (e) {
      return left(e);
    } catch (e) {
      return left(ServerFailure(message: e.toString()));
    }
  }
}
