import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/theme_palette.dart';
import 'ui_settings_store.dart';

class ThemePaletteCubit extends Cubit<AppThemePalette> {
  ThemePaletteCubit(this._store) : super(AppThemePalette.green);

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final saved = await _store.readThemePalette();
    if (saved != null && saved != state) {
      emit(saved);
    }
  }

  Future<void> setPalette(AppThemePalette palette) async {
    if (palette == state) {
      return;
    }
    emit(palette);
    await _store.writeThemePalette(palette);
  }
}
