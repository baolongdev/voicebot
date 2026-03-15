import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/default_settings.dart';
import 'ui_settings_store.dart';

class AutoReconnectCubit extends Cubit<bool> {
  AutoReconnectCubit(this._store)
    : super(DefaultSettingsRegistry.current.chat.autoReconnect);

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readAutoReconnectEnabled();
    if (saved != null) {
      emit(saved);
    }
  }

  void setEnabled(bool enabled) {
    emit(enabled);
    unawaited(_store.writeAutoReconnectEnabled(enabled));
  }
}
