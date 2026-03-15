import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/default_settings.dart';
import '../../core/system/ota/ota_service.dart';
import 'ui_settings_store.dart';

class DeviceMacCubit extends Cubit<String> {
  DeviceMacCubit(this._store, this._ota)
    : super(DefaultSettingsRegistry.current.device.defaultMacAddress);

  final UiSettingsStore _store;
  final OtaService _ota;

  Future<void> hydrate() async {
    final saved = await _store.readDeviceMacAddress();
    if (saved != null && saved.isNotEmpty) {
      emit(saved);
      return;
    }
    final defaultMac = DefaultSettingsRegistry.current.device.defaultMacAddress;
    if (defaultMac.isNotEmpty) {
      emit(defaultMac);
    }
  }

  void setMacAddress(String value) {
    final trimmed = value.trim();
    final defaultMac = DefaultSettingsRegistry.current.device.defaultMacAddress;
    final next = trimmed.isEmpty ? defaultMac : value;
    emit(next);
    unawaited(_store.writeDeviceMacAddress(next));
    unawaited(_ota.refreshIdentity());
  }
}
