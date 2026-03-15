import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/capabilities/protocol/protocol.dart';
import 'package:voicebot/capabilities/voice/session_coordinator.dart';
import 'package:voicebot/capabilities/voice/transport_client.dart';
import 'package:voicebot/core/system/ota/model/device_info.dart';
import 'package:voicebot/features/chat/domain/entities/chat_config.dart';
import 'package:voicebot/features/chat/infrastructure/repositories/chat_repository_impl.dart';
import 'package:voicebot/features/form/domain/models/server_form_data.dart';

void main() {
  group('ChatRepositoryImpl knowledge context', () {
    late _CaptureSessionCoordinator sessionCoordinator;
    ChatRepositoryImpl? repository;

    setUp(() {
      sessionCoordinator = _CaptureSessionCoordinator();
    });

    tearDown(() {
      repository?.dispose();
      repository = null;
    });

    test(
      'sendMessage attaches focused knowledge evidence for strong match',
      () async {
        repository = ChatRepositoryImpl(
          sessionCoordinator: sessionCoordinator,
          mcpHandleMessage: (payload) async {
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'bot_chanh.txt',
                    'title': 'Bột chanh Chavi',
                    'doc_type': 'product',
                    'score': 168,
                    'coverage_ratio': 1.0,
                    'confidence': 'high',
                    'exact_match': true,
                    'field_hits': <String>['title', 'content'],
                    'match_reasons': <String>[
                      'exact_identity',
                      'high_token_coverage',
                    ],
                    'summary': 'Bột chanh dùng cho pha uống và nấu ăn.',
                    'usage': '- Pha 1-2 muỗng với nước.',
                    'safety_note': 'Không thay thế thuốc.',
                    'snippet': 'Hạn sử dụng: 12 tháng.',
                    'content': '''
=== KDOC:v1 ===
[DOC_ID]
bot_chanh

[DOC_TYPE]
product

[TITLE]
Bột chanh Chavi

[ALIASES]
bột chanh | bot chanh | chavi

[SUMMARY]
Bột chanh dùng cho pha uống và nấu ăn.

[CONTENT]
- Thành phần: chanh sấy lạnh.
- Hạn sử dụng: 12 tháng.
- Bảo quản: nơi khô ráo, tránh nắng trực tiếp.

[USAGE]
- Pha 1-2 muỗng với nước.

[SAFETY_NOTE]
Không thay thế thuốc.

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''',
                  },
                ],
              });
            }
            return _toolError(payload['id'], 'unexpected tool');
          },
        );

        await repository!.connect(_chatConfig());
        final result = await repository!.sendMessage(
          'Bột chanh Chavi hạn sử dụng bao lâu?',
        );

        expect(result.isSuccess, isTrue);
        expect(sessionCoordinator.sentTexts, isNotEmpty);
        final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
        final text = payload['text'] as String;
        expect(text, contains('[DU_LIEU_NOI_BO_LIEN_QUAN]'));
        expect(text, contains('[HO_SO_TAI_LIEU_DAY_DU]'));
        expect(text, contains('[BANG_CHUNG_TRUC_TIEP]'));
        expect(text, contains('[DOAN_LIEN_QUAN_NHAT]'));
        expect(text, contains('Vi day la cau hoi'));
        expect(text, contains('Hạn sử dụng: 12 tháng'));
        expect(text, contains('Bảo quản: nơi khô ráo'));
        expect(text, isNot(contains('[GOI_Y_TAI_LIEU_NOI_BO]')));
      },
    );

    test('sendGreeting respects listenDetect text send mode', () async {
      repository = ChatRepositoryImpl(
        sessionCoordinator: sessionCoordinator,
        mcpHandleMessage: (payload) async =>
            _toolError(payload['id'], 'unexpected tool'),
      );

      await repository!.setTextSendMode(TextSendMode.listenDetect);
      await repository!.connect(_chatConfig());
      final result = await repository!.sendGreeting('Xin chào');

      expect(result.isSuccess, isTrue);
      expect(sessionCoordinator.sentTexts, isNotEmpty);
      final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
      expect(payload['type'], 'listen');
      expect(payload['state'], 'detect');
      expect(payload['text'], 'Xin chào');
    });

    test(
      'sendMessage includes full matched section for strategy question',
      () async {
        repository = ChatRepositoryImpl(
          sessionCoordinator: sessionCoordinator,
          mcpHandleMessage: (payload) async {
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'company_profile.txt',
                    'title': 'Công ty Chanh Việt',
                    'doc_type': 'company_profile',
                    'score': 88,
                    'coverage_ratio': 1.0,
                    'confidence': 'medium',
                    'exact_match': false,
                    'field_hits': <String>['content', 'summary'],
                    'match_reasons': <String>[
                      'high_token_coverage',
                      'structured_kdoc',
                    ],
                    'summary':
                        'Doanh nghiệp phát triển hệ sinh thái sản phẩm từ chanh.',
                    'usage': '',
                    'safety_note': '',
                    'snippet':
                        'Định hướng phát triển: mở rộng chuỗi giá trị chanh.',
                    'content': '''
=== KDOC:v1 ===
[DOC_ID]
company_profile

[DOC_TYPE]
company_profile

[TITLE]
Công ty Chanh Việt

[SUMMARY]
Doanh nghiệp phát triển hệ sinh thái sản phẩm từ chanh.

[CONTENT]
- Tên doanh nghiệp: Công ty Chanh Việt.
- Định hướng phát triển:
  Xây dựng chuỗi giá trị cho quả chanh từ vùng trồng, nghiên cứu, chế biến đến phân phối sản phẩm.
  Phát triển thương hiệu CHAVI để nâng cao giá trị nông sản Việt và đưa sản phẩm ra thị trường quốc tế.
- Quy mô: hơn 100 ha vùng nguyên liệu.

[MARKET]
- Trong nước: showroom, sàn thương mại điện tử.
- Xuất khẩu: Mỹ, Nhật Bản.

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''',
                  },
                ],
              });
            }
            return _toolError(payload['id'], 'unexpected tool');
          },
        );

        await repository!.connect(_chatConfig());
        final result = await repository!.sendMessage(
          'cho tôi thông tin về định hướng phát triển',
        );

        expect(result.isSuccess, isTrue);
        final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
        final text = payload['text'] as String;
        expect(text, contains('Loai cau hoi: strategy'));
        expect(text, contains('[BANG_CHUNG_TRUC_TIEP]'));
        expect(text, contains('[CONTENT]'));
        expect(
          text,
          contains(
            'Xây dựng chuỗi giá trị cho quả chanh từ vùng trồng, nghiên cứu, chế biến đến phân phối sản phẩm.',
          ),
        );
        expect(
          text,
          contains(
            'Vi day la cau hoi ve dinh huong/tam nhin/muc tieu phat trien',
          ),
        );
      },
    );

    test(
      'sendMessage keeps only primary company dossier for overview question',
      () async {
        repository = ChatRepositoryImpl(
          sessionCoordinator: sessionCoordinator,
          mcpHandleMessage: (payload) async {
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'company_profile.txt',
                    'title': 'Công ty Chanh Việt',
                    'doc_type': 'company_profile',
                    'score': 129,
                    'coverage_ratio': 0.5,
                    'confidence': 'medium',
                    'exact_match': false,
                    'field_hits': <String>['title', 'summary', 'content'],
                    'match_reasons': <String>[
                      'intent_doc_type',
                      'partial_token_coverage',
                      'structured_kdoc',
                    ],
                    'summary':
                        'Công ty Chanh Việt là doanh nghiệp phát triển hệ sinh thái sản phẩm từ chanh.',
                    'usage': '',
                    'safety_note':
                        'Thông tin mang tính giới thiệu doanh nghiệp.',
                    'snippet':
                        'Công ty Chanh Việt là doanh nghiệp phát triển hệ sinh thái sản phẩm từ chanh.',
                    'content': '''
=== KDOC:v1 ===
[DOC_ID]
company_profile

[DOC_TYPE]
company_profile

[TITLE]
Công ty Chanh Việt

[SUMMARY]
Công ty Chanh Việt là doanh nghiệp phát triển hệ sinh thái sản phẩm từ chanh.

[CONTENT]
- Tên doanh nghiệp: Công ty Chanh Việt.
- Lĩnh vực: trồng, nghiên cứu, chế biến và phân phối sản phẩm từ chanh.
- Định hướng phát triển: xây dựng chuỗi giá trị cho quả chanh.

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''',
                  },
                  <String, Object?>{
                    'name': 'nuoc_cot_chanh.txt',
                    'title': 'Nước cốt chanh Chavi',
                    'doc_type': 'product',
                    'score': 64,
                    'coverage_ratio': 0.5,
                    'confidence': 'medium',
                    'exact_match': false,
                    'field_hits': <String>['summary', 'content'],
                    'match_reasons': <String>[
                      'partial_token_coverage',
                      'structured_kdoc',
                    ],
                    'summary':
                        'Nguyên liệu pha chế từ chanh dùng cho đồ uống và món ăn.',
                    'usage': '',
                    'safety_note': 'Không thay thế thuốc.',
                    'snippet': 'Nước cốt chanh dùng cho pha chế.',
                    'content': '''
=== KDOC:v1 ===
[DOC_ID]
nuoc_cot_chanh

[DOC_TYPE]
product

[TITLE]
Nước cốt chanh Chavi

[SUMMARY]
Nguyên liệu pha chế từ chanh dùng cho đồ uống và món ăn.

[CONTENT]
- Thành phần: nước cốt chanh.
- Ứng dụng: pha chế và nấu ăn.

[SAFETY_NOTE]
Không thay thế thuốc.

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''',
                  },
                ],
              });
            }
            return _toolError(payload['id'], 'unexpected tool');
          },
        );

        await repository!.connect(_chatConfig());
        final result = await repository!.sendMessage(
          'cho tôi thông tin về công ty chanh việt',
        );

        expect(result.isSuccess, isTrue);
        final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
        final text = payload['text'] as String;
        expect(text, contains('Loai cau hoi: overview'));
        expect(text, contains('[TAI_LIEU_1]'));
        expect(text, contains('Công ty Chanh Việt'));
        expect(text, isNot(contains('[TAI_LIEU_2]')));
        expect(text, isNot(contains('Nước cốt chanh Chavi')));
        expect(text, contains('Khong duoc tu them thong tin suc khoe'));
      },
    );

    test(
      'sendMessage attaches direct knowledge evidence for "Chami Garden" typo',
      () async {
        repository = ChatRepositoryImpl(
          sessionCoordinator: sessionCoordinator,
          mcpHandleMessage: (payload) async {
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'chavi_garden.txt',
                    'title': 'CHAVI GARDEN',
                    'doc_type': 'info',
                    'score': 154,
                    'coverage_ratio': 0.75,
                    'confidence': 'high',
                    'exact_match': false,
                    'field_hits': <String>['title', 'aliases', 'summary'],
                    'match_reasons': <String>[
                      'high_token_coverage',
                      'structured_kdoc',
                    ],
                    'summary':
                        'Khu du lịch sinh thái giáo dục trải nghiệm thuộc hệ sinh thái Chanh Việt.',
                    'usage': '',
                    'safety_note':
                        'Các dịch vụ mang tính trải nghiệm và thư giãn.',
                    'snippet':
                        'Địa chỉ: Quốc lộ N2, ấp 5, xã Thạnh Lợi, tỉnh Tây Ninh.',
                    'content': '''
=== KDOC:v1 ===
[DOC_ID]
chavi_garden_overview

[DOC_TYPE]
info

[TITLE]
CHAVI GARDEN

[ALIASES]
Cha vi Garden | Chavi Garden | Khu du lịch Chavi

[SUMMARY]
Khu du lịch sinh thái giáo dục trải nghiệm thuộc hệ sinh thái Chanh Việt.

[CONTENT]
- Địa chỉ: Quốc lộ N2, ấp 5, xã Thạnh Lợi, tỉnh Tây Ninh.
- Diện tích: hơn 40 héc ta.

[SERVICES]
- Tham quan, vui chơi, thư giãn và lưu trú.

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''',
                  },
                ],
              });
            }
            return _toolError(payload['id'], 'unexpected tool');
          },
        );

        await repository!.connect(_chatConfig());
        final result = await repository!.sendMessage(
          'Tôi muốn thông tin về Chami Garden',
        );

        expect(result.isSuccess, isTrue);
        final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
        final text = payload['text'] as String;
        expect(text, contains('[DU_LIEU_NOI_BO_LIEN_QUAN]'));
        expect(text, contains('CHAVI GARDEN'));
        expect(text, isNot(contains('[GOI_Y_TAI_LIEU_NOI_BO]')));
      },
    );

    test(
      'sendMessage keeps food safety section in knowledge evidence',
      () async {
        repository = ChatRepositoryImpl(
          sessionCoordinator: sessionCoordinator,
          mcpHandleMessage: (payload) async {
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'company_profile.txt',
                    'title': 'Công ty Chanh Việt',
                    'doc_type': 'company_profile',
                    'score': 94,
                    'coverage_ratio': 0.5,
                    'confidence': 'medium',
                    'exact_match': false,
                    'field_hits': <String>['food_safety', 'summary', 'content'],
                    'match_reasons': <String>[
                      'partial_token_coverage',
                      'structured_kdoc',
                    ],
                    'summary': 'Doanh nghiệp chế biến sản phẩm từ chanh.',
                    'usage': '',
                    'safety_note':
                        'Thông tin mang tính giới thiệu doanh nghiệp.',
                    'snippet': 'An toàn thực phẩm: HACCP, HALAL, FDA.',
                    'content': '''
=== KDOC:v1 ===
[DOC_ID]
company_profile

[DOC_TYPE]
company_profile

[TITLE]
Công ty Chanh Việt

[ALIASES]
Chanh Việt | Chavi

[SUMMARY]
Doanh nghiệp chế biến sản phẩm từ chanh.

[CONTENT]
- Lĩnh vực hoạt động: trồng trọt, chế biến và phân phối sản phẩm từ chanh.

[FOOD_SAFETY]
- Giấy chứng nhận: HACCP, HALAL, FDA
- Sản phẩm đạt OCOP 4 sao

[LAST_UPDATED]
2026-03-15
=== END_KDOC ===
''',
                  },
                ],
              });
            }
            return _toolError(payload['id'], 'unexpected tool');
          },
        );

        await repository!.connect(_chatConfig());
        final result = await repository!.sendMessage(
          'cho tôi thông tin về an toàn thực phẩm',
        );

        expect(result.isSuccess, isTrue);
        final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
        final text = payload['text'] as String;
        expect(text, contains('An toàn thực phẩm'));
        expect(text, contains('[FOOD_SAFETY]'));
        expect(text, contains('HACCP, HALAL, FDA'));
        expect(text, contains('Vi day la cau hoi ve an toan thuc pham'));
        expect(text, contains('khong duoc noi la "khong co thong tin"'));
      },
    );

    test(
      'sendMessage falls back to clarification prompt when match is weak',
      () async {
        repository = ChatRepositoryImpl(
          sessionCoordinator: sessionCoordinator,
          mcpHandleMessage: (payload) async {
            final params = payload['params'];
            final name = params is Map ? params['name'] : null;
            if (name == 'self.knowledge.search') {
              return _toolResult(payload['id'], <String, Object?>{
                'results': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'company.txt',
                    'title': 'Hồ sơ Chanh Việt',
                    'doc_type': 'company_profile',
                    'score': 18,
                    'coverage_ratio': 0.2,
                    'confidence': 'low',
                    'exact_match': false,
                    'field_hits': <String>['title'],
                    'match_reasons': <String>['partial_token_coverage'],
                    'summary': 'Thông tin tổng quan doanh nghiệp.',
                    'usage': '',
                    'safety_note': '',
                    'snippet': 'Thông tin doanh nghiệp.',
                    'content': 'Thong tin tong quan.',
                  },
                ],
              });
            }
            if (name == 'self.knowledge.list_documents') {
              return _toolResult(payload['id'], <String, Object?>{
                'documents': <Map<String, Object?>>[
                  <String, Object?>{'name': 'bot_chanh.txt'},
                  <String, Object?>{'name': 'tinh_dau_chanh.txt'},
                ],
              });
            }
            return _toolError(payload['id'], 'unexpected tool');
          },
        );

        await repository!.connect(_chatConfig());
        final result = await repository!.sendMessage(
          'Tôi cần thông tin sản phẩm phù hợp',
        );

        expect(result.isSuccess, isTrue);
        final payload = jsonDecode(sessionCoordinator.sentTexts.last) as Map;
        final text = payload['text'] as String;
        expect(text, contains('[GOI_Y_TAI_LIEU_NOI_BO]'));
        expect(text, contains('- bot_chanh.txt'));
        expect(text, isNot(contains('[DU_LIEU_NOI_BO_LIEN_QUAN]')));
        expect(text, contains('Chua co bang chung du manh'));
      },
    );
  });
}

