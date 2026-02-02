import '../../domain/entities/chat_message.dart';

enum ChatConnectionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  error,
}

class ChatState {
  const ChatState({
    required this.messages,
    required this.isSending,
    required this.isSpeaking,
    required this.currentEmotion,
    required this.incomingLevel,
    required this.outgoingLevel,
    required this.connectionError,
    required this.networkWarning,
    required this.status,
    required this.lastTtsDurationMs,
    required this.lastTtsText,
  });

  factory ChatState.initial() {
    return const ChatState(
      messages: <ChatMessage>[],
      isSending: false,
      isSpeaking: false,
      currentEmotion: 'neutral',
      incomingLevel: 0,
      outgoingLevel: 0,
      connectionError: null,
      networkWarning: false,
      status: ChatConnectionStatus.idle,
      lastTtsDurationMs: null,
      lastTtsText: null,
    );
  }

  final List<ChatMessage> messages;
  final bool isSending;
  final bool isSpeaking;
  final String? currentEmotion;
  final double incomingLevel;
  final double outgoingLevel;
  final String? connectionError;
  final bool networkWarning;
  final ChatConnectionStatus status;
  final int? lastTtsDurationMs;
  final String? lastTtsText;

  bool get isConnected => status == ChatConnectionStatus.connected;

  bool get isConnecting =>
      status == ChatConnectionStatus.connecting ||
      status == ChatConnectionStatus.reconnecting;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isSpeaking,
    String? currentEmotion,
    double? incomingLevel,
    double? outgoingLevel,
    Object? connectionError = _noChange,
    bool? networkWarning,
    ChatConnectionStatus? status,
    Object? lastTtsDurationMs = _noChange,
    Object? lastTtsText = _noChange,
  }) {
    final nextError = connectionError == _noChange
        ? this.connectionError
        : connectionError as String?;
    final nextTtsDuration = lastTtsDurationMs == _noChange
        ? this.lastTtsDurationMs
        : lastTtsDurationMs as int?;
    final nextTtsText = lastTtsText == _noChange
        ? this.lastTtsText
        : lastTtsText as String?;
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentEmotion: currentEmotion ?? this.currentEmotion,
      incomingLevel: incomingLevel ?? this.incomingLevel,
      outgoingLevel: outgoingLevel ?? this.outgoingLevel,
      connectionError: nextError,
      networkWarning: networkWarning ?? this.networkWarning,
      status: status ?? this.status,
      lastTtsDurationMs: nextTtsDuration,
      lastTtsText: nextTtsText,
    );
  }

  static const Object _noChange = Object();
}
