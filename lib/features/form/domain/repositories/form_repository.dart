import '../models/server_form_data.dart';
import 'form_result.dart';

// Ported from Android Kotlin: FormRepository.kt
abstract class FormRepository {
  Future<void> submitForm(ServerFormData formData);

  Stream<FormResult?> get resultStream;

  FormResult? get lastResult;
}
