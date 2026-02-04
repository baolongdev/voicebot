import 'package:carousel_slider/carousel_slider.dart';
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
    required this.cameraEnabled,
    required this.cameraAspectRatio,
    required this.onCameraEnabledChanged,
  });

  final EmotionPalette palette;
  final ConnectionStatusData connectionData;
  final bool cameraEnabled;
  final double cameraAspectRatio;
  final ValueChanged<bool> onCameraEnabledChanged;

  static const double audioActiveThreshold = 0.02;
  static const double _carouselHeight = 256;
  static const List<String> _carouselImages = [
    'https://chanhviet.com/wp-content/uploads/2024/05/syrup-chanh-vang-chavi-1.png',
    'https://chanhviet.com/wp-content/uploads/2023/07/cot-chanh-tuoi-100-chavi-chavi-1024x1024.jpg',
    'https://chanhviet.com/wp-content/uploads/2019/11/bot-chanh-chavi.jpg',
    'https://chanhviet.com/wp-content/uploads/2019/11/nuoc-cot-chanh-100a-chanh-viet.png',
    'https://chanhviet.com/wp-content/uploads/2020/09/bot-thanh-long-hoa-tan-chavi-400g.png',
    'https://chanhviet.com/wp-content/uploads/2024/01/bot-trai-cay-hoa-tan-chavi-1kg-1024x1024.jpg',
  ];

  @override
  Widget build(BuildContext context) {
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
                      _BottomCarousel(palette: palette),
                    ],
                  ),
                ),
                HomeCameraOverlay(
                  areaSize: Size(constraints.maxWidth, constraints.maxHeight),
                  enabled: cameraEnabled,
                  onEnabledChanged: onCameraEnabledChanged,
                  aspectRatio: cameraAspectRatio,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomCarousel extends StatelessWidget {
  const _BottomCarousel({required this.palette});

  final EmotionPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeContent._carouselHeight,
      width: double.infinity,
      child: CarouselSlider(
        items: List.generate(HomeContent._carouselImages.length, (index) {
          final imageUrl = HomeContent._carouselImages[index];
          return GestureDetector(
            onTap: () => _openImagePreview(context, imageUrl),
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: ThemeTokens.spaceXs,
              ),
              decoration: BoxDecoration(
                color: palette.controlBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.controlBorder(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _error, _stackTrace) => Center(
                      child: Text(
                        'Hình ảnh lỗi',
                        style: context.theme.typography.sm.copyWith(
                          color: palette.controlForeground(context),
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
                            color: palette.controlForeground(context),
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
                          palette
                              .controlBackground(context)
                              .withValues(alpha: 0.35),
                          palette
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
        }),
        options: CarouselOptions(
          height: HomeContent._carouselHeight,
          viewportFraction: 0.7,
          enlargeCenterPage: true,
          enableInfiniteScroll: false,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 4),
          autoPlayAnimationDuration: const Duration(milliseconds: 700),
          autoPlayCurve: Curves.easeOutCubic,
          pauseAutoPlayOnTouch: true,
        ),
      ),
    );
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
                      errorBuilder: (context, _error, _stackTrace) => Center(
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
