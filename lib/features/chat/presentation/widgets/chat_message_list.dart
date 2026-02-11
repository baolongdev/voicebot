import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/related_chat_image.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    if (message.type == ChatMessageType.relatedImages) {
      return _RelatedImagesBubble(message: message);
    }
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final crossAxis = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Align(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: crossAxis,
        children: <Widget>[
          FCard(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(message.text, style: context.theme.typography.base),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RelatedImagesBubble extends StatelessWidget {
  const _RelatedImagesBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final images = message.relatedImages;
    final duration = AppConfig.chatRelatedImagesAnimationEnabled
        ? const Duration(milliseconds: 220)
        : Duration.zero;
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSize(
        duration: duration,
        curve: Curves.easeInOut,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: FCard(
            key: ValueKey<String>(
              images.isEmpty ? 'related-empty' : 'related-content',
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message.text.trim().isEmpty
                          ? 'Hình ảnh liên quan'
                          : message.text,
                      style: context.theme.typography.sm.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message.relatedQuery != null &&
                        message.relatedQuery!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Theo truy vấn: ${message.relatedQuery}',
                        style: context.theme.typography.xs.copyWith(
                          color: context.theme.colors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (images.isEmpty)
                      Text(
                        'MCP không tìm thấy ảnh phù hợp trong kho dữ liệu.',
                        style: context.theme.typography.xs.copyWith(
                          color: context.theme.colors.muted,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: images
                            .map((image) => _RelatedImageTile(image: image))
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RelatedImageTile extends StatelessWidget {
  const _RelatedImageTile({required this.image});

  static const double _thumbnailWidthLarge = 213;
  static const double _thumbnailHeightLarge = 120;
  static const double _thumbnailWidthSmall = 160;
  static const double _thumbnailHeightSmall = 90;
  static const double _smallScreenWidthBreakpoint = 380;

  final RelatedChatImage image;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final useSmallSize = screenWidth <= _smallScreenWidthBreakpoint;
    final thumbnailWidth = useSmallSize
        ? _thumbnailWidthSmall
        : _thumbnailWidthLarge;
    final thumbnailHeight = useSmallSize
        ? _thumbnailHeightSmall
        : _thumbnailHeightLarge;
    return GestureDetector(
      onTap: () => _showImagePreview(context, image),
      child: SizedBox(
        width: thumbnailWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: context.theme.colors.background,
                child: SizedBox(
                  width: thumbnailWidth,
                  height: thumbnailHeight,
                  child: Image.network(
                    image.url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'Không tải được ảnh',
                        textAlign: TextAlign.center,
                        style: context.theme.typography.xs.copyWith(
                          color: context.theme.colors.muted,
                        ),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.theme.colors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              image.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.xs.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              image.documentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showImagePreview(BuildContext context, RelatedChatImage image) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        backgroundColor: Colors.black,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  image.url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      'Không tải được ảnh',
                      style: context.theme.typography.base.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FButton.icon(
                onPress: () => Navigator.of(context).pop(),
                child: const Icon(FIcons.x),
              ),
            ),
          ],
        ),
      );
    },
  );
}
