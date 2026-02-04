import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../capabilities/protocol/protocol.dart';
import 'ui_settings_store.dart';

class ListeningModeCubit extends Cubit<ListeningMode> {
  ListeningModeCubit(this._store) : super(ListeningMode.autoStop);

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readListeningMode();
    if (saved != null) {
      emit(saved);
    }
  }

  void setMode(ListeningMode mode) {
    emit(mode);
    unawaited(_store.writeListeningMode(mode));
  }
}
