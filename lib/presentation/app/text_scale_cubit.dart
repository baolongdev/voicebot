import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/default_settings.dart';
import 'ui_settings_store.dart';

class TextScaleCubit extends Cubit<double> {
  TextScaleCubit(this._store)
    : super(DefaultSettingsRegistry.current.theme.textScale.clamp(0.85, 1.5));

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readTextScale();
    if (saved != null) {
      emit(saved.clamp(0.85, 1.5));
    }
  }

  void setScale(double scale) {
    final value = scale.clamp(0.85, 1.5);
    emit(value);
    unawaited(_store.writeTextScale(value));
  }
}
