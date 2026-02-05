import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'ui_settings_store.dart';

class FaceDetectionSettings {
  const FaceDetectionSettings({
    required this.landmarksEnabled,
    required this.meshEnabled,
    required this.eyeTrackingEnabled,
  });

  final bool landmarksEnabled;
  final bool meshEnabled;
  final bool eyeTrackingEnabled;

  FaceDetectionSettings copyWith({
    bool? landmarksEnabled,
    bool? meshEnabled,
    bool? eyeTrackingEnabled,
  }) {
    return FaceDetectionSettings(
      landmarksEnabled: landmarksEnabled ?? this.landmarksEnabled,
      meshEnabled: meshEnabled ?? this.meshEnabled,
      eyeTrackingEnabled: eyeTrackingEnabled ?? this.eyeTrackingEnabled,
    );
  }
}

class FaceDetectionSettingsCubit extends Cubit<FaceDetectionSettings> {
  FaceDetectionSettingsCubit(this._store)
      : super(
          const FaceDetectionSettings(
            landmarksEnabled: false,
            meshEnabled: false,
            eyeTrackingEnabled: false,
          ),
        );

  final UiSettingsStore _store;

  Future<void> hydrate() async {
    final landmarks = await _store.readFaceLandmarksEnabled();
    final mesh = await _store.readFaceMeshEnabled();
    final eyeTracking = await _store.readEyeTrackingEnabled();
    emit(
      state.copyWith(
        landmarksEnabled: landmarks ?? state.landmarksEnabled,
        meshEnabled: mesh ?? state.meshEnabled,
        eyeTrackingEnabled: eyeTracking ?? state.eyeTrackingEnabled,
      ),
    );
  }

  void setLandmarksEnabled(bool enabled) {
    emit(state.copyWith(landmarksEnabled: enabled));
    unawaited(_store.writeFaceLandmarksEnabled(enabled));
  }

  void setMeshEnabled(bool enabled) {
    emit(state.copyWith(meshEnabled: enabled));
    unawaited(_store.writeFaceMeshEnabled(enabled));
  }

  void setEyeTrackingEnabled(bool enabled) {
    emit(state.copyWith(eyeTrackingEnabled: enabled));
    unawaited(_store.writeEyeTrackingEnabled(enabled));
  }
}
