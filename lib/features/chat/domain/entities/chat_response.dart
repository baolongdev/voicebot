class ChatResponse {
  const ChatResponse({
    required this.text,
    this.isUser = false,
    this.audioBytes,
    this.emotion,
  });

  final String text;
  final bool isUser;
  final List<int>? audioBytes;
  final String? emotion;
}
