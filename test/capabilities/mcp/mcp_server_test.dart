import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/capabilities/mcp/mcp_server.dart';
import 'package:voicebot/capabilities/web_host/document_image_store.dart';

class _FakeMcpDeviceController implements McpDeviceController {
  @override
  Future<Map<String, dynamic>> getDeviceStatus() async {
    return <String, dynamic>{'volume': 25, 'platform': 'test'};
  }

  @override
  Future<Map<String, dynamic>> getSystemInfo() async {
    return <String, dynamic>{'os': 'test'};
  }

  @override
  Future<bool> setSpeakerVolume(int percent) async => true;
}

void main() {
  group('McpServer', () {
    late Directory tempRoot;
    late LocalKnowledgeBase knowledgeBase;
    late Future<DocumentImageStore> Function() imageStoreLoader;
    late McpServer server;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp(
        'voicebot_mcp_server_test_',
      );
      knowledgeBase = LocalKnowledgeBase(
        documentsDirectoryResolver: () async => tempRoot,
      );
      imageStoreLoader = () async {
        final store = DocumentImageStore(
          rootDirectory: Directory(
            '${tempRoot.path}${Platform.pathSeparator}images',
          ),
        );
        await store.initialize();
        return store;
      };
      server = McpServer(
        controller: _FakeMcpDeviceController(),
        knowledgeBase: knowledgeBase,
        imageStoreLoader: imageStoreLoader,
      );
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('accepts JSON-RPC requests with string id', () async {
      final response = await server.handleMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 'req-1',
        'method': 'initialize',
      });

      expect(response, isNotNull);
      expect(response!['id'], 'req-1');
      expect(response['result'], isA<Map>());
    });

    test('returns error for malformed request instead of null', () async {
      final response = await server.handleMessage(<String, dynamic>{
        'id': 'bad-1',
        'method': 'initialize',
      });

      expect(response, isNotNull);
      expect(response!['error'], isA<Map>());
      expect((response['error'] as Map)['code'], -32600);
    });

    test('tools/list invalid params do not crash', () async {
      final response = await server.handleMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 10,
        'method': 'tools/list',
        'params': <String, dynamic>{'cursor': 99},
      });

      expect(response, isNotNull);
      expect((response!['error'] as Map)['code'], -32602);
    });

    test('blocks userOnly tool for remote caller', () async {
      final response = await server.handleMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 11,
        'method': 'tools/call',
        'params': <String, dynamic>{
          'name': 'self.knowledge.list_documents',
          'arguments': <String, dynamic>{},
        },
      });

      expect(response, isNotNull);
      expect((response!['error'] as Map)['code'], -32001);
    });

    test('rejects non-integer numeric arguments', () async {
      final response = await server.handleMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 12,
        'method': 'tools/call',
        'params': <String, dynamic>{
          'name': 'self.audio_speaker.set_volume',
          'arguments': <String, dynamic>{'volume': 3.9},
        },
      }, caller: McpCallerType.internal);

      expect(response, isNotNull);
      expect((response!['error'] as Map)['code'], -32602);
    });

    test('returns canonical KDOC schema', () async {
      final response = await _callTool(
        server,
        name: 'self.knowledge.get_kdoc_schema',
        caller: McpCallerType.user,
      );
      final payload = _decodeToolPayload(response);

      expect(payload['format'], 'KDOC:v1');
      expect(
        (payload['section_order'] as List).contains('CORE_PRODUCTS'),
        isTrue,
      );
      final docTypes = payload['doc_types'] as Map<String, dynamic>;
      final companyProfile =
          docTypes['company_profile'] as Map<String, dynamic>;
      expect(
        (companyProfile['recommended_sections'] as List).contains(
          'FOOD_SAFETY',
        ),
        isTrue,
      );
    });

    test('delete and clear tools remove related images', () async {
      final uploadResponse = await _callTool(
        server,
        name: 'self.knowledge.upload_text',
        caller: McpCallerType.user,
        arguments: <String, dynamic>{
          'name': 'doc_a.txt',
          'text': _validKdoc('doc_a'),
        },
      );
      expect(uploadResponse['result'], isNotNull);

      final store = await imageStoreLoader();
      await store.saveImage(
        docName: 'doc_a.txt',
        fileName: 'sample.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList(List<int>.filled(16, 7)),
      );
      expect((await store.listImagesByDocument('doc_a.txt')).length, 1);

      final deleteResponse = await _callTool(
        server,
        name: 'self.knowledge.delete_document',
        caller: McpCallerType.user,
        arguments: <String, dynamic>{'name': 'doc_a.txt'},
      );
      final deletePayload = _decodeToolPayload(deleteResponse);
      expect(deletePayload['deleted'], isTrue);
      expect(deletePayload['removed_images'], 1);
      expect(await store.listImagesByDocument('doc_a.txt'), isEmpty);

      await _callTool(
        server,
        name: 'self.knowledge.upload_text',
        caller: McpCallerType.user,
        arguments: <String, dynamic>{
          'name': 'doc_b.txt',
          'text': _validKdoc('doc_b'),
        },
      );
      await store.saveImage(
        docName: 'doc_b.txt',
        fileName: 'sample-2.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList(List<int>.filled(16, 3)),
      );

      final clearResponse = await _callTool(
        server,
        name: 'self.knowledge.clear',
        caller: McpCallerType.user,
      );
      final clearPayload = _decodeToolPayload(clearResponse);
      expect(clearPayload['cleared'], isTrue);
      expect(clearPayload['removed_images'], 1);
      expect(await store.listImagesByDocument('doc_b.txt'), isEmpty);
    });

    test(
      'list_images resolves document references beyond exact file name',
      () async {
        await knowledgeBase.upsertDocument(
          name: 'product_1773564350708.txt',
          content: _customKdoc(
            docId: 'company_chanh_viet',
            docType: 'company_profile',
            title: 'Công ty Cổ phần Thương mại và Đầu tư Chanh Việt Long An',
            aliases: 'Chanh Việt | CHAVI | Cha vi',
            summary: 'Hồ sơ doanh nghiệp Chanh Việt.',
            content:
                '- Định hướng phát triển: xây dựng chuỗi giá trị cho quả chanh.',
          ),
        );

        final store = await imageStoreLoader();
        await store.saveImage(
          docName: 'Công ty Cổ phần Thương mại và Đầu tư Chanh Việt Long An',
          fileName: 'company.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(List<int>.filled(16, 7)),
        );
        await knowledgeBase.upsertDocument(
          name: 'bot_chanh_chavi_400g.txt',
          content: _customKdoc(
            docId: 'bot_chanh_chavi_400g',
            docType: 'product',
            title: 'Bột Chanh Hòa Tan Chavi',
            aliases: 'bot chanh | chavi',
            summary: 'Sản phẩm bột chanh.',
            content: '- Dùng để pha uống và nấu ăn.',
          ),
        );
        await store.saveImage(
          docName: 'Bột Chanh Hòa Tan Chavi',
          fileName: 'product.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(List<int>.filled(16, 5)),
        );

        final listResponse = await _callTool(
          server,
          name: 'self.knowledge.list_images',
          caller: McpCallerType.user,
          arguments: <String, dynamic>{
            'doc_name': 'product_1773564350708.txt',
            'limit': 4,
          },
        );
        final listPayload = _decodeToolPayload(listResponse);
        final listImages = listPayload['images'] as List<dynamic>;
        expect(listImages, hasLength(1));
        expect(
          (listImages.first as Map<String, dynamic>)['doc_name'],
          'Công ty Cổ phần Thương mại và Đầu tư Chanh Việt Long An',
        );

        final searchResponse = await _callTool(
          server,
          name: 'self.knowledge.search_images',
          caller: McpCallerType.internal,
          arguments: <String, dynamic>{
            'query': 'dinh huong phat trien cua Chanh Viet',
            'top_k': 3,
            'max_images': 4,
          },
        );
        final searchPayload = _decodeToolPayload(searchResponse);
        final searchImages = searchPayload['images'] as List<dynamic>;
        expect(searchImages, hasLength(1));
        expect(
          (searchImages.first as Map<String, dynamic>)['file_name'],
          'company.jpg',
        );

        final productListResponse = await _callTool(
          server,
          name: 'self.knowledge.list_images',
          caller: McpCallerType.user,
          arguments: <String, dynamic>{
            'doc_name': 'Bột chanh Chavi gói 400 gram',
            'limit': 4,
          },
        );
        final productListPayload = _decodeToolPayload(productListResponse);
        final productImages = productListPayload['images'] as List<dynamic>;
        expect(productImages, hasLength(1));
        expect(
          (productImages.first as Map<String, dynamic>)['file_name'],
          'product.jpg',
        );
      },
    );

    test('rolls back delete when persistence fails', () async {
      var failWrites = false;
      final writableKnowledgeBase = LocalKnowledgeBase(
        documentsDirectoryResolver: () async => tempRoot,
        storageWriter: (file, contents) async {
          if (failWrites) {
            throw FileSystemException('write failed');
          }
          await file.writeAsString(contents, flush: true);
        },
      );
      final rollbackServer = McpServer(
        controller: _FakeMcpDeviceController(),
        knowledgeBase: writableKnowledgeBase,
        imageStoreLoader: imageStoreLoader,
      );

      await _callTool(
        rollbackServer,
        name: 'self.knowledge.upload_text',
        caller: McpCallerType.user,
        arguments: <String, dynamic>{
          'name': 'doc_keep.txt',
          'text': _validKdoc('doc_keep'),
        },
      );

      failWrites = true;
      final deleteResponse = await _callTool(
        rollbackServer,
        name: 'self.knowledge.delete_document',
        caller: McpCallerType.user,
        arguments: <String, dynamic>{'name': 'doc_keep.txt'},
      );
      expect(deleteResponse['error'], isNotNull);

      failWrites = false;
      final getResponse = await _callTool(
        rollbackServer,
        name: 'self.knowledge.get_document',
        caller: McpCallerType.user,
        arguments: <String, dynamic>{'name': 'doc_keep.txt'},
      );
      final getPayload = _decodeToolPayload(getResponse);
      expect(getPayload['name'], 'doc_keep.txt');
    });

    test('retries image store initialization after failure', () async {
      var attempts = 0;
      final retryServer = McpServer(
        controller: _FakeMcpDeviceController(),
        knowledgeBase: knowledgeBase,
        imageStoreLoader: () async {
          attempts += 1;
          if (attempts == 1) {
            throw FileSystemException('temporary image-store failure');
          }
          return imageStoreLoader();
        },
      );

      final firstResponse = await _callTool(
        retryServer,
        name: 'self.knowledge.list_images',
        caller: McpCallerType.user,
      );
      expect(firstResponse['error'], isNotNull);

      final secondResponse = await _callTool(
        retryServer,
        name: 'self.knowledge.list_images',
        caller: McpCallerType.user,
      );
      expect(secondResponse['error'], isNull);
      expect(attempts, 2);
    });

    test(
      'prefers matching product document over generic company profile',
      () async {
        await knowledgeBase.upsertDocument(
          name: 'company_profile.txt',
          content: _customKdoc(
            docId: 'company_profile',
            docType: 'company_profile',
            title: 'Ho so doanh nghiep Chanh Viet',
            aliases: 'chanh viet | chavi',
            summary: 'Thong tin tong quan ve doanh nghiep va nha may.',
            content:
                '- Doanh nghiep san xuat cac san pham tu chanh.\n- Nha may dat tai Long An.',
          ),
        );
        await knowledgeBase.upsertDocument(
          name: 'bot_chanh.txt',
          content: _customKdoc(
            docId: 'bot_chanh',
            docType: 'product',
            title: 'Bot chanh Chavi',
            aliases: 'bot chanh | chavi',
            summary: 'San pham bot chanh.',
            content:
                '- Thanh phan: chanh say lanh.\n- Han su dung: 12 thang.\n- Bao quan noi kho rao.',
            usage: '- Pha voi nuoc hoac dung cho nau an.',
          ),
        );

        final results = await knowledgeBase.search(
          'Bột chanh Chavi hạn sử dụng bao lâu?',
          topK: 2,
        );

        expect(results, isNotEmpty);
        expect(results.first['name'], 'bot_chanh.txt');
        expect(results.first['doc_type'], 'product');
        expect(results.first['confidence'], isNotNull);
      },
    );

    test('does not confuse "công dụng" intent with company profile', () async {
      await knowledgeBase.upsertDocument(
        name: 'company_profile.txt',
        content: _customKdoc(
          docId: 'company_profile',
          docType: 'company_profile',
          title: 'Ho so doanh nghiep Chanh Viet',
          aliases: 'chanh viet | chavi',
          summary: 'Thong tin tong quan ve doanh nghiep va nha may.',
          content: '- Doanh nghiep san xuat cac san pham tu chanh.',
        ),
      );
      await knowledgeBase.upsertDocument(
        name: 'nuoc_cot_chanh.txt',
        content: _customKdoc(
          docId: 'nuoc_cot_chanh',
          docType: 'product',
          title: 'Nuoc cot chanh Chavi 1 lit',
          aliases: 'nuoc cot chanh | chavi',
          summary: 'Nguyen lieu pha che tu chanh.',
          content:
              '- Ung dung: pha tra chanh, do uong va che bien mon an.\n- Bao quan lanh sau khi mo nap.',
          usage: '- Dung cho pha che va nau an.',
        ),
      );

      final results = await knowledgeBase.search(
        'Công dụng của nước cốt chanh Chavi là gì?',
        topK: 2,
      );

      expect(results, isNotEmpty);
      expect(results.first['name'], 'nuoc_cot_chanh.txt');
      expect(results.first['doc_type'], 'product');
    });

    test('matches "Chami Garden" typo to Chavi Garden info document', () async {
      await knowledgeBase.upsertDocument(
        name: 'chavi_garden.txt',
        content: _customKdoc(
          docId: 'chavi_garden_overview',
          docType: 'info',
          title: 'CHAVI GARDEN',
          aliases: 'Cha vi Garden | Chavi Garden | Khu du lich Chavi',
          summary:
              'Khu du lich sinh thai giao duc trai nghiem thuoc he sinh thai Chanh Viet.',
          content:
              '- Dia chi: Quoc lo N2, ap 5, xa Thanh Loi, tinh Tay Ninh.\n- Hoat dong trai nghiem, vui choi, luu tru.',
        ),
      );

      final results = await knowledgeBase.search(
        'Tôi muốn thông tin về Chami Garden',
        topK: 3,
      );

      expect(results, isNotEmpty);
      expect(results.first['name'], 'chavi_garden.txt');
      expect(results.first['doc_type'], 'info');
    });

    test('boosts policy documents for policy questions', () async {
      await knowledgeBase.upsertDocument(
        name: 'faq.txt',
        content: _customKdoc(
          docId: 'faq_1',
          docType: 'faq',
          title: 'Hoi dap chung',
          aliases: 'hoi dap | faq',
          summary: 'Tong hop cau hoi chung.',
          content: 'Q: San pham nao dang ban?\nA: Co nhieu san pham tu chanh.',
        ),
      );
      await knowledgeBase.upsertDocument(
        name: 'policy.txt',
        content: _customKdoc(
          docId: 'policy_1',
          docType: 'policy',
          title: 'Chinh sach doi tra',
          aliases: 'doi tra | chinh sach',
          summary: 'Quy dinh doi tra va hoan tien.',
          content:
              '- Doi tra trong 7 ngay.\n- Hoan tien khi san pham loi do nha san xuat.',
        ),
      );

      final results = await knowledgeBase.search(
        'Chính sách đổi trả của Chavi như thế nào?',
        topK: 2,
      );

      expect(results, isNotEmpty);
      expect(results.first['name'], 'policy.txt');
      expect(results.first['doc_type'], 'policy');
    });

    test(
      'matches extended KDOC sections like MARKET for distribution queries',
      () async {
        await knowledgeBase.upsertDocument(
          name: 'muoi_ot_xanh.txt',
          content: _customKdoc(
            docId: 'muoi_ot_xanh',
            docType: 'product',
            title: 'Muoi ot xanh Chavi',
            aliases: 'muoi ot xanh | chavi',
            summary: 'Nuoc cham vi chanh va ot xanh.',
            content: '- Dung cham hai san va thit nuong.',
            extraSections: <String, String>{
              'MARKET':
                  '- Thi truong muc tieu: kenh sieu thi, dai ly va kenh online.\n- Kenh phan phoi: nha phan phoi khu vuc va cua hang dac san.',
            },
          ),
        );

        final results = await knowledgeBase.search(
          'thi truong va kenh phan phoi',
          topK: 1,
        );

        expect(results, isNotEmpty);
        expect(results.first['name'], 'muoi_ot_xanh.txt');
        expect(
          (results.first['field_hits'] as List).contains('market'),
          isTrue,
        );
      },
    );
  });
}

