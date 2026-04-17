import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/dark/colors.dart';
import '../../../../core/theme/forui/theme_tokens.dart';
import '../../../../presentation/app/related_images_settings_cubit.dart';
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
  DateTime? _lastTapTime;
  bool _wsActionInFlight = false;
  static const _doubleTapMs = 300;

  @override
  void initState() {
    super.initState();
    final relatedImagesEnabled = context
        .read<RelatedImagesSettingsCubit>()
        .state
        .enabled;
    context.read<ChatCubit>().setRelatedImagesEnabled(relatedImagesEnabled);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleWsConnection() async {
    if (_wsActionInFlight || !mounted) {
      return;
    }
    final cubit = context.read<ChatCubit>();
    final status = cubit.state.status;
    if (status == ChatConnectionStatus.connecting ||
        status == ChatConnectionStatus.reconnecting) {
      return;
    }
    setState(() {
      _wsActionInFlight = true;
    });
    try {
      if (status == ChatConnectionStatus.connected) {
        await cubit.disconnect(userInitiated: true);
        return;
      }
      await cubit.connect();
    } finally {
      if (mounted) {
        setState(() {
          _wsActionInFlight = false;
        });
      }
    }
  }

  Future<void> _handleMicTap() async {
    final now = DateTime.now();
    final cubit = context.read<ChatCubit>();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _doubleTapMs) {
      _lastTapTime = null;
      await _handleDoubleTap(cubit);
      return;
    }
    _lastTapTime = now;
    await Future.delayed(const Duration(milliseconds: _doubleTapMs));
    if (!mounted || _lastTapTime == null) return;
    _lastTapTime = null;
    await _handleSingleTap(cubit);
  }

  Future<void> _handleDoubleTap(ChatCubit cubit) async {
    if (!mounted) return;
    if (cubit.state.isConnected) {
      await cubit.disconnect(userInitiated: true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await cubit.connect();
    }
  }

  Future<void> _handleSingleTap(ChatCubit cubit) async {
    if (!mounted) return;
    await cubit.toggleListening();
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
    return BlocListener<RelatedImagesSettingsCubit, RelatedImagesSettings>(
      listener: (context, state) {
        context.read<ChatCubit>().setRelatedImagesEnabled(state.enabled);
      },
      child: FScaffold(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ThemeTokens.spaceMd,
                  vertical: ThemeTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trò chuyện',
                        style: context.theme.typography.xl,
                      ),
                    ),
                    _RelatedImagesToggle(),
                    const SizedBox(width: ThemeTokens.spaceSm),
                    BlocSelector<ChatCubit, ChatState, bool>(
                      selector: (state) => state.isSpeaking,
                      builder: (context, isSpeaking) {
                        if (!isSpeaking) return const SizedBox.shrink();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FIcons.volume2,
                              size: 20,
                              color: DarkThemeColors.accent,
                            ),
                            const SizedBox(width: ThemeTokens.spaceXs),
                            Text(
                              'Đang nói',
                              style: context.theme.typography.sm.copyWith(
                                color: DarkThemeColors.accent,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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
                      horizontal: ThemeTokens.spaceMd,
                      vertical: ThemeTokens.spaceSm,
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
                child: Stack(
                  children: [
                    BlocSelector<ChatCubit, ChatState, List<ChatMessage>>(
                      selector: (state) => state.messages,
                      builder: (context, messages) {
                        return ChatMessageList(
                          messages: messages,
                          scrollController: _scrollController,
                        );
                      },
                    ),
                    Positioned(
                      top: ThemeTokens.spaceSm,
                      left: ThemeTokens.spaceMd,
                      child:
                          BlocSelector<
                            ChatCubit,
                            ChatState,
                            ChatConnectionStatus
                          >(
                            selector: (state) => state.status,
                            builder: (context, status) {
                              return _ConnectionButton(
                                isConnected:
                                    status == ChatConnectionStatus.connected,
                                isConnecting:
                                    status == ChatConnectionStatus.connecting ||
                                    status ==
                                        ChatConnectionStatus.reconnecting ||
                                    _wsActionInFlight,
                                onTap: _toggleWsConnection,
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
              BlocSelector<
                ChatCubit,
                ChatState,
                (
                  bool isSending,
                  bool isListening,
                  double incomingLevel,
                  double outgoingLevel,
                )
              >(
                selector: (state) => (
                  state.isSending,
                  state.isListening,
                  state.incomingLevel,
                  state.outgoingLevel,
                ),
                builder: (context, data) {
                  final isSending = data.$1;
                  return ChatInput(
                    text: _inputText,
                    onTextChanged: (value) {
                      setState(() {
                        _inputText = value;
                      });
                    },
                    onSend: _handleSend,
                    isSending: isSending,
                    isListening: data.$2,
                    onMicToggle: _handleMicTap,
                    incomingLevel: data.$3,
                    outgoingLevel: data.$4,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedImagesToggle extends StatelessWidget {
  const _RelatedImagesToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RelatedImagesSettingsCubit, RelatedImagesSettings>(
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            context.read<RelatedImagesSettingsCubit>().setEnabled(
              !state.enabled,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: state.enabled
                  ? DarkThemeColors.accent.withValues(alpha: 0.2)
                  : DarkThemeColors.textMuted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(500),
            ),
            child: Icon(
              FIcons.image,
              size: 20,
              color: state.enabled
                  ? DarkThemeColors.accent
                  : DarkThemeColors.textMuted,
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  });

  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isConnecting) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 24, height: 24, child: FCircularProgress()),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isConnected
              ? DarkThemeColors.error.withValues(alpha: 0.2)
              : DarkThemeColors.accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(500),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? FIcons.x : FIcons.wifi,
              size: 18,
              color: isConnected
                  ? DarkThemeColors.error
                  : DarkThemeColors.accent,
            ),
            const SizedBox(width: ThemeTokens.spaceXs),
            Text(
              isConnected ? 'Ngắt WS' : 'Kết nối WS',
              style: context.theme.typography.sm.copyWith(
                color: isConnected
                    ? DarkThemeColors.error
                    : DarkThemeColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
