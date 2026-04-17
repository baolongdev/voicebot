import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/default_settings.dart';
import 'ui_settings_store.dart';

class RelatedImagesSettings {
  const RelatedImagesSettings({required this.enabled});

  final bool enabled;

  RelatedImagesSettings copyWith({bool? enabled}) {
    return RelatedImagesSettings(enabled: enabled ?? this.enabled);
  }
}

class RelatedImagesSettingsCubit extends Cubit<RelatedImagesSettings> {
  RelatedImagesSettingsCubit(this._store) : super(_defaultState());

  final UiSettingsStore _store;

  static RelatedImagesSettings _defaultState() {
    final defaults = DefaultSettingsRegistry.current.chat;
    return RelatedImagesSettings(enabled: defaults.relatedImagesEnabled);
  }

  void hydrate() {
    _store.readRelatedImagesEnabled().then((enabled) {
      if (isClosed) {
        return;
      }
      emit(RelatedImagesSettings(enabled: enabled ?? _defaultState().enabled));
    });
  }

  Future<void> setEnabled(bool value) async {
    emit(state.copyWith(enabled: value));
    await _store.writeRelatedImagesEnabled(value);
  }
}
