import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/forui/theme_tokens.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    super.key,
    required this.text,
    required this.onTextChanged,
    required this.onSend,
    required this.isSending,
  });

  final String text;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
                      selection: TextSelection.collapsed(
                        offset: text.length,
                      ),
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
                    : const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
