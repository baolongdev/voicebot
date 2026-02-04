import 'package:flutter/material.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import 'connection_status_banner.dart';
import 'emotion_palette.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.palette,
    required this.connectionData,
  });

  final EmotionPalette palette;
  final ConnectionStatusData connectionData;

  static const double audioActiveThreshold = 0.02;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        color: palette.surface,
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
          ],
        ),
      ),
    );
  }
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
