import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/capabilities/protocol/protocol.dart';
import 'package:voicebot/capabilities/voice/session_coordinator.dart';
import 'package:voicebot/capabilities/voice/transport_client.dart';
import 'package:voicebot/features/chat/infrastructure/repositories/chat_repository_impl.dart';

void main() {
  group('ChatRepositoryImpl.getRelatedImagesForQuery', () {
    late ChatRepositoryImpl repository;
    late List<Map<String, dynamic>> requests;
    late Future<Map<String, dynamic>?> Function(Map<String, dynamic>)
    mockMcpHandle;

    setUp(() {
      requests = <Map<String, dynamic>>[];
      mockMcpHandle = (payload) async {
        requests.add(Map<String, dynamic>.from(payload));
        final params = payload['params'];
        final name = params is Map ? params['name'] : null;
        if (name == 'self.knowledge.search_images') {
          return <String, dynamic>{
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result': <String, dynamic>{
              'content': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'text',
                  'text': jsonEncode(<String, Object?>{
                    'query': 'bot chanh',
                    'matched_docs': 2,
                    'images': <Map<String, Object?>>[
                      <String, Object?>{
                        'id': 'img_1',
                        'doc_name': 'doc_a.txt',
                        'file_name': 'a.jpg',
                        'mime_type': 'image/jpeg',
                        'bytes': 200,
                        'created_at': '2026-02-08T00:00:00.000Z',
                        'score': 90,
                        'url': '/api/documents/image/content?id=img_1',
                      },
                      <String, Object?>{
                        'id': 'img_shared',
                        'doc_name': 'doc_a.txt',
                        'file_name': 'shared-a.jpg',
                        'mime_type': 'image/jpeg',
                        'bytes': 210,
                        'created_at': '2026-02-08T00:10:00.000Z',
                        'score': 75,
                        'url': '/api/documents/image/content?id=img_shared',
                      },
                      <String, Object?>{
                        'id': 'img_shared',
                        'doc_name': 'doc_b.txt',
                        'file_name': 'shared-b.jpg',
                        'mime_type': 'image/jpeg',
                        'bytes': 220,
                        'created_at': '2026-02-08T00:11:00.000Z',
                        'score': 60,
                        'url': '/api/documents/image/content?id=img_shared',
                      },
                    ],
                  }),
                },
              ],
              'isError': false,
            },
          };
        }
        return <String, dynamic>{
          'jsonrpc': '2.0',
          'id': payload['id'],
          'error': <String, dynamic>{'message': 'unknown tool'},
        };
      };

      repository = ChatRepositoryImpl(
        sessionCoordinator: _FakeSessionCoordinator(),
        webHostBaseUriResolver: () => Uri.parse('http://127.0.0.1:8080/'),
        mcpHandleMessage: mockMcpHandle,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test(
      'maps MCP search_images -> related images, deduplicates and respects maxImages',
      () async {
        final images = await repository.getRelatedImagesForQuery(
          'bot chanh',
          topK: 3,
          maxImages: 2,
        );

        expect(images.length, 2);
        expect(images[0].id, 'img_1');
        expect(images[1].id, 'img_shared');
        expect(images[0].score >= images[1].score, isTrue);
        expect(images[0].url.startsWith('http://127.0.0.1:8080/'), isTrue);
        expect(requests, isNotEmpty);
        final last = requests.last;
        final params = last['params'] as Map<String, dynamic>;
        final args = params['arguments'] as Map<String, dynamic>;
        expect(params['name'], 'self.knowledge.search_images');
        expect(args['query'], 'bot chanh');
        expect(args['top_k'], 3);
        expect(args['max_images'], 2);
      },
    );

    test('returns empty list when MCP tool fails', () async {
      repository.dispose();
      repository = ChatRepositoryImpl(
        sessionCoordinator: _FakeSessionCoordinator(),
        webHostBaseUriResolver: () => Uri.parse('http://127.0.0.1:8080/'),
        mcpHandleMessage: (payload) async => <String, dynamic>{
          'jsonrpc': '2.0',
          'id': payload['id'],
          'error': <String, dynamic>{'message': 'tool failed'},
        },
      );

      final images = await repository.getRelatedImagesForQuery(
        'query',
        topK: 2,
        maxImages: 4,
      );
      expect(images, isEmpty);
    });
  });
}

class _FakeSessionCoordinator implements SessionCoordinator {
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
  Future<bool> connect(TransportClient transport) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendAudio(List<int> data) async {}

  @override
  Future<void> sendText(String text) async {}

  @override
  Future<void> startListening({bool enableMic = true}) async {}

  @override
  Future<void> stopListening() async {}

  @override
  void setListeningMode(ListeningMode mode) {}
}
