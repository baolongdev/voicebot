import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../domain/entities/chat_message.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    this.scrollController,
  });

  final List<ChatMessage> messages;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Chưa có tin nhắn',
          style: context.theme.typography.base.copyWith(
            color: context.theme.colors.muted,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(message: message);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final crossAxis =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Align(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: crossAxis,
        children: [
          FCard(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  message.text,
                  style: context.theme.typography.base,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}
