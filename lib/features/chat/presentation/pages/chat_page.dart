import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../di/locator.dart';
import '../../application/state/chat_controller.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_message_list.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatController _controller;
  final ScrollController _scrollController = ScrollController();
  String _inputText = '';

  @override
  void initState() {
    super.initState();
    _controller = getIt<ChatController>();
    _controller.initialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _inputText.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _inputText = '';
    });
    await _controller.sendMessage(text);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chat',
                  style: context.theme.typography.xl,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final error = _controller.connectionError;
                if (error == null || error.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    error,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.error,
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return ChatMessageList(
                    messages: _controller.messages,
                    scrollController: _scrollController,
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return ChatInput(
                  text: _inputText,
                  onTextChanged: (value) {
                    setState(() {
                      _inputText = value;
                    });
                  },
                  onSend: _handleSend,
                  isSending: _controller.isSending,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
