import 'package:voicebot/core/system/ota/model/ota_result.dart';

// Ported from Android Kotlin: FormRepository.kt
abstract class FormResult {
  const FormResult();
}

// Ported from Android Kotlin: FormRepository.kt
class SelfHostResult extends FormResult {
  const SelfHostResult();
}

// Ported from Android Kotlin: FormRepository.kt
class XiaoZhiResult extends FormResult {
  const XiaoZhiResult(this.otaResult);

  final OtaResult? otaResult;
}

