import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import 'connection_status_banner.dart';
import 'emotion_palette.dart';
import 'home_camera_overlay.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.palette,
    required this.connectionData,
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
  final ConnectionStatusData connectionData;
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
  @override
  Widget build(BuildContext context) {
    final images = carouselImages;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
                      ConnectionStatusBanner(
                        palette: palette,
                        audioThreshold: audioActiveThreshold,
                        data: connectionData,
                      ),
                      const SizedBox(height: ThemeTokens.spaceSm),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: CustomPaint(
                                  painter: _SmileFacePainter(
                                    color: palette.accentForeground,
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
  final Map<String, double> _aspectRatios = <String, double>{};
  final Set<String> _pendingAspectRatio = <String>{};
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant _BottomCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.images, widget.images)) {
      _currentIndex = 0;
      _pendingAspectRatio.removeWhere(
        (url) => !widget.images.contains(url),
      );
      _aspectRatios.removeWhere(
        (url, _) => !widget.images.contains(url),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = _resolveCarouselHeight(width);
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
                _ensureAspectRatio(imageUrl);
                return GestureDetector(
                  onTap: () => _openImagePreview(context, imageUrl),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: ThemeTokens.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: widget.palette.controlBackground(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.palette.controlBorder(context),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              'Hình ảnh lỗi',
                              style: context.theme.typography.sm.copyWith(
                                color:
                                    widget.palette.controlForeground(context),
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
                                  color:
                                      widget.palette.controlForeground(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
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
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double _resolveCarouselHeight(double width) {
    if (widget.images.isEmpty || width <= 0) {
      return widget.height;
    }
    final safeIndex = _currentIndex.clamp(0, widget.images.length - 1);
    final url = widget.images[safeIndex];
    final ratio = _aspectRatios[url];
    if (ratio == null || ratio <= 0) {
      return widget.height;
    }
    final computed = width / ratio;
    if (!computed.isFinite || computed <= 0) {
      return widget.height;
    }
    return computed;
  }

  void _ensureAspectRatio(String url) {
    if (_aspectRatios.containsKey(url) || _pendingAspectRatio.contains(url)) {
      return;
    }
    _pendingAspectRatio.add(url);
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (width > 0 && height > 0) {
          _aspectRatios[url] = width / height;
        }
        _pendingAspectRatio.remove(url);
        stream.removeListener(listener);
        if (!mounted) {
          return;
        }
        setState(() {});
      },
      onError: (_, __) {
        _pendingAspectRatio.remove(url);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
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

class _SmileFacePainter extends CustomPainter {
  const _SmileFacePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final eyeOffsetX = size.width * 0.18;
    final eyeOffsetY = size.height * 0.08;
    final eyeRadius = size.width * 0.04;

    canvas.drawCircle(
      Offset(center.dx - eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      dotPaint,
    );

    final nosePath = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.02)
      ..lineTo(center.dx - size.width * 0.02, center.dy + size.height * 0.03)
      ..lineTo(center.dx + size.width * 0.02, center.dy + size.height * 0.03);
    canvas.drawPath(nosePath, linePaint);

    final smileRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size.height * 0.12),
      width: size.width * 0.32,
      height: size.height * 0.18,
    );
    canvas.drawArc(smileRect, 0, 3.14, false, linePaint);

    final hairPath = Path()
      ..moveTo(center.dx - size.width * 0.1, center.dy - size.height * 0.32)
      ..cubicTo(
        center.dx - size.width * 0.02,
        center.dy - size.height * 0.42,
        center.dx + size.width * 0.08,
        center.dy - size.height * 0.38,
        center.dx + size.width * 0.04,
        center.dy - size.height * 0.3,
      );
    canvas.drawPath(hairPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
