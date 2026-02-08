class RelatedChatImage {
  const RelatedChatImage({
    required this.id,
    required this.documentName,
    required this.fileName,
    required this.url,
    required this.mimeType,
    required this.bytes,
    required this.score,
    this.createdAt,
  });

  final String id;
  final String documentName;
  final String fileName;
  final String url;
  final String mimeType;
  final int bytes;
  final int score;
  final DateTime? createdAt;
}
