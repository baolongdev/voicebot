import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_config.dart';
import '../../core/system/ota/ota_service.dart';
import 'ui_settings_store.dart';

class DeviceMacCubit extends Cubit<String> {
  DeviceMacCubit(this._store, this._ota)
      : super(AppConfig.defaultMacAddress);

  final UiSettingsStore _store;
  final OtaService _ota;

  Future<void> hydrate() async {
    final saved = await _store.readDeviceMacAddress();
    if (saved != null && saved.isNotEmpty) {
      emit(saved);
      return;
    }
    if (AppConfig.defaultMacAddress.isNotEmpty) {
      emit(AppConfig.defaultMacAddress);
    }
  }

  void setMacAddress(String value) {
    final trimmed = value.trim();
    final next =
        trimmed.isEmpty ? AppConfig.defaultMacAddress : value;
    emit(next);
    unawaited(_store.writeDeviceMacAddress(next));
    unawaited(_ota.refreshIdentity());
  }
}
