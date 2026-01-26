import '../models/server_form_data.dart';

// Ported from Android Kotlin: ValidateFormUseCase.kt
class ValidateFormUseCase {
  const ValidateFormUseCase();

  ValidationResult call(ServerFormData formData) {
    final errors = <String, String>{};

    switch (formData.serverType) {
      case ServerType.xiaoZhi:
        if (formData.xiaoZhiConfig.webSocketUrl.isEmpty) {
          errors['xiaoZhiWebSocketUrl'] = 'WebSocket URL không được để trống';
        }
        if (formData.xiaoZhiConfig.qtaUrl.isEmpty) {
          errors['qtaUrl'] = 'QTA URL không được để trống';
        }
        break;
      case ServerType.selfHost:
        if (formData.selfHostConfig.webSocketUrl.isEmpty) {
          errors['selfHostWebSocketUrl'] = 'WebSocket URL không được để trống';
        }
        break;
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
