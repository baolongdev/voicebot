import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/form_repository.dart';
import '../../domain/repositories/form_result.dart';
import '../../domain/models/server_form_data.dart';
import 'package:voicebot/core/system/ota/model/ota_result.dart';
import '../../domain/usecases/submit_form_use_case.dart';
import '../../domain/usecases/validate_form_use_case.dart';

// Ported from Android Compose: FormViewModel.kt
sealed class FormEvent {
  const FormEvent();
}

// Ported from Android Compose: FormViewModel.kt
class FormServerTypeChanged extends FormEvent {
  const FormServerTypeChanged(this.serverType);

  final ServerType serverType;
}

// Ported from Android Compose: FormViewModel.kt
class FormXiaoZhiConfigChanged extends FormEvent {
  const FormXiaoZhiConfigChanged(this.config);

  final XiaoZhiConfig config;
}

// Ported from Android Compose: FormViewModel.kt
class FormSelfHostConfigChanged extends FormEvent {
  const FormSelfHostConfigChanged(this.config);

  final SelfHostConfig config;
}

class FormResultReceived extends FormEvent {
  const FormResultReceived(this.result);

  final FormResult? result;
}

// Ported from Android Compose: FormViewModel.kt
class FormSubmitted extends FormEvent {
  const FormSubmitted();
}

// Ported from Android Compose: FormViewModel.kt
enum FormUiStatus { idle, loading, success, error }

// Ported from Android Compose: FormViewModel.kt
class FormUiState {
  const FormUiState._(this.status, this.message);

  const FormUiState.idle() : this._(FormUiStatus.idle, null);

  const FormUiState.loading() : this._(FormUiStatus.loading, null);

  const FormUiState.success(String message)
      : this._(FormUiStatus.success, message);

  const FormUiState.error(String message)
      : this._(FormUiStatus.error, message);

  final FormUiStatus status;
  final String? message;
}

// Ported from Android Compose: FormViewModel.kt
class FormState {
  const FormState({
    required this.formData,
    required this.validationResult,
    required this.uiState,
    required this.lastResult,
  });

  factory FormState.initial() {
    return const FormState(
      formData: ServerFormData(),
      validationResult: ValidationResult(isValid: true),
      uiState: FormUiState.idle(),
      lastResult: null,
    );
  }

  final ServerFormData formData;
  final ValidationResult validationResult;
  final FormUiState uiState;
  final FormResult? lastResult;

  bool get isLoading => uiState.status == FormUiStatus.loading;