Map<String, dynamic> _toolResult(Object? id, Map<String, Object?> payload) {
  return <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'result': <String, dynamic>{
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': jsonEncode(payload)},
      ],
      'isError': false,
    },
  };
}

Map<String, dynamic> _toolError(Object? id, String message) {
  return <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'error': <String, dynamic>{'message': message},
  };
}

ChatConfig _chatConfig() {
  return ChatConfig(
    url: 'ws://127.0.0.1:8080',
    accessToken: 'token',
    deviceInfo: DummyDataGenerator.generate(),
    transportType: TransportType.webSockets,
    mqttConfig: null,
  );
}

class _CaptureSessionCoordinator implements SessionCoordinator {
  final StreamController<Map<String, dynamic>> _incomingJsonController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _incomingAudioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _incomingLevelController =
      StreamController<double>.broadcast();
  final StreamController<double> _outgoingLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> _errorsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();
  final List<String> sentTexts = <String>[];

  @override
  Stream<Map<String, dynamic>> get incomingJson =>
      _incomingJsonController.stream;

  @override
  Stream<Uint8List> get incomingAudio => _incomingAudioController.stream;

  @override
  Stream<double> get incomingLevel => _incomingLevelController.stream;

  @override
  Stream<double> get outgoingLevel => _outgoingLevelController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Stream<bool> get speaking => _speakingController.stream;

  @override
  int get serverSampleRate => 16000;

  @override
  ListeningMode get listeningMode => ListeningMode.autoStop;

  @override
  void setPlaybackSuppressed(bool suppressed) {}

  @override
  Future<bool> connect(TransportClient transport) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> playChime() async {}

  @override
  Future<void> sendAudio(List<int> data) async {}

  @override
  Future<void> sendText(String text) async {
    sentTexts.add(text);
  }

  @override
  Future<void> startListening({bool enableMic = true}) async {}

  @override
  Future<void> stopListening() async {}

  @override
  void setListeningMode(ListeningMode mode) {}
}