Future<Map<String, dynamic>> _callTool(
  McpServer server, {
  required String name,
  required McpCallerType caller,
  Map<String, dynamic> arguments = const <String, dynamic>{},
}) async {
  return (await server.handleMessage(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 100,
        'method': 'tools/call',
        'params': <String, dynamic>{'name': name, 'arguments': arguments},
      }, caller: caller)) ??
      <String, dynamic>{};
}

Map<String, dynamic> _decodeToolPayload(Map<String, dynamic> response) {
  final result = response['result'];
  if (result is! Map) {
    return <String, dynamic>{};
  }
  final content = result['content'];
  if (content is! List || content.isEmpty) {
    return <String, dynamic>{};
  }
  final item = content.first;
  if (item is! Map || item['text'] is! String) {
    return <String, dynamic>{};
  }
  final text = item['text'] as String;
  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return Map<String, dynamic>.from(decoded as Map);
}

String _validKdoc(String docId) {
  return '''
=== KDOC:v1 ===
[DOC_ID]
$docId

[DOC_TYPE]
product

[TITLE]
Test $docId

[ALIASES]
test

[SUMMARY]
Tom tat

[CONTENT]
Noi dung

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''';
}

String _customKdoc({
  required String docId,
  required String docType,
  required String title,
  required String aliases,
  required String summary,
  required String content,
  String? usage,
  Map<String, String> extraSections = const <String, String>{},
}) {
  final usageBlock = usage == null
      ? ''
      : '''

[USAGE]
$usage''';
  final extraBlocks = extraSections.entries
      .map((entry) => '\n\n[${entry.key}]\n${entry.value}')
      .join();
  return '''
=== KDOC:v1 ===
[DOC_ID]
$docId

[DOC_TYPE]
$docType

[TITLE]
$title

[ALIASES]
$aliases

[SUMMARY]
$summary

[CONTENT]
$content$usageBlock$extraBlocks

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''';
}
