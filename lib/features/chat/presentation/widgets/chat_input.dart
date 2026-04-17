import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/forui/theme_tokens.dart';
import '../../../../core/theme/dark/colors.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    super.key,
    required this.text,
    required this.onTextChanged,
    required this.onSend,
    required this.isSending,
    required this.isListening,
    required this.onMicToggle,
    this.incomingLevel = 0,
    this.outgoingLevel = 0,
  });

  final String text;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSend;
  final bool isSending;
  final bool isListening;
  final VoidCallback onMicToggle;
  final double incomingLevel;
  final double outgoingLevel;

  @override
  Widget build(BuildContext context) {
    final hasActiveLevel = incomingLevel > 0.01 || outgoingLevel > 0.01;
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _AudioLevelIndicator(
              level: incomingLevel > outgoingLevel
                  ? incomingLevel
                  : outgoingLevel,
              isActive: hasActiveLevel,
            ),
            const SizedBox(width: ThemeTokens.spaceSm),
            SizedBox(
              width: 48,
              height: ThemeTokens.buttonHeight,
              child: FButton(
                onPress: isSending ? null : onMicToggle,
                child: Icon(
                  FIcons.mic,
                  size: 20,
                  color: isListening
                      ? DarkThemeColors.error
                      : DarkThemeColors.accent,
                ),
              ),
            ),
            const SizedBox(width: ThemeTokens.spaceSm),
            Expanded(
              child: Semantics(
                textField: true,
                label: 'Tin nhắn',
                child: FTextField(
                  label: const Text('Tin nhắn'),
                  minLines: 1,
                  maxLines: 4,
                  control: FTextFieldControl.lifted(
                    value: TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    ),
                    onChange: (value) => onTextChanged(value.text),
                  ),
                ),
              ),
            ),
            const SizedBox(width: ThemeTokens.spaceSm),
            SizedBox(
              height: ThemeTokens.buttonHeight,
              child: FButton(
                onPress: isSending ? null : onSend,
                child: isSending
                    ? const FCircularProgress()
                    : const Text('Gửi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioLevelIndicator extends StatelessWidget {
  const _AudioLevelIndicator({required this.level, required this.isActive});

  final double level;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = level.clamp(0.0, 1.0);
    final barCount = 4;
    final activeBars = (normalizedLevel * barCount).ceil();
    return SizedBox(
      width: 16,
      height: ThemeTokens.buttonHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (index) {
          final isBarActive = index < activeBars;
          return Container(
            width: 3,
            height: 4.0 + (index * 4.0),
            margin: const EdgeInsets.only(left: 1),
            decoration: BoxDecoration(
              color: isActive && isBarActive
                  ? DarkThemeColors.accent
                  : DarkThemeColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }
}
