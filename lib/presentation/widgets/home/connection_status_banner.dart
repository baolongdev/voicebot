import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/forui/theme_tokens.dart';
import '../../../features/chat/application/state/chat_state.dart';
import 'emotion_palette.dart';

class ConnectionStatusData {
  const ConnectionStatusData({
    required this.status,
    required this.isSpeaking,
    required this.outgoingLevel,
    required this.error,
    required this.networkWarning,
  });

  final ChatConnectionStatus status;
  final bool isSpeaking;
  final double outgoingLevel;
  final String? error;
  final bool networkWarning;
}

class ConnectionStatusBanner extends StatefulWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.palette,
    required this.audioThreshold,
    required this.data,
  });

  final EmotionPalette palette;
  final double audioThreshold;
  final ConnectionStatusData data;

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool? _lastWasSpeaking;

  FBadgeStyle _buildBadgeStyle(
    BuildContext context, {
    required Color background,
    required Color foreground,
    Color? border,
  }) {
    final typography = context.theme.typography;
    final borderRadius = FBadgeStyles.defaultRadius;
    final decoration = BoxDecoration(
      color: background,
      borderRadius: borderRadius,
      border: border == null
          ? null
          : Border.all(color: border, width: context.theme.style.borderWidth),
    );
    return FBadgeStyle(
      decoration: decoration,
      contentStyle: FBadgeContentStyle(
        labelTextStyle: typography.base.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ThemeTokens.badgePaddingHorizontal,
          vertical: ThemeTokens.badgePaddingVertical,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.data;
    final colors = context.theme.colors;
    final palette = widget.palette;
    final isListening =
        !snapshot.isSpeaking && snapshot.outgoingLevel > widget.audioThreshold;
    final status = snapshot.status;
    final networkWarning = snapshot.networkWarning;

    String label;
    FBadgeStyle badgeStyle;

    if (status == ChatConnectionStatus.connecting ||
        status == ChatConnectionStatus.reconnecting) {
      label = 'Đang kết nối';
      badgeStyle = _buildBadgeStyle(
        context,
        background: colors.primary,
        foreground: colors.primaryForeground,
      );
    } else if (status == ChatConnectionStatus.error || snapshot.error != null) {
      label = networkWarning ? 'Mất kết nối do mạng yếu' : 'Mất kết nối';
      badgeStyle = _buildBadgeStyle(
        context,
        background: colors.destructive,
        foreground: colors.destructiveForeground,
      );
    } else if (status == ChatConnectionStatus.connected) {
      if (snapshot.isSpeaking) {
        _lastWasSpeaking = true;
        label = 'Đang nói';
        badgeStyle = _buildBadgeStyle(
          context,
          background: palette.accent,
          foreground: palette.accentForeground,
        );
      } else if (isListening) {
        _lastWasSpeaking = false;
        label = 'Đang nghe';
        badgeStyle = _buildBadgeStyle(
          context,
          background: colors.secondary,
          foreground: colors.secondaryForeground,
        );
      } else {
        final wasSpeaking = _lastWasSpeaking ?? false;
        label = wasSpeaking ? 'Đang nói' : 'Đang nghe';
        badgeStyle = _buildBadgeStyle(
          context,
          background: wasSpeaking ? palette.accent : colors.secondary,
          foreground: wasSpeaking
              ? palette.accentForeground
              : colors.secondaryForeground,
        );
      }
    } else {
      label = 'Chưa kết nối';
      badgeStyle = _buildBadgeStyle(
        context,
        background: colors.muted,
        foreground: colors.mutedForeground,
        border: colors.border,
      );
    }

    final warningBadge =
        status == ChatConnectionStatus.connected && networkWarning
            ? FBadge(
                style: _buildBadgeStyle(
                  context,
                  background: colors.primary,
                  foreground: colors.primaryForeground,
                ).call,
                child: const Text('Mạng yếu'),
              )
            : null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FBadge(style: badgeStyle.call, child: Text(label)),
          if (warningBadge != null) ...[
            const SizedBox(height: ThemeTokens.spaceXs),
            warningBadge,
          ],
        ],
      ),
    );
  }
}
