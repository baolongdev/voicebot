import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ui_settings_store.dart';

class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit(this._store) : super(ThemeMode.system);

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readThemeMode();
    if (saved != null) {
      emit(saved);
    }
  }

  void setLight() {
    emit(ThemeMode.light);
    unawaited(_store.writeThemeMode(ThemeMode.light));
  }

  void setDark() {
    emit(ThemeMode.dark);
    unawaited(_store.writeThemeMode(ThemeMode.dark));
  }

  void setSystem() {
    emit(ThemeMode.system);
    unawaited(_store.writeThemeMode(ThemeMode.system));
  }
}
