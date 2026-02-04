import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_config.dart';
import 'ui_settings_store.dart';

class ConnectGreetingCubit extends Cubit<String> {
  ConnectGreetingCubit(this._store)
      : super(AppConfig.connectGreetingDefault);

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readConnectGreeting();
    if (saved != null) {
      emit(saved);
    }
  }

  void setGreeting(String value) {
    emit(value);
    unawaited(_store.writeConnectGreeting(value));
  }
}
