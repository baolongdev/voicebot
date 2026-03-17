import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import '../../../features/chat/application/state/chat_cubit.dart';
import '../../../features/chat/application/state/chat_state.dart';
import 'connection_status_banner.dart';
import 'emotion_palette.dart';
import 'home_camera_overlay.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.palette,
    required this.currentEmotion,
    required this.carouselImages,
    required this.cameraEnabled,
    required this.cameraAspectRatio,
    required this.onCameraEnabledChanged,
    required this.onFacePresenceChanged,
    required this.detectFacesEnabled,
    required this.faceLandmarksEnabled,
    required this.faceMeshEnabled,
    required this.eyeTrackingEnabled,
    required this.carouselHeight,
    required this.carouselAutoPlay,
    required this.carouselAutoPlayInterval,
    required this.carouselAnimationDuration,
    required this.carouselViewportFraction,
    required this.carouselEnlargeCenter,
  });

  final EmotionPalette palette;
  final String? currentEmotion;
  final List<String> carouselImages;
  final bool cameraEnabled;
  final double cameraAspectRatio;
  final ValueChanged<bool> onCameraEnabledChanged;
  final ValueChanged<bool> onFacePresenceChanged;
  final bool detectFacesEnabled;
  final bool faceLandmarksEnabled;
  final bool faceMeshEnabled;
  final bool eyeTrackingEnabled;
  final double carouselHeight;
  final bool carouselAutoPlay;
  final Duration carouselAutoPlayInterval;
  final Duration carouselAnimationDuration;
  final double carouselViewportFraction;
  final bool carouselEnlargeCenter;

  static const double audioActiveThreshold = 0.02;

  static const Map<String, String> _emotionEmojiMap = <String, String>{
    'neutral': '🙂',
    'happy': '😁',
    'laughing': '😆',
    'funny': '🤡',
    'silly': '🤪',
    'confident': '😏',
    'loving': '🥰',
    'kissy': '😘',
    'embarrassed': '😳',
    'winking': '😉',
    'sad': '🥺',
    'crying': '😭',
    'sleepy': '😴',
    'angry': '😠',
    'surprised': '😮',
    'shocked': '😱',
    'thinking': '🤔',
    'relaxed': '😌',
    'cool': '😎',
    'delicious': '🤤',
    'confused': '😕',
  };

  static const Map<String, String> _emotionAliases = <String, String>{
    'calm': 'relaxed',
    'casual': 'cool',
    'cheerful': 'happy',
    'clown': 'funny',
    'comforting': 'loving',
    'content': 'relaxed',
    'curious': 'thinking',
    'delighted': 'happy',
    'depressed': 'sad',
    'ecstatic': 'laughing',
    'elated': 'happy',
    'emotional': 'crying',
    'excited': 'happy',
    'flirty': 'kissy',
    'frustrated': 'angry',
    'giggle': 'laughing',
    'giggly': 'laughing',
    'glad': 'happy',
    'gloomy': 'sad',
    'grateful': 'loving',
    'grin': 'happy',
    'grinning': 'happy',
    'heartbroken': 'crying',
    'hilarious': 'laughing',
    'joking': 'funny',
    'joy': 'happy',
    'joyful': 'happy',
    'kiss': 'kissy',
    'laugh': 'laughing',
    'love': 'loving',
    'loved': 'loving',
    'melancholy': 'sad',
    'mischievous': 'silly',
    'nervous': 'embarrassed',
    'panic': 'shocked',
    'panicked': 'shocked',
    'peaceful': 'relaxed',
    'playful': 'silly',
    'proud': 'confident',
    'rage': 'angry',
    'scared': 'shocked',
    'serious': 'neutral',
    'smile': 'happy',
    'smiling': 'happy',
    'sorrowful': 'sad',
    'tearful': 'crying',
    'teary': 'crying',
    'touched': 'loving',
    'upset': 'sad',
    'worried': 'thinking',
    'yummy': 'delicious',
  };

  @override
  Widget build(BuildContext context) {
    final images = carouselImages;
    final emotionEmoji = _resolveEmotionEmoji(currentEmotion);
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(0.85, 1.5);
    final mascotOuterSize = ThemeTokens.homeMascotOuterSize * textScale;
    final mascotInnerSize = ThemeTokens.homeMascotInnerSize * textScale;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
      child: Container(
        width: double.infinity,
        color: palette.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: ThemeTokens.spaceSm),
                      BlocSelector<ChatCubit, ChatState, ConnectionStatusData>(
                        selector: (state) => ConnectionStatusData(
                          status: state.status,
                          isSpeaking: state.isSpeaking,
                          outgoingLevel: state.outgoingLevel,
                          error: state.connectionError,
                          networkWarning: state.networkWarning,
                        ),
                        builder: (context, data) {
                          return ConnectionStatusBanner(
                            palette: palette,
                            audioThreshold: audioActiveThreshold,
                            data: data,
                          );
                        },
                      ),
                      const SizedBox(height: ThemeTokens.spaceSm),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: mascotOuterSize,
                            height: mascotOuterSize,
                            child: Center(
                              child: SizedBox(
                                width: mascotInnerSize,
                                height: mascotInnerSize,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Text(
                                    emotionEmoji,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: mascotInnerSize * 0.72,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (images.isNotEmpty)
                        _BottomCarousel(
                          palette: palette,
                          images: images,
                          height: carouselHeight,
                          autoPlay: carouselAutoPlay,
                          autoPlayInterval: carouselAutoPlayInterval,
                          animationDuration: carouselAnimationDuration,
                          viewportFraction: carouselViewportFraction,
                          enlargeCenter: carouselEnlargeCenter,
                        ),
                    ],
                  ),
                ),
                HomeCameraOverlay(
                  areaSize: Size(constraints.maxWidth, constraints.maxHeight),
                  enabled: cameraEnabled,
                  onEnabledChanged: onCameraEnabledChanged,
                  onFacePresenceChanged: onFacePresenceChanged,
                  detectFacesEnabled: detectFacesEnabled,
                  aspectRatio: cameraAspectRatio,
                  faceLandmarksEnabled: faceLandmarksEnabled,
                  faceMeshEnabled: faceMeshEnabled,
                  eyeTrackingEnabled: eyeTrackingEnabled,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _resolveEmotionEmoji(String? emotion) {
    final normalized = _normalizeEmotion(emotion);
    if (normalized == null || normalized.isEmpty) {
      return _emotionEmojiMap['neutral']!;
    }
    return _emotionEmojiMap[normalized] ?? _emotionEmojiMap['neutral']!;
  }

  String? _normalizeEmotion(String? rawEmotion) {
    final normalized = rawEmotion?.toLowerCase().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (_emotionEmojiMap.containsKey(normalized)) {
      return normalized;
    }
    final alias = _emotionAliases[normalized];
    if (alias != null) {
      return alias;
    }

    for (final entry in _emotionAliases.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    for (final key in _emotionEmojiMap.keys) {
      if (normalized.contains(key)) {
        return key;
      }
    }
    return 'neutral';
  }
}

class _BottomCarousel extends StatefulWidget {
  const _BottomCarousel({
    required this.palette,
    required this.images,
    required this.height,
    required this.autoPlay,
    required this.autoPlayInterval,
    required this.animationDuration,
    required this.viewportFraction,
    required this.enlargeCenter,
  });

  final EmotionPalette palette;
  final List<String> images;
  final double height;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration animationDuration;
  final double viewportFraction;
  final bool enlargeCenter;

  @override
  State<_BottomCarousel> createState() => _BottomCarouselState();
}

class _BottomCarouselState extends State<_BottomCarousel>
    with TickerProviderStateMixin {
  static const double _carouselAspectRatio = 5 / 4;
  int _currentIndex = 0;
  int _cacheWidthPx = 0;
  int _cacheHeightPx = 0;
  String _lastPrecacheSignature = '';

  @override
  void didUpdateWidget(covariant _BottomCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.images, widget.images)) {
      _currentIndex = 0;
      _lastPrecacheSignature = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _precacheNearby(_currentIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
        final viewport = widget.viewportFraction.clamp(0.4, 1.0);
        final height = _resolveCarouselHeight(width, viewport);
        _cacheWidthPx = (width * viewport * dpr).round();
        _cacheHeightPx = (height * dpr).round();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _precacheNearby(_currentIndex);
        });
        return AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CarouselSlider.builder(
              itemCount: widget.images.length,
              itemBuilder: (context, index, _) {
                final imageUrl = widget.images[index];
                return GestureDetector(
                  onTap: () => _openImagePreview(context, imageUrl),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: ThemeTokens.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: widget.palette.controlBackground(context),
                      borderRadius: BorderRadius.circular(ThemeTokens.radiusLg),
                      border: Border.all(
                        color: widget.palette.controlBorder(context),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: _cacheWidthPx > 0
                                ? _cacheWidthPx
                                : null,
                            cacheHeight: _cacheHeightPx > 0
                                ? _cacheHeightPx
                                : null,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    'Hình ảnh lỗi',
                                    style: context.theme.typography.sm.copyWith(
                                      color: widget.palette.controlForeground(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) {
                                return child;
                              }
                              return Center(
                                child: Text(
                                  'Đang tải...',
                                  style: context.theme.typography.sm.copyWith(
                                    color: widget.palette.controlForeground(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                widget.palette
                                    .controlBackground(context)
                                    .withValues(alpha: 0.35),
                                widget.palette
                                    .controlBackground(context)
                                    .withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: height,
                viewportFraction: widget.viewportFraction.clamp(0.4, 1.0),
                enlargeCenterPage: widget.enlargeCenter,
                enableInfiniteScroll: true,
                autoPlay: widget.autoPlay,
                autoPlayInterval: widget.autoPlayInterval,
                autoPlayAnimationDuration: widget.animationDuration,
                autoPlayCurve: Curves.easeOutCubic,
                pauseAutoPlayOnTouch: true,
                onPageChanged: (index, _) {
                  if (!mounted || _currentIndex == index) {
                    return;
                  }
                  setState(() {
                    _currentIndex = index;
                  });
                  _precacheNearby(index);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double _resolveCarouselHeight(double width, double viewport) {
    if (width <= 0) {
      return 0;
    }
    final itemWidth = width * viewport;
    final computed = itemWidth / _carouselAspectRatio;
    if (!computed.isFinite || computed <= 0) {
      return 0;
    }
    // Hard-enforce 5:4 card ratio across all screen sizes.
    return computed;
  }

  void _precacheNearby(int centerIndex) {
    if (widget.images.isEmpty || _cacheWidthPx <= 0 || _cacheHeightPx <= 0) {
      return;
    }
    final signature =
        '$centerIndex|${widget.images.length}|$_cacheWidthPx|$_cacheHeightPx';
    if (_lastPrecacheSignature == signature) {
      return;
    }
    _lastPrecacheSignature = signature;
    for (final offset in const <int>[-1, 1]) {
      final next = centerIndex + offset;
      if (next < 0 || next >= widget.images.length) {
        continue;
      }
      final provider = ResizeImage(
        NetworkImage(widget.images[next]),
        width: _cacheWidthPx,
        height: _cacheHeightPx,
      );
      unawaited(precacheImage(provider, context));
    }
  }
}

void _openImagePreview(BuildContext context, String imageUrl) {
  showDialog<void>(
    context: context,
    barrierColor: context.theme.colors.barrier,
    builder: (context) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: context.theme.colors.background,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          'Hình ảnh lỗi',
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }
                        return Center(
                          child: Text(
                            'Đang tải...',
                            style: context.theme.typography.sm.copyWith(
                              color: context.theme.colors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: ThemeTokens.spaceSm,
                  right: ThemeTokens.spaceSm,
                  child: FButton.icon(
                    onPress: () => Navigator.of(context).pop(),
                    child: const Icon(FIcons.x),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