  FormState copyWith({
    ServerFormData? formData,
    ValidationResult? validationResult,
    FormUiState? uiState,
    FormResult? lastResult,
  }) {
    return FormState(
      formData: formData ?? this.formData,
      validationResult: validationResult ?? this.validationResult,
      uiState: uiState ?? this.uiState,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

// Ported from Android Compose: FormViewModel.kt
class FormBloc extends Bloc<FormEvent, FormState> {
  FormBloc({
    required ValidateFormUseCase validateForm,
    required SubmitFormUseCase submitForm,
    required FormRepository repository,
  })  : _validateForm = validateForm,
        _submitForm = submitForm,
        _repository = repository,
        super(FormState.initial()) {
    on<FormServerTypeChanged>(_onServerTypeChanged);
    on<FormXiaoZhiConfigChanged>(_onXiaoZhiConfigChanged);
    on<FormSelfHostConfigChanged>(_onSelfHostConfigChanged);
    on<FormResultReceived>(_onResultReceived);
    on<FormSubmitted>(_onSubmitted);
    _listenRepositoryResults();
  }

  final ValidateFormUseCase _validateForm;
  final SubmitFormUseCase _submitForm;
  final FormRepository _repository;
  final StreamController<String> _navigationController =
      StreamController<String>.broadcast();
  StreamSubscription<FormResult?>? _resultSubscription;

  Stream<String> get navigationStream => _navigationController.stream;

  void _listenRepositoryResults() {
    _resultSubscription = _repository.resultStream.listen((result) {
      if (result == null) {
        return;
      }
      add(FormResultReceived(result));
      if (result is SelfHostResult) {
        _navigationController.add('chat');
        return;
      }
      if (result is XiaoZhiResult) {
        _navigationController.add(_mapNavigationTarget(result.otaResult));
      }
    });
  }

  String _mapNavigationTarget(OtaResult? otaResult) {
    if (otaResult?.activation != null) {
      return 'activation';
    }
    return 'chat';
  }

  void _onServerTypeChanged(
    FormServerTypeChanged event,
    Emitter<FormState> emit,
  ) {
    final nextForm = ServerFormData(
      serverType: event.serverType,
      xiaoZhiConfig: state.formData.xiaoZhiConfig,
      selfHostConfig: state.formData.selfHostConfig,
    );
    emit(_withValidation(nextForm, state.uiState));
  }

  void _onXiaoZhiConfigChanged(
    FormXiaoZhiConfigChanged event,
    Emitter<FormState> emit,
  ) {
    final nextForm = ServerFormData(
      serverType: state.formData.serverType,
      xiaoZhiConfig: event.config,
      selfHostConfig: state.formData.selfHostConfig,
    );
    emit(_withValidation(nextForm, state.uiState));
  }

  void _onSelfHostConfigChanged(
    FormSelfHostConfigChanged event,
    Emitter<FormState> emit,
  ) {
    final nextForm = ServerFormData(
      serverType: state.formData.serverType,
      xiaoZhiConfig: state.formData.xiaoZhiConfig,
      selfHostConfig: event.config,
    );
    emit(_withValidation(nextForm, state.uiState));
  }

  Future<void> _onSubmitted(
    FormSubmitted event,
    Emitter<FormState> emit,
  ) async {
    final validation = _validateForm(state.formData);
    emit(state.copyWith(validationResult: validation));

    if (!validation.isValid) {
      return;
    }

    _logSubmission(state.formData);
    emit(state.copyWith(uiState: const FormUiState.loading()));
    final result = await _submitForm(state.formData);
    emit(
      state.copyWith(
        uiState: result.isSuccess
            ? const FormUiState.success('Gửi thành công')
            : const FormUiState.error('Gửi thất bại'),
      ),
    );
  }

  void _onResultReceived(
    FormResultReceived event,
    Emitter<FormState> emit,
  ) {
    emit(state.copyWith(lastResult: event.result));
    _logResult(event.result);
  }

  FormState _withValidation(ServerFormData formData, FormUiState uiState) {
    final validation = _validateForm(formData);
    return state.copyWith(
      formData: formData,
      validationResult: validation,
      uiState: uiState,
    );
  }

  void _logSubmission(ServerFormData data) {
    // ignore: avoid_print
    print(
      'Submit: type=${data.serverType}, '
      'ws=${data.serverType == ServerType.xiaoZhi ? data.xiaoZhiConfig.webSocketUrl : data.selfHostConfig.webSocketUrl}, '
      'qta=${data.serverType == ServerType.xiaoZhi ? data.xiaoZhiConfig.qtaUrl : '-'}, '
      'transport=${data.serverType == ServerType.xiaoZhi ? data.xiaoZhiConfig.transportType : data.selfHostConfig.transportType}',
    );
  }

  void _logResult(FormResult? result) {
    if (result == null) {
      return;
    }
    if (result is XiaoZhiResult) {
      final ota = result.otaResult;
      // ignore: avoid_print
      print(
        'Result: XiaoZhi, ota='
        'fw=${ota?.firmware?.version ?? '-'} '
        'url=${ota?.firmware?.url ?? '-'} '
        'activation=${ota?.activation?.code ?? '-'}',
      );
      return;
    }
    // ignore: avoid_print
    print('Result: SelfHost');
  }

  @override
  Future<void> close() async {
    await _resultSubscription?.cancel();
    await _navigationController.close();
    return super.close();
  }
}
