import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

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
    required this.isConnecting,
    required this.isConnected,
    required this.currentEmotion,
    required this.lastMessage,
    required this.lastTtsDurationMs,
    required this.lastTtsText,
    required this.incomingLevel,
    required this.outgoingLevel,
    required this.isSpeaking,
  });

  final Activation? activation;
  final bool awaitingActivation;
  final double activationProgress;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final bool isConnecting;
  final bool isConnected;
  final String? currentEmotion;
  final ChatMessage? lastMessage;
  final int? lastTtsDurationMs;
  final String? lastTtsText;
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
            _TranscriptPanel(message: lastTranscript),
          ],
          const SizedBox(height: ThemeTokens.spaceSm),
          _AudioLevelBar(
            incomingLevel: incomingLevel,
            outgoingLevel: outgoingLevel,
            isSpeaking: isSpeaking,
            threshold: _audioActiveThreshold,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: ThemeTokens.footerButtonWidth,
              ),
              child: IntrinsicWidth(
                child: SizedBox(
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
                                  vertical: ThemeTokens.buttonPaddingVertical,
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
              ),
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

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({required this.message});

  final ChatMessage? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return Text(
        'Transcript / lời thoại',
        textAlign: TextAlign.left,
        style: context.theme.typography.xl.copyWith(
          color: context.theme.colors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final rawText = message?.text ?? '';
    final text = normalizeTranscript(rawText);
    final prefix = message!.isUser ? 'USER: ' : 'AGENT: ';
    final readStyle = context.theme.typography.xl.copyWith(
      color: context.theme.colors.foreground,
      fontWeight: FontWeight.w600,
    );
    final prefixStyle = readStyle.copyWith(fontWeight: FontWeight.w700);
    final numberReadStyle = TextStyle(
      color: context.theme.colors.destructive,
      fontWeight: FontWeight.w700,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 84),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: prefix, style: prefixStyle),
              ...highlightNumbers(text, readStyle, numberReadStyle),
            ],
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}

class _AudioLevelBar extends StatelessWidget {
  const _AudioLevelBar({
    required this.incomingLevel,
    required this.outgoingLevel,
    required this.isSpeaking,
    required this.threshold,
  });

  final double incomingLevel;
  final double outgoingLevel;
  final bool isSpeaking;
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
      child: AudioWaveIndicator(level: level, color: color),
    );
  }
}
