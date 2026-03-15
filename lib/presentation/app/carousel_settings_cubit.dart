import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/default_settings.dart';
import 'ui_settings_store.dart';

class CarouselSettings {
  const CarouselSettings({
    required this.height,
    required this.autoPlay,
    required this.autoPlayInterval,
    required this.animationDuration,
    required this.viewportFraction,
    required this.enlargeCenter,
  });

  final double height;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration animationDuration;
  final double viewportFraction;
  final bool enlargeCenter;

  CarouselSettings copyWith({
    double? height,
    bool? autoPlay,
    Duration? autoPlayInterval,
    Duration? animationDuration,
    double? viewportFraction,
    bool? enlargeCenter,
  }) {
    return CarouselSettings(
      height: height ?? this.height,
      autoPlay: autoPlay ?? this.autoPlay,
      autoPlayInterval: autoPlayInterval ?? this.autoPlayInterval,
      animationDuration: animationDuration ?? this.animationDuration,
      viewportFraction: viewportFraction ?? this.viewportFraction,
      enlargeCenter: enlargeCenter ?? this.enlargeCenter,
    );
  }
}

class CarouselSettingsCubit extends Cubit<CarouselSettings> {
  CarouselSettingsCubit(this._store) : super(_defaultState());

  final UiSettingsStore _store;

  static CarouselSettings _defaultState() {
    final defaults = DefaultSettingsRegistry.current.carousel;
    return CarouselSettings(
      height: defaults.height,
      autoPlay: defaults.autoPlay,
      autoPlayInterval: defaults.autoPlayInterval,
      animationDuration: defaults.animationDuration,
      viewportFraction: defaults.viewportFraction,
      enlargeCenter: defaults.enlargeCenter,
    );
  }

  Future<void> hydrate() async {
    final height = await _store.readCarouselHeight();
    final autoPlay = await _store.readCarouselAutoPlay();
    final intervalMs = await _store.readCarouselIntervalMs();
    final animMs = await _store.readCarouselAnimationMs();
    final viewport = await _store.readCarouselViewport();
    final enlarge = await _store.readCarouselEnlarge();
    emit(
      state.copyWith(
        height: height ?? state.height,
        autoPlay: autoPlay ?? state.autoPlay,
        autoPlayInterval: intervalMs != null
            ? Duration(milliseconds: intervalMs)
            : state.autoPlayInterval,
        animationDuration: animMs != null
            ? Duration(milliseconds: animMs)
            : state.animationDuration,
        viewportFraction: viewport ?? state.viewportFraction,
        enlargeCenter: enlarge ?? state.enlargeCenter,
      ),
    );
  }

  void setHeight(double value) {
    emit(state.copyWith(height: value));
    unawaited(_store.writeCarouselHeight(value));
  }

  void setAutoPlay(bool enabled) {
    emit(state.copyWith(autoPlay: enabled));
    unawaited(_store.writeCarouselAutoPlay(enabled));
  }

  void setInterval(Duration interval) {
    emit(state.copyWith(autoPlayInterval: interval));
    unawaited(_store.writeCarouselIntervalMs(interval.inMilliseconds));
  }

  void setAnimationDuration(Duration duration) {
    emit(state.copyWith(animationDuration: duration));
    unawaited(_store.writeCarouselAnimationMs(duration.inMilliseconds));
  }

  void setViewportFraction(double value) {
    emit(state.copyWith(viewportFraction: value));
    unawaited(_store.writeCarouselViewport(value));
  }

  void setEnlargeCenter(bool enabled) {
    emit(state.copyWith(enlargeCenter: enabled));
    unawaited(_store.writeCarouselEnlarge(enabled));
  }
}
