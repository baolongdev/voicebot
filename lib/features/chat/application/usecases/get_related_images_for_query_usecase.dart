import '../../domain/entities/related_chat_image.dart';
import '../../domain/repositories/chat_repository.dart';

class GetRelatedImagesForQueryUseCase {
  const GetRelatedImagesForQueryUseCase(this._repository);

  final ChatRepository _repository;

  Future<List<RelatedChatImage>> call(
    String query, {
    int? topK,
    int? maxImages,
  }) {
    return _repository.getRelatedImagesForQuery(
      query,
      topK: topK,
      maxImages: maxImages,
    );
  }
}
