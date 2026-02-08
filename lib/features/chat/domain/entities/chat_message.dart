import 'related_chat_image.dart';

enum ChatMessageType { text, relatedImages }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.type = ChatMessageType.text,
    this.relatedImages = const <RelatedChatImage>[],
    this.relatedQuery,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageType type;
  final List<RelatedChatImage> relatedImages;
  final String? relatedQuery;

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    ChatMessageType? type,
    List<RelatedChatImage>? relatedImages,
    Object? relatedQuery = _noChange,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      relatedImages: relatedImages ?? this.relatedImages,
      relatedQuery: relatedQuery == _noChange
          ? this.relatedQuery
          : relatedQuery as String?,
    );
  }

  static const Object _noChange = Object();
}
