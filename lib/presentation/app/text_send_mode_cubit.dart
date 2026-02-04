import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../capabilities/protocol/protocol.dart';
import 'ui_settings_store.dart';

class TextSendModeCubit extends Cubit<TextSendMode> {
  TextSendModeCubit(this._store) : super(TextSendMode.listenDetect);

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readTextSendMode();
    if (saved != null) {
      emit(saved);
    }
  }

  void setMode(TextSendMode mode) {
    emit(mode);
    unawaited(_store.writeTextSendMode(mode));
  }
}
