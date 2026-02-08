import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:voicebot/core/theme/forui/forui_theme.dart';
import 'package:voicebot/features/chat/domain/entities/chat_message.dart';
import 'package:voicebot/features/chat/domain/entities/related_chat_image.dart';
import 'package:voicebot/features/chat/presentation/widgets/chat_message_list.dart';

void main() {
  Widget buildTestApp(List<ChatMessage> messages) {
    return MaterialApp(
      home: FAnimatedTheme(
        data: AppForuiTheme.light(),
        child: Scaffold(body: ChatMessageList(messages: messages)),
      ),
    );
  }

  ChatMessage relatedMessage({required List<RelatedChatImage> images}) {
    return ChatMessage(
      id: '__related_images__',
      text: images.isEmpty ? '' : 'Hinh anh lien quan',
      isUser: false,
      timestamp: DateTime(2026, 2, 8, 10),
      type: ChatMessageType.relatedImages,
      relatedImages: images,
      relatedQuery: 'tinh dau chanh chavi',
    );
  }

  testWidgets('renders related-images block when data exists', (tester) async {
    final images = <RelatedChatImage>[
      RelatedChatImage(
        id: 'img_1',
        documentName: 'doc_a.txt',
        fileName: 'tinh_dau_1.jpg',
        url: 'http://127.0.0.1:8080/api/documents/image/content?id=img_1',
        mimeType: 'image/jpeg',
        bytes: 1024,
        score: 90,
        createdAt: DateTime(2026, 2, 8, 10),
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(<ChatMessage>[relatedMessage(images: images)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hình ảnh liên quan'), findsOneWidget);
    expect(find.textContaining('Theo truy vấn:'), findsOneWidget);
    expect(find.text('tinh_dau_1.jpg'), findsOneWidget);
  });

  testWidgets('hides related-images block with animated switch', (
    tester,
  ) async {
    final images = <RelatedChatImage>[
      RelatedChatImage(
        id: 'img_1',
        documentName: 'doc_a.txt',
        fileName: 'tinh_dau_1.jpg',
        url: 'http://127.0.0.1:8080/api/documents/image/content?id=img_1',
        mimeType: 'image/jpeg',
        bytes: 1024,
        score: 90,
        createdAt: DateTime(2026, 2, 8, 10),
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(<ChatMessage>[relatedMessage(images: images)]),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('related-content')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      buildTestApp(<ChatMessage>[
        relatedMessage(images: const <RelatedChatImage>[]),
      ]),
    );

    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(const ValueKey<String>('related-content')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const ValueKey<String>('related-content')), findsNothing);
  });
}
