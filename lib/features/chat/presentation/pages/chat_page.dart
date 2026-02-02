import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import '../../application/state/chat_cubit.dart';
import '../../application/state/chat_state.dart';
import '../../domain/entities/chat_message.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_message_list.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  String _inputText = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    await context.read<ChatCubit>().sendMessage(text);
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
            BlocSelector<ChatCubit, ChatState, String?>(
              selector: (state) => state.connectionError,
              builder: (context, error) {
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
              child: BlocSelector<ChatCubit, ChatState, List<ChatMessage>>(
                selector: (state) => state.messages,
                builder: (context, messages) {
                  return ChatMessageList(
                    messages: messages,
                    scrollController: _scrollController,
                  );
                },
              ),
            ),
            BlocSelector<ChatCubit, ChatState, bool>(
              selector: (state) => state.isSending,
              builder: (context, isSending) {
                return ChatInput(
                  text: _inputText,
                  onTextChanged: (value) {
                    setState(() {
                      _inputText = value;
                    });
                  },
                  onSend: _handleSend,
                  isSending: isSending,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
