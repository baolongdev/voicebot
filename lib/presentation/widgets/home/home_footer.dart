import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../capabilities/protocol/protocol.dart';
import '../../../core/system/ota/model/ota_result.dart';
import '../../../core/theme/forui/theme_tokens.dart';
import '../../../features/chat/domain/entities/chat_message.dart';
import '../../../presentation/widgets/audio_wave_indicator.dart';
import '../../../theme/theme_extensions.dart';
import 'emotion_palette.dart';
import 'emotion_picker.dart';
import 'helper_formatters.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({
    super.key,
    required this.activation,
    required this.awaitingActivation,
    required this.activationProgress,
    required this.onConnect,
    required this.onDisconnect,
    required this.onManualSend,
    required this.isConnecting,
    required this.isConnected,
    required this.listeningMode,
    required this.currentEmotion,
    required this.lastMessage,
    required this.lastTtsDurationMs,
    required this.lastTtsText,
    required this.faceConnectProgress,
    required this.incomingLevel,
    required this.outgoingLevel,
    required this.isSpeaking,
  });

  final Activation? activation;
  final bool awaitingActivation;
  final double activationProgress;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onManualSend;
  final bool isConnecting;
  final bool isConnected;
  final ListeningMode listeningMode;
  final String? currentEmotion;
  final ChatMessage? lastMessage;
  final int? lastTtsDurationMs;
  final String? lastTtsText;
  final double? faceConnectProgress;
  final double incomingLevel;
  final double outgoingLevel;
  final bool isSpeaking;

  static const double _audioActiveThreshold = 0.02;

  static const List<String> _emotionOptions = [
    'neutral',
    'happy',
    'laughing',
    'funny',
    'sad',
    'angry',
    'crying',
    'loving',
    'embarrassed',
    'surprised',
    'shocked',
    'thinking',
    'winking',
    'cool',
    'relaxed',
    'delicious',
    'kissy',
    'confident',
    'sleepy',
    'silly',
    'confused',
  ];

  @override
  Widget build(BuildContext context) {
    final headerBackground = context.theme.brand.headerBackground;
    final headerForeground = context.theme.brand.headerForeground;
    final palette = EmotionPalette.resolve(context, currentEmotion);
    final selectedIndex = _emotionIndex(currentEmotion);
    final lastTranscript = lastMessage;
    final showManualSend = listeningMode == ListeningMode.manual;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.spaceMd,
        vertical: ThemeTokens.spaceSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmotionPicker(
            options: _emotionOptions,
            selectedIndex: selectedIndex,
            palette: palette,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          if (activation != null) ...[
            SizedBox(
              width: double.infinity,
              child: FTextField(
                label: const Text('Activation'),
                readOnly: true,
                control: FTextFieldControl.lifted(
                  value: TextEditingValue(
                    text: activation?.code ?? '',
                    selection: TextSelection.collapsed(
                      offset: (activation?.code ?? '').length,
                    ),
                  ),
                  onChange: (_) {},
                ),
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            if (awaitingActivation)
              FDeterminateProgress(
                value: activationProgress,
                semanticsLabel: 'Activation progress',
              ),
          ] else ...[
            _TranscriptPanel(
              message: lastTranscript,
              faceConnectProgress: faceConnectProgress,
            ),
          ],
          const SizedBox(height: ThemeTokens.spaceSm),
          _AudioLevelBar(
            incomingLevel: incomingLevel,
            outgoingLevel: outgoingLevel,
            isSpeaking: isSpeaking,
            isConnected: isConnected,
            threshold: _audioActiveThreshold,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Align(
            alignment: Alignment.center,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                const gap = ThemeTokens.spaceSm;
                final available =
                    (maxWidth - gap * 2).clamp(0.0, maxWidth).toDouble();
                final connectWidth = available * 0.6;
                final manualWidth = available * 0.2;
                return SizedBox(
                  width: maxWidth,
                  height: ThemeTokens.buttonHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: connectWidth,
                        height: ThemeTokens.buttonHeight,
                        child: FButton(
                          onPress: isConnected
                              ? onDisconnect
                              : isConnecting
                                  ? null
                                  : onConnect,
                          style: isConnected
                              ? FButtonStyle.secondary(
                                  (style) => style.copyWith(
                                    contentStyle: (content) => content.copyWith(
                                      textStyle: content.textStyle.map(
                                        (style) => style.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal:
                                            ThemeTokens.buttonPaddingHorizontal,
                                        vertical:
                                            ThemeTokens.buttonPaddingVertical,
                                      ),
                                    ),
                                  ),
                                )
                              : FButtonStyle.primary(
                                  (style) =>
                                      FButtonStyle.inherit(
                                        colors: context.theme.colors,
                                        typography: context.theme.typography,
                                        style: context.theme.style,
                                        color: headerBackground,
                                        foregroundColor: headerForeground,
                                      ).copyWith(
                                        contentStyle: (content) => content
                                            .copyWith(
                                              textStyle: content.textStyle.map(
                                                (style) => style.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: ThemeTokens
                                                    .buttonPaddingHorizontal,
                                                vertical: ThemeTokens
                                                    .buttonPaddingVertical,
                                              ),
                                            ),
                                      ),
                                ),
                          mainAxisSize: MainAxisSize.min,
                          child: Text(
                            isConnected
                                ? 'Ngắt kết nối'
                                : isConnecting
                                    ? 'Đang kết nối'
                                    : 'Kết nối',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (showManualSend)
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: manualWidth,
                            height: ThemeTokens.buttonHeight,
                            child: FButton(
                              onPress: isConnected && !isConnecting
                                  ? onManualSend
                                  : null,
                              style: FButtonStyle.secondary(
                                (style) => style.copyWith(
                                  contentStyle: (content) =>
                                      content.copyWith(
                                        textStyle: content.textStyle.map(
                                          (style) => style.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              ThemeTokens.buttonPaddingHorizontal,
                                          vertical:
                                              ThemeTokens.buttonPaddingVertical,
                                        ),
                                      ),
                                ),
                              ),
                              child: const Text('Gửi'),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: ThemeTokens.spaceXs),
          const Align(alignment: Alignment.center, child: AuthorLink()),
        ],
      ),
    );
  }

  int _emotionIndex(String? emotion) {
    if (emotion == null || emotion.isEmpty) {
      return 0;
    }
    final normalized = emotion.toLowerCase().trim();
    final index = _emotionOptions.indexOf(normalized);
    if (index == -1) {
      return 0;
    }
    return index;
  }
}

class AuthorLink extends StatelessWidget {
  const AuthorLink({super.key});

  static final Uri _authorUri = Uri.parse('https://github.com/baolongdev');

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.sm.copyWith(
      color: const Color(0xFF2F6BFF),
      fontWeight: FontWeight.w900,
      decoration: TextDecoration.underline,
    );
    return Semantics(
      link: true,
      button: true,
      label: 'baolongdev',
      child: GestureDetector(
        onTap: () {
          launchUrl(_authorUri, mode: LaunchMode.externalApplication);
        },
        child: Text(
          'Author: baolongdev + ACLAB',
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TranscriptPanel extends StatefulWidget {
  const _TranscriptPanel({
    required this.message,
    required this.faceConnectProgress,
  });

  final ChatMessage? message;
  final double? faceConnectProgress;

  @override
  State<_TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends State<_TranscriptPanel> {
  String _lastText = '';
  bool _lastIsUser = false;
  int _lastStyleHash = 0;
  List<TextSpan> _spans = const [];

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final progress = widget.faceConnectProgress;
    if (message == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null)
            FDeterminateProgress(
              value: progress.clamp(0.0, 1.0),
              semanticsLabel: 'Face connect progress',
            ),
          if (progress != null)
            const SizedBox(height: ThemeTokens.spaceXs),
          Text(
            'Transcript / lời thoại',
            textAlign: TextAlign.left,
            style: context.theme.typography.xl.copyWith(
              color: context.theme.colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final rawText = message.text;
    final text = normalizeTranscript(rawText);
    final isUser = message.isUser;
    final readStyle = context.theme.typography.xl.copyWith(
      color: context.theme.colors.foreground,
      fontWeight: FontWeight.w600,
    );
    final prefixStyle = readStyle.copyWith(fontWeight: FontWeight.w700);
    final braceStyle = readStyle.copyWith(fontWeight: FontWeight.w800);
    final numberReadStyle = TextStyle(
      color: context.theme.colors.destructive,
      fontWeight: FontWeight.w700,
    );
    final styleHash = Object.hash(
      readStyle,
      numberReadStyle,
      prefixStyle,
      braceStyle,
    );

    if (_lastText != text ||
        _lastIsUser != isUser ||
        _lastStyleHash != styleHash) {
      final prefix = isUser ? 'USER: ' : 'AGENT: ';
      _spans = [
        TextSpan(text: prefix, style: prefixStyle),
        ...highlightTranscriptTokens(
          text,
          readStyle,
          numberReadStyle,
          braceStyle,
        ),
      ];
      _lastText = text;
      _lastIsUser = isUser;
      _lastStyleHash = styleHash;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null)
            FDeterminateProgress(
              value: progress.clamp(0.0, 1.0),
              semanticsLabel: 'Face connect progress',
            ),
          if (progress != null)
            const SizedBox(height: ThemeTokens.spaceXs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: _spans),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioLevelBar extends StatelessWidget {
  const _AudioLevelBar({
    required this.incomingLevel,
    required this.outgoingLevel,
    required this.isSpeaking,
    required this.isConnected,
    required this.threshold,
  });

  final double incomingLevel;
  final double outgoingLevel;
  final bool isSpeaking;
  final bool isConnected;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final serverLevel = incomingLevel;
    final userLevel = outgoingLevel;
    final isServerSpeaking = isSpeaking;
    final isUserSpeaking = !isServerSpeaking && userLevel > threshold;
    final color = isServerSpeaking
        ? context.theme.colors.destructive
        : isUserSpeaking
            ? context.theme.colors.primary
            : context.theme.colors.mutedForeground;
    final level =
        isServerSpeaking ? serverLevel : (isUserSpeaking ? userLevel : 0.0);
    return RepaintBoundary(
      child: AudioWaveIndicator(
        level: level,
        color: color,
        idle: !isConnected,
      ),
    );
  }
}
